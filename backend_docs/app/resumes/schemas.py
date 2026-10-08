#Resume management ke liye

from typing import Optional
from pydantic import BaseModel, Field


class ResumeDeleteResponse(BaseModel):

    status: str = Field(
        ...,
        description="Deletion type: 'soft_deleted' or 'hard_deleted'",
        examples=["soft_deleted", "hard_deleted"],
    )
    message: str = Field(
        ...,
        description="Human-readable explanation of the deletion action taken.",
    )
    file_id: str = Field(..., description="The unique file identifier.")
    is_profile_resume: bool = Field(
        ...,
        description="Updated profile resume flag (always False after deletion).",
    )
    used_for_application: bool = Field(
        ...,
        description="Indicates if the resume was locked by an application.",
    )
    r2_deleted: bool = Field(
        ...,
        description="Whether the object was permanently deleted from Cloudflare R2.",
    )
