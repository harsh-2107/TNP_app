from typing import Any
from unittest.mock import MagicMock
import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.db.supabase_client import get_supabase_client
from app.students.router import students_router


class MockSupabaseTable:
    def __init__(self, table_name: str, db_state: dict):
        self.table_name = table_name
        self.db_state = db_state
        self._current_filters = {}

    def select(self, *args, **kwargs):
        return self

    def eq(self, column: str, value: Any):
        self._current_filters[column] = value
        return self

    def update(self, data: dict):
        self._update_data = data
        return self

    def order(self, column: str, desc: bool = False):
        return self

    def execute(self):
        records = self.db_state.get(self.table_name, [])
        filtered = [
            dict(r) for r in records
            if all(str(r.get(col)) == str(val) for col, val in self._current_filters.items())
        ]
        
        # If this is an update command
        if hasattr(self, "_update_data"):
            for r in filtered:
                # Find the actual record in db_state to persist changes
                orig_list = self.db_state.get(self.table_name, [])
                for orig in orig_list:
                    if orig.get("id") == r.get("id"):
                        orig.update(self._update_data)
                r.update(self._update_data)
        
        mock_res = MagicMock()
        mock_res.data = filtered
        return mock_res


class MockSupabaseClient:
    def __init__(self, db_state: dict):
        self.db_state = db_state

    def table(self, table_name: str):
        return MockSupabaseTable(table_name, self.db_state)


@pytest.fixture
def mock_app():
    from app.admin.router import admin_router
    from app.storage.router import storage_router
    app = FastAPI()
    app.include_router(students_router)
    app.include_router(admin_router)
    app.include_router(storage_router)
    return app


@pytest.mark.asyncio
async def test_get_student_profile_success(mock_app):
    """Verify that get_student_profile returns all database fields plus defaulted backlog fields."""
    db_state = {
        "students": [
            {
                "id": "student-123",
                "bt_id": "BT25CSA016",
                "full_name": "Aarav Sharma",
                "email": "bt25csa016@iiitn.ac.in",
                "branch": "CSA",
                "cgpa": 8.5,
                "placement_status": "unplaced",
            }
        ]
    }
    
    mock_supabase = MockSupabaseClient(db_state)
    mock_app.dependency_overrides[get_supabase_client] = lambda: mock_supabase
    
    headers = {
        "X-Student-Id": "student-123",
        "X-Student-Bt-Id": "BT25CSA016",
        "X-Student-Email": "bt25csa016@iiitn.ac.in",
    }
    
    transport = ASGITransport(app=mock_app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/api/students/profile", headers=headers)
        
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "success"
    profile = data["profile"]
    assert profile["id"] == "student-123"
    assert profile["full_name"] == "Aarav Sharma"
    assert profile["cgpa"] == 8.5
    assert profile["backlogs"] == 0  # Injected default
    assert profile["active_backlogs"] == 0  # Injected default


@pytest.mark.asyncio
async def test_get_student_profile_not_found(mock_app):
    """Verify that get_student_profile returns 404 if student ID does not match records."""
    db_state = {
        "students": []
    }
    
    mock_supabase = MockSupabaseClient(db_state)
    mock_app.dependency_overrides[get_supabase_client] = lambda: mock_supabase
    
    headers = {
        "X-Student-Id": "student-nonexistent",
        "X-Student-Bt-Id": "BT25CSA999",
        "X-Student-Email": "bt25csa999@iiitn.ac.in",
    }
    
    transport = ASGITransport(app=mock_app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/api/students/profile", headers=headers)
        
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_get_student_jobs_success(mock_app):
    """Verify that get_student_jobs lists drives, matches eligibility rules, and flags application status."""
    db_state = {
        "students": [
            {
                "id": "student-123",
                "bt_id": "BT25CSA016",
                "full_name": "Aarav Sharma",
                "email": "bt25csa016@iiitn.ac.in",
                "branch": "CSA",
                "cgpa": 8.5,
                "placement_status": "unplaced",
            }
        ],
        "companies_drives": [
            {
                "id": "drive-eligible",
                "company_name": "Eligible Corp",
                "role_title": "SDE",
                "status": "open",
                "eligibility_rules": {
                    "logic": "AND",
                    "conditions": [{"field": "cgpa", "operator": ">=", "value": 7.0}]
                },
                "raw_csv_data": {"job_description": "Great role", "expected_package": "10 LPA"}
            },
            {
                "id": "drive-ineligible",
                "company_name": "High Cutoff Inc",
                "role_title": "Quant",
                "status": "open",
                "eligibility_rules": {
                    "logic": "AND",
                    "conditions": [{"field": "cgpa", "operator": ">=", "value": 9.0}]
                },
                "raw_csv_data": {"job_description": "Math heavy", "expected_package": "40 LPA"}
            }
        ],
        "applications": [
            {
                "student_id": "student-123",
                "job_id": "drive-eligible"
            }
        ]
    }

    mock_supabase = MockSupabaseClient(db_state)
    mock_app.dependency_overrides[get_supabase_client] = lambda: mock_supabase

    headers = {
        "X-Student-Id": "student-123",
        "X-Student-Bt-Id": "BT25CSA016",
        "X-Student-Email": "bt25csa016@iiitn.ac.in",
    }

    transport = ASGITransport(app=mock_app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/api/students/jobs", headers=headers)

    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "success"
    assert data["count"] == 1

    jobs = data["jobs"]
    assert jobs[0]["company_name"] == "Eligible Corp"
    assert jobs[0]["is_eligible"] is True
    assert jobs[0]["has_applied"] is True
    assert jobs[0]["job_description"] == "Great role"
    assert jobs[0]["expected_package"] == "10 LPA"


@pytest.mark.asyncio
async def test_update_student_phone_number(mock_app):
    """Verify that updating profile updates only contact information."""
    db_state = {
        "students": [
            {
                "id": "student-123",
                "bt_id": "BT25CSA016",
                "full_name": "Aarav Sharma",
                "email": "bt25csa016@iiitn.ac.in",
                "branch": "CSA",
                "cgpa": 8.5,
            }
        ]
    }
    
    mock_supabase = MockSupabaseClient(db_state)
    mock_app.dependency_overrides[get_supabase_client] = lambda: mock_supabase
    
    headers = {
        "X-Student-Id": "student-123",
        "X-Student-Bt-Id": "BT25CSA016",
        "X-Student-Email": "bt25csa016@iiitn.ac.in",
    }
    
    transport = ASGITransport(app=mock_app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Update phone number
        resp = await client.patch(
            "/api/students/profile",
            json={"phone_number": "+91 98765 43210"},
            headers=headers
        )
        
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "success"
    
    # Check that database is updated
    student_in_db = db_state["students"][0]
    assert student_in_db["phone_number"] == "+91 98765 43210"
    
    # Ensure academic credentials were NOT modified or exposed for updates
    assert student_in_db["cgpa"] == 8.5
    assert student_in_db["branch"] == "CSA"


@pytest.mark.asyncio
async def test_student_notifications(mock_app):
    """Verify that fetching and reading in-app notifications works correctly."""
    db_state = {
        "student_notifications": [
            {
                "id": "notif-1",
                "student_id": "student-123",
                "title": "Eligible Job!",
                "content": "You are eligible for Microsoft drive.",
                "type": "eligible_job",
                "is_read": False,
                "created_at": "2026-08-13T00:00:00"
            }
        ]
    }
    
    mock_supabase = MockSupabaseClient(db_state)
    mock_app.dependency_overrides[get_supabase_client] = lambda: mock_supabase
    
    headers = {
        "X-Student-Id": "student-123",
        "X-Student-Bt-Id": "BT25CSA016",
        "X-Student-Email": "bt25csa016@iiitn.ac.in",
    }
    
    transport = ASGITransport(app=mock_app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Fetch notifications
        resp = await client.get("/api/students/notifications", headers=headers)
        assert resp.status_code == 200
        data = resp.json()
        assert data["count"] == 1
        assert data["notifications"][0]["title"] == "Eligible Job!"
        assert data["notifications"][0]["is_read"] is False

        # 2. Mark as read
        patch_resp = await client.patch("/api/students/notifications/notif-1/read", headers=headers)
        assert patch_resp.status_code == 200
        assert patch_resp.json()["notification"]["is_read"] is True
        
        # Verify db persistence
        assert db_state["student_notifications"][0]["is_read"] is True


@pytest.mark.asyncio
async def test_live_user_tracker(mock_app):
    """Verify that visiting student profile triggers last_active_at updates and lists active students."""
    db_state = {
        "students": [
            {
                "id": "student-123",
                "bt_id": "BT25CSA016",
                "full_name": "Aarav Sharma",
                "email": "bt25csa016@iiitn.ac.in",
                "branch": "CSA",
                "cgpa": 8.5,
                "last_active_at": "2026-08-11T00:00:00"
            }
        ]
    }
    
    mock_supabase = MockSupabaseClient(db_state)
    mock_app.dependency_overrides[get_supabase_client] = lambda: mock_supabase
    
    headers = {
        "X-Student-Id": "student-123",
        "X-Student-Bt-Id": "BT25CSA016",
        "X-Student-Email": "bt25csa016@iiitn.ac.in",
    }
    
    transport = ASGITransport(app=mock_app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Get profile
        resp = await client.get("/api/students/profile", headers=headers)
        assert resp.status_code == 200

        # Query active tracker list as admin
        admin_resp = await client.get("/api/admin/active-students")
        assert admin_resp.status_code == 200
        data = admin_resp.json()
        assert data["count"] == 1
        assert data["students"][0]["bt_id"] == "BT25CSA016"


@pytest.mark.asyncio
async def test_manual_rename_resume_to_btid(mock_app):
    """Verify that renaming a resume display name to the student's BTID works securely."""
    db_state = {
        "student_files": [
            {
                "id": "file-123",
                "student_id": "student-123",
                "filename": "my_cv.pdf",
                "object_key": "raw/file.pdf",
                "mime_type": "application/pdf"
            }
        ]
    }
    
    mock_supabase = MockSupabaseClient(db_state)
    mock_app.dependency_overrides[get_supabase_client] = lambda: mock_supabase
    
    headers = {
        "X-Student-Id": "student-123",
        "X-Student-Bt-Id": "BT25CSA016",
        "X-Student-Email": "bt25csa016@iiitn.ac.in",
    }
    
    transport = ASGITransport(app=mock_app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post("/storage/files/file-123/rename-to-btid", headers=headers)
        assert resp.status_code == 200
        
        # Verify db update
        assert db_state["student_files"][0]["filename"] == "BT25CSA016_Resume.pdf"
