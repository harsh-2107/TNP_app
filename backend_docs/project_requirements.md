# PlacedThere — Deployment & Integration Settings Guide

This document lists all configuration requirements, cloud settings, and database tables needed to deploy and integrate the **PlacedThere** backend service successfully.

---

## 1. Environment Configurations (`.env`)

Create a `.env` file in the root of the project. Ensure the following environment variables are set before launching in staging or production.

### 🌐 Supabase Integration
*   `SUPABASE_URL`: The URL of your Supabase project (found in Project Settings -> API).
*   `SUPABASE_KEY`: The Supabase anon/public key for standard client calls.
*   `SUPABASE_SERVICE_ROLE_KEY`: (Optional) Used for bypass-level admin operations.

### ☁️ Cloudflare R2 Credentials
*   `R2_ACCOUNT_ID`: Your Cloudflare Account ID (found on the right sidebar of the Cloudflare home page).
*   `R2_ACCESS_KEY_ID`: S3-compatible Access Key ID generated under Cloudflare R2 settings.
*   `R2_SECRET_ACCESS_KEY`: The corresponding S3-compatible secret key.
*   `R2_BUCKET_NAME`: The name of the bucket used to store resumes.
*   `R2_UPLOAD_URL_EXPIRY_SECONDS`: Presigned upload ticket expiry duration (default: `300` / 5 minutes).
*   `R2_DOWNLOAD_URL_EXPIRY_SECONDS`: Presigned download link expiry duration (default: `3600` / 1 hour).

### 🤖 Job Description parser (LLM)
*   `OPENAI_API_KEY`: Used by the admin AI parsing agent to parse PDF/text job postings automatically.
*   `OPENAI_MODEL`: Defaults to `gpt-4o-mini` for efficient extraction.

### 📧 SMTP Mail Server
*   `SMTP_HOST`: Mail server hostname (e.g. `smtp.gmail.com`).
*   `SMTP_PORT`: Port number (e.g. `587` for TLS / `465` for SSL).
*   `SMTP_USER`: Authentication email address.
*   `SMTP_PASSWORD`: Authentication password / App password.

---

## 2. Cloudflare R2 Bucket Configuration

Your Cloudflare R2 bucket must be configured via the Cloudflare dashboard to allow cross-origin uploads and clean up abandoned attempts.

### 📡 CORS (Cross-Origin Resource Sharing)
Since the Flutter mobile client uploads PDF files directly to your R2 bucket using presigned URLs, you must permit CORS PUT requests.
Go to **R2 Bucket -> Settings -> CORS Rules** and add:
```json
[
  {
    "AllowedOrigins": [
      "*"
    ],
    "AllowedMethods": [
      "PUT"
    ],
    "AllowedHeaders": [
      "*"
    ],
    "ExposeHeaders": []
  }
]
```

### 🗑️ Lifecycle Rule (Garbage Collection)
If a student starts an upload but cancels it or loses connection midway, the partial file will sit in the `pending/` directory forever.
**You must configure a lifecycle cleanup rule:**
1. Navigate to **R2 Bucket -> Settings -> Object Lifecycle Rules**.
2. Add a rule for the prefix: `pending/`.
3. Set the action to: **Delete**.
4. Set the age constraint to: **1 day** (deletes abandoned upload attempts after 24 hours).

---

## 3. Database Schema Migrations

Run the following SQL migrations in your **Supabase SQL Editor** to construct the tables and columns required by this application:

```sql
-- 1. Create share_tokens table (for recruiter review links)
CREATE TABLE IF NOT EXISTS public.share_tokens (
    file_id UUID PRIMARY KEY REFERENCES public.student_files(id) ON DELETE CASCADE,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Create pending_uploads table (for tracking uploads in progress)
CREATE TABLE IF NOT EXISTS public.pending_uploads (
    file_id VARCHAR(32) PRIMARY KEY,
    student_id UUID NOT NULL,
    pending_object_key TEXT NOT NULL,
    permanent_object_key TEXT NOT NULL,
    filename TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    file_type VARCHAR(20) NOT NULL,
    is_profile_file BOOLEAN NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL
);

-- 3. Add is_default column to student_files table (for tracking default resumes)
ALTER TABLE public.student_files ADD COLUMN IF NOT EXISTS is_default BOOLEAN NOT NULL DEFAULT FALSE;

-- 4. Add contact information and live tracker columns to students table
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS phone_number VARCHAR(20);
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS college_number VARCHAR(50);
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ DEFAULT NOW();

-- 5. Add application_deadline column to companies_drives table
ALTER TABLE public.companies_drives ADD COLUMN IF NOT EXISTS application_deadline TIMESTAMPTZ;

-- 6. Create student_notifications table (for In-App Notification Center)
CREATE TABLE IF NOT EXISTS public.student_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    type VARCHAR(50) NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```
