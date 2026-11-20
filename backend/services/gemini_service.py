import os
import json
import logging
from typing import List
from dotenv import load_dotenv
from google import genai
from google.genai import types

from backend.models.profile import MasterProfile

logger = logging.getLogger(__name__)
load_dotenv()


def get_genai_client() -> genai.Client:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key or api_key == "your_gemini_api_key_here":
        raise ValueError(
            "GEMINI_API_KEY is not configured in backend/.env. "
            "Please provide a valid Gemini API key to run AI resume parsing."
        )
    return genai.Client(api_key=api_key)


def parse_resume_with_gemini(resume_text: str) -> MasterProfile:
    """
    Parses resume text into a structured MasterProfile using Gemini Structured JSON Output.
    Enforces the zero-hallucination rule.
    """
    client = get_genai_client()

    system_instruction = (
        "You are an expert technical resume parser for a high-precision job matching platform.\n"
        "ZERO-HALLUCINATION RULE:\n"
        "- Extract and organize ONLY facts, skills, education, companies, metrics, and achievements explicitly mentioned in the text.\n"
        "- NEVER invent or extrapolate companies, job roles, GPAs, numbers, or technologies not present in the source text.\n"
        "- If a field (like email or phone) is not present, set it to null.\n"
        "- For target_roles, infer realistic engineering/tech job titles strictly based on the candidate's documented skills and experience."
    )

    prompt = f"Please extract the candidate's complete profile from this resume text:\n\n{resume_text}"

    # Try gemini-2.5-flash or gemini-2.0-flash with structured schema
    candidate_models = ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-1.5-flash", "gemini-4-hydrogen"]
    last_err = None

    for model_name in candidate_models:
        try:
            response = client.models.generate_content(
                model=model_name,
                contents=prompt,
                config=types.GenerateContentConfig(
                    system_instruction=system_instruction,
                    response_mime_type="application/json",
                    response_schema=MasterProfile,
                    temperature=0.1,
                ),
            )

            # Response can be accessed via .text (JSON) or .parsed
            if hasattr(response, "parsed") and response.parsed is not None:
                return response.parsed
            
            if response.text:
                data = json.loads(response.text)
                return MasterProfile.model_validate(data)

        except Exception as exc:
            logger.warning(f"Failed with model {model_name}: {exc}")
            last_err = exc
            continue

    raise RuntimeError(f"All Gemini models failed to parse resume: {last_err}")


def generate_profile_embedding(profile: MasterProfile) -> List[float]:
    """
    Generates a 768-dimensional embedding vector for the MasterProfile using text-embedding-004.
    """
    client = get_genai_client()

    # Formulate a rich semantic representation of the profile
    skills_str = ", ".join(profile.skills)
    roles_str = ", ".join(profile.target_roles)
    projects_str = "; ".join([f"{p.title}: {', '.join(p.bullet_points)}" for p in profile.projects[:5]])
    experience_str = "; ".join([f"{e.role} at {e.company}: {', '.join(e.bullet_points)}" for e in profile.experience[:5]])

    semantic_profile_text = (
        f"Target Roles: {roles_str}\n"
        f"Skills: {skills_str}\n"
        f"Projects: {projects_str}\n"
        f"Experience: {experience_str}"
    ).strip()

    try:
        response = client.models.embed_content(
            model="text-embedding-004",
            contents=semantic_profile_text,
        )

        if response.embeddings and len(response.embeddings) > 0:
            embedding = response.embeddings[0].values
            # Ensure 768 dimensions
            if len(embedding) == 768:
                return embedding
            elif len(embedding) > 768:
                return embedding[:768]
            else:
                return embedding + [0.0] * (768 - len(embedding))

    except Exception as exc:
        logger.error(f"Error generating embedding with text-embedding-004: {exc}")
        raise RuntimeError(f"Failed to generate profile embedding: {exc}")

    raise RuntimeError("Empty embedding returned by Gemini embedding model.")
