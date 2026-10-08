#yahaa se fastapi chalu hota hai and this joins
# r2 client, file repo, storage service, routers, and error lusts


from contextlib import asynccontextmanager

# pyrefly ignore
from fastapi import FastAPI, Request
# pyrefly ignore
from fastapi.responses import JSONResponse

from app.core.config import get_settings
from app.core.exceptions import StorageException
from app.core.logging import get_logger
from app.storage.r2_client import R2Client
from app.db.supabase_client import create_supabase_client
from app.storage.repository import (
    InMemoryFileRepository,
    InMemoryPendingUploadStore,
    SupabaseFileRepository,
    SupabasePendingUploadStore,
)
from app.storage.router import set_storage_service, share_router, storage_router
from app.admin.router import set_storage_service as set_admin_storage_service
from app.storage.service import StorageService

logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
   
    settings = get_settings()

    r2_client = R2Client(settings)

    # -----------------------------------------------------------------
    # Dependency wiring
    # -----------------------------------------------------------------
    is_prod = settings.ENVIRONMENT == "production"
    has_supabase_creds = (
        settings.SUPABASE_URL != "https://placeholder-project.supabase.co" #link of supabase
        and settings.SUPABASE_SERVICE_ROLE_KEY != ""
    )

    if is_prod or has_supabase_creds:
        logger.info("Initializing persistent Supabase storage services.")
        supabase_client = create_supabase_client(settings)
        if supabase_client is None:
            raise RuntimeError("Failed to initialize Supabase client. Check dependencies.")
        repository = SupabaseFileRepository(supabase_client)
        pending_store = SupabasePendingUploadStore(supabase_client)
    else:
        logger.info(
            "Starting in development mode with in-memory stores active.",
        )
        repository = InMemoryFileRepository()
        pending_store = InMemoryPendingUploadStore()

    service = StorageService(
        repository=repository,
        pending_store=pending_store,
        r2_client=r2_client,
        settings=settings,
    )

    set_storage_service(service)
    set_admin_storage_service(service)

    logger.info("Storage service initialised successfully.")

    yield

    logger.info("Shutting down.")


app = FastAPI(
    title="TNP File Storage API",
    description=(
        "File storage module for the college placement/internship platform. "
        "Handles student resume and cover letter uploads via Cloudflare R2."
    ),
    version="0.1.0",
    lifespan=lifespan,
)

#errors and exception


@app.exception_handler(StorageException)
async def storage_exception_handler(
    request: Request, exc: StorageException
) -> JSONResponse:
    """Map StorageException subclasses to appropriate HTTP responses."""
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail},
    )


from app.resumes.router import resumes_router
from app.applications.router import applications_router
from app.students.router import students_router
from app.admin.router import admin_router

app.include_router(storage_router)
app.include_router(share_router)
app.include_router(resumes_router)
app.include_router(applications_router)
app.include_router(students_router)
app.include_router(admin_router)



@app.get("/health", tags=["system"])
async def health_check() -> dict:
    """Basic health check endpoint."""
    return {"status": "ok"}
