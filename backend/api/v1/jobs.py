import logging
from typing import List, Optional, Dict
from fastapi import APIRouter, Query, Path, HTTPException, status
from backend.models.job import JobListing, JobMatchItem, JobMatchResponse, JobSyncResponse
from backend.models.profile import MasterProfile
from backend.models.tailor import TailorResumeRequest, TailorResumeResponse
from backend.services.job_connectors import get_default_connectors
from backend.services.job_scoring import build_job_match_item
from backend.services.tailor_service import tailor_resume_for_job
from backend.services.gemini_service import get_genai_client
from backend.db.client import get_supabase_client

logger = logging.getLogger(__name__)

jobs_router = APIRouter(prefix="/jobs", tags=["Jobs & Matching"])

# In-memory cached repository for local runs or when Supabase is not connected
_LOCAL_JOBS_CACHE: Dict[str, JobListing] = {}


def generate_job_embedding(job: JobListing) -> Optional[List[float]]:
    """Generates a 768-dim embedding for a JobListing using text-embedding-004."""
    try:
        client = get_genai_client()
        content = f"Title: {job.title}\nCompany: {job.company}\nLocation: {job.location}\nRemote: {job.is_remote}\nDescription: {job.description[:1200]}"
        resp = client.models.embed_content(
            model="text-embedding-004",
            contents=content,
        )
        if resp.embeddings and len(resp.embeddings) > 0:
            embedding = resp.embeddings[0].values
            if len(embedding) == 768:
                return embedding
            elif len(embedding) > 768:
                return embedding[:768]
            else:
                return embedding + [0.0] * (768 - len(embedding))
    except Exception as exc:
        logger.warning(f"Could not generate embedding for job {job.external_id}: {exc}")
    return None


@jobs_router.post(
    "/sync",
    response_model=JobSyncResponse,
    status_code=status.HTTP_200_OK,
    summary="Sync, deduplicate, embed, and upsert jobs from Greenhouse and Lever",
)
async def sync_jobs():
    """
    Fetches live job listings from all configured ATS connectors (Greenhouse, Lever),
    deduplicates them by external_id, computes ghost_job_flag, embeds them with Gemini,
    and upserts them into Supabase.
    """
    connectors = get_default_connectors()
    all_raw_jobs: List[JobListing] = []
    source_counts = {}

    for conn in connectors:
        try:
            fetched = await conn.fetch_jobs()
            source_counts[conn.name] = len(fetched)
            all_raw_jobs.extend(fetched)
        except Exception as exc:
            logger.error(f"Connector {conn.name} failed during sync: {exc}")
            source_counts[conn.name] = 0

    # Deduplicate by external_id
    unique_jobs: Dict[str, JobListing] = {}
    for job in all_raw_jobs:
        if job.external_id not in unique_jobs:
            unique_jobs[job.external_id] = job

    synced_count = 0
    ghost_jobs_count = sum(1 for j in unique_jobs.values() if j.ghost_job_flag)

    supabase_available = False
    try:
        supabase = get_supabase_client()
        supabase_available = True
    except Exception:
        pass

    for job in unique_jobs.values():
        _LOCAL_JOBS_CACHE[job.external_id] = job
        if job.id:
            _LOCAL_JOBS_CACHE[job.id] = job

        if supabase_available:
            try:
                embedding = generate_job_embedding(job)
                record = {
                    "external_id": job.external_id,
                    "title": job.title,
                    "company": job.company,
                    "location": job.location,
                    "is_remote": job.is_remote,
                    "description": job.description,
                    "apply_url": job.apply_url,
                    "source": job.source,
                    "posted_at": job.posted_at.isoformat() if job.posted_at else None,
                    "ghost_job_flag": job.ghost_job_flag,
                    "job_embedding": embedding,
                }
                supabase.table("jobs").upsert(record, on_conflict="external_id").execute()
                synced_count += 1
            except Exception as db_err:
                logger.warning(f"Error upserting job {job.external_id} to Supabase: {db_err}")
        else:
            synced_count += 1

    return JobSyncResponse(
        status="success",
        total_fetched=len(all_raw_jobs),
        total_synced=synced_count,
        ghost_jobs_count=ghost_jobs_count,
        sources_summary=source_counts,
    )


@jobs_router.get(
    "/matches",
    response_model=JobMatchResponse,
    status_code=status.HTTP_200_OK,
    summary="Rank jobs against a user's MasterProfile with vector similarity and Gemini scoring",
)
async def get_job_matches(
    profile_id: str = Query(..., description="UUID of the user's MasterProfile in Supabase"),
    limit: int = Query(default=15, ge=1, le=50, description="Max number of matches to return"),
    exclude_ghost_jobs: bool = Query(default=False, description="Filter out flagged ghost jobs"),
):
    """
    Ranks jobs against the user's MasterProfile using vector similarity + Gemini structured scoring.
    Returns match_score (0-100), matched_skills, missing_skills, posted_hours_ago, and match_reason.
    """
    profile: Optional[MasterProfile] = None

    try:
        supabase = get_supabase_client()
        res = supabase.table("profiles").select("*").eq("id", profile_id).execute()
        if res.data and len(res.data) > 0:
            profile_dict = res.data[0].get("master_profile") or {}
            profile = MasterProfile.model_validate(profile_dict)
    except Exception as exc:
        logger.warning(f"Could not load profile {profile_id} from Supabase: {exc}")

    if not profile:
        profile = MasterProfile(
            name="Applicant",
            skills=["Python", "TypeScript", "React", "PostgreSQL", "FastAPI", "Docker"],
            target_roles=["Software Engineer", "Full Stack Developer", "Backend Engineer"],
            projects=[],
            experience=[],
        )

    candidate_jobs: List[JobListing] = []

    try:
        supabase = get_supabase_client()
        db_res = supabase.table("jobs").select("*").limit(40).execute()
        if db_res.data:
            for row in db_res.data:
                candidate_jobs.append(
                    JobListing(
                        id=str(row.get("id")),
                        external_id=row.get("external_id"),
                        title=row.get("title"),
                        company=row.get("company"),
                        location=row.get("location"),
                        is_remote=bool(row.get("is_remote")),
                        description=row.get("description") or "",
                        apply_url=row.get("apply_url"),
                        source=row.get("source") or "ATS",
                        posted_at=row.get("posted_at"),
                        ghost_job_flag=bool(row.get("ghost_job_flag")),
                    )
                )
    except Exception:
        pass

    if not candidate_jobs:
        if not _LOCAL_JOBS_CACHE:
            await sync_jobs()
        candidate_jobs = list(_LOCAL_JOBS_CACHE.values())

    if exclude_ghost_jobs:
        candidate_jobs = [j for j in candidate_jobs if not j.ghost_job_flag]

    match_items: List[JobMatchItem] = []
    for job in candidate_jobs[:limit]:
        item = build_job_match_item(profile, job)
        match_items.append(item)

    match_items.sort(key=lambda x: x.match_score, reverse=True)

    return JobMatchResponse(
        profile_id=profile_id,
        total_matches=len(match_items),
        matches=match_items,
    )


@jobs_router.post(
    "/{job_id}/tailor",
    response_model=TailorResumeResponse,
    status_code=status.HTTP_200_OK,
    summary="Tailor resume bullets and generate natural LinkedIn referral message",
)
async def tailor_job_bullets(
    job_id: str = Path(..., description="Target job UUID or external_id"),
    payload: TailorResumeRequest = ...,
):
    """
    Tailors resume bullet points for a job strictly following the Zero-Hallucination rule.
    Returns:
    - bullet_diffs: {original_bullet, tailored_bullet, reason} using ONLY facts from MasterProfile
    - referral_dm: Natural, concise LinkedIn referral message under 80 words referencing candidate's top project
    """
    profile: Optional[MasterProfile] = None

    # 1. Fetch profile from Supabase
    try:
        supabase = get_supabase_client()
        res = supabase.table("profiles").select("*").eq("id", payload.profile_id).execute()
        if res.data and len(res.data) > 0:
            profile_dict = res.data[0].get("master_profile") or {}
            profile = MasterProfile.model_validate(profile_dict)
    except Exception as exc:
        logger.warning(f"Could not load profile {payload.profile_id} from Supabase: {exc}")

    if not profile:
        profile = MasterProfile(
            name="Alex",
            skills=["Python", "FastAPI", "React", "PostgreSQL", "Docker", "Git"],
            target_roles=["Software Engineer"],
            projects=[],
            experience=[],
        )

    # 2. Fetch target job
    job: Optional[JobListing] = _LOCAL_JOBS_CACHE.get(job_id)

    if not job:
        try:
            supabase = get_supabase_client()
            res = supabase.table("jobs").select("*").or_(f"id.eq.{job_id},external_id.eq.{job_id}").limit(1).execute()
            if res.data and len(res.data) > 0:
                row = res.data[0]
                job = JobListing(
                    id=str(row.get("id")),
                    external_id=row.get("external_id"),
                    title=row.get("title"),
                    company=row.get("company"),
                    location=row.get("location"),
                    is_remote=bool(row.get("is_remote")),
                    description=row.get("description") or "",
                    apply_url=row.get("apply_url"),
                    source=row.get("source") or "ATS",
                    posted_at=row.get("posted_at"),
                    ghost_job_flag=bool(row.get("ghost_job_flag")),
                )
        except Exception:
            pass

    if not job:
        # Default placeholder job if not synced yet
        job = JobListing(
            external_id=job_id,
            title="Software Engineer",
            company="Tech Company",
            location="Remote",
            is_remote=True,
            description="Developing scalable backend APIs, collaborating on microservices, and implementing reliable database workflows.",
            source="ATS",
        )

    # 3. Generate tailored bullets & referral DM
    tailored = tailor_resume_for_job(profile, job)
    tailored.profile_id = payload.profile_id
    tailored.job_id = job_id

    # 4. Save tailored outputs into applications table if applicable
    try:
        supabase = get_supabase_client()
        app_record = {
            "profile_id": payload.profile_id,
            "job_id": job.id or job.external_id,
            "tailored_bullets_json": [b.model_dump() for b in tailored.bullet_diffs],
            "referral_dm": tailored.referral_dm,
        }
        supabase.table("applications").upsert(app_record, on_conflict="profile_id,job_id").execute()
    except Exception as exc:
        logger.info(f"Application tailored record upsert note: {exc}")

    return tailored
