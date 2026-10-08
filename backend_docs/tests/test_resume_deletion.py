from typing import Any
from unittest.mock import MagicMock
# pyrefly: ignore [missing-import]
import pytest
# pyrefly: ignore [missing-import]
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.db.supabase_client import get_supabase_client
from app.resumes.router import get_r2_client, resumes_router



class MockSupabaseTable:
    def __init__(self, table_name: str, db_state: dict):
        self.table_name = table_name
        self.db_state = db_state
        self._current_filters = {}
        self._action = "select"
        self._update_data = None

    def select(self, *args, **kwargs):
        self._action = "select"
        return self

    def delete(self, *args, **kwargs):
        self._action = "delete"
        return self

    def update(self, data: dict):
        self._action = "update"
        self._update_data = data
        return self

    def eq(self, column: str, value: Any):
        self._current_filters[column] = value
        return self

    def execute(self):
        records = self.db_state.get(self.table_name, [])
        filtered = [
            r for r in records
            if all(str(r.get(col)) == str(val) for col, val in self._current_filters.items())
        ]

        if self._action == "select":
            mock_res = MagicMock()
            mock_res.data = filtered
            return mock_res

        elif self._action == "update":
            for r in filtered:
                r.update(self._update_data)
            mock_res = MagicMock()
            mock_res.data = filtered
            return mock_res

        elif self._action == "delete":
            for r in filtered:
                records.remove(r)
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
    app.include_router(resumes_router)
    return app


@pytest.mark.asyncio
async def test_soft_delete_when_used_for_application(mock_app):
    """If used_for_application == True, resume must be soft-deleted (is_profile_resume=False) without R2 deletion."""
    db_state = {
        "student_files": [
            {
                "id": "file-123",
                "student_id": "stud-1",
                "object_key": "resumes/file-123.pdf",
                "is_profile_resume": True,
                "used_for_application": True,
            }
        ]
    }

    mock_supabase = MockSupabaseClient(db_state)
    mock_r2 = MagicMock()

    mock_app.dependency_overrides[get_supabase_client] = lambda: mock_supabase
    mock_app.dependency_overrides[get_r2_client] = lambda: mock_r2

    transport = ASGITransport(app=mock_app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.delete("/api/resumes/file-123")

    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "soft_deleted"
    assert data["is_profile_resume"] is False
    assert data["r2_deleted"] is False

    # Check database row was updated, not deleted
    assert len(db_state["student_files"]) == 1
    assert db_state["student_files"][0]["is_profile_resume"] is False

    # Verify R2 delete_object was NOT called
    mock_r2.delete_object.assert_not_called()


@pytest.mark.asyncio
async def test_hard_delete_when_not_used_for_application(mock_app):
    """If used_for_application == False, resume must be hard-deleted from R2 and database."""
    db_state = {
        "student_files": [
            {
                "id": "file-456",
                "student_id": "stud-1",
                "object_key": "resumes/file-456.pdf",
                "is_profile_resume": True,
                "used_for_application": False,
            }
        ]
    }

    mock_supabase = MockSupabaseClient(db_state)
    mock_r2 = MagicMock()

    mock_app.dependency_overrides[get_supabase_client] = lambda: mock_supabase
    mock_app.dependency_overrides[get_r2_client] = lambda: mock_r2

    transport = ASGITransport(app=mock_app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.delete("/api/resumes/file-456")

    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "hard_deleted"
    assert data["r2_deleted"] is True

    # Check R2 delete_object was called
    mock_r2.delete_object.assert_called_once_with("resumes/file-456.pdf")

    # Check row was deleted from database
    assert len(db_state["student_files"]) == 0


@pytest.mark.asyncio
async def test_delete_non_existent_file(mock_app):
    """Should return 404 if file does not exist."""
    db_state = {"student_files": []}
    mock_supabase = MockSupabaseClient(db_state)
    mock_r2 = MagicMock()

    mock_app.dependency_overrides[get_supabase_client] = lambda: mock_supabase
    mock_app.dependency_overrides[get_r2_client] = lambda: mock_r2

    transport = ASGITransport(app=mock_app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.delete("/api/resumes/missing-id")

    assert resp.status_code == 404
