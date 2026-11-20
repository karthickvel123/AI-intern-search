import logging
from datetime import datetime, timezone
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from backend.api.v1.resume import resume_router
from backend.api.v1.jobs import jobs_router
from backend.api.v1.tracker import tracker_router

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("internpulse-backend")

app = FastAPI(
    title="InternPulse AI Job & Internship Hunter API",
    description="Backend service powered by FastAPI, Supabase (pgvector), and Google Gemini Structured JSON Output.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# Enable CORS for Flutter Web, iOS simulator, and Android emulator development
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", tags=["System"])
async def health_check():
    """Health check endpoint to verify backend status."""
    return {
        "status": "ok",
        "service": "InternPulse Backend API",
        "version": "1.0.0",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


# Include V1 API Routers
app.include_router(resume_router, prefix="/api/v1")
app.include_router(jobs_router, prefix="/api/v1")
app.include_router(tracker_router, prefix="/api/v1")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.main:app", host="0.0.0.0", port=8000, reload=True)
