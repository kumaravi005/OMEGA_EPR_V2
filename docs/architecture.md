# Architecture

Omega Education Centre V2 is a Flutter app (Dart, Riverpod) backed by
Firebase (Auth, Firestore, Storage, Cloud Messaging, Crashlytics). No
Cloud Functions or other server-side compute is used anywhere — the
project stays on Firebase's free Spark plan; see "Why no Cloud Functions"
below for how account creation and single-device sessions are still kept
secure without one.

## Folder structure

```
lib/
  main.dart                 Entry point: Firebase init, runApp
  app.dart                  Root MaterialApp.router widget + the global
                             session-invalidation watchdog
  router.dart                go_router route table + auth/role/session
                             redirect logic. The one file allowed to import
                             across every feature (it's the composition
                             root) — core/ and features/*/ never do this.

  core/                     Cross-cutting, app-wide code. No business logic.
                             Never imports from features/.
    constants/              Compile-time constants (collection names, storage
                             paths, branding, the accountId->email scheme).
                             Never operational data.
    theme/                  Colors, typography, spacing, ThemeData.
    routing/                Route path constants only (app_routes.dart) -
                             the router itself lives in lib/router.dart.
    services/                Firebase SDK providers + thin service wrappers
                             (AuthService, CrashlyticsService).
    utils/                  Small stateless helpers (validators, logging).
    widgets/                Reusable UI: AppButton, AppCard, AppTextField,
                             LoadingView, ErrorView, EmptyView.

  data/                     Firestore access, independent of any one feature.
    models/                 Base contracts (FirestoreDocument) that concrete
                             feature models implement.
    repositories/           Generic FirestoreRepository<T> — CRUD + streams
                             built on top of a datasource.
    datasources/            Thin Firestore collection wrappers used by
                             repositories.

  features/                 One folder per business feature/module.
    auth/                   Login, session/single-device enforcement, the
                             UserAccount model + repository.
      data/                 UserAccount model, Firestore repository provider.
      application/          AuthController (login/logout/heartbeat),
                             DeviceIdService, the currentUserAccountProvider.
      presentation/         LoginScreen.
    admin/                  Admin account-management + navigation dashboard.
      application/          AdminAccountController (create login account via
                             a secondary FirebaseApp instance; reset session /
                             toggle active via direct rule-gated writes).
      presentation/         AdminDashboardScreen (nav to every admin section),
                             AdminAccountsScreen (login-account list),
                             CreateAccountScreen.
    teacher/                Teacher-as-a-managed-record (Set 3) + the
                             teacher's own app area (Set 2 placeholder,
                             real nav hub as of Set 4).
      data/                 TeacherProfile (+ ClassSubjectAssignment) model,
                             Firestore repository provider.
      application/          TeacherFormController (create/update a profile).
      presentation/         TeacherListScreen, TeacherFormScreen (one screen
                             handles both create and edit),
                             TeacherHomeScreen (nav hub: attendance,
                             homework, assignments, tests).
    student/                Student-as-a-managed-record (Set 3, including
                             fees/payments) + the student/parent's own app
                             area (Set 2 placeholder, real nav hub as of
                             Set 4).
      data/                 StudentProfile, Payment models, Firestore
                             repository providers (payments is a
                             per-student subcollection - see
                             docs/database-architecture.md).
      application/          StudentFormController (admit/update),
                             PaymentController (record a payment).
      presentation/         StudentListScreen, StudentFormScreen (create/edit,
                             batch fee auto-population), StudentProfileScreen
                             (fee summary, payment history, call/WhatsApp),
                             FeeDuesScreen, AddPaymentDialog,
                             StudentHomeScreen (nav hub: attendance,
                             homework, assignments, results).
    batches/                Batch catalogue (name + standard monthly/
                             installment fee) - referenced by student
                             admission, not a role's own app area.
      data/                 Batch model, Firestore repository provider.
      application/          BatchController (create/update/toggle active).
      presentation/         BatchListScreen (list + create/edit dialog).
    attendance/ (Set 4)     Student attendance (one record per batch/date,
                             never per subject) and teacher attendance
                             (admin-marked, teacher views own only).
      data/                 StudentAttendanceRecord, TeacherAttendanceRecord.
      application/          AttendanceController (mark/correct - both use
                             a deterministic doc id, see
                             docs/database-architecture.md).
      presentation/         MarkStudentAttendanceScreen,
                             MarkTeacherAttendanceScreen (both admin),
                             *AttendanceHistoryScreen (own view, teacher
                             and student each get one).
    homework/, assignments/ (Set 4)   Same shape as each other - a batch-
                             wide entry a teacher creates and tracks
                             completion/status on, a student reads.
      data/, application/, presentation/   Model+repository, Controller,
                             an adaptive *ListScreen (teacher: batch
                             picker + create; student: fixed to their own
                             batch, read-only) plus a create dialog.
      Student-only wrapper: `Student{Homework,Assignments}Screen` resolves
      the signed-in student's own batch, then delegates to the shared
      list screen with `fixedBatchId` set.
    tests/ (Set 4)          Offline test metadata + marks - no online exam
                             engine (see docs/database-architecture.md).
      data/                 TestDefinition, TestResult models/repositories.
      application/          TestController (create test, enter/validate
                             marks, publish result).
      presentation/         TestListScreen (teacher/admin: batch picker +
                             create), EnterMarksScreen (mark-entry grid +
                             publish), StudentResultsScreen (own results,
                             published tests only).
    public/                 presentation/PublicHomeScreen - the one public,
                             no-login-required screen for now.
```

Every feature folder above is populated with only what's actually been
built. `fees` as its own module is still folded into `features/student/`
(tightly coupled to the student record - see
docs/database-architecture.md); `notifications` has no feature folder of
its own yet either - see `core/services/notification_hook.dart` below.

## Why this shape

- **`core` vs `features`**: anything reusable across every role (theme,
  Firebase wrappers, generic widgets) lives in `core`. Anything specific to
  one part of the product (student management, fees, attendance) lives in
  its own folder under `features`.
- **`data` is feature-agnostic**: `FirestoreRepository<T>` and
  `FirestoreDataSource` know nothing about students or fees — they just
  turn a Firestore collection into typed CRUD + streams. Feature code
  supplies the type and the map ↔ model conversion. This is what keeps
  future feature repositories (`StudentRepository`, `FeeRepository`, ...)
  small and consistent instead of each reinventing Firestore boilerplate.
- **No code generation, no `freezed`/`riverpod_generator`**: for a ~15-user
  admin/teacher pool and ~200 students, the build-time cost and extra
  tooling of code generation isn't worth it. Plain Dart classes and plain
  `Provider`/`StreamProvider` keep the project approachable.
- **Shared without over-unifying**: teacher and student forms don't share
  a single mega-widget (their field sets differ too much - qualification
  and assignments vs. father's name, academics and fees - a forced-shared
  form would be a worse abstraction than two focused ones). What they do
  share: `Gender` (`data/models/gender.dart`), the reusable widgets in
  `core/widgets/`, and - the part that actually mattered to get right
  once - `AccountProvisioningService` (`core/services/`), so the
  secondary-`FirebaseApp` trick for account creation isn't reimplemented
  three times over (admin/teacher/student).

## State management

[flutter_riverpod] providers. Firebase SDK singletons are exposed as
providers in `core/services/firebase_providers.dart` so they can be
overridden in tests instead of being called as global singletons directly.

## Routing

`go_router`, wired up in `lib/router.dart`. Redirect logic reads the
current Firebase Auth user, the account document
(`currentUserAccountProvider`), and the local device id together to
decide where a request for any path actually lands:

- signed out + protected path -> `/login`
- signed in, valid, on the right device -> role's home area
- signed in but the *wrong* role area -> redirected to their own home
- account missing/inactive/session claimed elsewhere -> held in place
  while `app.dart`'s watchdog forces a clean sign-out with an explanation
  (see docs/database-architecture.md's "Single-device session" section)

## Why no Cloud Functions

The project stays on the free Spark plan - no Cloud Functions, no other
server-side compute. Firestore security rules alone are enough for
single-device session enforcement and all role-based authorization (see
docs/database-architecture.md). The one operation that's normally tricky
without a server - creating a new account without hijacking the admin's
own signed-in session - is solved client-side instead: account creation
uses a throwaway secondary `FirebaseApp` instance to call
`createUserWithEmailAndPassword` in isolation (see
`AdminAccountController.createAccount`), so the admin's primary session
is never touched. The very first admin account is created once, manually,
via the Firebase Console (see docs/firebase-setup.md) - there is no
sign-up screen anywhere in the app, and `firestore.rules` denies `create`
on `users` to everyone except an already-existing admin.

## What's deliberately not here yet

- Teacher/student **photos** - Storage isn't enabled on this project (see
  docs/firebase-setup.md); every other admission/profile field is in
  place, so this is an isolated addition later, not a rework.
- The public website/content system (gallery, announcements, enquiries,
  admission enquiries, callback requests).
- Actual push notification *delivery* - `notifications` documents are
  written (see docs/database-architecture.md's "Notification event
  hooks"), but nothing sends an FCM push yet; there are no Cloud
  Functions in this project to trigger one from, and no in-app
  notifications feed reads the collection yet either.
- Enforcing "teacher may only manage their *assigned* class/subject" at
  the rules level for homework/assignments/tests - see
  docs/database-architecture.md for why this is a documented scope
  decision, not an oversight.
- Any feature folder beyond `auth`, `admin`, `teacher`, `student`,
  `batches`, `attendance`, `homework`, `assignments`, `tests`, `public` -
  e.g. `fees`/`notifications` as their own modules, enquiries, reports,
  exports, settings.
- Changing a role after account creation, or deleting an account/teacher/
  student/batch (admin deactivates via `active: false` instead).
- Editing or deleting a recorded payment, attendance heartbeat aside -
  attendance/testResults use a deterministic id so re-marking *corrects*
  the same record (not a delete+recreate); payments themselves stay
  append-only by design (see docs/database-architecture.md).
- Firebase App Check.

These are built phase-by-phase in later sets.
