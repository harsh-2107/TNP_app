#yaha se JWT token validate honge aur fir college id wali email restrict hogi
from dataclasses import dataclass
from typing import Any
from fastapi import Header, HTTPException, Depends

from app.core.config import Settings, get_settings
from app.db.supabase_client import get_supabase_client


@dataclass
class CurrentStudent:
    
#jo students proven hain wo yaha pe with their UUID, BTID, and bt email
    id: str
    bt_id: str
    email: str


async def get_current_student(
    authorization: str = Header(None, description="Bearer token from Supabase OAuth"),
    x_student_id: str = Header(None, description="Dev ONLY: Student UUID"),
    x_student_bt_id: str = Header(None, description="Dev ONLY: Student BT ID"),
    x_student_email: str = Header(None, description="Dev ONLY: Student email"),
    settings: Settings = Depends(get_settings),
    supabase: Any = Depends(get_supabase_client),
) -> CurrentStudent:
    #Fast API idhar se
    
    # (Supabase Auth)
    if authorization and authorization.startswith("Bearer "):
        token = authorization.split(" ")[1]
        try:
            # Query Supabase Auth for token verification
            user_response = supabase.auth.get_user(token)
            if not user_response or not user_response.user:
                raise HTTPException(status_code=401, detail="Invalid authentication token.")
            
            user = user_response.user
            email = user.email
            
            # forcing colleg email
            if not email or not email.endswith("@iiitn.ac.in"):
                raise HTTPException(
                    status_code=403,
                    detail="Access denied. Only @iiitn.ac.in college email IDs are permitted."
                )
            
            # parts clean split
            email_prefix = email.split("@")[0].upper()
            
            # table dhoond
            student_res = (
                supabase.table("students")
                .select("id", "bt_id")
                .or_(f"email.eq.{email},bt_id.eq.{email_prefix}")
                .execute()
            )
            
            if not student_res.data:
                raise HTTPException(
                    status_code=403,
                    detail="Access denied. No placement student profile matches this college email or BTID."
                )
            
            profile = student_res.data[0]
            return CurrentStudent(
                id=profile["id"],
                bt_id=profile["bt_id"],
                email=email,
            )
        except HTTPException:
            raise
        except Exception as exc:
            raise HTTPException(
                status_code=401,
                detail=f"Authentication token verification failed: {str(exc)}"
            )

    # fallbacks
    if settings.ENVIRONMENT == "development":
        if not x_student_id or not x_student_id.strip():
            raise HTTPException(status_code=401, detail="Authentication required.")
        
        bt_id = x_student_bt_id.strip() if x_student_bt_id else "BT25CSA016"
        email = x_student_email.strip() if x_student_email else "dev@example.com"
        
        return CurrentStudent(
            id=x_student_id.strip(),
            bt_id=bt_id,
            email=email
        )

    # If no token is provided in production
    raise HTTPException(status_code=401, detail="Authentication token required.")
