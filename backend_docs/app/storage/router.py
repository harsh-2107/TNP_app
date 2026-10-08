# FastAPI router endpoints for the storage module.

# Two routers
# - storage_router storage, all endpoints require student auth.
# - share_router share, no authentication



from typing import Any
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import RedirectResponse

from app.db.supabase_client import get_supabase_client
from app.auth.dependencies import CurrentStudent, get_current_student
from app.storage.schemas import (
    CompleteUploadRequest,
    CompleteUploadResponse,
    DeleteResponse,
    FileViewResponse,
    ProfileFileListResponse,
    UploadUrlRequest,
    UploadUrlResponse,
)

# These will be overwritten at app startup via set_storage_service()
_storage_service = None


def set_storage_service(service) -> None:
    # Called from main.py when just start

    global _storage_service
    _storage_service = service


def _get_service():
    if _storage_service is None:
        raise RuntimeError(
            "StorageService not initialised. "
            "Ensure set_storage_service() is called during app startup."
        )
    return _storage_service


#Storage routr

storage_router = APIRouter(prefix="/storage", tags=["storage"])


@storage_router.post(
    "/upload-url",
    response_model=UploadUrlResponse,
    summary="Request a presigned upload URL",
    description=(
        "Validates the file metadata and returns a presigned PUT URL "
        "for direct upload to R2. The client uploads the file directly "
        "to the returned URL, then calls /complete-upload."
    ),
)
async def request_upload_url(
    request: UploadUrlRequest,
    student: CurrentStudent = Depends(get_current_student),
) -> UploadUrlResponse:
    service = _get_service()
    return await service.request_upload_url(student.id, student.bt_id, request)


@storage_router.post(
    "/complete-upload",
    response_model=CompleteUploadResponse,
    summary="Finalize an upload",
    description=(
        "Called after the client has PUT the file to R2. Verifies the "
        "upload via HEAD, creates the database record, and returns "
        "the file metadata."
    ),
)
async def complete_upload(
    request: CompleteUploadRequest,
    student: CurrentStudent = Depends(get_current_student),
) -> CompleteUploadResponse:
    service = _get_service()
    return await service.complete_upload(student.id, request.file_id)


@storage_router.get(
    "/profile/files",
    response_model=ProfileFileListResponse,
    summary="List profile files",
    description="Returns metadata for all of the student's profile files.",
)
async def list_profile_files(
    student: CurrentStudent = Depends(get_current_student),
) -> ProfileFileListResponse:
    service = _get_service()
    return await service.get_profile_files(student.id)


@storage_router.get(
    "/files/{file_id}/view",
    response_model=FileViewResponse,
    summary="Get file view URL",
    description=(
        "Generates a short-lived presigned GET URL for viewing a file. "
        "The student can only access their own files."
    ),
)
async def view_file(
    file_id: str,
    student: CurrentStudent = Depends(get_current_student),
) -> FileViewResponse:
    service = _get_service()
    return await service.get_file_view_url(student.id, file_id)


@storage_router.delete(
    "/files/{file_id}",
    response_model=DeleteResponse,
    summary="Delete a profile resume",
    description=(
        "Deletes an unreferenced profile resume. Fails if the file is "
        "referenced by any application."
    ),
)
async def delete_file(
    file_id: str,
    student: CurrentStudent = Depends(get_current_student),
) -> DeleteResponse:
    service = _get_service()
    return await service.delete_file(student.id, file_id)


@storage_router.post(
    "/files/{file_id}/default",
    summary="Set default profile resume",
    description="Marks the specified resume as the student's default resume for recruitment drives.",
)
async def set_default_resume(
    file_id: str,
    student: CurrentStudent = Depends(get_current_student),
) -> dict:
    service = _get_service()
    await service.set_default_resume(student.id, file_id)
    return {"status": "success", "message": "Resume set as default successfully."}


@storage_router.post(
    "/files/{file_id}/rename-to-btid",
    summary="Rename file to BTID standard format",
    description="Renames the stored resume's display filename to the student's BTID standard (e.g. BT25CSA016_Resume.pdf).",
)
async def rename_file_to_btid(
    file_id: str,
    current_student: CurrentStudent = Depends(get_current_student),
    supabase: Any = Depends(get_supabase_client),
) -> Any:
    """Rename a student file record filename using their BTID."""
    try:
        # Check that the file belongs to the student first
        file_res = supabase.table("student_files").select("*").eq("id", file_id).execute()
        if not file_res.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="File not found."
            )
        file_rec = file_res.data[0]
        if file_rec["student_id"] != current_student.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not own this file."
            )

        from app.storage.utils import get_extension
        ext = get_extension(file_rec["filename"])
        new_name = f"{current_student.bt_id}_Resume{ext}"

        # Update filename in Supabase
        update_res = (
            supabase.table("student_files")
            .update({"filename": new_name})
            .eq("id", file_id)
            .execute()
        )
        return {
            "status": "success",
            "message": "File renamed successfully to BTID format.",
            "file": update_res.data[0]
        }
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to rename file: {str(exc)}"
        )


#Share router

share_router = APIRouter(tags=["share"])


@share_router.get(
    "/share/{token}",
    summary="Resolve share token",
    description=(
        "Resolves a share token to a fresh presigned R2 GET URL "
        "and returns an HTTP 302 redirect. Used by HR to view "
        "student files."
    ),
    responses={
        302: {"description": "Redirect to presigned R2 URL"},
        404: {"description": "Invalid or expired share token"},
    },
)
async def resolve_share_token(token: str) -> RedirectResponse:
    service = _get_service()
    download_url = await service.resolve_share_token(token)
    return RedirectResponse(url=download_url, status_code=302)
