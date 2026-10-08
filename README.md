# IIIT Nagpur Placement Cell — Flutter App

A production-architecture Flutter client for the IIIT Nagpur Training & Placement Cell portal: students sign in with their college identity, browse active on/off-campus opportunities, manage their profile, track notifications, and upload or generate resumes.

This document covers the app's **architecture**, **file structure**, and **feature set** as implemented in `lib/`.

> Scope note: only the `lib/` source tree was generated (no `pubspec.yaml`, assets, or platform folders). See [Setup & Configuration](#setup--configuration) for what you still need to add.

---

## 1. Architecture

The app follows a **layered, feature-first Clean Architecture**, split into two top-level trees:

```
lib/
├── core/        ← cross-cutting, feature-agnostic building blocks
└── features/    ← one folder per business capability (auth, home, profile, notifications, resume)
```

Every feature is internally split into three layers, and dependencies only ever point **inward**:

```
presentation  →  domain  →  data
   (UI, controllers)  (models)  (repositories, API calls)
```

### 1.1 Layer responsibilities

| Layer | Contains | Rules |
|---|---|---|
| **`data/`** | Repositories that talk to Supabase (Postgres tables, Storage, Auth) | Never imported by widgets directly. Converts raw SDK exceptions into `AppException`s. |
| **`domain/`** | Plain Dart model classes (`JobOpportunity`, `StudentProfile`, `AppNotification`, …) with `fromJson`/`toJson` | No Flutter or Supabase imports — pure data classes. |
| **`presentation/controllers/`** | Riverpod `AsyncNotifier`s that own screen state | The *only* place business logic lives. Widgets never call repositories directly. |
| **`presentation/pages/`** | Screens (`ConsumerWidget`/`ConsumerStatefulWidget`) | Declarative UI only — reads controller state via `ref.watch`, delegates actions via `ref.read(...).notifier`. |
| **`presentation/widgets/`** | Feature-specific UI pieces (`JobCard`, `NotificationCard`, …) | Reusable *within* a feature; cross-feature reusable widgets live in `core/widgets/` instead. |

### 1.2 State management

- **Riverpod** (`flutter_riverpod`), using **code-gen-free `AsyncNotifier`/`AsyncNotifierProvider`** — no `build_runner` dependency required.
- Every controller exposes `AsyncValue<T>`, so every screen handles **loading / data / error** uniformly via `.when(...)`.
- Controllers `ref.watch()` each other where there's a real dependency (e.g. `HomeController` watches `authControllerProvider` to know the signed-in user, `ProfileController` does the same). This means signing out automatically invalidates and clears dependent state.
- Mutations (`save()`, `submit()`, `pickAndUploadResume()`) return a `bool`/throw, letting the calling widget decide how to react (snackbar, navigation, dialog) — controllers don't reach into `BuildContext`.
- Optimistic updates are used where it's safe to do so (e.g. `NotificationController.markAsRead` flips `isRead` locally immediately, then reverts if the network call fails).

### 1.3 Error handling

A two-tier error model keeps the data layer's exceptions out of the UI:

```
Supabase SDK exception (AuthApiException, PostgrestException, StorageException)
        ↓  caught in core/services/*.dart or a repository
AppException  (NetworkException, AuthException, ServerException, ValidationException, StorageException, NotFoundException)
        ↓  Failure.fromException(e)
Failure  (sealed class: NetworkFailure, AuthFailure, ServerFailure, ValidationFailure, StorageFailure, NotFoundFailure)
        ↓  surfaced as AsyncError(failure) by a controller
AppErrorView(message: failure.message, onRetry: ...)
```

Widgets only ever pattern-match on `Failure` — they never see a raw `PostgrestException` or `AuthApiException`.

### 1.4 Routing

- **`go_router`**, configured entirely in `core/routing/app_router.dart`.
- Uses `StatefulShellRoute.indexedStack` so the 5 bottom-nav tabs (**Home / Resume / Add / Notify / Profile**) each keep their own navigation stack when switching tabs.
- `redirect` logic watches `authControllerProvider`: signed-out users are bounced to `/login`; signed-in users can't see `/login`.
- `GoRouterRefreshNotifier` bridges Riverpod's `AsyncValue<AppUser?>` into a `Listenable` so the router re-evaluates redirects the instant auth state changes (sign-in, sign-out, token refresh).
- Route paths/names are centralized in `route_names.dart` — screens navigate with `context.pushNamed(RouteNames.x)`, never a hardcoded string.

### 1.5 Theming

A **fully centralized design-token system** — no screen contains a raw `Color(0x...)` or magic-number `EdgeInsets`:

- `AppColors` — brand palette (teal gradient primary, navy secondary) + light/dark variants.
- `AppTypography` — the full text scale (`h1`…`caption`), one `fontFamily` to swap app-wide.
- `AppSpacing` / `AppRadius` / `AppShadows` — 4pt-grid spacing, corner radii, elevation presets.
- `AppTheme.lightTheme` / `AppTheme.darkTheme` — the only two `ThemeData` objects in the app, built from the tokens above and registered in `MaterialApp.router`.
- `AppThemeExtension` (a `ThemeExtension`) carries the handful of values that must actually *differ* between light/dark (e.g. success-tint backgrounds), accessed via `context.appTheme`.

Rebranding (new primary color, new font) means editing files in `core/theme/` only — zero screen-level changes.

### 1.6 Data layer (Supabase)

- One shared `SupabaseClient` exposed via `supabaseClientProvider`; nothing calls `Supabase.instance.client` directly.
- `AuthService` wraps Supabase Auth (email/password) **and** native `google_sign_in`, exchanging the Google ID token for a Supabase session via `signInWithIdToken`.
- `StorageService` handles resume PDF uploads to a Supabase Storage bucket, enforcing the 2MB/PDF-only rule *before* any network call.
- Assumed Postgres tables: `students`, `jobs`, `notifications`, `resumes`, `generated_resumes` (see [Setup & Configuration](#setup--configuration) — adjust to your real schema).

---

## 2. File Structure

```
lib/
├── app.dart                          # MaterialApp.router + theme + router wiring
├── main.dart                         # Entry point: Supabase.initialize + ProviderScope
│
├── core/
│   ├── constants/
│   │   ├── app_config.dart           # Env vars (--dart-define), Supabase keys, feature limits
│   │   ├── app_strings.dart          # All user-facing copy (i18n-ready seam)
│   │   └── app_assets.dart           # Centralized asset path registry
│   │
│   ├── errors/
│   │   ├── exceptions.dart           # AppException + subtypes (thrown by data layer)
│   │   └── failures.dart             # Failure sealed class (surfaced to UI)
│   │
│   ├── extensions/
│   │   ├── context_extensions.dart   # context.appTheme, context.showSnackBar, context.isTablet
│   │   ├── string_extensions.dart    # isValidEmail, isValidIndianPhone, initials, truncate
│   │   └── datetime_extensions.dart  # timeAgo, formattedDate
│   │
│   ├── network/
│   │   └── supabase_client_provider.dart   # Shared SupabaseClient + authStateChangesProvider
│   │
│   ├── routing/
│   │   ├── app_router.dart           # GoRouter config, shell route, auth redirect
│   │   └── route_names.dart          # RoutePaths / RouteNames constants
│   │
│   ├── services/
│   │   ├── auth_service.dart         # Supabase Auth + Google Sign-In
│   │   └── storage_service.dart      # Resume PDF upload/delete
│   │
│   ├── storage/
│   │   └── secure_storage.dart       # flutter_secure_storage wrapper (onboarding flag, last user id)
│   │
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_typography.dart
│   │   ├── app_spacing.dart
│   │   ├── app_radius.dart
│   │   ├── app_shadows.dart
│   │   └── app_theme.dart            # ThemeData factories + AppThemeExtension
│   │
│   ├── utils/
│   │   ├── validators.dart           # Form field validators (composable)
│   │   └── debouncer.dart            # Debounce rapid calls
│   │
│   └── widgets/                      # App-wide reusable components
│       ├── app_button.dart           # Primary/secondary/outline/text/google variants
│       ├── app_text_field.dart       # AppTextField + AppTextArea
│       ├── app_card.dart             # Neutral/success/muted bordered surface
│       ├── app_app_bar.dart          # Gradient app bar
│       ├── app_bottom_navigation.dart
│       ├── app_loader.dart           # AppLoader + AppInlineLoader
│       ├── app_error_view.dart       # Error state + retry
│       ├── app_empty_state.dart      # "Nothing here yet" state
│       ├── app_icon_button.dart      # Circular header icon button w/ badge
│       ├── app_chip.dart             # Status pill (Eligible / Not Eligible, etc.)
│       ├── app_avatar.dart           # Circular avatar w/ initials fallback
│       ├── app_dialog.dart           # Confirm / info dialogs
│       └── main_shell.dart           # StatefulShellRoute scaffold + bottom nav
│
└── features/
    ├── auth/
    │   ├── data/auth_repository.dart
    │   ├── domain/user_model.dart              # AppUser
    │   └── presentation/
    │       ├── controllers/auth_controller.dart
    │       └── pages/login_page.dart
    │
    ├── home/
    │   ├── data/job_repository.dart
    │   ├── domain/
    │   │   ├── job_model.dart                  # JobOpportunity, JobMode
    │   │   └── student_summary_model.dart      # StudentSummary (CGPA/year strip)
    │   └── presentation/
    │       ├── controllers/home_controller.dart
    │       ├── pages/home_page.dart
    │       └── widgets/
    │           ├── home_header.dart             # Gradient header + summary strip
    │           └── job_card.dart
    │
    ├── profile/
    │   ├── data/profile_repository.dart
    │   ├── domain/student_profile_model.dart    # StudentProfile
    │   └── presentation/
    │       ├── controllers/profile_controller.dart
    │       ├── pages/
    │       │   ├── profile_page.dart
    │       │   └── edit_profile_page.dart
    │       └── widgets/profile_field_card.dart
    │
    ├── notifications/
    │   ├── data/notification_repository.dart
    │   ├── domain/notification_model.dart       # AppNotification, NotificationType
    │   └── presentation/
    │       ├── controllers/notification_controller.dart
    │       ├── pages/notifications_page.dart
    │       └── widgets/notification_card.dart
    │
    └── resume/
        ├── data/resume_repository.dart
        ├── domain/resume_model.dart             # ResumeTemplate, UserResume, ResumeFormData
        └── presentation/
            ├── controllers/resume_controller.dart   # ResumeController + CreateResumeController
            ├── pages/
            │   ├── resume_page.dart              # Upload + template browser
            │   └── create_resume_page.dart        # Multi-field resume builder form
            └── widgets/resume_type_card.dart
```

**65 Dart files** across `core/` (34) and `features/` (31).

---

## 3. Features

### 3.1 Authentication (`features/auth`)
- Email/password sign-in with college-email validation (`Validators.collegeEmail`).
- **Google Sign-In**, native SDK → ID token exchanged for a Supabase session.
- Centralized `AuthController` drives both the Login screen *and* the router's redirect logic — one source of truth for "is anyone signed in."
- Sign-out available from the Profile screen behind a confirmation dialog.

### 3.2 Home (`features/home`)
- Gradient header with personalized greeting, notification bell (unread badge), and profile shortcut.
- **CGPA / Current Year** summary strip, loaded in parallel with the opportunity feed via `Future.wait`.
- **Active Opportunities** feed: each `JobCard` shows title, company, on/off-campus mode, and an **Eligible / Not Eligible** status chip.
- Pull-to-refresh, loading/error/empty states throughout.

### 3.3 Profile (`features/profile`)
- Read-only profile view: avatar, name, email, roll number, program, current year, CGPA, specialization, contact number — each rendered as a `ProfileFieldCard`.
- **Edit Profile** screen (separate route, pushed on the root navigator so it opens full-screen over the tab shell) for updating name, contact number, and specialization, with validation and optimistic-safe save via `AsyncNotifier`.
- Sign-out entry point with a destructive-style confirmation dialog.

### 3.4 Notifications (`features/notifications`)
- Reverse-chronological feed of `AppNotification`s (job openings, interview alerts, application updates, tips, general).
- Unread indicator dot per item; tapping a notification **optimistically marks it read** and reverts if the backend call fails.
- `unreadNotificationCountProvider` feeds the badge shown on the Home header's bell icon.

### 3.5 Resume (`features/resume`)
- **Upload Resume**: native file picker restricted to PDF, client-side 2MB size check before any network call, list of previously uploaded resumes.
- **Resume Templates**: three preset types (Technology, Finance & Consulting, Internship Programs), each with a "View Details" action that opens the create-resume form.
- **Create New Resume** form: resume-type dropdown, personal details (name/email/phone, pre-filled from the signed-in user), technical skills, work experience/projects, and per-role visibility checkboxes — all validated before submit.

### 3.6 Shared UI system (`core/widgets`)
Every screen above is built exclusively from the components in `core/widgets/` (`AppButton`, `AppTextField`, `AppCard`, `AppChip`, `AppAvatar`, `AppLoader`, `AppErrorView`, `AppEmptyState`, `AppDialog`, `AppBottomNavigation`, `MainShell`) — no screen hand-rolls its own button, input, or loading spinner.

---

## 4. Setup & Configuration

This repo currently contains **only `lib/`**. To run it, you'll additionally need:

1. **`pubspec.yaml`** declaring:
   `flutter_riverpod`, `go_router`, `supabase_flutter`, `google_sign_in`, `flutter_secure_storage`, `file_picker`.
2. **Environment variables** at build/run time (see `core/constants/app_config.dart`):
   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=xxxx \
     --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx
   ```
3. **Supabase schema** matching the tables referenced by the repositories:
   `students`, `jobs`, `notifications`, `resumes`, `generated_resumes`, plus a `resumes` Storage bucket. Column names are documented via each model's `fromJson`/`toJson` (e.g. `features/home/domain/job_model.dart`, `features/profile/domain/student_profile_model.dart`).
4. **Google Sign-In platform config** (`google-services.json` for Android, `GoogleService-Info.plist` for iOS) per the `google_sign_in` package docs.
5. Standard Flutter project scaffolding (`android/`, `ios/`, `assets/`, `test/`) — not generated here.

---

## 5. Extending the App

- **New screen**: add a `features/<name>/` folder with the same `data/domain/presentation` split, register its route in `core/routing/route_names.dart` + `app_router.dart`.
- **New reusable UI piece**: put it in `core/widgets/` if it's used by 2+ features, otherwise in that feature's `presentation/widgets/`.
- **Rebrand**: edit `core/theme/app_colors.dart` (colors) and/or `app_typography.dart` (fonts) — nothing else changes.
- **New backend error type**: add it to `core/errors/exceptions.dart`, map it in `Failure.fromException`, and it's automatically handled everywhere `AppErrorView` is used.
