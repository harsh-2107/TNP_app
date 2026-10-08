"""Pure helper functions for the storage module.

All functions in this module are pure — no boto3, no database access,
no FastAPI dependencies, no I/O. They can be tested in complete isolation.
"""

import hashlib
import os
import re
import secrets
import uuid
from datetime import datetime, timezone

from app.storage.constants import ALLOWED_EXTENSIONS, ALLOWED_MIME_TYPES
from app.storage.constants import OBJECT_KEY_PREFIX_PENDING, OBJECT_KEY_PREFIX_PERMANENT


def generate_file_id() -> str:
    """Generate a unique file identifier.

    Returns:
        UUID4 hex string (32 characters, no hyphens).
    """
    return uuid.uuid4().hex


def get_extension(filename: str) -> str:
    """Extract the lowercase file extension from a filename.

    Args:
        filename: Original filename.

    Returns:
        Lowercase extension including the leading dot (e.g. ".pdf").
        Empty string if no extension is present.
    """
    _, ext = os.path.splitext(filename)
    return ext.lower()


def generate_structured_filename(bt_id: str, file_id: str, extension: str) -> str:
    """Generate the structured filename for R2 storage.

    Format: {bt_id}_{timestamp}_{uuid}{extension}
    Example: BT25CSA016_20260810T013421_550e8400.pdf
    """
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
    # Take first 8 chars of uuid for brevity in the filename, or use full if preferred.
    # We will use the full or shortened file_id (we already generate a 32-char file_id).
    # The requirement says UUID, we'll use an 8-char slice for the filename to match the example `550e8400`.
    short_uuid = file_id[:8]
    return f"{bt_id}_{timestamp}_{short_uuid}{extension}"


def build_pending_key(bt_id: str, structured_filename: str) -> str:
    """Build the pending R2 object key."""
    return f"{OBJECT_KEY_PREFIX_PENDING}{bt_id}/{structured_filename}"


def build_permanent_key(bt_id: str, structured_filename: str) -> str:
    """Build the permanent R2 object key."""
    return f"{OBJECT_KEY_PREFIX_PERMANENT}{bt_id}/{structured_filename}"


def sanitize_filename(name: str) -> str:
    """Sanitize a filename for safe storage and display."""
    # Remove null bytes
    name = name.replace("\x00", "")
    # Extract basename (remove path components)
    name = os.path.basename(name)
    # Replace characters that aren't alphanumeric, dots, hyphens,
    # underscores, or spaces
    name = re.sub(r"[^\w.\-\s]", "_", name)
    # Collapse consecutive underscores and spaces
    name = re.sub(r"[_\s]+", "_", name)
    # Limit length
    name = name[:255]
    # Strip leading/trailing whitespace and dots
    name = name.strip(". ")
    return name or "unnamed_file"


def validate_mime_type(mime_type: str) -> bool:
    """Check whether a MIME type is in the allowed set."""
    return mime_type in ALLOWED_MIME_TYPES


def validate_extension(filename: str) -> bool:
    """Check whether a filename has an allowed extension."""
    ext = get_extension(filename)
    return ext in ALLOWED_EXTENSIONS


def validate_pdf_magic_bytes(data: bytes) -> bool:
    """Check if the provided bytes start with the PDF magic number (%PDF-)."""
    return data.startswith(b"%PDF-")


def generate_share_token() -> str:
    """Generate a cryptographically secure share token."""
    return secrets.token_urlsafe(32)


def hash_share_token(token: str) -> str:
    """Hash a share token using SHA-256."""
    return hashlib.sha256(token.encode("utf-8")).hexdigest()
