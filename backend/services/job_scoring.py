import logging
import json
from datetime import datetime, timezone
from typing import List, Optional
from pydantic import BaseModel, Field

from google import genai
from google.genai import types

from backend.models.profile import MasterProfile
from backend.models.job import JobListing, JobMatchItem
from backend.services.gemini_service import get_genai_client

logger = logging.getLogger(__name__)


class GeminiScoringOutput(BaseModel):
    match_score: int = Field(ge=0, le=100, description="Match score between candidate profile and job requirements")
    matched_skills: List[str] = Field(default_factory=list, description="Skills explicitly found in both candidate profile and job")
    missing_skills: List[str] = Field(default_factory=list, description="Key skills required by job that candidate is missing")
    match_reason: str = Field(description="Strictly a single concise sentence explaining why this job matches the profile")


def score_job_with_gemini(profile: MasterProfile, job: JobListing) -> GeminiScoringOutput:
    """
    Evaluates a candidate's MasterProfile against a single JobListing using Gemini Structured Output.
    Enforces the Zero-Hallucination Rule: only credit skills actually in the MasterProfile.
    """
    try:
        client = get_genai_client()

        system_instruction = (
            "You are an objective technical recruiter evaluation engine.\n"
            "CRITICAL ZERO-HALLUCINATION RULE:\n"
            "- Only include skills in 'matched_skills' if they are EXPLICITLY present in the candidate's Master Profile.\n"
            "- Never hallucinate, assume, or extrapolate skills the candidate does not have.\n"
            "- Evaluate match_score (0-100) based on relevance of candidate skills, experience level, and project history to the job requirements.\n"
            "- Provide strictly a 1-sentence 'match_reason'."
        )

        prompt = (
            f"Candidate Master Profile:\n"
            f"- Name: {profile.name}\n"
            f"- Skills: {', '.join(profile.skills)}\n"
            f"- Target Roles: {', '.join(profile.target_roles)}\n"
            f"- Projects: {[p.title for p in profile.projects]}\n"
            f"- Experience: {[f'{e.role} at {e.company}' for e in profile.experience]}\n\n"
            f"Job Listing:\n"
            f"- Title: {job.title}\n"
            f"- Company: {job.company}\n"
            f"- Location: {job.location} (Remote: {job.is_remote})\n"
            f"- Description excerpt: {job.description[:1800]}\n"
        )

        for model_name in ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-1.5-flash", "gemini-4-hydrogen"]:
            try:
                response = client.models.generate_content(
                    model=model_name,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        system_instruction=system_instruction,
                        response_mime_type="application/json",
                        response_schema=GeminiScoringOutput,
                        temperature=0.1,
                    ),
                )
                if hasattr(response, "parsed") and response.parsed is not None:
                    return response.parsed
                if response.text:
                    return GeminiScoringOutput.model_validate_json(response.text)
            except Exception as e:
                logger.warning(f"Scoring attempt failed on model {model_name}: {e}")
                continue

    except Exception as exc:
        logger.warning(f"Gemini API unavailable for scoring ({exc}); using deterministic scoring fallback.")

    # Deterministic high-precision fallback if Gemini API is unreachable or key not set
    profile_skills_lower = {s.lower() for s in profile.skills}
    job_text = (job.title + " " + job.description).lower()
    
    matched = [s for s in profile.skills if s.lower() in job_text]
    
    # Common tech skills to check for missing
    common_skills = [
        "python", "react", "typescript", "javascript", "go", "java", "c++", "sql",
        "aws", "docker", "kubernetes", "pytorch", "graphql", "linux", "ci/cd"
    ]
    missing = [cs.capitalize() for cs in common_skills if cs in job_text and cs not in profile_skills_lower][:4]

    score = min(100, int((len(matched) / max(1, len(matched) + len(missing))) * 80 + (20 if job.is_remote else 10)))
    reason = f"Candidate matches key skills ({', '.join(matched[:3]) if matched else 'foundational concepts'}) relevant to {job.title} at {job.company}."

    return GeminiScoringOutput(
        match_score=score,
        matched_skills=matched[:6],
        missing_skills=missing[:4],
        match_reason=reason,
    )


def build_job_match_item(profile: MasterProfile, job: JobListing) -> JobMatchItem:
    """Combines job listing data with Gemini scoring and posted_hours_ago."""
    scoring = score_job_with_gemini(profile, job)

    hours_ago: Optional[float] = None
    if job.posted_at:
        now = datetime.now(timezone.utc)
        p_at = job.posted_at if job.posted_at.tzinfo else job.posted_at.replace(tzinfo=timezone.utc)
        delta = now - p_at
        hours_ago = round(max(0.0, delta.total_seconds() / 3600.0), 1)

    return JobMatchItem(
        id=job.id,
        external_id=job.external_id,
        title=job.title,
        company=job.company,
        location=job.location,
        is_remote=job.is_remote,
        apply_url=job.apply_url,
        source=job.source,
        match_score=scoring.match_score,
        matched_skills=scoring.matched_skills,
        missing_skills=scoring.missing_skills,
        posted_hours_ago=hours_ago,
        ghost_job_flag=job.ghost_job_flag,
        match_reason=scoring.match_reason,
    )
