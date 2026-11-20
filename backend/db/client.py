import os
import logging
from typing import Optional
from dotenv import load_dotenv
from supabase import create_client, Client

# Configure logging
logger = logging.getLogger(__name__)

# Load environment variables from backend/.env or parent .env
load_dotenv()

_supabase_client: Optional[Client] = None

def get_supabase_client() -> Client:
    """
    Creates or returns a singleton Supabase client instance.
    Prefers SUPABASE_SERVICE_ROLE_KEY for server operations, falling back to SUPABASE_KEY.
    """
    global _supabase_client

    if _supabase_client is not None:
        return _supabase_client

    supabase_url: Optional[str] = os.getenv("SUPABASE_URL")
    supabase_key: Optional[str] = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_KEY")

    if not supabase_url or not supabase_key:
        error_msg = (
            "Supabase credentials not configured. Please set SUPABASE_URL and "
            "SUPABASE_KEY (or SUPABASE_SERVICE_ROLE_KEY) in backend/.env"
        )
        logger.error(error_msg)
        raise ValueError(error_msg)

    try:
        _supabase_client = create_client(supabase_url, supabase_key)
        logger.info("Supabase client initialized successfully.")
        return _supabase_client
    except Exception as exc:
        logger.error(f"Failed to connect to Supabase: {exc}")
        raise

# Lazy initialization proxy or callable
class _SupabaseProxy:
    def __getattr__(self, name):
        return getattr(get_supabase_client(), name)

supabase = _SupabaseProxy()
