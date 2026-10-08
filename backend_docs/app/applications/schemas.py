#Placement applications schma
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class ApplyRequest(BaseModel):
    #Payload for submitting appliocation

    student_id: str = Field(..., description="Unique UUID/ID of the applying student.")
    job_id: str = Field(..., description="Unique ID of the company drive (companies_drives).")
    resume_file_id: str = Field(
        ..., description="ID of the student's resume file (student_files) to attach."
    )


class ApplyResponse(BaseModel):
    #successful returm

    status: str = Field(default="success", description="Application status code.")
    message: str = Field(
        ..., description="Human-readable confirmation of application submission."
    )
    application_id: str = Field(..., description="Unique ID of the created application record.")
    student_id: str = Field(..., description="Student who submitted the application.")
    job_id: str = Field(..., description="Job drive applied to.")
    resume_file_id: str = Field(
        ..., description="Resume file attached to the application."
    )
    resume_locked: bool = Field(
        default=True,
        description="True indicating `used_for_application` has been permanently set on the resume.",
    )


class IneligibleApplicationResponse(BaseModel):
    #Failed repsonse reuturn

    status: str = Field(default="ineligible")
    message: str = Field(
        default="Student does not satisfy the eligibility criteria for this recruitment drive."
    )
    is_eligible: bool = Field(default=False)
    reasons: List[str] = Field(
        ..., description="List of failed criteria explaining why the student is ineligible."
    )
