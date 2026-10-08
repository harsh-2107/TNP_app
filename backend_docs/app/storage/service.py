# /*vibe coded because i dont know about Cloudflare*/
"""Business logic for file storage operations.

StorageService orchestrates R2 operations, repository calls, and
pending upload management. It contains all authorization and
validation logic for the storage module.

Constructor takes:
    - FileRepositoryInterface (database operations)
    - PendingUploadStoreInterface (pending upload state)
    - R2Client (Cloudflare R2 operations)
    - Settings (application configuration)
"""

from datetime import datetime, timedelta, timezone

from app.core.config import Settings
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
from app.core.logging import get_logger
from app.db.pending_upload_interface import (
    PendingUpload,
    PendingUploadStoreInterface,
)
from app.db.repository_interface import FileRecord, FileRepositoryInterface
from app.storage.constants import (
    FILE_TYPE_RESUME,
    FILE_TYPE_COVER_LETTER,
)
from app.storage.r2_client import R2Client
from app.storage.schemas import (
    CompleteUploadResponse,
    DeleteResponse,
    FileRecordResponse,
    FileViewResponse,
    ProfileFileListResponse,
    UploadUrlRequest,
    UploadUrlResponse,
)
from app.storage.utils import (
    build_pending_key,
    build_permanent_key,
    generate_file_id,
    generate_structured_filename,
    generate_share_token,
    get_extension,
    hash_share_token,
    sanitize_filename,
    validate_extension,
    validate_mime_type,
    validate_pdf_magic_bytes,
)

logger = get_logger(__name__)


def _file_record_to_response(record: FileRecord) -> FileRecordResponse:
    """Convert a FileRecord to a FileRecordResponse.

    object_key is intentionally omitted from the response.
    """
    return FileRecordResponse(
        id=record.id,
        filename=record.filename,
        file_type=record.file_type,
        mime_type=record.mime_type,
        size_bytes=record.size_bytes,
        is_profile_file=record.is_profile_file,
        used_for_application=record.used_for_application,
        created_at=record.created_at,
    )


class StorageService:
    """Business logic for file storage operations.

    This service is injected into router endpoints via FastAPI
    dependency injection. It coordinates between:
    - R2Client for S3-compatible storage operations
    - FileRepositoryInterface for database operations
    - PendingUploadStoreInterface for transient upload state
    """

    def __init__(
        self,
        repository: FileRepositoryInterface,
        pending_store: PendingUploadStoreInterface,
        r2_client: R2Client,
        settings: Settings,
    ) -> None:
        self._repo = repository
        self._pending = pending_store
        self._r2 = r2_client
        self._settings = settings

    # -----------------------------------------------------------------
    # Upload URL
    # -----------------------------------------------------------------

    async def request_upload_url(
        self, student_id: str, bt_id: str, request: UploadUrlRequest
    ) -> UploadUrlResponse:
        """Validate upload request and generate a presigned PUT URL."""
        # Sanitize and validate
        safe_filename = sanitize_filename(request.filename)

        if not validate_extension(safe_filename):
            raise InvalidFileType(
                detail="File extension not supported. Allowed: .pdf"
            )

        if not validate_mime_type(request.mime_type):
            raise InvalidFileType(
                detail=f"MIME type '{request.mime_type}' is not supported."
            )

        if request.size_bytes > self._settings.MAX_FILE_SIZE_BYTES:
            max_mb = self._settings.MAX_FILE_SIZE_BYTES / (1024 * 1024)
            raise FileTooLarge(
                detail=f"Declared file exceeds maximum size of {max_mb:.0f} MB."
            )

        # Profile limit check
        if request.is_profile_file:
            if request.file_type == FILE_TYPE_RESUME:
                current_count = await self._repo.count_profile_resumes(student_id)
                if current_count >= self._settings.MAX_PROFILE_RESUMES:
                    raise ProfileResumeLimitExceeded(
                        detail=(
                            f"You already have {current_count} profile resume(s). "
                            f"Maximum allowed: {self._settings.MAX_PROFILE_RESUMES}."
                        )
                    )
            elif request.file_type == FILE_TYPE_COVER_LETTER:
                # Assuming 1 max cover letter
                current_count = await self._repo.count_profile_cover_letters(student_id)
                if current_count >= 1:
                    raise ProfileResumeLimitExceeded(
                        detail=(
                            f"You already have {current_count} profile cover letter. "
                            f"Maximum allowed: 1."
                        )
                    )

        # Generate identifiers
        file_id = generate_file_id()
        extension = get_extension(safe_filename)

        structured_filename = generate_structured_filename(bt_id, file_id, extension)
        pending_key = build_pending_key(bt_id, structured_filename)
        permanent_key = build_permanent_key(bt_id, structured_filename)

        # Save pending upload state
        expiry_seconds = self._settings.R2_UPLOAD_URL_EXPIRY_SECONDS
        expires_at = datetime.now(timezone.utc) + timedelta(
            seconds=expiry_seconds
        )

        pending = PendingUpload(
            file_id=file_id,
            student_id=student_id,
            pending_object_key=pending_key,
            permanent_object_key=permanent_key,
            filename=structured_filename,
            mime_type=request.mime_type,
            file_type=request.file_type,
            is_profile_file=request.is_profile_file,
            expires_at=expires_at,
        )
        await self._pending.save_pending_upload(pending)

        # Generate presigned PUT URL
        upload_url = self._r2.generate_presigned_put_url(
            object_key=pending_key,
            content_type=request.mime_type,
            expiry=expiry_seconds,
        )

        logger.info(
            "Upload URL generated: file_id=%s student=%s filename=%s",
            file_id,
            student_id,
            safe_filename,
        )

        return UploadUrlResponse(
            file_id=file_id,
            upload_url=upload_url,
            expires_in=expiry_seconds,
        )

    # -----------------------------------------------------------------
    # Complete Upload
    # -----------------------------------------------------------------

    async def complete_upload(
        self, student_id: str, file_id: str
    ) -> CompleteUploadResponse:
        """Finalize an upload after the client has PUT the file to R2.

        Flow:
        1. Retrieve pending upload
        2. Verify student_id matches
        3. HEAD object in R2 to confirm upload
        4. Create final DB file record
        5. Remove pending upload
        6. Return file metadata

        Args:
            student_id: Authenticated student's ID.
            file_id: The file_id from the upload-url response.

        Returns:
            CompleteUploadResponse with the created file record.

        Raises:
            UploadNotFound: If no pending upload exists for this file_id.
            UnauthorizedFileAccess: If student_id doesn't match.
            R2OperationFailed: If the file is not found in R2.
        """
        pending = await self._pending.get_pending_upload(file_id)
        if pending is None:
            raise UploadNotFound()

        if pending.student_id != student_id:
            logger.warning(
                "Upload ownership mismatch: file_id=%s expected=%s got=%s",
                file_id,
                pending.student_id,
                student_id,
            )
            raise UnauthorizedFileAccess(
                detail="This upload does not belong to you."
            )

        # Verify the file exists in R2 and check actual size
        head_result = self._r2.head_object(pending.pending_object_key)
        actual_size = head_result["ContentLength"]

        if actual_size > self._settings.MAX_FILE_SIZE_BYTES:
            self._r2.delete_object(pending.pending_object_key)
            await self._pending.remove_pending_upload(file_id)
            max_mb = self._settings.MAX_FILE_SIZE_BYTES / (1024 * 1024)
            raise FileTooLarge(
                detail=f"Actual file exceeds maximum size of {max_mb:.0f} MB."
            )

        # Validate magic bytes
        try:
            first_bytes = self._r2.read_object_bytes(pending.pending_object_key, 5)
            if not validate_pdf_magic_bytes(first_bytes):
                raise ValueError("Invalid magic bytes")
        except Exception:
            self._r2.delete_object(pending.pending_object_key)
            await self._pending.remove_pending_upload(file_id)
            raise InvalidFileType(detail="The uploaded file is not a valid PDF.")

        # Copy from pending to permanent
        self._r2.copy_object(pending.pending_object_key, pending.permanent_object_key)

        # Extract bt_id from permanent_key or structured_filename
        bt_id = pending.filename.split("_")[0] if "_" in pending.filename else "STUDENT"
        ext = get_extension(pending.filename)
        renamed_filename = f"{bt_id}_Resume{ext}" if pending.file_type == FILE_TYPE_RESUME else f"{bt_id}_CoverLetter{ext}"

        # Create the final database record
        try:
            record = await self._repo.create_file_record(
                file_id=pending.file_id,
                student_id=pending.student_id,
                object_key=pending.permanent_object_key,
                filename=renamed_filename,
                mime_type=pending.mime_type,
                size_bytes=actual_size,
                file_type=pending.file_type,
                is_profile_file=pending.is_profile_file,
                used_for_application=False,  # strictly false upon upload
            )
        except Exception as exc:
            # Rollback permanent object if DB creation fails
            self._r2.delete_object(pending.permanent_object_key)
            logger.error("DB creation failed for file_id=%s, rolled back R2: %s", file_id, exc)
            raise

        # Remove pending object and state
        self._r2.delete_object(pending.pending_object_key)
        await self._pending.remove_pending_upload(file_id)

        logger.info(
            "Upload completed: file_id=%s student=%s size=%d",
            file_id,
            student_id,
            actual_size,
        )

        return CompleteUploadResponse(file=_file_record_to_response(record))

    # -----------------------------------------------------------------
    # Profile Files
    # -----------------------------------------------------------------

    async def get_profile_files(
        self, student_id: str
    ) -> ProfileFileListResponse:
        """List all profile files for a student."""
        records = await self._repo.get_profile_files(student_id)
        return ProfileFileListResponse(
            files=[_file_record_to_response(r) for r in records]
        )

    # -----------------------------------------------------------------
    # File View
    # -----------------------------------------------------------------

    async def get_file_view_url(
        self, student_id: str, file_id: str
    ) -> FileViewResponse:
        """Generate a short-lived presigned GET URL for viewing a file.

        A student must never be able to access another student's file.

        Args:
            student_id: Authenticated student's ID.
            file_id: The file to view.

        Returns:
            FileViewResponse with presigned download URL.

        Raises:
            FileNotFoundError_: If the file does not exist.
            UnauthorizedFileAccess: If the file belongs to another student.
        """
        record = await self._repo.get_file_by_id(file_id)
        if record is None:
            raise FileNotFoundError_()

        if record.student_id != student_id:
            raise UnauthorizedFileAccess()

        expiry = self._settings.R2_DOWNLOAD_URL_EXPIRY_SECONDS
        download_url = self._r2.generate_presigned_get_url(
            object_key=record.object_key,
            expiry=expiry,
        )

        return FileViewResponse(
            download_url=download_url,
            expires_in=expiry,
        )

    # -----------------------------------------------------------------
    # File Deletion
    # -----------------------------------------------------------------

    async def delete_file(
        self, student_id: str, file_id: str
    ) -> DeleteResponse:
        """Remove a profile file.

        Files marked as used_for_application are only softly removed
        from the profile; unused files are hard deleted.
        """
        record = await self._repo.get_file_by_id(file_id)
        if record is None:
            raise FileNotFoundError_()

        if record.student_id != student_id:
            raise UnauthorizedFileAccess()

        if not record.is_profile_file:
            raise InvalidFileType(
                detail="Only profile files can be removed through this endpoint."
            )

        if record.used_for_application:
            # Soft remove from profile
            await self._repo.update_profile_status(file_id, False)
            logger.info("Soft-removed profile file_id=%s student=%s", file_id, student_id)
            return DeleteResponse(message="File removed from profile successfully.")

        # Hard delete
        # Delete R2 object FIRST — if this fails, do NOT delete the DB record
        self._r2.delete_object(record.object_key)

        # Only after successful R2 deletion, delete the DB record
        await self._repo.delete_file_record(file_id)

        logger.info(
            "File deleted: file_id=%s student=%s", file_id, student_id
        )

        return DeleteResponse(message="File deleted successfully.")

    # -----------------------------------------------------------------
    # Share Links (internal — not exposed as HTTP endpoint)
    # -----------------------------------------------------------------

    async def create_share_link(self, file_id: str) -> str:
        """Generate a permanent share link for a file.

        This function is called internally by the admin CSV module,
        NOT exposed as an HTTP endpoint to students.

        Flow:
        1. Verify the file exists
        2. Generate a cryptographically secure token
        3. Hash the token
        4. Store the hash in the database
        5. Return the permanent application URL

        Args:
            file_id: The file to create a share link for.

        Returns:
            Permanent URL like:
            https://placements.example.com/share/{token}

        Raises:
            FileNotFoundError_: If the file does not exist.
        """
        record = await self._repo.get_file_by_id(file_id)
        if record is None:
            raise FileNotFoundError_()

        token = generate_share_token()
        token_hash = hash_share_token(token)

        await self._repo.store_share_token(file_id, token_hash)

        share_url = f"{self._settings.SHARE_URL_BASE}/share/{token}"

        logger.info("Share link created for file_id=%s", file_id)

        return share_url

    async def resolve_share_token(self, token: str) -> str:
        """Resolve a share token to a fresh presigned R2 GET URL.

        Called by GET /share/{token}. The router performs the
        HTTP 302 redirect.

        Args:
            token: Raw share token from the URL path.

        Returns:
            Fresh presigned GET URL for the associated file.

        Raises:
            InvalidShareToken: If the token is not found.
        """
        token_hash = hash_share_token(token)
        record = await self._repo.get_file_by_share_token_hash(token_hash)

        if record is None:
            raise InvalidShareToken()

        expiry = self._settings.R2_DOWNLOAD_URL_EXPIRY_SECONDS
        download_url = self._r2.generate_presigned_get_url(
            object_key=record.object_key,
            expiry=expiry,
        )

        logger.info("Share token resolved for file_id=%s", record.id)

        return download_url

    async def set_default_resume(self, student_id: str, file_id: str) -> None:
        """Mark a specific resume as the student's default profile resume."""
        record = await self._repo.get_file_by_id(file_id)
        if record is None:
            raise FileNotFoundError_()

        if record.student_id != student_id:
            raise UnauthorizedFileAccess()

        if not record.is_profile_file or record.file_type != FILE_TYPE_RESUME:
            raise InvalidFileType(
                detail="Only active profile resumes can be set as default."
            )

        await self._repo.set_default_resume(student_id, file_id)
