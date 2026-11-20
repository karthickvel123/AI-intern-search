import logging
from typing import Optional
from fastapi import APIRouter, File, UploadFile, HTTPException, status
from backend.models.profile import MasterProfile, ResumeParseResponse
from backend.services.pdf_parser import extract_text_from_pdf
from backend.services.gemini_service import parse_resume_with_gemini, generate_profile_embedding
from backend.db.client import get_supabase_client

logger = logging.getLogger(__name__)

resume_router = APIRouter(prefix="/resume", tags=["Resume Parsing"])


@resume_router.post(
    "/parse",
    response_model=ResumeParseResponse,
    status_code=status.HTTP_200_OK,
    summary="Parse PDF Resume into Structured MasterProfile & Vector Embedding",
    description="Upload a PDF resume. Extracts text with PyMuPDF, parses structured data with Gemini, generates a 768-dim embedding, and persists to Supabase.",
)
async def parse_resume(file: UploadFile = File(..., description="PDF resume file")):
    # 1. Validate file extension / MIME type
    if not file.filename.lower().endswith(".pdf"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid file type. Please upload a standard PDF (.pdf) document.",
        )

    try:
        pdf_bytes = await file.read()
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to read uploaded file: {exc}",
        )

    # 2. Extract clean text using PyMuPDF
    try:
        raw_text = extract_text_from_pdf(pdf_bytes)
    except ValueError as val_err:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(val_err),
        )

    # 3. Parse with Gemini using Structured JSON Output
    try:
        master_profile = parse_resume_with_gemini(raw_text)
    except ValueError as ve:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(ve),
        )
    except Exception as exc:
        logger.error(f"Gemini resume parsing error: {exc}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"AI model error during resume parsing: {exc}",
        )

    # 4. Generate 768-dim embedding
    embedding_vector = None
    try:
        embedding_vector = generate_profile_embedding(master_profile)
    except Exception as exc:
        logger.warning(f"Could not generate profile embedding: {exc}")

    # 5. Persist to Supabase 'profiles' table
    saved_to_db = False
    profile_id: Optional[str] = None

    try:
        supabase = get_supabase_client()
        profile_record = {
            "master_profile": master_profile.model_dump(),
            "target_roles": master_profile.target_roles,
            "preferred_locations": [master_profile.location] if master_profile.location else [],
            "remote_preference": True,
            "resume_embedding": embedding_vector,
        }
        res = supabase.table("profiles").insert(profile_record).execute()
        if res.data and len(res.data) > 0:
            saved_to_db = True
            profile_id = str(res.data[0].get("id"))
    except ValueError:
        logger.info("Supabase is not yet configured with valid credentials; skipped DB persist.")
    except Exception as db_exc:
        logger.warning(f"Failed to save profile into Supabase: {db_exc}")

    return ResumeParseResponse(
        profile_id=profile_id,
        master_profile=master_profile,
        embedding_dimension=len(embedding_vector) if embedding_vector else 768,
        saved_to_db=saved_to_db,
        message="Resume parsed successfully with Gemini Structured JSON Output.",
    )
