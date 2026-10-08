from typing import Any
from unittest.mock import MagicMock
import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.db.supabase_client import get_supabase_client
from app.admin.router import admin_router


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

    def order(self, column: str, desc: bool = False):
        return self

    def insert(self, data: dict):
        self.db_state.setdefault(self.table_name, []).append(data)
        
        mock_res = MagicMock()
        mock_res.data = [data]
        return mock_res

    def execute(self):
        records = self.db_state.get(self.table_name, [])
        filtered = [
            dict(r) for r in records
            if all(str(r.get(col)) == str(val) for col, val in self._current_filters.items())
        ]
        
        # Resolve relationships for mock testing joins
        if self.table_name == "applications":
            for app in filtered:
                student_id = app.get("student_id")
                students = self.db_state.get("students", [])
                app["students"] = next((s for s in students if s["id"] == student_id), None)
                
                job_id = app.get("job_id")
                drives = self.db_state.get("companies_drives", [])
                app["companies_drives"] = next((d for d in drives if d["id"] == job_id), None)
        
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
    app.include_router(admin_router)
    return app


@pytest.mark.asyncio
async def test_create_placement_drive_success(mock_app):
    """Verify drive creation compiles primary and custom eligibility rules correctly."""
    db_state = {"companies_drives": []}
    mock_supabase = MockSupabaseClient(db_state)
    mock_app.dependency_overrides[get_supabase_client] = lambda: mock_supabase

    payload = {
        "company_name": "Google India",
        "role_title": "Software Development Engineer",
        "job_description": "We are looking for backend engineers.",
        "expected_package": "18 LPA",
        "min_cgpa": 7.5,
        "max_backlogs": 0,
        "max_education_gaps": 1,
        "allowed_branches": ["CSE", "ECE"],
        "min_tenth_percentage": 85.0,
        "custom_criteria": [
            {
                "field": "skills",
                "operator": "contains",
                "value": "Python"
            }
        ]
    }

    transport = ASGITransport(app=mock_app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post("/api/admin/drives", json=payload)

    assert resp.status_code == 201
    data = resp.json()
    assert data["status"] == "success"
    
    # Verify the database mock contains the new drive row
    drives = db_state["companies_drives"]
    assert len(drives) == 1
    inserted_drive = drives[0]
    
    assert inserted_drive["company_name"] == "Google India"
    assert inserted_drive["role_title"] == "Software Development Engineer"
    assert inserted_drive["status"] == "open"
    
    # Verify JD and package metadata stored in raw_csv_data
    assert inserted_drive["raw_csv_data"]["job_description"] == "We are looking for backend engineers."
    assert inserted_drive["raw_csv_data"]["expected_package"] == "18 LPA"
    
    # Verify compiled eligibility rules
    rules = inserted_drive["eligibility_rules"]
    assert rules["logic"] == "AND"
    conditions = rules["conditions"]
    
    # Check that conditions match expected rules
    fields = [c["field"] for c in conditions]
    assert "cgpa" in fields
    assert "backlogs" in fields
    assert "education_gaps" in fields
    assert "branch" in fields
    assert "tenth_percentage" in fields
    assert "skills" in fields

    # Check cgpa condition value
    cgpa_cond = next(c for c in conditions if c["field"] == "cgpa")
    assert cgpa_cond["operator"] == ">="
    assert cgpa_cond["value"] == 7.5

    # Check skills custom condition
    skills_cond = next(c for c in conditions if c["field"] == "skills")
    assert skills_cond["operator"] == "contains"
    assert skills_cond["value"] == "Python"


@pytest.mark.asyncio
async def test_list_and_get_placement_drives(mock_app):
    """Verify retrieve endpoints list and fetch specific drives successfully."""
    db_state = {
        "companies_drives": [
            {
                "id": "drive-uuid-1",
                "company_name": "Microsoft",
                "role_title": "Data Analyst",
                "status": "open",
                "eligibility_rules": {},
                "raw_csv_data": {"job_description": "Descr", "expected_package": "12 LPA"}
            }
        ]
    }
    mock_supabase = MockSupabaseClient(db_state)
    mock_app.dependency_overrides[get_supabase_client] = lambda: mock_supabase

    transport = ASGITransport(app=mock_app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Test List
        list_resp = await client.get("/api/admin/drives")
        assert list_resp.status_code == 200
        list_data = list_resp.json()
        assert list_data["count"] == 1
        assert list_data["drives"][0]["company_name"] == "Microsoft"

        # Test Get by ID
        get_resp = await client.get("/api/admin/drives/drive-uuid-1")
        assert get_resp.status_code == 200
        get_data = get_resp.json()
        assert get_data["drive"]["company_name"] == "Microsoft"

        # Test Get Nonexistent
        missing_resp = await client.get("/api/admin/drives/drive-uuid-missing")
        assert missing_resp.status_code == 404


@pytest.mark.asyncio
async def test_parse_csv_columns_success(mock_app):
    """Verify that uploading a CSV correctly parses column headers and types."""
    transport = ASGITransport(app=mock_app)
    
    # Dummy CSV data
    csv_content = b"name,cgpa,backlogs,is_placed\nAlice,8.5,0,True\nBob,7.2,1,False\n"
    
    files = {"file": ("students.csv", csv_content, "text/csv")}
    
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post("/api/admin/drives/parse-csv-columns", files=files)
        
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "success"
    assert data["filename"] == "students.csv"
    
    columns = data["columns"]
    assert len(columns) == 4
    
    # Check that columns and types were inferred correctly
    assert columns[0]["name"] == "name"
    assert columns[0]["type"] == "string"
    
    assert columns[1]["name"] == "cgpa"
    assert columns[1]["type"] == "number"
    
    assert columns[2]["name"] == "backlogs"
    assert columns[2]["type"] == "number"
    
    assert columns[3]["name"] == "is_placed"
    assert columns[3]["type"] == "boolean"


@pytest.mark.asyncio
async def test_parse_csv_columns_invalid_format(mock_app):
    """Verify that uploading a non-CSV file returns 400 Bad Request."""
    transport = ASGITransport(app=mock_app)
    files = {"file": ("students.txt", b"some-text", "text/plain")}
    
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post("/api/admin/drives/parse-csv-columns", files=files)
        
    assert resp.status_code == 400
    assert "CSV" in resp.json()["detail"]


@pytest.mark.asyncio
async def test_list_drive_applicants_success(mock_app):
    """Verify that listing and filtering applicants works correctly."""
    db_state = {
        "applications": [
            {
                "id": "app-1",
                "student_id": "student-123",
                "job_id": "drive-uuid-1",
                "resume_file_id": "file-123",
                "status": "applied",
                "created_at": "2026-08-13T00:00:00"
            }
        ],
        "students": [
            {
                "id": "student-123",
                "bt_id": "BT25CSA016",
                "full_name": "Aarav Sharma",
                "email": "bt25csa016@iiitn.ac.in",
                "branch": "CSE",
                "cgpa": 8.5,
                "phone_number": "9876543210",
                "college_number": "12345"
            }
        ],
        "companies_drives": [
            {
                "id": "drive-uuid-1",
                "company_name": "Microsoft",
                "role_title": "Data Analyst",
                "status": "open",
                "eligibility_rules": {},
                "raw_csv_data": {"job_description": "Descr", "expected_package": "12 LPA"}
            }
        ]
    }
    
    mock_supabase = MockSupabaseClient(db_state)
    mock_app.dependency_overrides[get_supabase_client] = lambda: mock_supabase

    transport = ASGITransport(app=mock_app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Test basic list
        resp = await client.get("/api/admin/applicants")
        assert resp.status_code == 200
        data = resp.json()
        assert data["count"] == 1
        applicant = data["applicants"][0]
        assert applicant["full_name"] == "Aarav Sharma"
        assert applicant["company_name"] == "Microsoft"
        assert applicant["resume_link"] != "N/A"
        assert applicant["phone_number"] == "9876543210"

        # Test filter match
        match_resp = await client.get("/api/admin/applicants?company_name=Micro")
        assert match_resp.json()["count"] == 1

        # Test filter mismatch
        mismatch_resp = await client.get("/api/admin/applicants?branch=ECE")
        assert mismatch_resp.json()["count"] == 0


@pytest.mark.asyncio
async def test_export_applicants_csv_success(mock_app):
    """Verify that export endpoint returns downloadable CSV content."""
    db_state = {
        "applications": [
            {
                "id": "app-1",
                "student_id": "student-123",
                "job_id": "drive-uuid-1",
                "resume_file_id": "file-123",
                "status": "applied",
                "created_at": "2026-08-13T00:00:00"
            }
        ],
        "students": [
            {
                "id": "student-123",
                "bt_id": "BT25CSA016",
                "full_name": "Aarav Sharma",
                "email": "bt25csa016@iiitn.ac.in",
                "branch": "CSE",
                "cgpa": 8.5
            }
        ],
        "companies_drives": [
            {
                "id": "drive-uuid-1",
                "company_name": "Microsoft",
                "role_title": "Data Analyst",
                "status": "open",
                "eligibility_rules": {},
                "raw_csv_data": {"job_description": "Descr", "expected_package": "12 LPA"}
            }
        ]
    }
    
    mock_supabase = MockSupabaseClient(db_state)
    mock_app.dependency_overrides[get_supabase_client] = lambda: mock_supabase

    transport = ASGITransport(app=mock_app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/api/admin/drives/drive-uuid-1/export")
        
    assert resp.status_code == 200
    assert resp.headers["content-type"] == "text/csv; charset=utf-8"
    assert "attachment; filename=" in resp.headers["content-disposition"]
    
    csv_text = resp.text
    assert "Student Name,BTID,Email" in csv_text
    assert "Aarav Sharma,BT25CSA016" in csv_text


@pytest.mark.asyncio
async def test_deadline_reminders_trigger(mock_app):
    """Verify that send-reminders scans open drives and triggers alerts for eligible students."""
    from datetime import datetime, timezone, timedelta
    
    # Set deadline exactly 12 hours from now
    target_deadline = (datetime.now(timezone.utc) + timedelta(hours=12)).isoformat()

    db_state = {
        "applications": [], # student-123 has NOT applied yet
        "students": [
            {
                "id": "student-123",
                "bt_id": "BT25CSA016",
                "full_name": "Aarav Sharma",
                "email": "bt25csa016@iiitn.ac.in",
                "branch": "CSE",
                "cgpa": 8.5
            }
        ],
        "companies_drives": [
            {
                "id": "drive-uuid-1",
                "company_name": "Microsoft",
                "role_title": "Data Analyst",
                "status": "open",
                "eligibility_rules": {
                    "logic": "AND",
                    "conditions": [
                        {"field": "cgpa", "operator": ">=", "value": 8.0}
                    ]
                },
                "application_deadline": target_deadline,
                "raw_csv_data": {}
            }
        ]
    }
    
    mock_supabase = MockSupabaseClient(db_state)
    mock_app.dependency_overrides[get_supabase_client] = lambda: mock_supabase

    transport = ASGITransport(app=mock_app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post("/api/admin/drives/send-reminders")
        
    assert resp.status_code == 200
    assert resp.json()["status"] == "success"
