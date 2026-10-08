"""Pydantic v2 request/response schemas for the storage module.

object_key is NEVER returned to the client — it is internal to
the backend and R2.
"""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Request schemas
# ---------------------------------------------------------------------------


class UploadUrlRequest(BaseModel):
    """Request body for POST /storage/upload-url."""

    filename: str = Field(
        ...,
        description="Original filename (e.g. 'resume.pdf').",
        min_length=1,
        max_length=255,
    )
    mime_type: str = Field(
        ...,
        description="MIME type of the file (e.g. 'application/pdf').",
    )
    size_bytes: int = Field(
        ...,
        description="Client-reported file size in bytes.",
        gt=0,
    )
    file_type: Literal["resume", "cover_letter"] = Field(
        ...,
        description="Type of file being uploaded.",
    )
    is_profile_file: bool = Field(
        default=False,
        description=(
            "True if this upload is for a profile file. "
        ),
    )


class CompleteUploadRequest(BaseModel):
    """Request body for POST /storage/complete-upload."""

    file_id: str = Field(
        ...,
        description="file_id returned from the upload-url endpoint.",
        min_length=1,
    )


# ---------------------------------------------------------------------------
# Response schemas
# ---------------------------------------------------------------------------


class UploadUrlResponse(BaseModel):
    """Response body for POST /storage/upload-url."""

    file_id: str
    upload_url: str
    expires_in: int = Field(
        ..., description="Presigned URL lifetime in seconds."
    )


class FileRecordResponse(BaseModel):
    """Public representation of a file record.

    object_key is intentionally omitted — never exposed to clients.
    """

    id: str
    filename: str
    file_type: Literal["resume", "cover_letter"]
    mime_type: str
    size_bytes: int
    is_profile_file: bool
    used_for_application: bool
    created_at: datetime


class ProfileFileListResponse(BaseModel):
    """Response body for GET /storage/profile/files."""

    files: list[FileRecordResponse]


class FileViewResponse(BaseModel):
    """Response body for GET /storage/files/{id}/view."""

    download_url: str
    expires_in: int = Field(
        ..., description="Presigned URL lifetime in seconds."
    )


class CompleteUploadResponse(BaseModel):
    """Response body for POST /storage/complete-upload."""

    file: FileRecordResponse


class DeleteResponse(BaseModel):
    """Response body for DELETE /storage/files/{id}."""

    message: str
