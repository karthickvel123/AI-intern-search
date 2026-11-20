from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class JobListing(BaseModel):
    id: Optional[str] = Field(default=None, description="Internal database UUID")
    external_id: str = Field(description="Unique external ID (e.g. greenhouse:figma:12345)")
    title: str = Field(description="Job title")
    company: str = Field(description="Company name")
    location: Optional[str] = Field(default=None, description="Job location")
    is_remote: bool = Field(default=False, description="Whether the position is remote-friendly")
    description: str = Field(description="Plain text job description and requirements")
    apply_url: Optional[str] = Field(default=None, description="Direct URL to apply for the position")
    source: str = Field(description="Source ATS or board (e.g. Greenhouse, Lever, JSearch)")
    posted_at: Optional[datetime] = Field(default=None, description="Publication timestamp")
    ghost_job_flag: bool = Field(
        default=False,
        description="True if job is older than 30 days or titled Intern while requiring 3+ years experience",
    )
    tags: List[str] = Field(default_factory=list, description="Extracted technology and skill tags")


class JobMatchItem(BaseModel):
    id: Optional[str] = Field(default=None, description="Job ID")
    external_id: str = Field(description="External ID")
    title: str = Field(description="Job title")
    company: str = Field(description="Company name")
    location: Optional[str] = Field(default=None, description="Location")
    is_remote: bool = Field(default=False, description="Remote flag")
    apply_url: Optional[str] = Field(default=None, description="Application link")
    source: str = Field(description="Source ATS")
    match_score: int = Field(ge=0, le=100, description="Match score from 0 to 100")
    matched_skills: List[str] = Field(default_factory=list, description="Skills present in both profile and job")
    missing_skills: List[str] = Field(default_factory=list, description="Job required skills missing from profile")
    posted_hours_ago: Optional[float] = Field(default=None, description="Hours since posting")
    ghost_job_flag: bool = Field(default=False, description="Ghost job flag indicator")
    match_reason: str = Field(description="Concise 1-sentence explanation of the match rationale")


class JobMatchResponse(BaseModel):
    profile_id: str = Field(description="Target profile ID")
    total_matches: int = Field(description="Number of matches returned")
    matches: List[JobMatchItem] = Field(default_factory=list)


class JobSyncResponse(BaseModel):
    status: str = Field(default="success")
    total_fetched: int = Field(description="Total raw jobs fetched across all connectors")
    total_synced: int = Field(description="Total unique jobs upserted/persisted")
    ghost_jobs_count: int = Field(description="Number of jobs flagged as ghost jobs")
    sources_summary: dict = Field(default_factory=dict, description="Summary per connector source")
