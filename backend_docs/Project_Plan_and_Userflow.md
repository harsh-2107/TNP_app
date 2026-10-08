# Soham bhaia  - said

## 1. All possible requirements advanced and regular

## 2. Csv mam ke liye uploaded hardcoded na ho mam change kar sakein company preferences ko

## 3. Limitation upto 2 JDs

## 4.Resume sharing to company drive integrating
 
## 5.Renaming 

## 6.Lpa package

# Project Plan and User Flow: College Placement Platform

## 1. Tech Stack Overview

Based on your requirements, here is the recommended tech stack architecture:

*   **Mobile App (Students):** Flutter (Dart) for a smooth, cross-platform native experience.
*   **Admin Panel (Web):** Flutter Web (to share UI components/models with the app) or a Python-based web framework (fastAPI)
*   **Backend & Database:** Supabase (provides PostgreSQL database and Google OAuth authentication).
*   **File Storage:** Cloudflare R2 (S3-compatible bucket storage used for storing resumes and generated Excel files. This eliminates Supabase's bandwidth limitations and egress fees).
*   **Backend Microservices (Data Processing, Emails):** Python (FastAPI/Flask) to handle heavy tasks such as parsing Excel files, generating reports, and sending automated emails.
*   **Extra Dependencies:**
    *   **Email Provider:** SendGrid, Resend, or Amazon SES (integrated via Python backend).
    *   **Excel Processing:** `pandas` and `openpyxl` (Python) for generating and parsing spreadsheets.
    *   **Cloudflare R2 Client:** `boto3` (Python library) to upload, download, and generate secure, pre-signed download URLs for resumes and Excel files.

---

## 2. Student User Flow (Flutter App)

### Authentication & Onboarding
1.  **Google Sign-In:** Student signs in using their official college Google account (BTID).
2.  **Data Fetching:** The system identifies the BTID and queries the college database (Supabase) to fetch academic history (CGPA, backlogs, branch, etc.).
3.  **Eligibility Verification:** The system evaluates the student's records against predefined college placement criteria.
    *   *If ineligible for specific general criteria:* The dashboard explicitly shows which criterion was not satisfied.
4.  **Resume Upload:** Student uploads one or multiple resumes (e.g., "Software Dev Resume", "Data Analyst Resume") and titles them. Resumes are saved securely to Cloudflare R2 Storage.

### Dashboard & Job Discovery
1.  **Job Feed:** The dashboard displays all on-campus placement jobs. Information includes Company Name, Job Title, Job Role, and Job Description.
2.  **Eligibility Filtering:**
    *   Jobs where the student meets the criteria are marked as **Eligible**.
    *   Jobs where criteria are missed are marked as **Ineligible**, and the app shows exactly *which* desired criteria need to be fulfilled (e.g., "Requires 8.0 CGPA").

### Application Process
1.  **Job Details:** Student taps an eligible job to read the full description.
2.  **Apply ("I'm interested"):** Student clicks the apply button.
3.  **Resume Selection:** A bottom sheet prompts the student to select which of their uploaded resumes they want to submit for this specific role.
4.  **Submission:** The application is recorded in the database.

### Automated Notifications (via Email)
*   **New Job Alert:** Email sent when a newly uploaded job matches their eligibility.
*   **Deadline Reminder:** Email sent 12 hours before a job's application deadline if the student is eligible but hasn't applied.
*   **Result Update:** Email sent when the student is marked as Selected or Rejected by the Admin.

---

## 3. Admin User Flow (Web Panel)

### Job Creation
1.  **Upload Job:** Admin fills a form to create a job posting (Company, Role, Description, Deadline).
2.  **Set Criteria:** Admin sets specific eligibility rules for this job (e.g., Min CGPA, Max Backlogs, Allowed Branches).

### Monitoring & Analytics
1.  **Live Dashboard:** Real-time sync showing how many students have applied.
2.  **Filtering:** Admin can filter the applicant list by Company and Job Role to see detailed applicant data and resumes.

### Result Processing (Excel Workflow)
1.  **Generate Excel:** Admin clicks "Generate Official Excel". The Python backend compiles the applied students' data (Name, BTID, Resume Links) into an `.xlsx` file and downloads it.
2.  **External Decision:** The Excel file is sent to the company. The company adds a new column: `Selected/Unselected`.
3.  **Upload Result:** Admin uploads the modified Excel file back to the portal.
4.  **Result Parsing:** The Python backend parses the Excel file.
5.  **Database Update & Mails:** The database marks students as Selected/Rejected, and triggers the respective notification emails to the students.

---
