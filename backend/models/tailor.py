from typing import List
from pydantic import BaseModel, Field


class BulletDiff(BaseModel):
    original_bullet: str = Field(description="The original bullet point from candidate's profile")
    tailored_bullet: str = Field(
        description="Tailored bullet point rephrasing or emphasizing relevant keywords without inventing any facts"
    )
    reason: str = Field(description="Explanation of how this adjustment aligns with the job requirements")


class TailorResumeRequest(BaseModel):
    profile_id: str = Field(description="UUID of the candidate's MasterProfile")


class TailorResumeResponse(BaseModel):
    job_id: str = Field(description="Target job ID")
    profile_id: str = Field(description="Target candidate profile ID")
    bullet_diffs: List[BulletDiff] = Field(default_factory=list, description="Original vs tailored bullet points")
    referral_dm: str = Field(
        description="Concise, natural LinkedIn referral message under 80 words referencing the candidate's most relevant project"
    )
