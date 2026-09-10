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
    report_templates/ (Set 7)  The admin-configurable A4 report-letterhead
                             designer - a different thing from
                             `reports/data/report_template.dart` (Set 6's
                             saved export column/filter configs) despite
                             the similar name; see "Report layout
                             templates" below.
      data/                  ReportLayoutTemplate (+ ReportHeaderConfig/
                             ReportFooterConfig) model and repository.
                             `toBranding()` bakes a template into the
                             `core/export/report_branding.dart` shapes the
                             engine actually renders from.
      application/           ReportLayoutTemplateController (create/
                             update/delete).
      presentation/          ReportLayoutTemplatesScreen (list, admin CRUD
                             entry point), ReportTemplateDesignerScreen
                             (the A4 preview + header/footer form).
      presentation/widgets/  A4Preview, DraggableLogo (the one true
                             drag/resize interaction - see "Report layout
                             templates" below), ReportLayoutPicker (the
                             "which template" dropdown embedded in every
                             compatible export screen).
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

## Report layout templates (Set 7)

An admin-designed, reusable A4 letterhead - logo, institute name/tagline/
address/contact, and a footer (signature area/page number/date/contact) -
picked by name from any compatible export screen. This is a template
system layered on top of Set 6's engine, not a second one:

```
ReportTemplateDesignerScreen (A4Preview + form)
        ↓ admin saves
reportLayoutTemplates/{templateId}          <- ReportHeaderConfig/ReportFooterConfig
        ↓ .toBranding(), fetched fresh right before "Generate"
ReportBranding                               <- core/export/report_branding.dart
        ↓ ExportDataset.branding
PdfReportBuilder / ExcelReportBuilder / DocxReportBuilder   <- same Set 6 builders, branding-aware
```

- **Visual editing, kept simple**: the logo is the one element that's
  genuinely drag-to-move/drag-to-resize (`DraggableLogo`, reporting back
  fractions of the header area - see [`LogoPlacement`] in
  `core/export/report_branding.dart`). Every other header/footer element
  (institute name, tagline, address, contact, other header text, footer
  text, signature label, date, page number, footer contact) is a text
  field plus a show/hide switch - not draggable. This is the literal
  "keep the editor simple... do not build a full Canva-like design
  system" boundary: one free-form interaction, everything else is a
  form.
- **`A4Preview` mirrors `PdfReportBuilder`'s layout logic**, not just its
  data: logo-side text anchoring (text block sits on whichever half of
  the header the logo *isn't* on) and the same 3-column footer row
  (signature left, footer text center, date/contact/page-number right)
  are reimplemented in Flutter widgets so what the admin sees while
  dragging is what the generated PDF actually looks like - not an
  approximation.
- **Why an already-generated report doesn't change when its template is
  edited later**: every export screen fetches the chosen template fresh
  (`getById`, not a cached/watched value) and calls `.toBranding()`
  immediately before rendering, producing a plain, disconnected
  `ReportBranding` value object - there is no code path anywhere that
  re-reads a template to redraw a report after the fact. Combined with
  every export already being "generate once, hand over static bytes"
  (Set 6), this is structurally guaranteed, not something that needed
  extra versioning/snapshot machinery to build.
- **Rich header/footer/logo rendering is PDF-only.** Excel and DOCX get a
  lightweight text-based letterhead (institute name/tagline/address/
  contact as plain rows/paragraphs above the title) when a template is
  applied, not a visual replica - "A4 header/footer with a positioned
  logo" and printed page numbering are fundamentally PDF/print concepts;
  Excel has no page-orientation API in the installed `excel` package
  version to hook into either (same limitation noted in Set 6). This
  keeps every format "connected" to the one template system without
  pretending Excel/DOCX have a print layout the way a PDF page does.
- **What counts as a "compatible report"**: every export screen built in
  Set 6 (student list, fee dues, test result, in all three modes) got the
  `ReportLayoutPicker` dropdown - that's the literal integration point.
  An "attendance report" export (mentioned in the Set 7 spec's reuse
  list) was **not** built here - Set 6 never built an attendance export
  screen to begin with, and adding a new export module was out of scope
  for "build the template system and connect it to the existing engine".
  The engine/template system is generic enough that an attendance export
  added later would reuse both without changes.
- **Logo images are pasted URLs**, same as every other image field since
  Set 5 - Storage still isn't enabled (see docs/firebase-setup.md). No
  new decision here, just the established pattern applied again.

## Set 8: integration, security and production hardening

No new business features - this set verified and fixed cross-cutting
correctness/quality issues across Sets 1-7.

- **The Firestore query-shape bug** (the headline finding) - see
  docs/database-architecture.md's "Firestore query-shape requirement"
  section for the full explanation and every provider/rule it touched.
  In short: several `list` queries scanned a whole collection and
  filtered client-side, which Firestore only permits for a caller whose
  rule branch is role-only (admin) - it silently failed for the actual
  target user (a teacher's own attendance, a student's attendance/
  homework/assignments/tests/notifications/own-profile lookups, and the
  public site's content for anonymous visitors). Fixed by adding
  `FirestoreRepository.watchWhere()` and using it everywhere a rule's
  non-privileged branch depends on a document field.
- **Connectivity** (`core/services/connectivity_provider.dart`,
  `core/widgets/offline_banner.dart`): a slim banner shown app-wide
  whenever the device has no network interface at all (via
  `connectivity_plus`, not a Firestore-cache heuristic - `snapshot.metadata.isFromCache`
  is briefly true on every fresh load even while online, so it isn't a
  reliable signal on its own). Firestore's own offline persistence
  already queues writes and replays them, and refreshes reads,
  automatically on reconnect - this banner is purely informational, not
  a custom sync layer (deliberately not "an unnecessarily complicated
  offline architecture").
- **User-facing error messages** (`core/utils/error_formatting.dart`):
  `ErrorView` now runs its `message` through `friendlyErrorText()`
  before display, which rewrites a Firebase-style `[plugin/code] detail`
  tag anywhere in the text into plain language (falling back to a
  generic "Something went wrong" for an unrecognized code). This was a
  one-file fix for the ~40 screens that already did
  `ErrorView(message: 'Could not load X.\n$error')` - they never needed
  to change, since the raw exception is translated centrally rather than
  at each call site.
- **Phone number validation** (`Validators.phone` in
  `core/utils/validators.dart`): every phone/mobile field across the app
  (student, teacher, admission enquiry, callback request, institute
  contact phone) previously only checked "not empty" (or nothing at all
  for optional fields) - now format-checked (10-12 digits after
  stripping spaces/dashes/`+91`/leading `0`), client-side, before it
  ever reaches Firestore's own minimum-length rule check.
- **Dependency cleanup**: `firebase_storage` and `firebase_messaging`
  were declared but had zero real call sites anywhere in `lib/`
  (`firebase_storage` only backed one unused provider; `firebase_messaging`
  wasn't referenced at all) - removed, along with their transitive
  packages. `async` and `connectivity_plus` were added, each for a
  specific, documented reason above (not speculative).

## Admin configuration reference (Set 8)

Everything below is changeable by an admin from inside the running app -
no source change, redeploy, or developer involvement needed for normal
operation:

| Configurable via the app | Screen |
|---|---|
| Batches + their standard monthly/installment fee | Admin → Batches |
| Teachers (profile, class/subject assignments) | Admin → Teachers |
| Login accounts (create, deactivate, reset a stuck session) | Admin → Login accounts |
| Students (admission, fee/discount, batch) | Admin → Students |
| Gallery images | Admin → Gallery |
| Banners (+ optional display window) | Admin → Banners |
| Upcoming batch listings | Admin → Upcoming batches |
| Advertisements (+ popup, + active window) | Admin → Advertisements |
| Announcements | Admin → Announcements |
| Institute profile (name, tagline, about, contact, address) | Admin → Institute profile |
| Report/export letterhead: logo (position/size), header text, footer/signature/page-number/date | Admin → Report templates |
| Saved export column/filter presets | Any export screen's "Save as template" |
| Admission enquiries / callback requests (status only) | Admin → Enquiries / Callback requests |

**Two items from the original Set 1 plan were never built as their own
configurable entities, by design, not oversight**: "academic session"
and "subject" are free-text fields typed per student/homework/test
record, not a managed catalogue with its own admin screen (unlike
`batches`, which is a real collection). Building a dedicated CRUD module
for either would be a **new business feature**, out of scope for a
hardening phase - if this turns out to matter operationally (e.g.
sessions/subjects need to be constrained to a fixed list rather than
free text), that's its own future set, not a Set 8 fix.

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
  `enquiries`, `notifications`, `reports`, `report_templates` - e.g.
  `fees` as its own module, settings, audit logs.
- An attendance-report export screen - Set 6 never built one, and adding
  a new export module wasn't in scope for Set 7's own goal (the template
  system + connecting it to what already exists). See "Report layout
  templates" above.
- Changing a role after account creation, or deleting an account/teacher/
  student/batch (admin deactivates via `active: false` instead).
- Editing or deleting a recorded payment, attendance heartbeat aside -
  attendance/testResults use a deterministic id so re-marking *corrects*
  the same record (not a delete+recreate); payments themselves stay
  append-only by design (see docs/database-architecture.md).
- Firebase App Check.

These are built phase-by-phase in later sets.
