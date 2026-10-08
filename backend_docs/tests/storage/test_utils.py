"""Tests for app.storage.utils — pure helper functions."""

import pytest

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


class TestGenerateFileId:
    """Tests for generate_file_id()."""

    def test_returns_32_char_hex_string(self):
        file_id = generate_file_id()
        assert len(file_id) == 32
        assert file_id == file_id.lower()
        # Should be valid hex
        int(file_id, 16)

    def test_unique_ids(self):
        ids = {generate_file_id() for _ in range(100)}
        assert len(ids) == 100


class TestGetExtension:
    """Tests for get_extension()."""

    def test_pdf(self):
        assert get_extension("resume.pdf") == ".pdf"

    def test_docx(self):
        assert get_extension("resume.docx") == ".docx"

    def test_uppercase(self):
        assert get_extension("Resume.PDF") == ".pdf"

    def test_mixed_case(self):
        assert get_extension("My_Resume.Docx") == ".docx"

    def test_no_extension(self):
        assert get_extension("resume") == ""

    def test_multiple_dots(self):
        assert get_extension("my.resume.v2.pdf") == ".pdf"


class TestGenerateStructuredFilename:
    """Tests for generate_structured_filename()."""

    def test_structured_filename(self):
        filename = generate_structured_filename("BT25CSA016", "abc456", ".pdf")
        import re
        assert re.match(r"^BT25CSA016_\d{8}T\d{6}_abc456\.pdf$", filename)


class TestBuildKeys:
    """Tests for build_pending_key() and build_permanent_key()."""

    def test_pending_key(self):
        key = build_pending_key("BT25CSA016", "BT25CSA016_abc456.pdf")
        assert key == "pending/BT25CSA016/BT25CSA016_abc456.pdf"

    def test_permanent_key(self):
        key = build_permanent_key("BT25CSA016", "BT25CSA016_abc456.pdf")
        assert key == "files/BT25CSA016/BT25CSA016_abc456.pdf"


class TestSanitizeFilename:
    """Tests for sanitize_filename()."""

    def test_simple_filename(self):
        assert sanitize_filename("resume.pdf") == "resume.pdf"

    def test_strips_path(self):
        assert sanitize_filename("/tmp/uploads/resume.pdf") == "resume.pdf"

    def test_windows_path(self):
        result = sanitize_filename("C:\\Users\\student\\resume.pdf")
        # os.path.basename handles this on Linux by not splitting
        # at backslash, but the regex replaces backslashes
        assert "resume.pdf" in result or "resume" in result

    def test_null_bytes_removed(self):
        result = sanitize_filename("resume\x00.pdf")
        assert "\x00" not in result
        assert result == "resume.pdf"

    def test_special_characters_replaced(self):
        result = sanitize_filename("my<resume>.pdf")
        assert "<" not in result
        assert ">" not in result

    def test_empty_string_returns_default(self):
        assert sanitize_filename("") == "unnamed_file"

    def test_only_dots_returns_default(self):
        assert sanitize_filename("...") == "unnamed_file"

    def test_length_limit(self):
        long_name = "a" * 300 + ".pdf"
        result = sanitize_filename(long_name)
        assert len(result) <= 255

    def test_collapses_consecutive_underscores(self):
        result = sanitize_filename("my___resume.pdf")
        assert "___" not in result


class TestValidateMimeType:
    """Tests for validate_mime_type()."""

    def test_pdf_allowed(self):
        assert validate_mime_type("application/pdf") is True



    def test_jpeg_rejected(self):
        assert validate_mime_type("image/jpeg") is False

    def test_empty_rejected(self):
        assert validate_mime_type("") is False

    def test_text_plain_rejected(self):
        assert validate_mime_type("text/plain") is False


class TestValidateExtension:
    """Tests for validate_extension()."""

    def test_pdf_allowed(self):
        assert validate_extension("resume.pdf") is True



    def test_doc_rejected(self):
        assert validate_extension("resume.doc") is False

    def test_txt_rejected(self):
        assert validate_extension("notes.txt") is False

    def test_no_extension_rejected(self):
        assert validate_extension("resume") is False

    def test_case_insensitive(self):
        assert validate_extension("Resume.PDF") is True

class TestValidatePdfMagicBytes:
    """Tests for validate_pdf_magic_bytes()."""

    def test_valid_pdf_magic_bytes(self):
        assert validate_pdf_magic_bytes(b"%PDF-1.4") is True
        assert validate_pdf_magic_bytes(b"%PDF-") is True

    def test_invalid_pdf_magic_bytes(self):
        assert validate_pdf_magic_bytes(b"PK\x03\x04\x14") is False
        assert validate_pdf_magic_bytes(b"") is False
        assert validate_pdf_magic_bytes(b"%PD") is False


class TestShareToken:
    """Tests for generate_share_token() and hash_share_token()."""

    def test_token_length(self):
        token = generate_share_token()
        # secrets.token_urlsafe(32) produces 43 characters
        assert len(token) == 43

    def test_token_uniqueness(self):
        tokens = {generate_share_token() for _ in range(100)}
        assert len(tokens) == 100

    def test_hash_deterministic(self):
        token = "test-token-123"
        hash1 = hash_share_token(token)
        hash2 = hash_share_token(token)
        assert hash1 == hash2

    def test_hash_is_sha256_hex(self):
        token = "test-token"
        result = hash_share_token(token)
        assert len(result) == 64  # SHA-256 hex digest
        int(result, 16)  # Should be valid hex

    def test_different_tokens_different_hashes(self):
        hash1 = hash_share_token("token-a")
        hash2 = hash_share_token("token-b")
        assert hash1 != hash2
