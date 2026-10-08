import os
import uuid
import pytest
from datetime import datetime, timezone, timedelta
from app.core.config import get_settings
from app.db.supabase_client import create_supabase_client
from app.storage.repository import SupabaseFileRepository, SupabasePendingUploadStore
from app.db.pending_upload_interface import PendingUpload

settings = get_settings()
has_real_supabase = (
    settings.SUPABASE_URL != "https://placeholder-project.supabase.co"
    and settings.SUPABASE_SERVICE_ROLE_KEY != ""
)

pytestmark = pytest.mark.skipif(
    not has_real_supabase,
    reason="Supabase integration tests skipped because credentials are placeholders."
)


@pytest.fixture
def supabase_client():
    client = create_supabase_client(settings)
    assert client is not None
    return client


@pytest.fixture
def file_repo(supabase_client):
    return SupabaseFileRepository(supabase_client)


@pytest.fixture
def pending_store(supabase_client):
    return SupabasePendingUploadStore(supabase_client)


@pytest.mark.asyncio
async def test_supabase_file_repository_crud(file_repo):
    """Verify that student_files database CRUD works on the live database."""
    student_id = "9376cd15-aa1d-43a0-8478-174fe63ab7d5"  # Valid student UUID from inspection
    file_id = str(uuid.uuid4())
    object_key = f"resumes/{file_id}.pdf"
    filename = "test_resume.pdf"
    
    # 1. Create
    record = await file_repo.create_file_record(
        file_id=file_id,
        student_id=student_id,
        object_key=object_key,
        filename=filename,
        mime_type="application/pdf",
        size_bytes=1024,
        file_type="resume",
        is_profile_file=True,
        used_for_application=False
    )
    
    assert record.id == file_id
    assert record.student_id == student_id
    assert record.filename == filename
    assert record.is_profile_file is True
    
    # 2. Get by ID
    fetched = await file_repo.get_file_by_id(file_id)
    assert fetched is not None
    assert fetched.id == file_id
    
    # 3. Get Student File
    student_file = await file_repo.get_student_file(file_id, student_id)
    assert student_file is not None
    
    # 4. Get Profile Files
    profile_files = await file_repo.get_profile_files(student_id)
    assert len(profile_files) > 0
    assert any(f.id == file_id for f in profile_files)
    
    # 5. Count Profile Resumes
    count = await file_repo.count_profile_resumes(student_id)
    assert count >= 1
    
    # 6. Update Profile Status
    await file_repo.update_profile_status(file_id, False)
    fetched_updated = await file_repo.get_file_by_id(file_id)
    assert fetched_updated.is_profile_file is False
    
    # 7. Mark Used For Application
    await file_repo.mark_file_used_for_application(file_id)
    fetched_app = await file_repo.get_file_by_id(file_id)
    assert fetched_app.used_for_application is True
    
    # 8. Delete
    await file_repo.delete_file_record(file_id)
    deleted = await file_repo.get_file_by_id(file_id)
    assert deleted is None


@pytest.mark.asyncio
async def test_supabase_pending_uploads_crud(pending_store):
    """Verify that pending_uploads CRUD works.
    
    NOTE: This will raise an error if the public.pending_uploads table is missing.
    """
    file_id = str(uuid.uuid4())[:32]  # Max 32 chars
    student_id = "9376cd15-aa1d-43a0-8478-174fe63ab7d5"
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)
    
    pending = PendingUpload(
        file_id=file_id,
        student_id=student_id,
        pending_object_key=f"pending/{file_id}.pdf",
        permanent_object_key=f"files/{file_id}.pdf",
        filename="test_pending.pdf",
        mime_type="application/pdf",
        file_type="resume",
        is_profile_file=True,
        expires_at=expires_at
    )
    
    try:
        # Save
        await pending_store.save_pending_upload(pending)
        
        # Get
        fetched = await pending_store.get_pending_upload(file_id)
        assert fetched is not None
        assert fetched.filename == "test_pending.pdf"
        
        # Remove
        await pending_store.remove_pending_upload(file_id)
        deleted = await pending_store.get_pending_upload(file_id)
        assert deleted is None
        
    except Exception as exc:
        if "public.pending_uploads" in str(exc):
            pytest.skip("Skipped because public.pending_uploads table has not been created yet in Supabase.")
        else:
            raise


@pytest.mark.asyncio
async def test_supabase_share_tokens(file_repo):
    """Verify that share token operations work.
    
    NOTE: This will raise an error if the public.share_tokens table is missing.
    """
    student_id = "9376cd15-aa1d-43a0-8478-174fe63ab7d5"
    file_id = str(uuid.uuid4())
    object_key = f"resumes/{file_id}.pdf"
    
    try:
        # Create a file first
        await file_repo.create_file_record(
            file_id=file_id,
            student_id=student_id,
            object_key=object_key,
            filename="test_share.pdf",
            mime_type="application/pdf",
            size_bytes=1024,
            file_type="resume",
            is_profile_file=True,
            used_for_application=False
        )
        
        token_hash = "fake-sha256-hash-value-for-testing"
        
        # Store token
        await file_repo.store_share_token(file_id, token_hash)
        
        # Get by token
        record = await file_repo.get_file_by_share_token_hash(token_hash)
        assert record is not None
        assert record.id == file_id
        
        # Cleanup file (which should trigger token cleanup)
        await file_repo.delete_file_record(file_id)
        
    except Exception as exc:
        # Cleanup file if created
        try:
            await file_repo.delete_file_record(file_id)
        except Exception:
            pass
            
        if "public.share_tokens" in str(exc):
            pytest.skip("Skipped because public.share_tokens table has not been created yet in Supabase.")
        else:
            raise


@pytest.mark.asyncio
async def test_supabase_default_resume(file_repo):
    """Verify that default resume setting works.
    
    NOTE: This will raise an error if the public.student_files table is missing the is_default column.
    """
    student_id = "9376cd15-aa1d-43a0-8478-174fe63ab7d5"
    file_id = str(uuid.uuid4())
    object_key = f"resumes/{file_id}.pdf"
    
    try:
        # Create a file first
        await file_repo.create_file_record(
            file_id=file_id,
            student_id=student_id,
            object_key=object_key,
            filename="test_default.pdf",
            mime_type="application/pdf",
            size_bytes=1024,
            file_type="resume",
            is_profile_file=True,
            used_for_application=False
        )
        
        # Set default
        await file_repo.set_default_resume(student_id, file_id)
        
        # Verify it is default
        record = await file_repo.get_file_by_id(file_id)
        assert record is not None
        assert record.is_default is True
        
        # Cleanup
        await file_repo.delete_file_record(file_id)
        
    except Exception as exc:
        try:
            await file_repo.delete_file_record(file_id)
        except Exception:
            pass
            
        if "student_files.is_default" in str(exc) or "column" in str(exc):
            pytest.skip("Skipped because public.student_files table does not have is_default column yet.")
        else:
            raise
