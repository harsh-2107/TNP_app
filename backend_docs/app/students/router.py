#Fast API for student managament

from typing import Any
from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks

from app.auth.dependencies import get_current_student, CurrentStudent
from app.db.supabase_client import get_supabase_client
from pydantic import BaseModel, Field

students_router = APIRouter(prefix="/api/students", tags=["students"])


def update_student_active_timestamp(student_id: str, supabase: Any):
#timestamp logs ke liye update
    try:
        from datetime import datetime, timezone
        supabase.table("students").update({"last_active_at": datetime.now(timezone.utc).isoformat()}).eq("id", student_id).execute()
    except Exception:
        pass


@students_router.get(
    "/profile",
    status_code=status.HTTP_200_OK,
    summary="Get current student profile details",
    description=(
        "Retrieves academic, placement, and personal metadata of the authenticated student.\n"
        "Automatically injects CGPA, branch, and mock backlog values for the client app."
    ),
)
async def get_student_profile(
    background_tasks: BackgroundTasks,
    current_student: CurrentStudent = Depends(get_current_student),
    supabase: Any = Depends(get_supabase_client),
) -> Any:
    #Fetch logged in user activiity for logs
     # Track user activity in background
    background_tasks.add_task(update_student_active_timestamp, current_student.id, supabase)
    try:
        res = (
            supabase.table("students")
            .select("*")
            .eq("id", current_student.id)
            .execute()
        )
        
        if not res.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Student profile details not found in the database.",
            )
        
        profile = res.data[0]
        
        # fallbacks
        profile["backlogs"] = profile.get("backlogs", 0)
        profile["active_backlogs"] = profile.get("active_backlogs", 0)
        
        return {
            "status": "success",
            "profile": profile
        }
        
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database query failed: {str(exc)}",
        )


@students_router.get(
    "/jobs",
    status_code=status.HTTP_200_OK,
    summary="Get job drives for the student dashboard",
    description="Lists all open placement drives, evaluates eligibility, and checks application status for the student.",
)
async def get_student_jobs(
    current_student: CurrentStudent = Depends(get_current_student),
    supabase: Any = Depends(get_supabase_client),
) -> Any:
    """Fetch and evaluate placement jobs for the logged-in student."""
    try:
        #etch Student Profile
        student_res = (
            supabase.table("students")
            .select("*")
            .eq("id", current_student.id)
            .execute()
        )
        if not student_res.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Student profile not found in database.",
            )
        profile = student_res.data[0]
        
        profile["backlogs"] = profile.get("backlogs", 0)
        profile["active_backlogs"] = profile.get("active_backlogs", 0)

        # Fetch Open Placement Drives
        drives_res = (
            supabase.table("companies_drives")
            .select("*")
            .eq("status", "open")
            .execute()
        )
        drives = drives_res.data or []

        # Fetch Student's Submitted Applications (to check has_applied)
        apps_res = (
            supabase.table("applications")
            .select("job_id")
            .eq("student_id", current_student.id)
            .execute()
        )
        applied_job_ids = {a["job_id"] for a in apps_res.data} if apps_res.data else set()

        # checks eligibliltiy
        from app.services.eligibility_engine import EligibilityEngine
        
        jobs_list = []
        for drive in drives:
            rules = drive.get("eligibility_rules")
            eval_result = EligibilityEngine.evaluate(profile, rules)
            
            #filter - eligible only dikhengi
            if not eval_result["is_eligible"]:
                continue
                
            raw_metadata = drive.get("raw_csv_data") or {}
            deadline = drive.get("application_deadline") or raw_metadata.get("application_deadline", "")
            
            jobs_list.append({
                "id": drive["id"],
                "company_name": drive["company_name"],
                "job_title": drive["role_title"],
                "job_description": raw_metadata.get("job_description", ""),
                "expected_package": raw_metadata.get("expected_package", ""),
                "application_deadline": deadline,
                "is_eligible": True,
                "reasons": [],
                "has_applied": drive["id"] in applied_job_ids
            })

        # Sort jobs alphabetically 
        jobs_list.sort(key=lambda x: x["company_name"])

        return {
            "status": "success",
            "count": len(jobs_list),
            "jobs": jobs_list
        }

    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch job drives: {str(exc)}",
        )


class UpdateProfileRequest(BaseModel):
    phone_number: str = Field(..., min_length=10, max_length=15, description="Student's contact phone number.")


@students_router.patch(
    "/profile",
    status_code=status.HTTP_200_OK,
    summary="Update student phone number",
    description="Allows students to self-report contact details. All academic and eligibility parameters remain locked in the DB.",
)
async def update_student_profile(
    payload: UpdateProfileRequest,
    current_student: CurrentStudent = Depends(get_current_student),
    supabase: Any = Depends(get_supabase_client),
) -> Any:
    #Contact update
    try:
        res = (
            supabase.table("students")
            .update({"phone_number": payload.phone_number.strip()})
            .eq("id", current_student.id)
            .execute()
        )
        if not res.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Student profile not found to update.",
            )
        return {
            "status": "success",
            "message": "Phone number updated successfully.",
            "profile": res.data[0]
        }
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update student profile: {str(exc)}",
        )


@students_router.get(
    "/notifications",
    summary="Retrieve student in-app notifications",
    description="Fetches a list of notifications, alerts, and mail copies for the authenticated student, ordered by newest first.",
)
async def list_student_notifications(
    current_student: CurrentStudent = Depends(get_current_student),
    supabase: Any = Depends(get_supabase_client),
) -> Any:
    """Fetch all notifications for the authenticated student."""
    try:
        res = (
            supabase.table("student_notifications")
            .select("*")
            .eq("student_id", current_student.id)
            .order("created_at", desc=True)
            .execute()
        )
        return {
            "status": "success",
            "count": len(res.data) if res.data else 0,
            "notifications": res.data or []
        }
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve notifications: {str(exc)}",
        )


@students_router.patch(
    "/notifications/{notification_id}/read",
    summary="Mark notification as read",
    description="Marks a specific in-app notification as read by the student.",
)
async def mark_notification_as_read(
    notification_id: str,
    current_student: CurrentStudent = Depends(get_current_student),
    supabase: Any = Depends(get_supabase_client),
) -> Any:
    #notification readed
    try:
        res = (
            supabase.table("student_notifications")
            .update({"is_read": True})
            .eq("id", notification_id)
            .eq("student_id", current_student.id)
            .execute()
        )
        if not res.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Notification not found or unauthorized.",
            )
        return {
            "status": "success",
            "message": "Notification marked as read.",
            "notification": res.data[0]
        }
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update notification: {str(exc)}",
        )
