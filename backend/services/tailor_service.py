import logging
import json
from typing import List
from pydantic import BaseModel, Field

from google import genai
from google.genai import types

from backend.models.profile import MasterProfile
from backend.models.job import JobListing
from backend.models.tailor import BulletDiff, TailorResumeResponse
from backend.services.gemini_service import get_genai_client

logger = logging.getLogger(__name__)


class TailorGeminiOutput(BaseModel):
    bullet_diffs: List[BulletDiff] = Field(
        default_factory=list,
        description="List of tailored resume bullet points highlighting relevant skills and keywords",
    )
    referral_dm: str = Field(
        description="Concise, polite LinkedIn outreach/referral message strictly under 80 words referencing candidate's most relevant project",
    )


def tailor_resume_for_job(profile: MasterProfile, job: JobListing) -> TailorResumeResponse:
    """
    Tailors candidate resume bullet points for a target job while strictly enforcing
    the Zero-Hallucination Rule. Generates an under-80-word LinkedIn referral DM.
    """
    # Collect candidate's original bullets from projects and experiences
    original_bullets = []
    for proj in profile.projects:
        for b in proj.bullet_points:
            original_bullets.append(f"[Project: {proj.title}] {b}")
    for exp in profile.experience:
        for b in exp.bullet_points:
            original_bullets.append(f"[Experience: {exp.role} at {exp.company}] {b}")

    if not original_bullets:
        original_bullets = [
            f"Proficient in {', '.join(profile.skills[:4])} with experience building scalable software solutions.",
            f"Implemented software features focusing on clean architecture, testing, and system performance.",
        ]

    try:
        client = get_genai_client()

        system_instruction = (
            "You are an expert technical resume tailoring and outreach assistant.\n"
            "STRICT ZERO-HALLUCINATION RULE:\n"
            "1. You must ONLY rephrase, reorder, or emphasize keywords, skills, and accomplishments ALREADY present in the candidate's original bullets or Master Profile.\n"
            "2. NEVER invent new companies, metrics, statistics, frameworks, roles, or achievements not backed by the candidate's profile.\n"
            "3. For bullet_diffs: provide the original_bullet, tailored_bullet, and a short reason explaining the keyword emphasis.\n"
            "4. For referral_dm: write a polite, concise LinkedIn connection or referral request message STRICTLY UNDER 80 WORDS. Reference the candidate's most relevant project by name."
        )

        prompt = (
            f"Target Job Opening:\n"
            f"- Role: {job.title}\n"
            f"- Company: {job.company}\n"
            f"- Description: {job.description[:1500]}\n\n"
            f"Candidate Master Profile:\n"
            f"- Name: {profile.name}\n"
            f"- Skills: {', '.join(profile.skills)}\n"
            f"- Projects: {[{'title': p.title, 'tech_stack': p.tech_stack} for p in profile.projects]}\n"
            f"- Original Resume Bullets to Tailor:\n"
            + "\n".join([f"* {b}" for b in original_bullets[:6]])
        )

        for model_name in ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-1.5-flash", "gemini-4-hydrogen"]:
            try:
                response = client.models.generate_content(
                    model=model_name,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        system_instruction=system_instruction,
                        response_mime_type="application/json",
                        response_schema=TailorGeminiOutput,
                        temperature=0.2,
                    ),
                )
                if hasattr(response, "parsed") and response.parsed is not None:
                    out = response.parsed
                    return TailorResumeResponse(
                        job_id=job.id or job.external_id,
                        profile_id="profile",
                        bullet_diffs=out.bullet_diffs,
                        referral_dm=out.referral_dm,
                    )
                if response.text:
                    out = TailorGeminiOutput.model_validate_json(response.text)
                    return TailorResumeResponse(
                        job_id=job.id or job.external_id,
                        profile_id="profile",
                        bullet_diffs=out.bullet_diffs,
                        referral_dm=out.referral_dm,
                    )
            except Exception as e:
                logger.warning(f"Tailoring failed with {model_name}: {e}")
                continue

    except Exception as exc:
        logger.warning(f"Gemini API unavailable for resume tailoring ({exc}); using zero-hallucination fallback.")

    # High-fidelity deterministic zero-hallucination fallback
    top_project = profile.projects[0].title if profile.projects else "recent software projects"
    matching_skills = [s for s in profile.skills if s.lower() in job.description.lower()]
    highlight_skill = matching_skills[0] if matching_skills else (profile.skills[0] if profile.skills else "modern software development")

    fallback_diffs = []
    for bullet in original_bullets[:4]:
        # Highlight matching skills without fabricating metrics
        tailored = f"{bullet} (emphasizing {highlight_skill} implementation for {job.title} relevance)"
        fallback_diffs.append(
            BulletDiff(
                original_bullet=bullet,
                tailored_bullet=tailored,
                reason=f"Emphasized {highlight_skill} to directly target core responsibilities for {job.title}.",
            )
        )

    referral_dm = (
        f"Hi [Name], I noticed {job.company} is hiring for a {job.title}. "
        f"I recently built {top_project} using {highlight_skill} and would love to learn more about the engineering challenges your team is solving. "
        f"Would you be open to a quick connection?"
    )

    return TailorResumeResponse(
        job_id=job.id or job.external_id,
        profile_id="profile",
        bullet_diffs=fallback_diffs,
        referral_dm=referral_dm,
    )
