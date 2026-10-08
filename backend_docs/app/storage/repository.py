##Vibe coded hai bhai, dont know cloudflare
"""Stub repository and in-memory pending upload store.
 
Contains:
- InMemoryFileRepository: Stub implementing FileRepositoryInterface.
  Raises NotImplementedError in production — intended to be replaced
  with actual SQL/Supabase queries by the teammate owning the schema.

- InMemoryPendingUploadStore: In-memory dict-based implementation of
  PendingUploadStoreInterface. Suitable ONLY for local development
  and testing. The application refuses to start in production mode
  with this implementation.
"""

from datetime import datetime, timezone
from typing import Any
import uuid

from app.core.logging import get_logger
from app.db.pending_upload_interface import (
    PendingUpload,
    PendingUploadStoreInterface,
)
from app.db.repository_interface import FileRecord, FileRepositoryInterface

logger = get_logger(__name__)


# ---------------------------------------------------------------------------
# In-memory FileRepository (for testing only)
# ---------------------------------------------------------------------------


class InMemoryFileRepository(FileRepositoryInterface):
    """In-memory stub of FileRepositoryInterface.

    This implementation stores records in a plain dict and is intended
    ONLY for local development and testing. It will be replaced with
    actual PostgreSQL/Supabase queries when the database schema is
    confirmed by the teammate who owns it.

    WARNING: Data is lost on process restart.
    """

    def __init__(self) -> None:
        # file_id -> FileRecord
        self._files: dict[str, FileRecord] = {}
        # file_id -> token_hash
        self._share_tokens: dict[str, str] = {}
        # token_hash -> file_id (reverse index for lookup)
        self._token_hash_to_file: dict[str, str] = {}
        self._token_hash_to_file: dict[str, str] = {}

    async def create_file_record(
        self,
        *,
        file_id: str,
        student_id: str,
        object_key: str,
        filename: str,
        mime_type: str,
        size_bytes: int,
        file_type: str,
        is_profile_file: bool,
        used_for_application: bool,
    ) -> FileRecord:
        """Insert a completed file record.

        TODO: Replace with:
            INSERT INTO student_files (id, student_id, object_key,
                filename, mime_type, size_bytes, file_type,
                is_profile_file, used_for_application, created_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
            RETURNING *;
        """
        record = FileRecord(
            id=file_id,
            student_id=student_id,
            object_key=object_key,
            filename=filename,
            mime_type=mime_type,
            size_bytes=size_bytes,
            file_type=file_type,
            is_profile_file=is_profile_file,
            used_for_application=used_for_application,
            created_at=datetime.now(timezone.utc),
        )
        self._files[file_id] = record
        logger.info("Created file record id=%s for student=%s", file_id, student_id)
        return record

    async def get_file_by_id(self, file_id: str) -> FileRecord | None:
        """Fetch a single file record by its primary key.

        TODO: Replace with:
            SELECT * FROM student_files WHERE id = $1;
        """
        return self._files.get(file_id)

    async def get_student_file(
        self, file_id: str, student_id: str
    ) -> FileRecord | None:
        """Fetch a file record only if it belongs to the given student.

        TODO: Replace with:
            SELECT * FROM student_files
            WHERE id = $1 AND student_id = $2;
        """
        record = self._files.get(file_id)
        if record and record.student_id == student_id:
            return record
        return None

    async def get_profile_files(self, student_id: str) -> list[FileRecord]:
        """List all profile files for a student.

        TODO: Replace with:
            SELECT * FROM student_files
            WHERE student_id = $1 AND is_profile_file = TRUE
            ORDER BY created_at DESC;
        """
        return sorted(
            [
                f
                for f in self._files.values()
                if f.student_id == student_id and f.is_profile_file
            ],
            key=lambda f: f.created_at,
            reverse=True,
        )

    async def count_profile_resumes(self, student_id: str) -> int:
        """Count the number of profile resumes for a student."""
        return sum(
            1
            for f in self._files.values()
            if f.student_id == student_id and f.is_profile_file and f.file_type == "resume"
        )

    async def count_profile_cover_letters(self, student_id: str) -> int:
        """Count the number of profile cover letters for a student."""
        return sum(
            1
            for f in self._files.values()
            if f.student_id == student_id and f.is_profile_file and f.file_type == "cover_letter"
        )

    async def update_profile_status(self, file_id: str, is_profile_file: bool) -> None:
        """Update the is_profile_file status of a file record."""
        if file_id in self._files:
            self._files[file_id].is_profile_file = is_profile_file

    async def mark_file_used_for_application(self, file_id: str) -> None:
        """Set used_for_application = True for a file record."""
        if file_id in self._files:
            self._files[file_id].used_for_application = True



    async def delete_file_record(self, file_id: str) -> None:
        """Hard-delete a file record.

        TODO: Replace with:
            DELETE FROM student_files WHERE id = $1;
        """
        self._files.pop(file_id, None)
        # Clean up share tokens
        old_hash = self._share_tokens.pop(file_id, None)
        if old_hash:
            self._token_hash_to_file.pop(old_hash, None)
        logger.info("Deleted file record id=%s", file_id)

    async def get_file_by_share_token_hash(
        self, token_hash: str
    ) -> FileRecord | None:
        """Look up a file using a hashed share token.

        TODO: Replace with:
            SELECT sf.* FROM student_files sf
            JOIN share_tokens st ON sf.id = st.file_id
            WHERE st.token_hash = $1;
        """
        file_id = self._token_hash_to_file.get(token_hash)
        if file_id is None:
            return None
        return self._files.get(file_id)

    async def store_share_token(self, file_id: str, token_hash: str) -> None:
        """Persist a share-token hash for a file.

        TODO: Replace with:
            INSERT INTO share_tokens (file_id, token_hash)
            VALUES ($1, $2)
            ON CONFLICT (file_id) DO UPDATE SET token_hash = $2;
        """
        # Remove old token hash if exists
        old_hash = self._share_tokens.get(file_id)
        if old_hash:
            self._token_hash_to_file.pop(old_hash, None)

        self._share_tokens[file_id] = token_hash
        self._token_hash_to_file[token_hash] = file_id
        logger.info("Stored share token hash for file_id=%s", file_id)

    async def set_default_resume(self, student_id: str, file_id: str) -> None:
        # Check if target file exists and belongs to the student
        target = self._files.get(file_id)
        if not target or target.student_id != student_id:
            raise ValueError("Target resume not found or does not belong to the student.")
        
        # Set all other resumes for the student to is_default = False
        for record in self._files.values():
            if record.student_id == student_id:
                record.is_default = False
                
        # Set the target file to is_default = True
        target.is_default = True
        logger.info("Set default resume for student=%s to file_id=%s", student_id, file_id)




# ---------------------------------------------------------------------------
# In-memory Pending Upload Store (development/testing only)
# ---------------------------------------------------------------------------


class InMemoryPendingUploadStore(PendingUploadStoreInterface):
    """Dict-based pending upload store for local development/testing.

    WARNING: NOT production-ready.
    - Data is lost on process restart.
    - No concurrency safety beyond Python's GIL.
    - The application refuses to start in production mode with this
      implementation (enforced in main.py).

    Once the actual database schema is provided, pending upload
    persistence should be implemented through the repository/database
    layer.
    """

    def __init__(self) -> None:
        self._store: dict[str, PendingUpload] = {}

    async def save_pending_upload(self, pending: PendingUpload) -> None:
        """Store pending upload metadata in memory."""
        self._store[pending.file_id] = pending
        logger.info("Saved pending upload file_id=%s", pending.file_id)

    async def get_pending_upload(self, file_id: str) -> PendingUpload | None:
        """Retrieve a pending upload by file_id.

        Returns None if not found or expired.
        """
        pending = self._store.get(file_id)
        if pending is None:
            return None
        # Check expiry
        if datetime.now(timezone.utc) > pending.expires_at:
            # Expired — clean up and return None
            self._store.pop(file_id, None)
            logger.info("Pending upload expired: file_id=%s", file_id)
            return None
        return pending

    async def remove_pending_upload(self, file_id: str) -> None:
        """Remove a pending upload after successful completion."""
        self._store.pop(file_id, None)
        logger.info("Removed pending upload file_id=%s", file_id)


# ---------------------------------------------------------------------------
# Production Supabase Repository implementations
# ---------------------------------------------------------------------------


class SupabaseFileRepository(FileRepositoryInterface):
    """Production database repository using Supabase."""

    def __init__(self, client: Any) -> None:
        self._client = client

    def _row_to_record(self, row: dict[str, Any]) -> FileRecord:
        # DB: id, student_id, object_key, original_filename, mime_type, size_bytes, is_profile_resume, used_for_application, created_at
        # Python: id, student_id, object_key, filename, mime_type, size_bytes, file_type, is_profile_file, used_for_application, created_at
        # Handle datetime parsing (remove potential Z character and convert to ISO)
        created_at_str = row["created_at"]
        if created_at_str.endswith("Z"):
            created_at_str = created_at_str[:-1] + "+00:00"
        
        try:
            created_at_dt = datetime.fromisoformat(created_at_str)
        except Exception:
            created_at_dt = datetime.now(timezone.utc)

        return FileRecord(
            id=row["id"],
            student_id=row["student_id"],
            object_key=row["object_key"],
            filename=row["original_filename"],
            mime_type=row["mime_type"],
            size_bytes=row["size_bytes"],
            file_type="resume",  # implicitly always resume since DB column file_type is missing
            is_profile_file=row["is_profile_resume"],
            used_for_application=row["used_for_application"],
            created_at=created_at_dt,
            is_default=row.get("is_default", False),
        )

    async def create_file_record(
        self,
        *,
        file_id: str,
        student_id: str,
        object_key: str,
        filename: str,
        mime_type: str,
        size_bytes: int,
        file_type: str,
        is_profile_file: bool,
        used_for_application: bool,
    ) -> FileRecord:
        data = {
            "id": file_id,
            "student_id": student_id,
            "object_key": object_key,
            "original_filename": filename,
            "mime_type": mime_type,
            "size_bytes": size_bytes,
            "is_profile_resume": is_profile_file,
            "used_for_application": used_for_application,
        }
        try:
            res = self._client.table("student_files").insert(data).execute()
            if not res.data:
                raise RuntimeError("Failed to create file record in Supabase (empty response).")
            return self._row_to_record(res.data[0])
        except Exception as exc:
            logger.error("Supabase insert error for file_id=%s: %s", file_id, exc)
            raise

    async def get_file_by_id(self, file_id: str) -> FileRecord | None:
        try:
            res = self._client.table("student_files").select("*").eq("id", file_id).execute()
            if not res.data:
                return None
            return self._row_to_record(res.data[0])
        except Exception as exc:
            logger.error("Supabase select error for file_id=%s: %s", file_id, exc)
            return None

    async def get_student_file(
        self, file_id: str, student_id: str
    ) -> FileRecord | None:
        try:
            res = (
                self._client.table("student_files")
                .select("*")
                .eq("id", file_id)
                .eq("student_id", student_id)
                .execute()
            )
            if not res.data:
                return None
            return self._row_to_record(res.data[0])
        except Exception as exc:
            logger.error("Supabase select error for file_id=%s student_id=%s: %s", file_id, student_id, exc)
            return None

    async def get_profile_files(self, student_id: str) -> list[FileRecord]:
        try:
            res = (
                self._client.table("student_files")
                .select("*")
                .eq("student_id", student_id)
                .eq("is_profile_resume", True)
                .order("created_at", desc=True)
                .execute()
            )
            return [self._row_to_record(row) for row in res.data]
        except Exception as exc:
            logger.error("Supabase get_profile_files error for student_id=%s: %s", student_id, exc)
            return []

    async def count_profile_resumes(self, student_id: str) -> int:
        try:
            res = (
                self._client.table("student_files")
                .select("id", count="exact")
                .eq("student_id", student_id)
                .eq("is_profile_resume", True)
                .execute()
            )
            return res.count or 0
        except Exception as exc:
            logger.error("Supabase count_profile_resumes error for student_id=%s: %s", student_id, exc)
            return 0

    async def count_profile_cover_letters(self, student_id: str) -> int:
        # Since DB schema does not have cover letters in public.student_files (no file_type column), return 0
        return 0

    async def update_profile_status(self, file_id: str, is_profile_file: bool) -> None:
        try:
            self._client.table("student_files").update(
                {"is_profile_resume": is_profile_file}
            ).eq("id", file_id).execute()
        except Exception as exc:
            logger.error("Supabase update_profile_status error for file_id=%s: %s", file_id, exc)
            raise

    async def mark_file_used_for_application(self, file_id: str) -> None:
        try:
            self._client.table("student_files").update(
                {"used_for_application": True}
            ).eq("id", file_id).execute()
        except Exception as exc:
            logger.error("Supabase mark_file_used_for_application error for file_id=%s: %s", file_id, exc)
            raise

    async def delete_file_record(self, file_id: str) -> None:
        # Delete share tokens first if they exist
        try:
            self._client.table("share_tokens").delete().eq("file_id", file_id).execute()
        except Exception as exc:
            logger.warning("Could not delete from share_tokens for file_id=%s: %s", file_id, exc)

        try:
            self._client.table("student_files").delete().eq("id", file_id).execute()
        except Exception as exc:
            logger.error("Supabase delete_file_record error for file_id=%s: %s", file_id, exc)
            raise

    async def get_file_by_share_token_hash(
        self, token_hash: str
    ) -> FileRecord | None:
        try:
            res = (
                self._client.table("share_tokens")
                .select("file_id")
                .eq("token_hash", token_hash)
                .execute()
            )
            if not res.data:
                return None
            file_id = res.data[0]["file_id"]
            return await self.get_file_by_id(file_id)
        except Exception as exc:
            logger.error("Supabase get_file_by_share_token_hash error: %s", exc)
            return None

    async def store_share_token(self, file_id: str, token_hash: str) -> None:
        try:
            # Delete any existing token for this file
            self._client.table("share_tokens").delete().eq("file_id", file_id).execute()
            
            # Insert new token
            data = {
                "file_id": file_id,
                "token_hash": token_hash
            }
            self._client.table("share_tokens").insert(data).execute()
        except Exception as exc:
            logger.error("Supabase store_share_token error for file_id=%s: %s", file_id, exc)
            raise

    async def set_default_resume(self, student_id: str, file_id: str) -> None:
        try:
            # 1. Update all other resumes for the student to is_default = False
            self._client.table("student_files").update(
                {"is_default": False}
            ).eq("student_id", student_id).execute()
            
            # 2. Update target file to is_default = True
            self._client.table("student_files").update(
                {"is_default": True}
            ).eq("id", file_id).eq("student_id", student_id).execute()
            
            logger.info("Set default resume in Supabase for student=%s to file_id=%s", student_id, file_id)
        except Exception as exc:
            logger.error("Supabase set_default_resume error for student_id=%s file_id=%s: %s", student_id, file_id, exc)
            raise


class SupabasePendingUploadStore(PendingUploadStoreInterface):
    """Production pending upload store using Supabase database."""

    def __init__(self, client: Any) -> None:
        self._client = client

    def _row_to_pending(self, row: dict[str, Any]) -> PendingUpload:
        expires_at_str = row["expires_at"]
        if expires_at_str.endswith("Z"):
            expires_at_str = expires_at_str[:-1] + "+00:00"

        try:
            expires_at_dt = datetime.fromisoformat(expires_at_str)
        except Exception:
            expires_at_dt = datetime.now(timezone.utc)

        return PendingUpload(
            file_id=row["file_id"],
            student_id=row["student_id"],
            pending_object_key=row["pending_object_key"],
            permanent_object_key=row["permanent_object_key"],
            filename=row["filename"],
            mime_type=row["mime_type"],
            file_type=row["file_type"],
            is_profile_file=row["is_profile_file"],
            expires_at=expires_at_dt,
        )

    async def save_pending_upload(self, pending: PendingUpload) -> None:
        data = {
            "file_id": pending.file_id,
            "student_id": pending.student_id,
            "pending_object_key": pending.pending_object_key,
            "permanent_object_key": pending.permanent_object_key,
            "filename": pending.filename,
            "mime_type": pending.mime_type,
            "file_type": pending.file_type,
            "is_profile_file": pending.is_profile_file,
            "expires_at": pending.expires_at.isoformat(),
        }
        try:
            self._client.table("pending_uploads").insert(data).execute()
            logger.info("Saved pending upload file_id=%s to Supabase", pending.file_id)
        except Exception as exc:
            logger.error("Supabase save_pending_upload error for file_id=%s: %s", pending.file_id, exc)
            raise

    async def get_pending_upload(self, file_id: str) -> PendingUpload | None:
        try:
            res = (
                self._client.table("pending_uploads")
                .select("*")
                .eq("file_id", file_id)
                .execute()
            )
            if not res.data:
                return None
            
            pending = self._row_to_pending(res.data[0])
            # Check expiry
            if datetime.now(timezone.utc) > pending.expires_at:
                await self.remove_pending_upload(file_id)
                logger.info("Pending upload expired: file_id=%s", file_id)
                return None
            return pending
        except Exception as exc:
            logger.error("Supabase get_pending_upload error for file_id=%s: %s", file_id, exc)
            return None

    async def remove_pending_upload(self, file_id: str) -> None:
        try:
            self._client.table("pending_uploads").delete().eq("file_id", file_id).execute()
            logger.info("Removed pending upload file_id=%s from Supabase", file_id)
        except Exception as exc:
            logger.error("Supabase remove_pending_upload error for file_id=%s: %s", file_id, exc)
            raise
