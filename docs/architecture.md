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
    public/ (Set 5)          The public, no-login-required area, plus the
                             admin screens that manage its content (gallery,
                             banners, upcoming batches, advertisements,
                             announcements, institute profile - all image
                             fields are plain pasted URLs, since Storage
                             isn't enabled; see docs/database-architecture.md).
      data/                 GalleryItem, BannerItem, UpcomingBatch,
                             Advertisement, Announcement, InstituteProfile
                             models + one shared repositories file (each
                             repository is a trivial one-liner over
                             FirestoreRepository<T>).
      application/           PublicContentController - save/toggle-active
                             for all six content types (they share no real
                             business logic beyond "write it, stamp
                             timestamps, translate failures", so one class
                             covers all of them rather than six near-empty
                             ones).
      presentation/          PublicHomeScreen (hero, banners, upcoming
                             batches, gallery, announcements, about,
                             contact w/ call+WhatsApp, enquiry/callback
                             buttons - each section hides itself when
                             empty), AdPopupTrigger (the once-per-session ad
                             popup, see below), presentation/admin/ (one
                             list+dialog screen per content type).
    enquiries/ (Set 5)       Admission enquiries + callback requests from
                             visitors - no login required to submit, admin-
                             only to view/manage. No telecaller role exists;
                             admin handles all enquiry/callback management.
      data/                  Enquiry, CallbackRequest models (+ their status
                             enums) and repositories.
      application/           EnquiryController - submitEnquiry/
                             submitCallbackRequest (public, unauthenticated)
                             and updateStatus for each (admin-only).
      presentation/          EnquiriesScreen, CallbackRequestsScreen (admin,
                             with call/WhatsApp + a status dropdown),
                             SubmitEnquiryDialog, RequestCallbackDialog
                             (public, reachable from PublicHomeScreen).
    notifications/ (Set 5)   A shared, read-only notification feed for every
                             signed-in role.
      presentation/          NotificationsScreen - reads myNotificationsProvider
                             (core/services/notification_event.dart);
                             firestore.rules does the actual per-user
                             targeting, not the screen.
    reports/ (Set 6)         Admin export/report screens - each one builds
                             its own data (its own filters/columns/
                             sorting), then hands a plain `ExportDataset`
                             to the shared engine in `core/export/` for
                             actual PDF/Excel/DOCX rendering. See "The
                             export/report engine" below.
      data/                  ReportTemplate model + repository (saved
                             export configurations), StudentReportColumns
                             (the column catalogue shared by the student
                             list and fee-dues exports - see
                             docs/database-architecture.md).
      application/           ReportTemplateController (save/delete a
                             template).
      presentation/          ReportsHubScreen (nav to the three export
                             screens), StudentReportExportScreen (the one
                             implementation behind both StudentExportScreen
                             and FeeDuesExportScreen - they differ only in
                             title/defaults/an extra "dues only" filter,
                             not in how rows are built or rendered),
                             TestResultExportScreen (all three test-report
                             modes).
      presentation/widgets/  ColumnPicker, FormatPicker, OrientationPicker,
                             TemplateBar - shared controls every export
                             screen composes instead of reimplementing.
```

## The export/report engine (Set 6)

`lib/core/export/` is the one place PDF/Excel/DOCX rendering is
implemented - every export screen (student list, fee dues, test result,
in whichever of its three modes) builds its own `ExportDataset` (title,
optional subtitle, column headers, pre-formatted string rows, an
orientation hint) and hands it to `ExportService`; nothing downstream of
that point is module-specific.

```
data source + filters + selected columns + sorting   <- each export screen, on its own
        ↓
ExportDataset (title, columns, rows, orientation)     <- the shared "engine input" shape
        ↓
ExportService.export(dataset, format)                 <- the one shared facade
        ↓
PdfReportBuilder | ExcelReportBuilder | DocxReportBuilder   <- one renderer per format, used by every module
        ↓
Printing.layoutPdf (PDF - print/save preview) | Share.shareXFiles (Excel/DOCX)
```

- **`PdfReportBuilder`** (`pdf` + `printing` packages): A4, `pw.MultiPage`
  auto-paginates a `pw.TableHelper.fromTextArray` table across as many
  pages as the row count needs, with a repeating header row and a "Page X
  of Y" footer on every page - this is the "multiple pages, proper table
  wrapping, long names, page numbering" requirement, implemented once.
- **`ExcelReportBuilder`** (`excel` package): a single-sheet workbook -
  title, subtitle, a bold header row, then one row per data row.
- **`DocxReportBuilder`**: hand-rolled WordprocessingML, zipped with the
  `archive` package - not a template-filling package, because a fixed
  template can't express an admin-chosen, variable number of table
  columns. See docs/database-architecture.md for why this is safe/simple
  enough to hand-roll.
- **Orientation**: `ExportDataset.isLandscape` defaults to landscape past
  6 columns (`ReportOrientation.auto`), overridable per export via
  `OrientationPicker`. PDF and DOCX both honor it (Excel has no
  print-orientation concept the `excel` package exposes at this version,
  so it's ignored there).
- **Currency in exports**: exported currency cells read "Rs. 1234", not
  "₹1234" - the default PDF/DOCX/Excel fonts have no Rupee-sign glyph,
  and bundling a custom font for one symbol wasn't worth it. This only
  affects exported files; the in-app UI still shows ₹ everywhere else.
- **Delivery**: PDF goes through `Printing.layoutPdf`, which opens the
  platform's native print/save preview - deliberate, since the fee-dues
  report specifically is meant to be printed and handed to staff for
  manual calling, not just downloaded. Excel/DOCX go through
  `Share.shareXFiles` (a download on web, the share sheet on Android),
  since neither has anything print-preview-shaped to open.
- **Saved templates**: `reportTemplates/{templateId}` (admin-only,
  freely deletable - unlike every append-only collection elsewhere in
  this project, a saved template is a preference, not a record) stores
  `{name, module, config}`, where `config` is a free-form map each export
  screen defines and interprets for itself (selected columns, filters,
  sort, format, orientation - test-result mode/batch/subject/test
  selections are deliberately NOT saved, since those are one-off per
  report, not a reusable preference). `TemplateBar` is the one shared
  load/save/delete widget every export screen embeds.
- **What's shared vs. what isn't, deliberately**: `StudentReportColumns`
  (the column catalogue: name, father name, class, board, batch, session,
  mobiles, final fee, paid, due) and `StudentReportExportScreen` (the
  whole filter/column/sort/generate implementation) are shared by both
  the student-list export and the fee-dues export - they're the same
  underlying entity with different default filters. Test-result export
  is genuinely a different data shape (marks/tests/subjects, not student
  fields), so it has its own screen - but it reuses the same
  `ExportDataset`/`ExportService`/`FormatPicker`/`OrientationPicker` as
  everything else, and its ranking logic (`core/utils/ranking.dart`) and
  combined-score math (`core/utils/marks_combiner.dart`) are pure,
  independently unit-tested functions, not something reimplemented per
  test-report mode.

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

- Teacher/student **photos**, and every public-content image
  (gallery/banner/advertisement/upcoming-batch poster) - Storage isn't
  enabled on this project (see docs/firebase-setup.md), so as of Set 5
  every such field is a plain `imageUrl`/`posterUrl` string the admin
  pastes (external hosting - e.g. any image host URL). Every other
  admission/profile/content field is in place, so switching to real
  uploads later is an isolated addition, not a rework.
- Actual push notification *delivery* - `notifications` documents are
  written (see docs/database-architecture.md's "Notification event
  hooks") and, as of Set 5, read back by a shared `NotificationsScreen`
  per role, but nothing sends an FCM push yet - there are no Cloud
  Functions in this project to trigger one from. "Fee due/reminder"
  notifications specifically are also not implemented, since a
  *scheduled* reminder needs a cron-like trigger, which needs server-side
  compute this project deliberately doesn't have.
- Enforcing "teacher may only manage their *assigned* class/subject" at
  the rules level for homework/assignments/tests - see
  docs/database-architecture.md for why this is a documented scope
  decision, not an oversight.
- A telecaller role - enquiry/callback management is admin-only by
  explicit requirement (Set 5).
- A "grade" export column - the Set 6 spec explicitly says not to invent
  a grading system, and none is configured anywhere else in this project
  to reuse. Rank/total/percentage are implemented; grade is left for a
  later phase once an actual grading scale exists to compute from.
- A scheduled "fee due/reminder" notification - it would need a cron-like
  trigger, which needs server-side compute this project deliberately
  doesn't have (see "Why no Cloud Functions"). The fee-dues *export*
  (Set 6) is the export/print-and-call substitute for it.
- Any feature folder beyond `auth`, `admin`, `teacher`, `student`,
  `batches`, `attendance`, `homework`, `assignments`, `tests`, `public`,
  `enquiries`, `notifications`, `reports` - e.g. `fees` as its own
  module, settings, audit logs.
- Changing a role after account creation, or deleting an account/teacher/
  student/batch (admin deactivates via `active: false` instead).
- Editing or deleting a recorded payment, attendance heartbeat aside -
  attendance/testResults use a deterministic id so re-marking *corrects*
  the same record (not a delete+recreate); payments themselves stay
  append-only by design (see docs/database-architecture.md).
- Firebase App Check.

These are built phase-by-phase in later sets.
