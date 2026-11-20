import logging
from datetime import datetime, timezone
from typing import Dict, List, Optional
from fastapi import APIRouter, Query, Path, HTTPException, status
from backend.models.tracker import (
    ApplicationItem,
    ApplicationStatus,
    TrackerListResponse,
    TrackerUpdateRequest,
)
from backend.db.client import get_supabase_client
from backend.api.v1.jobs import _LOCAL_JOBS_CACHE

logger = logging.getLogger(__name__)

tracker_router = APIRouter(prefix="/tracker", tags=["Application Tracker"])

# Local in-memory store for tracker entries (fallback & testing)
_LOCAL_TRACKER_STORE: Dict[str, ApplicationItem] = {}


@tracker_router.get(
    "",
    response_model=TrackerListResponse,
    status_code=status.HTTP_200_OK,
    summary="List all tracked applications for a profile",
)
async def get_tracked_applications(
    profile_id: str = Query(..., description="UUID of the user's MasterProfile"),
    status_filter: Optional[ApplicationStatus] = Query(default=None, description="Filter by status"),
):
    """
    Returns all tracked job applications for a profile across pipeline stages
    ('saved', 'applied', 'interview', 'offer', 'rejected').
    """
    applications: List[ApplicationItem] = []

    # 1. Fetch from Supabase applications table if connected
    try:
        supabase = get_supabase_client()
        query = supabase.table("applications").select("*, jobs(*)").eq("profile_id", profile_id)
        if status_filter:
            query = query.eq("status", status_filter.value)
        res = query.order("updated_at", desc=True).execute()

        if res.data:
            for row in res.data:
                job_data = row.get("jobs")
                app_item = ApplicationItem(
                    id=str(row.get("id")),
                    profile_id=row.get("profile_id"),
                    job_id=row.get("job_id"),
                    status=ApplicationStatus(row.get("status", "saved")),
                    tailored_bullets_json=row.get("tailored_bullets_json"),
                    referral_dm=row.get("referral_dm"),
                    notes=row.get("notes"),
                    created_at=row.get("created_at"),
                    updated_at=row.get("updated_at"),
                )
                if job_data:
                    from backend.models.job import JobListing
                    app_item.job = JobListing.model_validate(job_data)
                applications.append(app_item)
    except Exception as exc:
        logger.warning(f"Could not load applications from Supabase ({exc}); checking local store.")

    # 2. If no DB applications found, fallback to local store
    if not applications:
        for key, item in _LOCAL_TRACKER_STORE.items():
            if item.profile_id == profile_id:
                if status_filter and item.status != status_filter:
                    continue
                applications.append(item)

    return TrackerListResponse(
        profile_id=profile_id,
        total=len(applications),
        applications=applications,
    )


@tracker_router.patch(
    "/{job_id}",
    response_model=ApplicationItem,
    status_code=status.HTTP_200_OK,
    summary="Save a job or update its application pipeline stage",
)
async def update_application_status(
    job_id: str = Path(..., description="Target job ID or external_id"),
    payload: TrackerUpdateRequest = ...,
):
    """
    Saves a job or updates its application status ('saved', 'applied', 'interview', 'offer', 'rejected')
    in the Supabase applications table.
    """
    now = datetime.now(timezone.utc)
    app_key = f"{payload.profile_id}:{job_id}"

    # Associated job if present in cache
    associated_job = _LOCAL_JOBS_CACHE.get(job_id)

    app_entry = ApplicationItem(
        profile_id=payload.profile_id,
        job_id=job_id,
        status=payload.status,
        notes=payload.notes,
        job=associated_job,
        created_at=now,
        updated_at=now,
    )

    # Persist in local store
    _LOCAL_TRACKER_STORE[app_key] = app_entry

    # Persist in Supabase
    try:
        supabase = get_supabase_client()
        record = {
            "profile_id": payload.profile_id,
            "job_id": job_id,
            "status": payload.status.value,
        }
        res = supabase.table("applications").upsert(
            record,
            on_conflict="profile_id,job_id"
        ).execute()

        if res.data and len(res.data) > 0:
            app_entry.id = str(res.data[0].get("id"))
    except Exception as exc:
        logger.warning(f"Supabase applications upsert note: {exc}")

    return app_entry
