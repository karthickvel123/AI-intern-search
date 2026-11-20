from typing import List, Optional
from pydantic import BaseModel, Field


class EducationItem(BaseModel):
    institution: str = Field(description="Name of the university, college, or school")
    degree: str = Field(description="Degree and major, e.g., B.S. in Computer Science")
    graduation_year: Optional[str] = Field(default=None, description="Year or expected year of graduation")
    gpa: Optional[str] = Field(default=None, description="GPA if explicitly provided in resume")


class ProjectItem(BaseModel):
    title: str = Field(description="Project title or system name")
    tech_stack: List[str] = Field(default_factory=list, description="List of technologies, frameworks, or tools used")
    bullet_points: List[str] = Field(
        default_factory=list,
        description="Key accomplishments, metrics, or technical implementation details",
    )
    link: Optional[str] = Field(default=None, description="GitHub or live URL if available")


class ExperienceItem(BaseModel):
    company: str = Field(description="Company, startup, or organization name")
    role: str = Field(description="Title or position held")
    location: Optional[str] = Field(default=None, description="Location (e.g. 'San Francisco, CA' or 'Remote')")
    start_date: Optional[str] = Field(default=None, description="Start date (e.g. 'May 2023')")
    end_date: Optional[str] = Field(default=None, description="End date (e.g. 'August 2023' or 'Present')")
    bullet_points: List[str] = Field(
        default_factory=list,
        description="Key duties, achievements, and impact metrics",
    )


class MasterProfile(BaseModel):
    name: str = Field(description="Candidate's full name")
    email: Optional[str] = Field(default=None, description="Candidate's email address")
    phone: Optional[str] = Field(default=None, description="Candidate's phone number")
    location: Optional[str] = Field(default=None, description="Current city/country or preferred location")
    education: List[EducationItem] = Field(default_factory=list, description="Education history")
    skills: List[str] = Field(
        default_factory=list,
        description="Technical skills, languages, libraries, and developer tools",
    )
    projects: List[ProjectItem] = Field(
        default_factory=list,
        description="Software projects and technical builds",
    )
    experience: List[ExperienceItem] = Field(
        default_factory=list,
        description="Internships and professional work experience",
    )
    target_roles: List[str] = Field(
        default_factory=list,
        description="Target job or internship titles inferred from candidate profile",
    )


class ResumeParseResponse(BaseModel):
    profile_id: Optional[str] = Field(
        default=None,
        description="UUID of the stored profile in Supabase (if database is connected)",
    )
    master_profile: MasterProfile
    embedding_dimension: int = Field(default=768, description="Dimension of the generated resume vector")
    saved_to_db: bool = Field(default=False, description="Whether the profile was persisted to Supabase")
    message: str = Field(default="Resume parsed successfully")
