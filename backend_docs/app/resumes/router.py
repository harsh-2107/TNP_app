# FastAPI router for resume delete

from typing import Any, Optional
from fastapi import APIRouter, Depends, HTTPException, status

from app.core.config import Settings, get_settings
from app.core.logging import get_logger
from app.db.supabase_client import get_supabase_client
from app.resumes.schemas import ResumeDeleteResponse
from app.storage.r2_client import R2Client

logger = get_logger(__name__)

resumes_router = APIRouter(prefix="/api/resumes", tags=["resumes"])


def get_r2_client(settings: Settings = Depends(get_settings)) -> R2Client:
    #Cloudfare - Harsh Jaiswal
    return R2Client(settings)


@resumes_router.delete(
    "/{file_id}",
    response_model=ResumeDeleteResponse,
    status_code=status.HTTP_200_OK,
    summary="Delete a resume (Soft vs Hard delete)",
    description=(
        "Deletes a student resume according to strict retention rules:\n"
        "- If `used_for_application == True`: Performs a SOFT DELETE by setting "
        "`is_profile_resume = False` in the database. Preserves the file in Cloudflare R2.\n"
        "- If `used_for_application == False`: Performs a HARD DELETE by deleting the object "
        "from Cloudflare R2 via boto3, then deleting the database row from `student_files`."
    ),
)
async def delete_resume(
    file_id: str,
    supabase: Any = Depends(get_supabase_client),
    r2_client: R2Client = Depends(get_r2_client),
) -> ResumeDeleteResponse:
    # Delete a resume file
    logger.info("Initiating resume deletion for file_id=%s", file_id)

    # 1. aasks Supabase for the file record
    try:
        query_res = supabase.table("student_files").select("*").eq("id", file_id).execute()
    except Exception as exc:
        logger.error("Supabase query error for file_id=%s: %s", file_id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database query failed: {str(exc)}",
        )

    if not query_res.data or len(query_res.data) == 0:
        logger.warning("Resume file_id=%s not found in registry", file_id)
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Resume file with ID '{file_id}' not found.",
        )

    file_record = query_res.data[0]
    used_for_app: bool = bool(file_record.get("used_for_application", False))
    object_key: str = file_record.get("object_key", "")

    # 2. SOFT DELETE Logic (used_for_application == True)
    if used_for_app:
        logger.info(
            "File file_id=%s is linked to an application. Performing SOFT DELETE (is_profile_resume=False)",
            file_id,
        )
        try:
            supabase.table("student_files").update({"is_profile_resume": False}).eq("id", file_id).execute()
        except Exception as exc:
            logger.error("Failed to soft-delete file_id=%s in Supabase: %s", file_id, exc)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to update profile resume status: {str(exc)}",
            )

        return ResumeDeleteResponse(
            status="soft_deleted",
            message=(
                "Resume was previously submitted to a placement drive. Soft-deleted "
                "by unmarking 'is_profile_resume=False' while preserving the file in "
                "Cloudflare R2 for recruiter review."
            ),
            file_id=file_id,
            is_profile_resume=False,
            used_for_application=True,
            r2_deleted=False,
        )

    # 3. HARD DELETE Logi
    logger.info(
        "File file_id=%s has NOT been used in any application. Performing HARD DELETE",
        file_id,
    )

    # Delete from Cloudflare R2 storage  boto3 wrapper
    if object_key:
        try:
            r2_client.delete_object(object_key)
            logger.info("Successfully deleted object_key=%s from R2", object_key)
        except Exception as exc:
            logger.error("Failed to delete object_key=%s from R2: %s", object_key, exc)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Cloudflare R2 storage deletion failed: {str(exc)}",
            )

    # Delete record from Supabase 
    try:
        supabase.table("student_files").delete().eq("id", file_id).execute()
        logger.info("Successfully deleted row for file_id=%s from student_files", file_id)
    except Exception as exc:
        logger.error("Failed to delete record for file_id=%s from Supabase: %s", file_id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to remove file record from database: {str(exc)}",
        )

    return ResumeDeleteResponse(
        status="hard_deleted",
        message="Resume permanently deleted from both Cloudflare R2 storage and database registry.",
        file_id=file_id,
        is_profile_resume=False,
        used_for_application=False,
        r2_deleted=True,
    )
