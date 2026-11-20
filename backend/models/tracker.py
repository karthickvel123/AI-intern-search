from datetime import datetime
from enum import Enum
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field
from backend.models.job import JobListing


class ApplicationStatus(str, Enum):
    SAVED = "saved"
    APPLIED = "applied"
    INTERVIEW = "interview"
    OFFER = "offer"
    REJECTED = "rejected"


class ApplicationItem(BaseModel):
    id: Optional[str] = Field(default=None, description="Application entry UUID")
    profile_id: str = Field(description="Profile ID")
    job_id: str = Field(description="Job ID")
    status: ApplicationStatus = Field(default=ApplicationStatus.SAVED, description="Application progress status")
    tailored_bullets_json: Optional[Dict[str, Any]] = Field(default=None, description="Tailored bullets diffs")
    referral_dm: Optional[str] = Field(default=None, description="Generated LinkedIn referral message")
    notes: Optional[str] = Field(default=None, description="Candidate's personal interview notes or contacts")
    job: Optional[JobListing] = Field(default=None, description="Associated job listing data")
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class TrackerListResponse(BaseModel):
    profile_id: str
    total: int
    applications: List[ApplicationItem] = Field(default_factory=list)


class TrackerUpdateRequest(BaseModel):
    profile_id: str = Field(description="UUID of the candidate's profile")
    status: ApplicationStatus = Field(description="New status ('saved', 'applied', 'interview', 'offer', 'rejected')")
    notes: Optional[str] = Field(default=None, description="Optional interview or recruiter notes")
