

import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, File, UploadFile
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

from app.core.logging import get_logger
from app.db.supabase_client import get_supabase_client

logger = get_logger(__name__)

admin_router = APIRouter(prefix="/api/admin", tags=["admin"])

_storage_service = None

def set_storage_service(service) -> None:
    global _storage_service
    _storage_service = service


# schemas
class CustomCriteria(BaseModel):
    field: str = Field(..., description="The name of the database column or profile attribute.")
    operator: str = Field(..., description="Comparison operator (e.g. >=, ==, <=, in).")
    value: Any = Field(..., description="The threshold/expected value to evaluate against.")


class CreateDrivePayload(BaseModel):
    is_job: bool = Field(True, description="Whether this is a Job (True) or Internship (False).")
    company_name: str = Field(..., min_length=1, description="Name of the hiring organization.")
    role_title: str = Field(..., min_length=1, description="Designation / job profile name.")
    job_description: str = Field(..., min_length=1, description="Overview of job responsibilities and details.")
    expected_package: str = Field(..., min_length=1, description="CTC offering (e.g., 18 LPA, 85k/month).")
    
    # Primary check boxes 
    min_cgpa: Optional[float] = Field(None, description="Minimum CGPA cutoff check.")
    max_backlogs: Optional[int] = Field(None, description="Maximum allowed active backlogs count check.")
    max_education_gaps: Optional[int] = Field(None, description="Maximum permitted years of education gap.")
    
    # Advanced options
    allowed_branches: Optional[List[str]] = Field(None, description="List of eligible branches (e.g. ['CSE', 'ECE']).")
    allowed_batches: Optional[List[str]] = Field(None, description="List of eligible batches (e.g. ['2026', '2027']).")
    min_tenth_percentage: Optional[float] = Field(None, description="Minimum 10th standard percentage required.")
    min_twelfth_percentage: Optional[float] = Field(None, description="Minimum 12th standard/Diploma percentage required.")
    
    # Custom criteria by admin
    custom_criteria: Optional[List[CustomCriteria]] = Field(None, description="Custom criteria columns and rules.")
    
    # Deadline to apply
    application_deadline: Optional[datetime] = Field(None, description="Deadline to apply for the drive.")

#endpoints

@admin_router.post(
    "/drives",
    status_code=status.HTTP_201_CREATED,
    summary="Create a new recruitment drive",
    description="Registers a placement drive, compiles UI criteria into eligibility rules, and stores JD/CTC metadata.",
)
async def create_placement_drive(
    payload: CreateDrivePayload,
    supabase: Any = Depends(get_supabase_client),
) -> Any:
    """Create a new placement drive and compile criteria into JSONB rules."""
    logger.info(
        "Received request to create placement drive: company=%s, role=%s",
        payload.company_name,
        payload.role_title,
    )
    
    # Compile the eligibility rules conditions list
    conditions = []
    
    # 1. Primary checkbox rules
    if payload.min_cgpa is not None:
        conditions.append({"field": "cgpa", "operator": ">=", "value": payload.min_cgpa})
        
    if payload.max_backlogs is not None:
        conditions.append({"field": "backlogs", "operator": "<=", "value": payload.max_backlogs})
        
    if payload.max_education_gaps is not None:
        conditions.append({"field": "education_gaps", "operator": "<=", "value": payload.max_education_gaps})
        
    # 2. Advanced checkboxes / inputs
    if payload.allowed_branches:
       
        branches = [b.strip().upper() for b in payload.allowed_branches if b.strip()]
        if branches:
            conditions.append({"field": "branch", "operator": "in", "value": branches})
            
    if payload.allowed_batches:
        batches = [b.strip() for b in payload.allowed_batches if b.strip()]
        if batches:
            conditions.append({"field": "batch", "operator": "in", "value": batches})
            
    if payload.min_tenth_percentage is not None:
        conditions.append({"field": "tenth_percentage", "operator": ">=", "value": payload.min_tenth_percentage})
        
    if payload.min_twelfth_percentage is not None:
        conditions.append({"field": "twelfth_percentage", "operator": ">=", "value": payload.min_twelfth_percentage})
        
    # 3. Custom admin criteria
    if payload.custom_criteria:
        for c in payload.custom_criteria:
            field_name = c.field.strip().lower()
            if field_name:
                conditions.append({
                    "field": field_name,
                    "operator": c.operator.strip(),
                    "value": c.value
                })
                
   
    rules = {}
    if conditions:
        rules = {
            "logic": "AND",
            "conditions": conditions
        }
        
    # Generate drive ID
    drive_id = str(uuid.uuid4())
    
    # Compile raw_csv_data metadata
    raw_metadata = {
        "job_description": payload.job_description.strip(),
        "expected_package": payload.expected_package.strip(),
    }
    if payload.application_deadline:
        raw_metadata["application_deadline"] = payload.application_deadline.isoformat()

    # Prepare row data
    drive_data = {
        "id": drive_id,
        "is_job": payload.is_job,
        "company_name": payload.company_name.strip(),
        "role_title": payload.role_title.strip(),
        "status": "open",
        "eligibility_rules": rules,
        "raw_csv_data": raw_metadata
    }
    
    # deadline insertion
    try:
        if payload.application_deadline:
            drive_data["application_deadline"] = payload.application_deadline.isoformat()
    except Exception:
        pass
    
    try:
        res = supabase.table("companies_drives").insert(drive_data).execute()
        if not res.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Database operation succeeded but returned no data.",
            )
            
        logger.info("Successfully created placement drive drive_id=%s", drive_id)
        
        # Trigger notificatins in background email
        import asyncio
        asyncio.create_task(
            send_eligibility_emails(
                drive_id=drive_id,
                company=payload.company_name.strip(),
                role=payload.role_title.strip(),
                rules=rules,
                supabase=supabase
            )
        )

        return {
            "status": "success",
            "message": "Placement drive created successfully.",
            "drive": res.data[0]
        }
        
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to create placement drive: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to save placement drive: {str(exc)}",
        )


@admin_router.get(
    "/drives",
    summary="List all placement drives",
)
async def list_placement_drives(
    supabase: Any = Depends(get_supabase_client),
) -> Any:
    #documents retriaval
    try:
        res = supabase.table("companies_drives").select("*").order("created_at", desc=True).execute()
        return {
            "status": "success",
            "count": len(res.data) if res.data else 0,
            "drives": res.data or []
        }
    except Exception as exc:
        logger.error("Failed to list placement drives: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database query failed: {str(exc)}",
        )


@admin_router.get(
    "/drives/{drive_id}",
    summary="Get drive details",
)
async def get_placement_drive(
    drive_id: str,
    supabase: Any = Depends(get_supabase_client),
) -> Any:
   
    try:
        res = supabase.table("companies_drives").select("*").eq("id", drive_id).execute()
        if not res.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Placement drive with ID '{drive_id}' not found.",
            )
        return {
            "status": "success",
            "drive": res.data[0]
        }
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to fetch placement drive drive_id=%s: %s", drive_id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database query failed: {str(exc)}",
        )


@admin_router.post(
    "/drives/parse-csv-columns",
    summary="Parse column headers from an uploaded CSV file",
    description="Reads the uploaded CSV and extracts column names along with basic type inference (number, string, boolean) to dynamically fill criteria selectors.",
)
async def parse_csv_columns(
    file: UploadFile = File(...),
) -> Any:
   #Parse columsn and rows
    if not file.filename.endswith(".csv"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only CSV files (.csv) are supported."
        )

    try:
        contents = await file.read()
        import io
        import csv

        # Decode contents to string
        text_data = contents.decode("utf-8")
        reader = csv.reader(io.StringIO(text_data))
        
        # Read headers
        headers = next(reader, None)
        if not headers:
            raise ValueError("CSV file is empty.")
            
        first_row = next(reader, None)
        
        columns = []
        for i, col in enumerate(headers):
            inferred_type = "string"
            if first_row and i < len(first_row):
                val = first_row[i].strip()
                # kya numver hai?
                try:
                    float(val)
                    inferred_type = "number"
                except ValueError:
                    # boolean hai?
                    if val.lower() in ("true", "false", "yes", "no"):
                        inferred_type = "boolean"
                        
            columns.append({
                "name": str(col).strip(),
                "type": inferred_type
            })

        logger.info("Successfully parsed %d columns from CSV file=%s", len(columns), file.filename)
        return {
            "status": "success",
            "filename": file.filename,
            "columns": columns
        }
    except Exception as exc:
        logger.error("Failed to parse CSV columns: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to parse CSV file: {str(exc)}"
        )


@admin_router.get(
    "/applicants",
    summary="Get and filter applicants for placement drives",
    description="Lists all submitted applications with student profiles, company name, role, and R2 resume link. Supports filtering by company_name, role_title, branch, and job_id.",
)
async def list_drive_applicants(
    job_id: Optional[str] = None,
    company_name: Optional[str] = None,
    role_title: Optional[str] = None,
    branch: Optional[str] = None,
    supabase: Any = Depends(get_supabase_client),
) -> Any:
    """Retrieve joined applicant profiles with flexible query filters."""
    try:
        # Fetch joined recordsapplications + students + companies_drives
        res = (
            supabase.table("applications")
            .select("*, students(*), companies_drives(*)")
            .execute()
        )
        raw_apps = res.data or []
        
        filtered_apps = []
        for app in raw_apps:
            student = app.get("students") or {}
            drive = app.get("companies_drives") or {}
            
            
            if job_id and str(app.get("job_id")) != job_id:
                continue
                
            if company_name and company_name.lower() not in str(drive.get("company_name", "")).lower():
                continue
                
            if role_title and role_title.lower() not in str(drive.get("role_title", "")).lower():
                continue
                
            if branch and str(student.get("branch", "")).strip().lower() != branch.strip().lower():
                continue
                
            # Compile resume review link
            resume_file_id = app.get("resume_file_id")
            resume_link = "N/A"
            if resume_file_id:
                if _storage_service:
                    try:
                        resume_link = await _storage_service.create_share_link(resume_file_id)
                    except Exception:
                        resume_link = f"https://placeholder.com/share/{resume_file_id}"
                else:
                    resume_link = f"https://placeholder.com/share/{resume_file_id}"
                    
            filtered_apps.append({
                "application_id": app["id"],
                "student_id": app["student_id"],
                "full_name": student.get("full_name", "N/A"),
                "bt_id": student.get("bt_id", "N/A"),
                "email": student.get("email", "N/A"),
                "phone_number": student.get("phone_number", "N/A"),
                "college_number": student.get("college_number", "N/A"),
                "branch": student.get("branch", "N/A"),
                "cgpa": student.get("cgpa", 0.0),
                "application_status": app.get("status", "applied"),
                "applied_at": app.get("created_at"),
                "job_id": app["job_id"],
                "company_name": drive.get("company_name", "N/A"),
                "role_title": drive.get("role_title", "N/A"),
                "resume_link": resume_link
            })
            
        return {
            "status": "success",
            "count": len(filtered_apps),
            "applicants": filtered_apps
        }
    except Exception as exc:
        logger.error("Failed to retrieve or filter applicants: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database lookup failed: {str(exc)}"
        )


@admin_router.get(
    "/drives/{drive_id}/export",
    summary="Export applicants to CSV (Excel compatible)",
    description="Generates a downloadable CSV sheet of all eligible applied students for a specific drive.",
)
async def export_applicants_csv(
    drive_id: str,
    supabase: Any = Depends(get_supabase_client),
) -> StreamingResponse:
    """Generate and stream a CSV file containing applicants for a drive."""
    try:
        import csv
        import io
        
        # Fetch drive details first to get the name
        drive_res = supabase.table("companies_drives").select("*").eq("id", drive_id).execute()
        if not drive_res.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Placement drive '{drive_id}' not found."
            )
        drive = drive_res.data[0]
        company_name = drive["company_name"].replace(" ", "_")
        role_title = drive["role_title"].replace(" ", "_")

        # Fetch applications for this drive with student details
        res = (
            supabase.table("applications")
            .select("*, students(*)")
            .eq("job_id", drive_id)
            .execute()
        )
        apps = res.data or []

        #string buffer for csv
        output = io.StringIO()
        writer = csv.writer(output)
        
    
        writer.writerow([
            "Student Name", 
            "BTID", 
            "Email", 
            "Phone Number", 
            "College Number", 
            "Branch", 
            "CGPA", 
            "Status", 
            "Resume Share Link"
        ])
   
        for app in apps:
            student = app.get("students") or {}
            resume_file_id = app.get("resume_file_id")
            
            # Generate resume share link
            resume_link = "N/A"
            if resume_file_id:
                if _storage_service:
                    try:
                        resume_link = await _storage_service.create_share_link(resume_file_id)
                    except Exception:
                        resume_link = f"https://placeholder.com/share/{resume_file_id}"
                else:
                    resume_link = f"https://placeholder.com/share/{resume_file_id}"
                    
            writer.writerow([
                student.get("full_name", "N/A"),
                student.get("bt_id", "N/A"),
                student.get("email", "N/A"),
                student.get("phone_number", "N/A"),
                student.get("college_number", "N/A"),
                student.get("branch", "N/A"),
                student.get("cgpa", "N/A"),
                app.get("status", "applied"),
                resume_link
            ])
            
        # Reset pointer
        output.seek(0)
        
        headers = {
            "Content-Disposition": f'attachment; filename="applicants_{company_name}_{role_title}.csv"'
        }
        return StreamingResponse(
            iter([output.getvalue()]), 
            media_type="text/csv", 
            headers=headers
        )
        
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to export CSV for drive drive_id=%s: %s", drive_id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate CSV export: {str(exc)}"
        )


@admin_router.post(
    "/drives/send-reminders",
    summary="Trigger 12-hour application deadline reminders",
    description="Finds open placement drives whose deadline is exactly 12 hours away, and sends reminder emails to eligible students who have not applied yet.",
)
async def trigger_deadline_reminders(
    supabase: Any = Depends(get_supabase_client),
) -> Any:
    """Manually or cron-triggered deadline reminders executor."""
    await check_and_send_deadline_reminders(supabase)
    return {"status": "success", "message": "Deadline reminders check completed."}


async def send_eligibility_emails(
    drive_id: str, company: str, role: str, rules: dict, supabase: Any
) -> None:
    """Evaluate and notify eligible students of a new job posting in the background."""
    try:
        from app.services.eligibility_engine import EligibilityEngine
        from app.services.email_service import EmailService

        students_res = supabase.table("students").select("*").execute()
        students = students_res.data or []

        for student in students:
      
            student_profile = dict(student)
            student_profile["backlogs"] = student_profile.get("backlogs", 0)
            student_profile["active_backlogs"] = student_profile.get("active_backlogs", 0)

            eval_result = EligibilityEngine.evaluate(student_profile, rules)
            if eval_result.get("is_eligible", False):
                # Write inapp notification record
                try:
                    notif_data = {
                        "id": str(uuid.uuid4()),
                        "student_id": student["id"],
                        "title": f"Eligible Placement Drive: {role} at {company}",
                        "content": f"A new placement drive for '{role}' at '{company}' has been posted. You are eligible to apply! View details and apply in the dashboard.",
                        "type": "eligible_job",
                        "is_read": False
                    }
                    supabase.table("student_notifications").insert(notif_data).execute()
                except Exception as db_exc:
                    logger.warning("Could not store in-app notification: %s", db_exc)

                email = student.get("email")
                if email:
                    subject = f"Eligible Placement Drive: {role} at {company}"
                    body = (
                        f"Dear {student.get('full_name', 'Student')},\n\n"
                        f"A new placement drive for '{role}' at '{company}' has been posted. "
                        f"Based on your profile, you are eligible to apply!\n\n"
                        f"Please log in to the PlacedThere student dashboard to view details and submit your application.\n\n"
                        f"Best regards,\n"
                        f"Training & Placement Cell, IIITN"
                    )
                    await EmailService.send_email(email, subject, body)
    except Exception as exc:
        logger.error("Failed to send eligibility notifications for drive %s: %s", drive_id, exc)


async def check_and_send_deadline_reminders(supabase: Any) -> None:
    """Scan open drives and notify eligible non-applicants if deadline is 12h away."""
    try:
        from datetime import datetime, timezone, timedelta
        from app.services.eligibility_engine import EligibilityEngine
        from app.services.email_service import EmailService

        now = datetime.now(timezone.utc)
        
        lower_bound = now + timedelta(hours=11)
        upper_bound = now + timedelta(hours=13)

        drives_res = supabase.table("companies_drives").select("*").eq("status", "open").execute()
        drives = drives_res.data or []

        for drive in drives:
            raw_metadata = drive.get("raw_csv_data") or {}
            deadline_str = drive.get("application_deadline") or raw_metadata.get("application_deadline")
            if not deadline_str:
                continue

            try:
                # Standardize ISO parse 
                if deadline_str.endswith("Z"):
                    deadline_str = deadline_str[:-1] + "+00:00"
                deadline = datetime.fromisoformat(deadline_str)
            except Exception:
                continue

            if lower_bound <= deadline <= upper_bound:
                logger.info("Drive %s is in the 12-hour reminder window.", drive["company_name"])

                # Get student applications
                apps_res = supabase.table("applications").select("student_id").eq("job_id", drive["id"]).execute()
                applied_student_ids = {a["student_id"] for a in apps_res.data} if apps_res.data else set()

                # Get all students
                students_res = supabase.table("students").select("*").execute()
                students = students_res.data or []

                for student in students:
                    if student["id"] in applied_student_ids:
                        continue

                    # checks eligibility
                    student_profile = dict(student)
                    student_profile["backlogs"] = student_profile.get("backlogs", 0)
                    student_profile["active_backlogs"] = student_profile.get("active_backlogs", 0)

                    eval_result = EligibilityEngine.evaluate(student_profile, drive.get("eligibility_rules"))
                    if eval_result.get("is_eligible", False):
                        # Write i
                        try:
                            notif_data = {
                                "id": str(uuid.uuid4()),
                                "student_id": student["id"],
                                "title": f"Deadline Reminder: Apply to {drive['role_title']} at {drive['company_name']}",
                                "content": f"This is a reminder that the application deadline for '{drive['role_title']}' at '{drive['company_name']}' is in 12 hours! You are eligible, but have not applied yet.",
                                "type": "deadline_reminder",
                                "is_read": False
                            }
                            supabase.table("student_notifications").insert(notif_data).execute()
                        except Exception as db_exc:
                            logger.warning("Could not store in-app notification: %s", db_exc)

                        email = student.get("email")
                        if email:
                            subject = f"Deadline Reminder: Apply to {drive['role_title']} at {drive['company_name']}"
                            body = (
                                f"Dear {student.get('full_name', 'Student')},\n\n"
                                f"This is a reminder that the application deadline for '{drive['role_title']}' "
                                f"at '{drive['company_name']}' is in 12 hours!\n\n"
                                f"You are eligible to apply, but have not submitted your application yet.\n\n"
                                f"Please log in to the PlacedThere dashboard to apply before it's too late.\n\n"
                                f"Best regards,\n"
                                f"Training & Placement Cell, IIITN"
                            )
                            await EmailService.send_email(email, subject, body)
    except Exception as exc:
        logger.error("Failed running check_and_send_deadline_reminders: %s", exc)


@admin_router.get(
    "/active-students",
    summary="List active students (Live User Tracker)",
    description="Returns all student profiles ordered by their last active timestamp, showing who is currently online/active.",
)
async def list_active_students(
    supabase: Any = Depends(get_supabase_client),
) -> Any:
    """Retrieve students sorted by activity log."""
    try:
        res = (
            supabase.table("students")
            .select("id, bt_id, full_name, email, branch, last_active_at")
            .order("last_active_at", desc=True)
            .execute()
        )
        return {
            "status": "success",
            "count": len(res.data) if res.data else 0,
            "students": res.data or []
        }
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to query active students: {str(exc)}",
        )
