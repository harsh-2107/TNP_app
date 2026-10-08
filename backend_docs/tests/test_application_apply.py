"""Unit tests for Application Submission Route (Eligibility verification + resume locking)."""

from typing import Any
from unittest.mock import MagicMock
import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.applications.router import applications_router
from app.db.supabase_client import get_supabase_client


class MockSupabaseTable:
    def __init__(self, table_name: str, db_state: dict):
        self.table_name = table_name
        self.db_state = db_state
        self._current_filters = {}
        self._action = "select"
        self._insert_data = None
        self._update_data = None

    def select(self, *args, **kwargs):
        self._action = "select"
        return self

    def insert(self, data: dict):
        self._action = "insert"
        self._insert_data = data
        return self

    def update(self, data: dict):
        self._action = "update"
        self._update_data = data
        return self

    def eq(self, column: str, value: Any):
        self._current_filters[column] = value
        return self

    def execute(self):
        records = self.db_state.setdefault(self.table_name, [])
        filtered = [
            r for r in records
            if all(str(r.get(col)) == str(val) for col, val in self._current_filters.items())
        ]

        if self._action == "select":
            mock_res = MagicMock()
            mock_res.data = filtered
            return mock_res

        elif self._action == "insert":
            records.append(self._insert_data)
            mock_res = MagicMock()
            mock_res.data = [self._insert_data]
            return mock_res

        elif self._action == "update":
            for r in filtered:
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
    app = FastAPI()
    app.include_router(applications_router)
    return app


@pytest.mark.asyncio
async def test_apply_successful_locks_resume(mock_app):
    """When a student is eligible, application is inserted and used_for_application is set to True."""
    db_state = {
        "student_files": [
            {
                "id": "file-101",
                "student_id": "stud-1",
                "object_key": "resumes/file-101.pdf",
                "is_profile_resume": True,
                "used_for_application": False,
            }
        ],
        "companies_drives": [
            {
                "id": "job-google",
                "eligibility_rules": {
                    "logic": "AND",
                    "conditions": [
                        {"field": "cgpa", "operator": ">=", "value": 8.0},
                        {"field": "branch", "operator": "IN", "value": ["CSE", "IT"]},
                    ],
                },
            }
        ],
        "students": [
            {
                "id": "stud-1",
                "cgpa": 8.5,
                "branch": "CSE",
                "placement_status": "unplaced",
            }
        ],
        "applications": [],
    }

    mock_supabase = MockSupabaseClient(db_state)
    mock_app.dependency_overrides[get_supabase_client] = lambda: mock_supabase

    payload = {
        "student_id": "stud-1",
        "job_id": "job-google",
        "resume_file_id": "file-101",
    }

    transport = ASGITransport(app=mock_app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post("/api/applications/apply", json=payload)

    assert resp.status_code == 201
    data = resp.json()
    assert data["status"] == "success"
    assert data["resume_locked"] is True

    # Verify application row was created
    assert len(db_state["applications"]) == 1
    assert db_state["applications"][0]["student_id"] == "stud-1"
    assert db_state["applications"][0]["job_id"] == "job-google"

    # CRITICAL: Verify used_for_application is now True in student_files
    assert db_state["student_files"][0]["used_for_application"] is True


@pytest.mark.asyncio
async def test_apply_ineligible_student_rejected(mock_app):
    """When a student fails eligibility criteria, application is rejected (400) and resume is NOT locked."""
    db_state = {
        "student_files": [
            {
                "id": "file-101",
                "student_id": "stud-1",
                "is_profile_resume": True,
                "used_for_application": False,
            }
        ],
        "companies_drives": [
            {
                "id": "job-google",
                "eligibility_rules": {
                    "field": "cgpa",
                    "operator": ">=",
                    "value": 8.0,
                },
            }
        ],
        "students": [
            {
                "id": "stud-1",
                "cgpa": 7.2,  # Ineligible (< 8.0)
                "branch": "CSE",
            }
        ],
        "applications": [],
    }

    mock_supabase = MockSupabaseClient(db_state)
    mock_app.dependency_overrides[get_supabase_client] = lambda: mock_supabase

    payload = {
        "student_id": "stud-1",
        "job_id": "job-google",
        "resume_file_id": "file-101",
    }

    transport = ASGITransport(app=mock_app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post("/api/applications/apply", json=payload)

    assert resp.status_code == 400
    data = resp.json()
    assert data["is_eligible"] is False
    assert len(data["reasons"]) > 0

    # Verify no application was inserted
    assert len(db_state["applications"]) == 0

    # Verify resume was NOT locked
    assert db_state["student_files"][0]["used_for_application"] is False


@pytest.mark.asyncio
async def test_apply_resume_ownership_check(mock_app):
    """If resume belongs to another student, return 403 Forbidden."""
    db_state = {
        "student_files": [
            {
                "id": "file-101",
                "student_id": "other-student",
                "used_for_application": False,
            }
        ],
        "companies_drives": [{"id": "job-1", "eligibility_rules": {}}],
        "students": [{"id": "stud-1"}],
        "applications": [],
    }

    mock_supabase = MockSupabaseClient(db_state)
    mock_app.dependency_overrides[get_supabase_client] = lambda: mock_supabase

    payload = {
        "student_id": "stud-1",
        "job_id": "job-1",
        "resume_file_id": "file-101",
    }

    transport = ASGITransport(app=mock_app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post("/api/applications/apply", json=payload)

    assert resp.status_code == 403
