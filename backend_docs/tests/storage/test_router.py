

import pytest
import pytest_asyncio

from app.core.exceptions import R2OperationFailed


STUDENT_HEADERS = {
    "X-Student-Id": "student-001",
    "X-Student-Bt-Id": "BT25CSA016",
    "X-Student-Email": "student@example.com",
}

OTHER_STUDENT_HEADERS = {
    "X-Student-Id": "student-002",
    "X-Student-Bt-Id": "BT25CSA017",
    "X-Student-Email": "other@example.com",
}





async def _upload_complete(client, headers=None) -> dict:
    """Helper: request upload URL + complete upload via HTTP. Returns file record."""
    if headers is None:
        headers = STUDENT_HEADERS

    # Request upload URL
    resp = await client.post(
        "/storage/upload-url",
        json={
            "filename": "resume.pdf",
            "mime_type": "application/pdf",
            "size_bytes": 1024,
            "file_type": "resume",
            "is_profile_file": True,
        },
        headers=headers,
    )
    assert resp.status_code == 200
    upload_data = resp.json()

    # Complete upload
    resp = await client.post(
        "/storage/complete-upload",
        json={"file_id": upload_data["file_id"]},
        headers=headers,
    )
    assert resp.status_code == 200
    return resp.json()["file"]




class TestUploadUrlEndpoint:

    @pytest.mark.asyncio
    async def test_success(self, test_client):
        resp = await test_client.post(
            "/storage/upload-url",
            json={
                "filename": "resume.pdf",
                "mime_type": "application/pdf",
                "size_bytes": 1024,
                "file_type": "resume",
                "is_profile_file": True,
            },
            headers=STUDENT_HEADERS,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "file_id" in data
        assert "upload_url" in data
        assert "expires_in" in data
        assert len(data["file_id"]) == 32

    @pytest.mark.asyncio
    async def test_missing_auth_header_401(self, test_client):
        resp = await test_client.post(
            "/storage/upload-url",
            json={
                "filename": "resume.pdf",
                "mime_type": "application/pdf",
                "size_bytes": 1024,
                "file_type": "resume",
                "is_profile_file": True,
            },
        )
        assert resp.status_code == 422 or resp.status_code == 401

    @pytest.mark.asyncio
    async def test_invalid_file_type_400(self, test_client):
        resp = await test_client.post(
            "/storage/upload-url",
            json={
                "filename": "resume.txt",
                "mime_type": "application/pdf",
                "size_bytes": 1024,
                "file_type": "resume",
                "is_profile_file": False,
            },
            headers=STUDENT_HEADERS,
        )
        assert resp.status_code == 400

    @pytest.mark.asyncio
    async def test_file_too_large_400(self, test_client):
        resp = await test_client.post(
            "/storage/upload-url",
            json={
                "filename": "resume.pdf",
                "mime_type": "application/pdf",
                "size_bytes": 10_000_000,
                "file_type": "resume",
                "is_profile_file": False,
            },
            headers=STUDENT_HEADERS,
        )
        assert resp.status_code == 400





class TestCompleteUploadEndpoint:
    #Test for upload complete

    @pytest.mark.asyncio
    async def test_success(self, test_client):
        file_record = await _upload_complete(test_client)
        assert file_record["filename"].endswith(".pdf")
        assert file_record["mime_type"] == "application/pdf"
        assert file_record["is_profile_file"] is True
        assert "object_key" not in file_record

    @pytest.mark.asyncio
    async def test_nonexistent_upload_404(self, test_client):
        resp = await test_client.post(
            "/storage/complete-upload",
            json={"file_id": "nonexistent-id"},
            headers=STUDENT_HEADERS,
        )
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_wrong_student_403(self, test_client):
        # student 001
        resp = await test_client.post(
            "/storage/upload-url",
            json={
                "filename": "resume.pdf",
                "mime_type": "application/pdf",
                "size_bytes": 1024,
                "file_type": "resume",
                "is_profile_file": True,
            },
            headers=STUDENT_HEADERS,
        )
        file_id = resp.json()["file_id"]

        # Try to complete as student002
        resp = await test_client.post(
            "/storage/complete-upload",
            json={"file_id": file_id},
            headers=OTHER_STUDENT_HEADERS,
        )
        assert resp.status_code == 403





class TestProfileFilesEndpoint:
#getting files
    @pytest.mark.asyncio
    async def test_empty_list(self, test_client):
        resp = await test_client.get(
            "/storage/profile/files",
            headers=STUDENT_HEADERS,
        )
        assert resp.status_code == 200
        assert resp.json()["files"] == []

    @pytest.mark.asyncio
    async def test_returns_profile_files(self, test_client):
        await _upload_complete(test_client)

        resp = await test_client.get(
            "/storage/profile/files",
            headers=STUDENT_HEADERS,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["files"]) == 1
        assert data["files"][0]["is_profile_file"] is True
        assert "object_key" not in data["files"][0]




class TestFileViewEndpoint:
   #viewing files

    @pytest.mark.asyncio
    async def test_success(self, test_client):
        file_record = await _upload_complete(test_client)

        resp = await test_client.get(
            f"/storage/files/{file_record['id']}/view",
            headers=STUDENT_HEADERS,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "download_url" in data
        assert "expires_in" in data

    @pytest.mark.asyncio
    async def test_nonexistent_file_404(self, test_client):
        resp = await test_client.get(
            "/storage/files/nonexistent-id/view",
            headers=STUDENT_HEADERS,
        )
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_idor_protection_403(self, test_client):
        # Student B cannot view Student A's file.
        file_record = await _upload_complete(test_client, STUDENT_HEADERS)

        resp = await test_client.get(
            f"/storage/files/{file_record['id']}/view",
            headers=OTHER_STUDENT_HEADERS,
        )
        assert resp.status_code == 403





class TestDeleteFileEndpoint:
  #delete test

    @pytest.mark.asyncio
    async def test_delete_success(self, test_client):
        file_record = await _upload_complete(test_client)

        resp = await test_client.delete(
            f"/storage/files/{file_record['id']}",
            headers=STUDENT_HEADERS,
        )
        assert resp.status_code == 200
        assert resp.json()["message"] == "File deleted successfully."

    @pytest.mark.asyncio
    async def test_delete_nonexistent_404(self, test_client):
        resp = await test_client.delete(
            "/storage/files/nonexistent-id",
            headers=STUDENT_HEADERS,
        )
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_delete_wrong_student_403(self, test_client):
        file_record = await _upload_complete(test_client, STUDENT_HEADERS)

        resp = await test_client.delete(
            f"/storage/files/{file_record['id']}",
            headers=OTHER_STUDENT_HEADERS,
        )
        assert resp.status_code == 403

    @pytest.mark.asyncio
    async def test_delete_referenced_file_soft_removes(
        self, test_client, in_memory_repository
    ):
        file_record = await _upload_complete(test_client)

        # Simulate application reference
        await in_memory_repository.mark_file_used_for_application(
            file_record["id"]
        )

        resp = await test_client.delete(
            f"/storage/files/{file_record['id']}",
            headers=STUDENT_HEADERS,
        )
        assert resp.status_code == 200
        assert resp.json()["message"] == "File removed from profile successfully."





class TestShareTokenEndpoint:
    

    @pytest.mark.asyncio
    async def test_valid_token_302_redirect(
        self, test_client, in_memory_repository
    ):

        # Create a file and share link directly via service
        file_record = await _upload_complete(test_client)

        # repo se share link banao
        from app.storage.utils import generate_share_token, hash_share_token

        token = generate_share_token()
        token_hash = hash_share_token(token)
        await in_memory_repository.store_share_token(
            file_record["id"], token_hash
        )

        resp = await test_client.get(
            f"/share/{token}",
            follow_redirects=False,
        )
        assert resp.status_code == 302
        assert "location" in resp.headers
        # location pre assigned hai?
        assert resp.headers["location"]

    @pytest.mark.asyncio
    async def test_invalid_token_404(self, test_client):
        resp = await test_client.get(
            "/share/invalid-token-that-does-not-exist",
            follow_redirects=False,
        )
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_no_auth_required(self, test_client, in_memory_repository):
        file_record = await _upload_complete(test_client)

        from app.storage.utils import generate_share_token, hash_share_token

        token = generate_share_token()
        token_hash = hash_share_token(token)
        await in_memory_repository.store_share_token(
            file_record["id"], token_hash
        )

        # No auth headers
        resp = await test_client.get(
            f"/share/{token}",
            follow_redirects=False,
        )
        assert resp.status_code == 302





class TestDefaultResumeEndpoint:

    @pytest.mark.asyncio
    async def test_set_default_success(self, test_client, in_memory_repository):
        # Upload a file
        file_record = await _upload_complete(test_client)

        # Set default
        resp = await test_client.post(
            f"/storage/files/{file_record['id']}/default",
            headers=STUDENT_HEADERS,
        )
        assert resp.status_code == 200
        assert resp.json()["status"] == "success"

        # repo ke andar default hai?
        record = await in_memory_repository.get_file_by_id(file_record["id"])
        assert record.is_default is True

    @pytest.mark.asyncio
    async def test_set_default_nonexistent_404(self, test_client):
        resp = await test_client.post(
            "/storage/files/nonexistent-id/default",
            headers=STUDENT_HEADERS,
        )
        assert resp.status_code == 404
