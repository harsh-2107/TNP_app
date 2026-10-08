#app configuration

from functools import lru_cache

try:
    from pydantic_settings import BaseSettings, SettingsConfigDict
except ImportError:
    try:
        from pydantic import BaseSettings
        SettingsConfigDict = None
    except ImportError:
        class BaseSettings:
            def __init__(self, **kwargs):
                for k, v in kwargs.items():
                    setattr(self, k, v)
        SettingsConfigDict = None


class Settings(BaseSettings):
    #settins loaded from .env

    

    if SettingsConfigDict is not None:
        model_config = SettingsConfigDict(
            env_file=".env",
            env_file_encoding="utf-8",
            case_sensitive=True,
            extra="ignore",
        )


    # Cloudflare R2
    R2_ACCOUNT_ID: str = "default_account"
    R2_ACCESS_KEY_ID: str = "default_key"
    R2_SECRET_ACCESS_KEY: str = "default_secret"
    R2_BUCKET_NAME: str = "default_bucket"


    #url expirty
    R2_UPLOAD_URL_EXPIRY_SECONDS: int = 300
    R2_DOWNLOAD_URL_EXPIRY_SECONDS: int = 3600

    # File limits
    MAX_PROFILE_RESUMES: int = 2
    MAX_FILE_SIZE_BYTES: int = 5_242_880  # 5 MB

    # Application
    SHARE_URL_BASE: str = "https://placements.example.com"

    # Supabase 
    SUPABASE_URL: str = "https://placeholder-project.supabase.co"
    SUPABASE_KEY: str = "placeholder-supabase-key"
    SUPABASE_SERVICE_ROLE_KEY: str = ""

    #parser ka agent hai yye
    OPENAI_API_KEY: str = ""
    OPENAI_MODEL: str = "gpt-4o-mini"

   
    ENVIRONMENT: str = "development"

    @property
    def r2_endpoint_url(self) -> str:
        """Cloudflare R2 S3-compatible endpoint URL."""
        return f"https://{self.R2_ACCOUNT_ID}.r2.cloudflarestorage.com"


@lru_cache
def get_settings() -> Settings:
    """Return cached application settings singleton."""
    return Settings()

