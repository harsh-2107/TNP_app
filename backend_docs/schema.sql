
CREATE TABLE IF NOT EXISTS public.students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bt_id VARCHAR(20) UNIQUE NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    branch VARCHAR(10) NOT NULL,
    cgpa NUMERIC(4,2) NOT NULL,
    backlogs INT NOT NULL DEFAULT 0,
    active_backlogs INT NOT NULL DEFAULT 0,
    education_gaps INT NOT NULL DEFAULT 0,
    phone_number VARCHAR(20),
    college_number VARCHAR(50),
    last_active_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);


-- files ke liye
CREATE TABLE IF NOT EXISTS public.student_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    object_key TEXT NOT NULL,
    filename TEXT NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    size_bytes BIGINT NOT NULL,
    file_type VARCHAR(20) NOT NULL DEFAULT 'resume',
    is_profile_file BOOLEAN NOT NULL DEFAULT TRUE,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    used_for_application BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- #uploads pending me jo hai
CREATE TABLE IF NOT EXISTS public.pending_uploads (
    file_id VARCHAR(32) PRIMARY KEY,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    pending_object_key TEXT NOT NULL,
    permanent_object_key TEXT NOT NULL,
    filename TEXT NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    file_type VARCHAR(20) NOT NULL,
    is_profile_file BOOLEAN NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL
);

-- table tokens
CREATE TABLE IF NOT EXISTS public.share_tokens (
    file_id UUID PRIMARY KEY REFERENCES public.student_files(id) ON DELETE CASCADE,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- job post wali table
CREATE TABLE IF NOT EXISTS public.companies_drives (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name VARCHAR(100) NOT NULL,
    role_title VARCHAR(100) NOT NULL,
    eligibility_rules JSONB NOT NULL DEFAULT '{}'::jsonb,
    raw_csv_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    status VARCHAR(20) NOT NULL DEFAULT 'open',
    application_deadline TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    job_id UUID NOT NULL REFERENCES public.companies_drives(id) ON DELETE CASCADE,
    resume_file_id UUID NOT NULL REFERENCES public.student_files(id),
    status VARCHAR(20) NOT NULL DEFAULT 'applied',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(student_id, job_id)
);

-- notifications
CREATE TABLE IF NOT EXISTS public.student_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    type VARCHAR(50) NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);