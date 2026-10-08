#applicatio submissionwala fast API



from datetime import datetime, timezone
from typing import Any
import uuid

# pyrefly: ignore
from fastapi import APIRouter, Depends, HTTPException, status
# pyrefly: ignore 
from fastapi.responses import JSONResponse

from app.applications.schemas import ApplyRequest, ApplyResponse, IneligibleApplicationResponse
from app.core.logging import get_logger
from app.db.supabase_client import get_supabase_client
from app.services.eligibility_engine import EligibilityEngine

logger = get_logger(__name__)

applications_router = APIRouter(prefix="/api/applications", tags=["applications"])


@applications_router.post(
    "/apply",
    response_model=ApplyResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Submit job drive application",
    description=(
        "Submits a student's application for a company recruitment drive:\n"
        "1. Validates the attached resume exists and belongs to the student.\n"
        "2. Evaluates the drive's dynamic JSONB eligibility rules against the student profile.\n"
        "3. Rejects with 400 Bad Request and detailed failure reasons if ineligible.\n"
        "4. If eligible: Inserts a new row into the `applications` table.\n"
        "5. CRITICAL: Updates `student_files` to set `used_for_application = True`, "
        "permanently locking the resume from hard deletion."
    ),
    responses={
        201: {"model": ApplyResponse, "description": "Application accepted and resume locked"},
        400: {"model": IneligibleApplicationResponse, "description": "Student is ineligible"},
        404: {"description": "Drive, student, or resume not found"},
        409: {"description": "Duplicate application"},
    },
)
async def submit_application(
    payload: ApplyRequest,
    supabase: Any = Depends(get_supabase_client),
) -> Any:
    #Dynamic eligibility - Soham bhaia special
    student_id = payload.student_id.strip()
    job_id = payload.job_id.strip()
    resume_file_id = payload.resume_file_id.strip()

    logger.info(
        "Received application submission: student_id=%s, job_id=%s, resume_file_id=%s",
        student_id,
        job_id,
        resume_file_id,
    )

#Resume file validate and signature get
    try:
        file_res = (
            supabase.table("student_files")
            .select("*")
            .eq("id", resume_file_id)
            .execute()
        )
    except Exception as exc:
        logger.error("Database query failed for student_files id=%s: %s", resume_file_id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error while verifying resume: {str(exc)}",
        )

    if not file_res.data:
        logger.warning("Resume file_id=%s not found", resume_file_id)
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Resume file with ID '{resume_file_id}' not found.",
        )

    file_record = file_res.data[0]
    if str(file_record.get("student_id")) != student_id:
        logger.warning(
            "Resume ownership mismatch: file owned by %s, requested by %s",
            file_record.get("student_id"),
            student_id,
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="The specified resume does not belong to the applying student.",
        )

    #Fetch eligibliliy rules
    try:
        drive_res = (
            supabase.table("companies_drives")
            .select("*")
            .eq("id", job_id)
            .execute()
        )
    except Exception as exc:
        logger.error("Database query failed for companies_drives id=%s: %s", job_id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error while fetching drive info: {str(exc)}",
        )

    if not drive_res.data:
        logger.warning("Company drive job_id=%s not found", job_id)
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Placement drive with ID '{job_id}' not found.",
        )

    drive_record = drive_res.data[0]
    eligibility_rules = drive_record.get("eligibility_rules")

   #Student profile nikalo
    try:
        student_res = (
            supabase.table("students")
            .select("*")
            .eq("id", student_id)
            .execute()
        )
    except Exception as exc:
        logger.error("Database query failed for students id=%s: %s", student_id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error while fetching student profile: {str(exc)}",
        )

    if not student_res.data:
        
        try:
            student_res = (
                supabase.table("profiles")
                .select("*")
                .eq("id", student_id)
                .execute()
            )
        except Exception:
            pass

    if not student_res.data:
        logger.warning("Student profile student_id=%s not found", student_id)
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Student profile with ID '{student_id}' not found.",
        )

    student_profile = student_res.data[0]

   #Duplicate na ho
    try:
        existing_app = (
            supabase.table("applications")
            .select("id")
            .eq("student_id", student_id)
            .eq("job_id", job_id)
            .execute()
        )
        if existing_app.data and len(existing_app.data) > 0:
            logger.warning(
                "Duplicate application attempt: student=%s, drive=%s",
                student_id,
                job_id,
            )
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="You have already submitted an application for this recruitment drive.",
            )
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Error checking existing applications: %s", exc)

   #Eligibility check
    eval_result = EligibilityEngine.evaluate(student_profile, eligibility_rules)

    if not eval_result.get("is_eligible", False):
        failed_reasons = eval_result.get("reasons", ["Criteria not met"])
        logger.warning(
            "Student %s is ineligible for job %s: %s",
            student_id,
            job_id,
            failed_reasons,
        )
        return JSONResponse(
            status_code=status.HTTP_400_BAD_REQUEST,
            content={
                "status": "ineligible",
                "message": "Student does not satisfy the eligibility criteria for this recruitment drive.",
                "is_eligible": False,
                "reasons": failed_reasons,
            },
        )

    #insert applicarion
    app_id = str(uuid.uuid4())
    application_data = {
        "id": app_id,
        "student_id": student_id,
        "job_id": job_id,
        "resume_file_id": resume_file_id,
        "status": "applied",
        "created_at": datetime.now(timezone.utc).isoformat(),
    }

    try:
        app_insert = supabase.table("applications").insert(application_data).execute()
        created_record = app_insert.data[0] if app_insert.data else application_data
    except Exception as exc:
        logger.error("Failed to insert application: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to record application: {str(exc)}",
        )

#lock resume - default
    try:
        supabase.table("student_files").update({"used_for_application": True}).eq("id", resume_file_id).execute()
        logger.info(
            "Successfully set used_for_application=True on resume file_id=%s",
            resume_file_id,
        )
    except Exception as exc:
        logger.critical(
            "FATAL: Application %s created but failed to lock resume %s: %s",
            app_id,
            resume_file_id,
            exc,
        )
        # Attempt rollback or raise
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Application saved but failed to lock file: {str(exc)}",
        )

    return ApplyResponse(
        status="success",
        message="Application submitted successfully. Resume has been locked to prevent deletion.",
        application_id=created_record.get("id", app_id),
        student_id=student_id,
        job_id=job_id,
        resume_file_id=resume_file_id,
        resume_locked=True,
    )
