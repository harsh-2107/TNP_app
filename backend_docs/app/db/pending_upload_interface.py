# /*ye vibe coded hai a good fallback jo maine socha bhi nahi tha*/
"""Abstract interface for pending upload state management.

Between POST /storage/upload-url and POST /storage/complete-upload,
the backend must track the association between a file_id and its
metadata (student_id, object_key, expected MIME type, etc.).

This interface abstracts that storage so the concrete implementation
can be swapped between:
- In-memory store (development/testing only)
- Database table (production — requires schema confirmation from teammate)
- Cache store with TTL (alternative production option)

The production implementation decision is deferred to the teammate
who owns the database schema. The interface is designed so swapping
is a one-file change in the dependency wiring.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime


@dataclass
class PendingUpload:
    """Metadata for an upload that has been initiated but not yet completed.

    Created when POST /storage/upload-url is called.
    Consumed and removed when POST /storage/complete-upload succeeds.

    Attributes:
        file_id: Unique identifier generated for this upload.
        student_id: The student who requested the upload.
        object_key: R2 object key where the file will be stored.
        original_filename: Sanitized filename provided by the student.
        mime_type: Expected MIME type of the file.
        file_type: "resume" or "cover_letter".
        is_profile_resume: Whether this upload is for a profile resume.
        expires_at: When this pending upload record expires.
    """

    file_id: str
    student_id: str
    pending_object_key: str
    permanent_object_key: str
    filename: str
    mime_type: str
    file_type: str
    is_profile_file: bool
    expires_at: datetime


class PendingUploadStoreInterface(ABC):
    """Abstract base class for pending upload state management.

    Implementations must handle expiry: get_pending_upload should
    return None for expired entries.
    """

    @abstractmethod
    async def save_pending_upload(self, pending: PendingUpload) -> None:
        """Store pending upload metadata.

        Args:
            pending: The PendingUpload to store.
        """
        ...

    @abstractmethod
    async def get_pending_upload(self, file_id: str) -> PendingUpload | None:
        """Retrieve a pending upload by file_id.

        Should return None if the pending upload does not exist
        or has expired.

        Args:
            file_id: The unique file identifier.

        Returns:
            The PendingUpload if found and not expired, None otherwise.
        """
        ...

    @abstractmethod
    async def remove_pending_upload(self, file_id: str) -> None:
        """Remove a pending upload after successful completion.

        Args:
            file_id: The unique file identifier.
        """
        ...
