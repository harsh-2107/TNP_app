"""Tests for app.storage.service — StorageService business logic.

All tests use mocked R2Client and in-memory repository/pending store.
No real Cloudflare credentials needed.
"""

from unittest.mock import MagicMock

import pytest
import pytest_asyncio

from app.core.exceptions import (
    FileAlreadyUsed,
    FileNotFoundError_,
    FileTooLarge,
    InvalidFileType,
    InvalidShareToken,
    ProfileResumeLimitExceeded,
    R2OperationFailed,
    UnauthorizedFileAccess,
    UploadNotFound,
)
from app.storage.repository import InMemoryFileRepository
from app.storage.schemas import UploadUrlRequest
from app.storage.service import StorageService

STUDENT_ID = "student-001"
OTHER_STUDENT_ID = "student-002"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_upload_request(
    filename: str = "resume.pdf",
    mime_type: str = "application/pdf",
    size_bytes: int = 1024,
    file_type: str = "resume",
    is_profile_file: bool = True,
) -> UploadUrlRequest:
    return UploadUrlRequest(
        filename=filename,
        mime_type=mime_type,
        size_bytes=size_bytes,
        file_type=file_type,
        is_profile_file=is_profile_file,
    )

async def _create_completed_file(
    service: StorageService,
    student_id: str = STUDENT_ID,
    filename: str = "resume.pdf",
    is_profile_file: bool = True,
) -> str:
    """Helper: request upload URL + complete upload. Returns file_id."""
    request = _make_upload_request(
        filename=filename,
        is_profile_file=is_profile_file,
    )
    url_response = await service.request_upload_url(student_id, "BT25CSA016", request)
    complete_response = await service.complete_upload(
        student_id, url_response.file_id
    )
    return complete_response.file.id


# ---------------------------------------------------------------------------
# Upload URL Tests
# ---------------------------------------------------------------------------


class TestRequestUploadUrl:
    """Tests for StorageService.request_upload_url()."""

    @pytest.mark.asyncio
    async def test_success_returns_file_id_and_url(self, storage_service):
        request = _make_upload_request()
        response = await storage_service.request_upload_url(
            STUDENT_ID, "BT25CSA016", request
        )

        assert response.file_id
        assert len(response.file_id) == 32
        assert response.upload_url
        assert response.expires_in == 300

    @pytest.mark.asyncio
    async def test_cover_letter_upload(self, storage_service):
        request = _make_upload_request(
            file_type="cover_letter",
            is_profile_file=False,
        )
        response = await storage_service.request_upload_url(
            STUDENT_ID, "BT25CSA016", request
        )
        assert response.file_id
        assert response.upload_url

    @pytest.mark.asyncio
    async def test_invalid_extension_rejected(self, storage_service):
        request = _make_upload_request(filename="resume.txt")
        with pytest.raises(InvalidFileType):
            await storage_service.request_upload_url(STUDENT_ID, "BT25CSA016", request)

    @pytest.mark.asyncio
    async def test_invalid_mime_type_rejected(self, storage_service):
        request = _make_upload_request(mime_type="image/jpeg")
        with pytest.raises(InvalidFileType):
            await storage_service.request_upload_url(STUDENT_ID, "BT25CSA016", request)

    @pytest.mark.asyncio
    async def test_file_too_large_rejected(self, storage_service):
        request = _make_upload_request(size_bytes=10_000_000)
        with pytest.raises(FileTooLarge):
            await storage_service.request_upload_url(STUDENT_ID, "BT25CSA016", request)

    @pytest.mark.asyncio
    async def test_profile_resume_limit_enforced(self, storage_service):
        """Creating 3 profile resumes should fail on the 3rd."""
        # Create 2 completed profile resumes
        await _create_completed_file(storage_service, STUDENT_ID)
        await _create_completed_file(
            storage_service, STUDENT_ID, filename="resume2.pdf"
        )

        # 3rd upload URL request should fail
        request = _make_upload_request()
        with pytest.raises(ProfileResumeLimitExceeded):
            await storage_service.request_upload_url(STUDENT_ID, "BT25CSA016", request)

    @pytest.mark.asyncio
    async def test_non_profile_resume_no_limit(self, storage_service):
        """Non-profile resumes should not count toward the limit."""
        # Create 2 profile resumes
        await _create_completed_file(storage_service, STUDENT_ID)
        await _create_completed_file(
            storage_service, STUDENT_ID, filename="resume2.pdf"
        )

        # Non-profile upload should still work
        request = _make_upload_request(is_profile_file=False)
        response = await storage_service.request_upload_url(
            STUDENT_ID, "BT25CSA016", request
        )
        assert response.file_id


# ---------------------------------------------------------------------------
# Complete Upload Tests
# ---------------------------------------------------------------------------


class TestCompleteUpload:
    """Tests for StorageService.complete_upload()."""

    @pytest.mark.asyncio
    async def test_success_creates_record(self, storage_service, mock_r2_client):
        mock_r2_client.read_object_bytes.return_value = b"%PDF-"
        request = _make_upload_request()
        url_response = await storage_service.request_upload_url(
            STUDENT_ID, "BT25CSA016", request
        )

        complete_response = await storage_service.complete_upload(
            STUDENT_ID, url_response.file_id
        )

        assert complete_response.file.id == url_response.file_id
        assert complete_response.file.filename.endswith(".pdf")
        assert complete_response.file.mime_type == "application/pdf"
        assert complete_response.file.size_bytes == 12345  # from mock HEAD
        assert complete_response.file.is_profile_file is True
        assert complete_response.file.used_for_application is False

    @pytest.mark.asyncio
    async def test_nonexistent_upload_rejected(self, storage_service):
        with pytest.raises(UploadNotFound):
            await storage_service.complete_upload(
                STUDENT_ID, "nonexistent-file-id"
            )

    @pytest.mark.asyncio
    async def test_wrong_student_rejected(self, storage_service):
        request = _make_upload_request()
        url_response = await storage_service.request_upload_url(
            STUDENT_ID, "BT25CSA016", request
        )

        with pytest.raises(UnauthorizedFileAccess):
            await storage_service.complete_upload(
                OTHER_STUDENT_ID, url_response.file_id
            )

    @pytest.mark.asyncio
    async def test_missing_r2_object_rejected(
        self, storage_service, mock_r2_client
    ):
        """If HEAD object fails, the upload should be rejected."""
        mock_r2_client.head_object.side_effect = R2OperationFailed(
            detail="Uploaded file not found in storage."
        )

        request = _make_upload_request()
        url_response = await storage_service.request_upload_url(
            STUDENT_ID, "BT25CSA016", request
        )

        with pytest.raises(R2OperationFailed):
            await storage_service.complete_upload(
                STUDENT_ID, url_response.file_id
            )


# ---------------------------------------------------------------------------
# Profile File Tests
# ---------------------------------------------------------------------------


class TestGetProfileFiles:
    """Tests for StorageService.get_profile_files()."""

    @pytest.mark.asyncio
    async def test_empty_list(self, storage_service):
        response = await storage_service.get_profile_files(STUDENT_ID)
        assert response.files == []

    @pytest.mark.asyncio
    async def test_returns_only_profile_files(self, storage_service, mock_r2_client):
        mock_r2_client.read_object_bytes.return_value = b"%PDF-"
        await _create_completed_file(
            storage_service, STUDENT_ID, is_profile_file=True
        )
        await _create_completed_file(
            storage_service, STUDENT_ID, is_profile_file=False
        )

        response = await storage_service.get_profile_files(STUDENT_ID)
        assert len(response.files) == 1
        assert response.files[0].is_profile_file is True

    @pytest.mark.asyncio
    async def test_does_not_return_other_students_files(
        self, storage_service, mock_r2_client
    ):
        mock_r2_client.read_object_bytes.return_value = b"%PDF-"
        await _create_completed_file(
            storage_service, STUDENT_ID, is_profile_file=True
        )
        await _create_completed_file(
            storage_service, OTHER_STUDENT_ID, is_profile_file=True
        )

        response = await storage_service.get_profile_files(STUDENT_ID)
        assert len(response.files) == 1


# ---------------------------------------------------------------------------
# File View Tests
# ---------------------------------------------------------------------------


class TestGetFileViewUrl:
    """Tests for StorageService.get_file_view_url()."""

    @pytest.mark.asyncio
    async def test_success(self, storage_service):
        file_id = await _create_completed_file(storage_service)
        response = await storage_service.get_file_view_url(
            STUDENT_ID, file_id
        )
        assert response.download_url
        assert response.expires_in == 3600

    @pytest.mark.asyncio
    async def test_nonexistent_file_404(self, storage_service):
        with pytest.raises(FileNotFoundError_):
            await storage_service.get_file_view_url(
                STUDENT_ID, "nonexistent-id"
            )

    @pytest.mark.asyncio
    async def test_idor_protection(self, storage_service):
        """Student B cannot view Student A's file."""
        file_id = await _create_completed_file(
            storage_service, STUDENT_ID
        )
        with pytest.raises(UnauthorizedFileAccess):
            await storage_service.get_file_view_url(
                OTHER_STUDENT_ID, file_id
            )


# ---------------------------------------------------------------------------
# File Deletion Tests
# ---------------------------------------------------------------------------


class TestDeleteFile:
    """Tests for StorageService.delete_file()."""

    @pytest.mark.asyncio
    async def test_delete_unused_profile_file(
        self, storage_service, in_memory_repository, mock_r2_client
    ):
        mock_r2_client.read_object_bytes.return_value = b"%PDF-"
        file_id = await _create_completed_file(storage_service)

        response = await storage_service.delete_file(STUDENT_ID, file_id)
        assert response.message == "File deleted successfully."

        # Verify record is gone
        record = await in_memory_repository.get_file_by_id(file_id)
        assert record is None

    @pytest.mark.asyncio
    async def test_delete_nonexistent_file_404(self, storage_service):
        with pytest.raises(FileNotFoundError_):
            await storage_service.delete_file(STUDENT_ID, "nonexistent")

    @pytest.mark.asyncio
    async def test_delete_wrong_student_403(self, storage_service, mock_r2_client):
        mock_r2_client.read_object_bytes.return_value = b"%PDF-"
        file_id = await _create_completed_file(storage_service)
        with pytest.raises(UnauthorizedFileAccess):
            await storage_service.delete_file(OTHER_STUDENT_ID, file_id)

    @pytest.mark.asyncio
    async def test_delete_non_profile_file_rejected(self, storage_service, mock_r2_client):
        mock_r2_client.read_object_bytes.return_value = b"%PDF-"
        file_id = await _create_completed_file(
            storage_service, is_profile_file=False
        )
        with pytest.raises(InvalidFileType):
            await storage_service.delete_file(STUDENT_ID, file_id)

    @pytest.mark.asyncio
    async def test_soft_remove_referenced_file(
        self, storage_service, in_memory_repository, mock_r2_client
    ):
        """Files referenced by applications are softly removed from profile."""
        mock_r2_client.read_object_bytes.return_value = b"%PDF-"
        file_id = await _create_completed_file(storage_service)

        # Simulate application reference
        await in_memory_repository.mark_file_used_for_application(file_id)

        response = await storage_service.delete_file(STUDENT_ID, file_id)
        assert response.message == "File removed from profile successfully."

        # Verify record still exists but is_profile_file is False
        record = await in_memory_repository.get_file_by_id(file_id)
        assert record is not None
        assert record.is_profile_file is False

    @pytest.mark.asyncio
    async def test_r2_delete_failure_preserves_db_record(
        self, storage_service, mock_r2_client, in_memory_repository
    ):
        """If R2 deletion fails, the DB record must not be deleted."""
        mock_r2_client.read_object_bytes.return_value = b"%PDF-"
        file_id = await _create_completed_file(storage_service)

        mock_r2_client.delete_object.side_effect = R2OperationFailed(
            detail="R2 deletion failed."
        )

        with pytest.raises(R2OperationFailed):
            await storage_service.delete_file(STUDENT_ID, file_id)

        # DB record must still exist
        record = await in_memory_repository.get_file_by_id(file_id)
        assert record is not None


# ---------------------------------------------------------------------------
# Share Link Tests
# ---------------------------------------------------------------------------


class TestShareLinks:
    """Tests for create_share_link() and resolve_share_token()."""

    @pytest.mark.asyncio
    async def test_create_share_link_returns_url(self, storage_service):
        file_id = await _create_completed_file(storage_service)
        share_url = await storage_service.create_share_link(file_id)

        assert share_url.startswith("https://placements.example.com/share/")
        # Token part should be 43 chars (secrets.token_urlsafe(32))
        token = share_url.split("/share/")[1]
        assert len(token) == 43

    @pytest.mark.asyncio
    async def test_create_share_link_nonexistent_file(self, storage_service):
        with pytest.raises(FileNotFoundError_):
            await storage_service.create_share_link("nonexistent")

    @pytest.mark.asyncio
    async def test_resolve_valid_token(self, storage_service):
        file_id = await _create_completed_file(storage_service)
        share_url = await storage_service.create_share_link(file_id)
        token = share_url.split("/share/")[1]

        download_url = await storage_service.resolve_share_token(token)
        assert download_url  # Should be a presigned URL

    @pytest.mark.asyncio
    async def test_resolve_invalid_token(self, storage_service):
        with pytest.raises(InvalidShareToken):
            await storage_service.resolve_share_token("invalid-token-abc")

    @pytest.mark.asyncio
    async def test_new_share_link_replaces_old(self, storage_service, mock_r2_client):
        """Creating a new share link for the same file replaces the old one."""
        mock_r2_client.read_object_bytes.return_value = b"%PDF-"
        file_id = await _create_completed_file(storage_service)

        url1 = await storage_service.create_share_link(file_id)
        url2 = await storage_service.create_share_link(file_id)

        # URLs should be different (new token)
        assert url1 != url2

        # Old token should no longer work
        old_token = url1.split("/share/")[1]
        with pytest.raises(InvalidShareToken):
            await storage_service.resolve_share_token(old_token)

        # New token should work
        new_token = url2.split("/share/")[1]
        download_url = await storage_service.resolve_share_token(new_token)
        assert download_url
