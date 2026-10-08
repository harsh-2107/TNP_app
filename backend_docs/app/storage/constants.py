"""Constants for the storage module."""

# ---------------------------------------------------------------------------
# Supported file types
# ---------------------------------------------------------------------------

# Allowed MIME types for resume and cover letter uploads.
ALLOWED_MIME_TYPES: set[str] = {
    "application/pdf",
}

# Allowed file extensions (lowercase, with leading dot).
ALLOWED_EXTENSIONS: set[str] = {".pdf"}

# ---------------------------------------------------------------------------
# R2 object key prefixes
# ---------------------------------------------------------------------------

OBJECT_KEY_PREFIX_PENDING = "pending/"
OBJECT_KEY_PREFIX_PERMANENT = "files/"

# ---------------------------------------------------------------------------
# File type identifiers (used in UploadUrlRequest.file_type)
# ---------------------------------------------------------------------------

FILE_TYPE_RESUME = "resume"
FILE_TYPE_COVER_LETTER = "cover_letter"
