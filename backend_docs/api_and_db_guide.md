# Storage Module: API & Supabase DB Guide

This guide explains how to interact with the Storage Module APIs and outlines the expected database schema for implementing the real Supabase backend.

## 1. Storage API Workflow

The file upload process uses a highly secure, two-phase upload system.

### Phase 1: Request Upload URL
```http
POST /storage/upload-url
```
**Headers Required:**
- `X-Student-Id`: UUID of the authenticated student
- `X-Student-Bt-Id`: BT ID of the student (e.g. `BT25CSA016`)

**Body:**
```json
{
  "filename": "resume.pdf",
  "mime_type": "application/pdf",
  "size_bytes": 1024,
  "file_type": "resume",
  "is_profile_file": true
}
```
**Response:**
Returns a `file_id` and a `upload_url` (a Cloudflare R2 presigned PUT URL). The frontend must use this URL to directly PUT the file bytes to R2.

### Phase 2: Complete Upload
Once the frontend successfully uploads the file to the `upload_url`, it must notify the backend to verify and permanently store the file.

```http
POST /storage/complete-upload
```
**Body:**
```json
{
  "file_id": "the-file-id-from-phase-1"
}
```
**Action performed by backend:**
1. Verifies the file actually exists in R2.
2. Performs a magic-byte check (`%PDF-`) by reading the first 5 bytes.
3. Checks actual file size.
4. Copies the file from the `pending/` directory to the `files/` directory in R2.
5. Saves the file record in the Database.
6. Deletes the `pending/` file.

### Retrieving and Managing Files
- **Get Profile Files:** `GET /storage/profile/files`
- **View File:** `GET /storage/files/{id}/view` (returns a presigned short-lived GET URL)
- **Delete File:** `DELETE /storage/files/{id}` (Soft deletes if `used_for_application` is true, otherwise hard deletes)
- **Share Link:** `GET /share/{token}` (Redirects to a presigned GET URL for HR/faculty)

---

## 2. Supabase DB Schema Contract

The current implementation uses `InMemoryFileRepository`. When migrating to Supabase (PostgreSQL), your database schema must support the following structure exactly as defined by the `FileRecord` interface.

### Table: `files`
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `VARCHAR(32)` | PRIMARY KEY | The 32-character hex string generated during upload-url. |
| `student_id` | `UUID` | NOT NULL | Foreign key to your future `users` or `students` table. |
| `filename` | `VARCHAR(255)` | NOT NULL | The structured filename (e.g., `BT25CSA016_20260810T090148_abc.pdf`). |
| `file_type` | `VARCHAR` | NOT NULL | Either `resume` or `cover_letter`. |
| `mime_type` | `VARCHAR` | NOT NULL | e.g. `application/pdf`. |
| `size_bytes` | `BIGINT` | NOT NULL | The verified actual size of the file. |
| `object_key` | `VARCHAR` | NOT NULL | The exact path in the R2 bucket (e.g. `files/BT25CSA016/BT25CSA...pdf`). |
| `is_profile_file` | `BOOLEAN` | DEFAULT `FALSE` | Indicates if the file is currently visible on the student's profile. |
| `used_for_application` | `BOOLEAN` | DEFAULT `FALSE` | Set to true when an application uses this file. Triggers soft-deletes. |
| `created_at` | `TIMESTAMPTZ` | DEFAULT `NOW()` | Timestamp of successful upload completion. |

### Application Lifecycle Flow
When a student submits an application using a resume:
1. Ensure the backend submission logic securely calls the storage repository function `mark_file_used_for_application(file_id)` to set `used_for_application = True`.
2. Do not manually touch `is_profile_file` during application submissions.

### How to Implement Supabase
To implement Supabase:
1. Create a new class `SupabaseFileRepository` inside `app/storage/repository.py`.
2. Have it implement the `FileRepositoryInterface`.
3. Use the `supabase-py` client (or raw SQL/SQLAlchemy depending on your architecture) to query the `files` table based on the interface methods.
4. Swap the dependency injection in `app/main.py` or your router to inject `SupabaseFileRepository` instead of `InMemoryFileRepository`.
