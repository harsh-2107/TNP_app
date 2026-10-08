"""Shared test fixtures for the storage module tests."""

import os
from unittest.mock import AsyncMock, MagicMock

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.core.config import Settings
from app.storage.r2_client import R2Client
from app.storage.repository import (
    InMemoryFileRepository,
    InMemoryPendingUploadStore,
)
from app.storage.service import StorageService


# ---------------------------------------------------------------------------
# Environment override — prevent pydantic-settings from requiring real
# R2 credentials during testing.
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def _set_test_env(monkeypatch):
    """Ensure test environment variables are always set."""
    monkeypatch.setenv("R2_ACCOUNT_ID", "test-account-id")
    monkeypatch.setenv("R2_ACCESS_KEY_ID", "test-access-key")
    monkeypatch.setenv("R2_SECRET_ACCESS_KEY", "test-secret-key")
    monkeypatch.setenv("R2_BUCKET_NAME", "test-bucket")
    monkeypatch.setenv("ENVIRONMENT", "development")
    monkeypatch.setenv("SHARE_URL_BASE", "https://placements.example.com")


@pytest.fixture
def settings() -> Settings:
    """Test settings with deterministic values."""
    return Settings(
        R2_ACCOUNT_ID="test-account-id",
        R2_ACCESS_KEY_ID="test-access-key",
        R2_SECRET_ACCESS_KEY="test-secret-key",
        R2_BUCKET_NAME="test-bucket",
        R2_UPLOAD_URL_EXPIRY_SECONDS=300,
        R2_DOWNLOAD_URL_EXPIRY_SECONDS=3600,
        MAX_PROFILE_RESUMES=2,
        MAX_FILE_SIZE_BYTES=5_242_880,
        SHARE_URL_BASE="https://placements.example.com",
        ENVIRONMENT="development",
    )


@pytest.fixture
def mock_r2_client() -> MagicMock:
    """Mocked R2Client — no real boto3 calls."""
    client = MagicMock(spec=R2Client)
    client.generate_presigned_put_url.return_value = (
        "https://r2.example.com/put-presigned-url"
    )
    client.generate_presigned_get_url.return_value = (
        "https://r2.example.com/get-presigned-url"
    )
    client.head_object.return_value = {
        "ContentLength": 12345,
        "ContentType": "application/pdf",
    }
    client.read_object_bytes.return_value = b"%PDF-"
    client.copy_object.return_value = None
    client.delete_object.return_value = None
    return client


@pytest.fixture
def in_memory_repository() -> InMemoryFileRepository:
    """Fresh in-memory file repository."""
    return InMemoryFileRepository()


@pytest.fixture
def in_memory_pending_store() -> InMemoryPendingUploadStore:
    """Fresh in-memory pending upload store."""
    return InMemoryPendingUploadStore()


@pytest.fixture
def storage_service(
    in_memory_repository: InMemoryFileRepository,
    in_memory_pending_store: InMemoryPendingUploadStore,
    mock_r2_client: MagicMock,
    settings: Settings,
) -> StorageService:
    """StorageService wired with in-memory stores and mocked R2."""
    return StorageService(
        repository=in_memory_repository,
        pending_store=in_memory_pending_store,
        r2_client=mock_r2_client,
        settings=settings,
    )


@pytest_asyncio.fixture
async def test_client(
    in_memory_repository,
    in_memory_pending_store,
    mock_r2_client,
    settings,
):
    """httpx AsyncClient against the FastAPI app with test dependencies."""
    from app.storage.router import set_storage_service
    from app.storage.service import StorageService

    service = StorageService(
        repository=in_memory_repository,
        pending_store=in_memory_pending_store,
        r2_client=mock_r2_client,
        settings=settings,
    )
    set_storage_service(service)

    # Import app AFTER setting service to avoid lifespan issues
    from app.main import app

    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport,
        base_url="http://testserver",
    ) as client:
        yield client
