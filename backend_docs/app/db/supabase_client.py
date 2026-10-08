#Supabase ka access yahaan se

from functools import lru_cache
from typing import Any, Optional

from app.core.config import Settings, get_settings
from app.core.logging import get_logger

logger = get_logger(__name__)


_supabase_client: Optional[Any] = None


def create_supabase_client(settings: Optional[Settings] = None) -> Any:
    """Instantiate a Supabase client using configuration settings."""
    if settings is None:
        settings = get_settings()

    url = settings.SUPABASE_URL
    # Prefer service role key 
    key = settings.SUPABASE_SERVICE_ROLE_KEY or settings.SUPABASE_KEY

    try:
        from supabase import Client, create_client

        client: Client = create_client(url, key)
        logger.info("Supabase client initialized for URL: %s", url)
        return client
    except ImportError:
        logger.warning(
            "supabase package not installed. Ensure `pip install supabase` is executed."
        )
        # Return a lightweight proxy/mock for local testing when supabase is absent
        return None


def get_supabase_client() -> Any:

    global _supabase_client
    if _supabase_client is None:
        _supabase_client = create_supabase_client()
    return _supabase_client


def set_supabase_client(client: Any) -> None:

    global _supabase_client
    _supabase_client = client
