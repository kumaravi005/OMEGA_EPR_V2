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
    teacher/                Teacher-as-a-managed-record (Set 3, subjects
                             wired to the Set 9 subject master and
                             active/inactive status added in Set 12) +
                             the teacher's own app area (Set 2
                             placeholder, real nav hub as of Set 4).
      data/                 TeacherProfile model (+ dedupeSubjectIds, a
                             pure helper so "no duplicate subject" holds
                             regardless of caller), Firestore repository
                             provider (+ activeTeachersProvider, used by
                             Set 22's assignment form to pick a teacher).
      application/          TeacherFormController (create/update a
                             profile, setActive).
      presentation/         TeacherListScreen (search + subject/status
                             filters), TeacherFormScreen (one screen
                             handles both create and edit; subjects are
                             picked from the Set 9 master via a
                             checkbox-list dialog, never typed),
                             TeacherProfileScreen (Teacher information /
                             Professional information / Contact
                             information / Subjects taught / Account
                             information, call/WhatsApp,
                             activate/deactivate), TeacherHomeScreen (nav
                             hub: my assignments (Set 22), attendance,
                             homework, assignments, tests).
    student/                Student-as-a-managed-record (Set 3, admission
                             wired to Set 9/10 master data in Set 11) +
                             the student/parent's own app area (Set 2
                             placeholder, real nav hub as of Set 4).
      data/                 StudentProfile - stable identity + the
                             CURRENT admission's fee/academic snapshot;
                             StudentAdmission - one immutable-once-
                             created record per admission event, at
                             `students/{uid}/admissions/{admissionId}`
                             (initial admission, or a later batch
                             transfer - see "Student admission (Set 11)"
                             below); Payment model - LEGACY as of Set 19
                             (see `fees/` below), kept only so pre-Set-19
                             payments recorded at
                             `students/{uid}/payments` stay visible.
                             Firestore repository providers (admissions/
                             payments are both per-student subcollections
                             - see docs/database-architecture.md).
      application/          StudentFormController (admit/update/
                             changeBatch/setActive - see below). The old
                             PaymentController (recorded a payment at the
                             legacy subcollection) was removed in Set 19 -
                             see `fees/application/fee_payment_controller.dart`.
      presentation/         StudentListScreen (search + session/class/
                             batch/status filters), StudentFormScreen
                             (new admission: full form incl. session ->
                             class -> batch -> fee; edit: identity/
                             contact/board only - academic/fee fields
                             are read-only, changed only via "Change
                             batch"), ChangeBatchDialog (records a new
                             admission, preserves the superseded one),
                             InstallmentEntryDialog (shared by both),
                             StudentProfileScreen (Student information /
                             Parent & contact / Academic information /
                             Account information, call/WhatsApp,
                             activate/deactivate, and a link into
                             `fees/`'s StudentFeeDetailsScreen - the old
                             inline fee-agreement card and "Record
                             payment" button moved there in Set 19),
                             StudentFeeScreen (student/parent's own fee
                             summary/installments/history - rewritten in
                             Set 19 to read the new ledger, see `fees/`
                             below), StudentHomeScreen (nav hub:
                             attendance, homework, assignments, results,
                             fees).
    fees/ (Set 19)          Fee Collection & Payment Management - admin
                             records payments against a student's
                             EXISTING Set 11 `StudentAdmission` fee
                             agreement (no second fee-agreement system;
                             see docs/database-architecture.md's "Fee
                             Collection & Payment Management (Set 19)").
      data/                 FeePayment model (a top-level `feePayments`
                             ledger, not another `students/{uid}`
                             subcollection - see the docs section above
                             for why) + repository providers;
                             fee_calculator.dart - pure functions
                             (totalActiveFeePaymentAmount,
                             combinedTotalPaid/combinedBalanceDue -
                             combining the new ledger with any legacy
                             history, computeInstallmentRows,
                             computeFeeStatus), the same reusable-
                             calculation-engine pattern as
                             `result_calculator.dart`/`attendance_stats.dart`;
                             fee_summary.dart - `allStudentFeeSummariesProvider`,
                             the admin Fee Management list's per-student
                             rollup.
      application/          FeePaymentController (recordPayment -
                             validates amount/admission/outstanding
                             balance BEFORE an admin check, atomic
                             payment-number generation via
                             SequenceService; reversePayment - a narrow
                             partial update, never a delete or amount
                             edit).
      presentation/         FeeManagementScreen (admin "Fees": search +
                             class/batch/session/board/status filters),
                             StudentFeeDetailsScreen (admin: academic
                             info / current fee agreement / installment
                             schedule / payment summary / history +
                             Record/Reverse actions), RecordPaymentDialog
                             (amount -> date -> mode -> reference ->
                             remark -> optional installment, with a live
                             Current Fee/Total Paid/Due/This Payment/
                             Remaining Due review before confirming),
                             ReversePaymentDialog (reason required).
    batches/ (Set 3, extended Set 10)   Batch catalogue - each batch
                             belongs to exactly one academic session and
                             class (Set 9 master data), optionally a
                             board, and carries its own standard monthly/
                             installment fee - referenced by student
                             admission, not a role's own app area.
      data/                 Batch model + repository (+
                             activeBatchesForClassProvider and
                             batchesForSessionAndClass, the "Session ->
                             Class -> matching batches" lookups Student
                             Admission (Set 11) uses). InstallmentScheduleItem -
                             one row of a student's installment schedule,
                             embedded in `StudentAdmission.installments`
                             (see docs/database-architecture.md's
                             "Student admission (Set 11)").
      application/          BatchController (create/update/toggle active).
      presentation/         BatchListScreen (search + session/class/status
                             filters), BatchFormDialog (create/edit,
                             including fee configuration).
    teacher_assignments/ (Set 22)   The actual teacher -> class/batch/
                             subject teaching assignment - distinct from
                             `TeacherProfile.subjectIds` (capability only).
                             See "Teacher assignments (Set 22)" below.
      data/                 TeacherAssignment model (+ idFor, the
                             deterministic-id duplicate-prevention
                             scheme) and repository (+
                             allTeacherAssignmentsProvider,
                             ownTeacherAssignmentsProvider,
                             assignmentsForTeacherProvider,
                             assignmentsForBatchProvider,
                             assignmentsForSubjectProvider,
                             assignmentsMatching, isDuplicateAssignment,
                             subjectOptionsForAssignment).
      application/          TeacherAssignmentController
                             (createAssignment/setActive).
      presentation/         TeacherAssignmentsScreen (admin: search +
                             teacher/session/class/batch/subject/status
                             filters, Add Assignment, Activate/
                             Deactivate), TeacherAssignmentFormDialog
                             (Teacher -> Session -> Class -> Batch ->
                             Subject cascade), MyAssignmentsScreen
                             (teacher's own read-only assignment list).
    attendance/ (Set 4, extended Set 13, teacher-scoped Set 23)   Student
                             attendance (one record per batch/date, never
                             per subject) and teacher attendance
                             (admin-marked, teacher views own only).
                             Marking cascades Session -> Class -> (matching
                             active batches) for admin; a signed-in
                             teacher instead picks directly from their own
                             active `TeacherAssignment` batch scopes,
                             deduplicated by batch since attendance has no
                             subject (Set 23 - see "Teacher-scoped
                             academic operations (Set 23)" below for why
                             this one module's write rule is a documented,
                             narrower-than-usual exception). Admin gets a
                             history/summary view for both, on top of each
                             role's own view.
      data/                 StudentAttendanceRecord (+ an
                             academicSessionId/classId snapshot of the
                             batch at marking time),
                             TeacherAttendanceRecord - both split the old
                             single `markedBy` into createdBy/updatedBy.
                             AttendanceStats/computeAttendanceStats - the
                             one shared present/absent/percentage
                             calculation every history/summary view uses,
                             always computed on demand, never a stored
                             counter.
      application/          AttendanceController (mark/correct - both use
                             a deterministic doc id, see
                             docs/database-architecture.md;
                             markTeacherAttendanceBulk saves a whole
                             day's staff in one WriteBatch commit instead
                             of one write per teacher).
      presentation/         AttendanceHubScreen (admin's entry point),
                             MarkStudentAttendanceScreen (admin: Session ->
                             Class -> Batch -> Date -> student list;
                             teacher: one assignment-batch dropdown ->
                             Date -> student list - Set 23, same screen,
                             role-branched, not a second implementation),
                             MarkTeacherAttendanceScreen (Date -> teacher
                             list, staged + one Save action, admin),
                             Student/TeacherAttendanceReportScreen (admin
                             history: filters + a date range, per-
                             student/teacher present/absent/percentage;
                             Set 20 added a PDF/Excel/DOCX export action
                             to each, reusing the same on-screen rows -
                             no separate attendance-report export screen),
                             *AttendanceHistoryScreen (own view, teacher
                             and student each get one, both now show a
                             percentage).
    academic_work/ (Set 16, replacing Set 4's separate homework/ and
                             assignments/ folders)   Homework and
                             assignments unified into one reusable model
                             with a `type` field - "do not create two
                             completely duplicated database structures"
                             (Set 16 spec). Cascades Academic Session ->
                             Class -> (matching active batches) ->
                             Subject (only what the selected class
                             offers), same pattern as Attendance/Tests.
                             Admin-only to create/edit/publish/close -
                             there is still no Teacher -> Batch
                             assignment module (Set 12's scope
                             boundary), so teacher creation stays
                             disabled rather than inventing an
                             unsupported authorization scheme (see
                             docs/database-architecture.md).
      data/                 AcademicWork model (+ `isOverdue(now)`,
                             computed on demand, never stored) and
                             repository providers.
      application/          AcademicWorkController (create, edit,
                             setStatus - draft/published/closed, freely
                             reversible either direction).
      presentation/         AcademicWorkListScreen (admin/teacher:
                             search + type/session/class/batch/subject/
                             status filters, teacher's subject filter
                             defaults to their own `TeacherProfile.
                             subjectIds`; the "New" action shows for
                             admin, or a teacher with an active
                             assignment - Set 23), CreateAcademicWorkDialog
                             (admin: the full cascade; teacher: one
                             dropdown of their own active `TeacherAssignment`s,
                             which fully determines session/class/batch/
                             subject at once - Set 23), AcademicWorkDetailsScreen
                             (shared by every role - edit/status controls
                             show for admin, or a teacher whose active
                             assignment matches the item's scope - Set 23;
                             everyone else sees the same layout read-only),
                             StudentAcademicWorkScreen (own batch's
                             published/closed work only, All/Homework/
                             Assignments and Active/Closed filters).
    tests/ (Set 4, extended Set 14, teacher-scoped Set 23)   Offline test
                             metadata + marks - no online exam engine (see
                             docs/database-architecture.md). A test
                             cascades Academic Session -> Class ->
                             (matching active batches) -> Subject (only
                             what the selected class actually offers,
                             per Set 9's `SchoolClass.subjectIds`) for
                             admin; a teacher instead picks one of their
                             own active `TeacherAssignment`s (Set 23,
                             same pattern as academicWork above) -
                             creating/publishing/entering marks is no
                             longer admin-only, now gated by assignment
                             match instead (see "Teacher-scoped academic
                             operations (Set 23)" below); a teacher with
                             no matching assignment for a given test still
                             gets read-only access, same as before.
      data/                 TestDefinition (+ an academicSessionId/
                             classId/subjectId snapshot of the batch/
                             subject at creation time, and active/
                             inactive status reusing the Batch/Teacher/
                             Student convention), TestResult (+ an
                             `isAbsent` flag so "not attempted" is never
                             confused with a genuine zero) models/
                             repositories.
      application/          TestController (create test, saveMarksBulk -
                             the whole marks sheet in one WriteBatch
                             commit, publish result, setActive -
                             deactivate/restore a test without touching
                             its marks).
      presentation/         TestListScreen (search + session/class/
                             batch/subject/status filters; "New test"
                             shows for admin or an assignment-holding
                             teacher - Set 23), CreateTestDialog (admin:
                             the full cascade; teacher: one assignment
                             dropdown - Set 23), TestDetailsScreen (test/
                             academic/marks-completion information, Enter
                             or View Marks depending on whether the caller
                             can manage this test - admin, or a teacher
                             whose active assignment matches its scope),
                             EnterMarksScreen (bulk marks-entry grid with
                             an Absent toggle per student, one Save action,
                             editable under that same admin-or-assignment-
                             match condition), StudentResultsScreen (own
                             results, published tests only, unchanged).
    results/ (Set 15)       Results & Ranking - a read-only calculation
                             layer over Set 14's `tests`/`testResults`,
                             never a second marks database (nothing here
                             is persisted; every screen re-derives its
                             table from the same Test/Marks records on
                             each load). Admin-only - not exposed to
                             teacher or student routes.
      data/                 result_calculator.dart: pure functions
                             (`computeSubjectResults`,
                             `computeCombinedResults`) and value types
                             (`SubjectCell`/`CellStatus`, `ResultStatus`,
                             `SubjectResultRow`, `CombinedResultRow`) -
                             no Firestore calls, no UI, fully unit
                             tested. Ranking itself lives in the shared
                             `core/utils/ranking.dart`
                             (`rankByPercentage`, null-aware on top of
                             the existing `competitionRanks`), reused
                             as-is by the Set 6 test-result export
                             screen rather than duplicated.
      presentation/         ResultsHubScreen, TestResultScreen (Session
                             -> Class -> Batch -> Subject -> Test; serves
                             both the hub's "Subject-wise Result" and
                             "Test Result" entries, since a Set 14 test
                             always belongs to exactly one subject),
                             CombinedResultScreen (Session -> Class ->
                             Batch, then check which subjects to combine
                             and pick each one's own test - never a
                             fabricated shared test id).
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
      presentation/          PublicHomeScreen (hero incl. logo, banners,
                             upcoming batches, gallery, announcements,
                             public notices (Set 18 - a curated `notices`
                             subset, see below), about, contact w/
                             call+WhatsApp+secondary phone+website,
                             enquiry/callback buttons - each section hides
                             itself when empty), AdPopupTrigger (the
                             once-per-session ad popup, see below),
                             presentation/admin/ (one list+dialog screen
                             per content type). Set 18 added no new public
                             batch-visibility mechanism - `upcomingBatches`
                             already solved that in Set 5 (see docs/
                             database-architecture.md's "Public batch
                             visibility (Set 18)").
    enquiries/ (Set 5, extended Set 18) Visitor enquiries (admission +
                             callback, one collection with an `enquiryType`
                             field - Set 18 section 15) from unauthenticated
                             visitors, admin-managed afterward. No
                             telecaller role exists; admin handles all
                             enquiry/callback management directly.
      data/                  Enquiry (+ `EnquiryType`, `classId`/`boardId`
                             referencing Set 9 master data, `boardDisplay`),
                             CallbackRequest (Set 5, now legacy-only - see
                             below) models and repositories.
      application/           EnquiryController - submitEnquiry (admission,
                             requires class/board), submitCallbackRequest
                             (callback - writes into the SAME `enquiries`
                             collection now, not `callbackRequests`), plus
                             length/phone-format validation and
                             updateStatus/updateCallbackStatus (admin-only).
      presentation/          EnquiriesScreen (admin: search by name/phone +
                             type/class/board/status filters, Set 18),
                             EnquiryDetailsScreen (Set 18: visitor info +
                             call buttons + status dropdown),
                             CallbackRequestsScreen ("(history)" - Set 5,
                             pre-Set-18 requests only, nothing writes here
                             anymore), SubmitEnquiryDialog (now with
                             Class/Board pickers), RequestCallbackDialog
                             (both public, reachable from PublicHomeScreen).
    notifications/ (Set 5)   A shared, read-only notification feed for every
                             signed-in role.
      presentation/          NotificationsScreen - reads myNotificationsProvider
                             (core/services/notification_event.dart);
                             firestore.rules does the actual per-user
                             targeting, not the screen.
    notices/ (Set 17, extended Set 18) Admin-authored, targeted,
                             published/closed Notices - NOT the same
                             feature as `notifications/` above (that's the
                             Set 4/5 auto-generated event trail; this is
                             admin-created content with a real lifecycle
                             and per-user read state). See docs/database-
                             architecture.md's "Notices (Set 17)" and
                             "Public notices (Set 18)" sections for the
                             full targeting/security design.
      data/                  Notice model (+ `targetKey`, the single
                             derived field every visibility check keys
                             off; `isExpired(now)`, computed on demand,
                             never stored; `isPublic` - Set 18, an admin-
                             only public-site visibility switch, entirely
                             independent of `targetKey`), NoticeReadState
                             (`users/{uid}/noticeReadStates/{noticeId}` -
                             absence means unread) + repository providers
                             (incl. `publicNoticesProvider` - Set 18,
                             unauthenticated-safe).
      application/           NoticeController (create, edit - draft only,
                             publish, close - a one-way Draft -> Published
                             -> Closed lifecycle, unlike AcademicWork's
                             freely-reversible status; setPublicVisibility
                             - Set 18, reachable at any status).
      presentation/          NoticesListScreen (admin: search + type/
                             audience/status filters), CreateNoticeDialog
                             (now with a "Show on public website" switch),
                             NoticeDetailsScreen (shared by every role,
                             AND an anonymous public visitor for a public
                             notice - the Targeting card is hidden unless
                             signed in; admin gets edit/publish/close +
                             the public-visibility switch), MyNoticesScreen
                             (teacher/student/parent's own inbox - a
                             parent sees exactly what the associated
                             student account sees, since this project has
                             no separate parent login), PublicNoticeDialog
                             (Set 18 - the public-site read view, title/
                             type/message/date only).
    reports/ (Set 6, extended Set 20)   Admin export/report screens - each
                             one builds its own data (its own filters/
                             columns/sorting), then hands a plain
                             `ExportDataset` to the shared engine in
                             `core/export/` for actual PDF/Excel/DOCX
                             rendering. See "The export/report engine"
                             and "Reports & Exports, extended (Set 20)"
                             below.
      data/                  ReportTemplate model + repository (saved
                             export configurations - `ReportModule` Set
                             20 addition: `paymentReport`),
                             StudentReportColumns (Student Data Export's
                             column catalogue - 5 columns added in Set
                             20), FeeReportColumns (Set 20 - Fee Due
                             Report / staff contact list, built on Set
                             19's `StudentFeeSummary`), PaymentReportColumns
                             (Set 20 - built on Set 19's `FeePayment`).
      application/           ReportTemplateController (save/delete a
                             template).
      presentation/          ReportsHubScreen (Set 20: categorized -
                             Students/Attendance/Tests & Results/Fees,
                             not a flat list), StudentExportScreen +
                             StudentReportExportScreen (Student Data
                             Export only, as of Set 20 - see below),
                             FeeDueReportScreen (Set 20, new - replaces
                             the old FeeDuesExportScreen, which reused
                             StudentReportExportScreen), PaymentReportScreen
                             (Set 20, new), TestResultExportScreen (all
                             three test-report modes, refactored in Set
                             20 to call `computeSubjectResults`/
                             `computeCombinedResults` directly instead of
                             a separate ad-hoc calculation).
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
    academics/ (Set 9)       Institute/academic master data, centrally
                             configured by admin instead of hard-coded or
                             free-text per module - see "Admin
                             configuration and academic master data
                             (Set 9)" below.
      data/                  AcademicSession, SchoolClass, Board, Subject
                             models + one shared repositories file (same
                             "each repository is a trivial one-liner"
                             reasoning as `public_content_repositories.dart`).
      application/           AcademicConfigController - save/activate/
                             deactivate for all four master-data types,
                             plus the one-time idempotent `seedDefaults()`
                             action (Class 5-12, CBSE/BSEB/Others, the
                             standard subject list).
      presentation/          AcademicConfigHubScreen (nav to the four
                             sections + the "load defaults" action),
                             AcademicSessionsScreen, ClassesScreen (also
                             owns the class-subject picker), BoardsScreen,
                             SubjectsScreen.
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
  and `StudentReportExportScreen` (the whole filter/column/sort/generate
  implementation) power the general Student Data Export. Test-result
  export is genuinely a different data shape (marks/tests/subjects, not
  student fields), so it has its own screen - but it reuses the same
  `ExportDataset`/`ExportService`/`FormatPicker`/`OrientationPicker` as
  everything else, and (as of Set 20 - see "Reports & Exports, extended
  (Set 20)" below) calls Set 15's `computeSubjectResults`/
  `computeCombinedResults` directly for its ranking/percentage/absent-
  vs-incomplete logic, rather than a separate, less rigorous calculation
  of its own. Fee dues (now "Fee Due Report") and payments each gained
  their own Set 20 screen instead of being force-fit into the student
  export's shape - see that section for why.

Every feature folder above is populated with only what's actually been
built. `fees` as its own module is still folded into `features/student/`
(tightly coupled to the student record - see
docs/database-architecture.md). `notifications/` (Set 5, the auto-
generated event trail) and `notices/` (Set 17, admin-authored) are
deliberately two separate feature folders/collections, not one - see
`notices/`'s own entry above and docs/database-architecture.md's
"Notices (Set 17)" section for why they were kept apart instead of
merged or renamed.

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
  added later would reuse both without changes - which is exactly what
  Set 20 did (see "Reports & Exports, extended (Set 20)" below).
- **Logo images are pasted URLs**, same as every other image field since
  Set 5 - Storage still isn't enabled (see docs/firebase-setup.md). No
  new decision here, just the established pattern applied again.

## Report layout templates, completed (Set 21)

Set 21's brief was to inspect the Set 7 designer/template system before
changing anything, and implement only genuine gaps against a 25-point
spec - it explicitly forbade a second designer, a duplicate template
model/collection, or rewriting anything from Set 20. Almost everything
the spec asked for turned out to already exist (configurable A4
orientation via the export engine's own width-driven auto-landscape,
fraction-based logo positioning that already works unmodified in both
orientations, template/report separation, admin-only Firestore rules,
preview/PDF consistency, deactivate-free simple CRUD lifecycle). Three
real gaps were found and closed:

- **Header gained Secondary Phone and Website fields**
  (`ReportHeaderConfig.secondaryPhone`/`.website`, each with its own
  `show*` flag, same pattern as the pre-existing `contact` field). These
  render in both `A4Preview` and `PdfReportBuilder` as additional text
  lines between "Primary phone / contact" (the old `contact` field,
  relabeled only - not renamed at the data level, since renaming its
  Firestore key would be a breaking change to every saved template for a
  label-only difference) and "Other header text". A pre-Set-21 saved
  template has neither field in Firestore; `fromMap` defaults both to
  hidden/empty, so an existing template's rendered output is unchanged
  until an admin explicitly opts in. No Firestore rules change was
  needed - `newReportLayoutTemplateIsValid()` only validates `header`/
  `footer` as opaque maps at the top level, never their nested key
  shape, so a new nested field is automatically permitted.
- **"Use institute profile" autofill** (a button next to the designer's
  Header section title): a one-time copy of `InstituteProfile`'s name/
  logo/tagline/address/contact/secondary phone/website (Set 9) into the
  template's text fields - never a live binding. This matches the same
  "resolve once, don't re-read later" philosophy `ReportBranding` itself
  is built on (see below); the admin can freely edit or hide anything
  afterward, and tapping the button again just re-copies the profile's
  current values. Only fields `InstituteProfile` actually has are used -
  no field was invented on either model for this.
- **Attendance reports gained template support**
  (`StudentAttendanceReportScreen`/`TeacherAttendanceReportScreen`, the
  one export pair Set 20 built without any `ReportLayoutPicker`
  integration at all - see "Reports & Exports, extended (Set 20)"
  above). Each gained a `ReportLayoutPicker` in its existing filter
  panel and now fetches the chosen template fresh
  (`reportLayoutTemplateRepositoryProvider.getById`) and bakes it via
  `.toBranding()` immediately before building its `ExportDataset`,
  exactly like every other Set 20 export screen - no new column-picker/
  format-picker/orientation-picker was added, since that machinery was a
  deliberate Set 20 omission (a fixed, narrow column shape), not a gap.

No orientation field was added to the stored template: logo/element
positions are already stored as 0..1 fractions of the header area (see
[`LogoPlacement`]), which are resolution- and orientation-independent -
one saved template already renders correctly in both portrait and
landscape without a stored orientation, so "store orientation if the
architecture supports it" resolved to "no change needed." No report
title field was added either - `ExportDataset.title`/`.subtitle` remain
report-specific, set by each report screen, entirely separate from the
template's header/footer config, per the spec's explicit "the template
controls presentation, not report data" boundary.

## Reports & Exports, extended (Set 20)

Set 20's brief was explicit: inspect what already exists before building
anything, and it turned out most of "Reports & Exports" already existed
(Sets 6-7's engine, hub, student/fee-dues/test-result export screens,
report-layout templates) - so this set is almost entirely an
EXTENSION/reorganization, not a new module, plus one real bug fix.

- **The Reports Hub is now categorized** (`ReportsHubScreen`, section 1:
  "organize into logical categories" - Students/Attendance/Tests &
  Results/Fees) instead of a flat three-tile list. Every tile still
  points at either an existing screen or a genuinely new one below - no
  category is a placeholder for something unbuilt.
- **Student Data Export gained its missing filters** (section 2's
  "required filters" list): `StudentReportExportScreen` had only a
  free-text "session contains" field and a batch dropdown; Class, Board,
  Active-only, and a name/account-id search were simply missing. Added
  in place (the screen already existed and already had the column
  picker/format/orientation/template machinery - this is section 28's
  "reuse it, refactor it, avoid maintaining two competing
  implementations" applied literally). The session filter was also
  upgraded from free-text-contains to a proper dropdown keyed by
  `academicSessionId`, matching every session filter built since Set 18.
  Five columns section 2 asks for and the catalogue didn't yet have
  (`admissionNumber`, `address`, `dateOfBirth`, `gender`, `standardFee`)
  were added to `StudentReportColumns` - nothing invented beyond what
  `StudentProfile` already has (no "Mother's Name" column - that field
  doesn't exist on `StudentProfile`, and section 2 says "only show
  columns that actually exist").
- **A REAL bug in the existing Test Result export was found and fixed**
  (sections 7-8, 11, 19, 28): `TestResultExportScreen`'s subject-wise and
  multi-subject modes called `combineMarks` (Set 6, pre-dating Set 15's
  result engine) directly on each student's raw marks list, with no
  "was this student absent/not-yet-marked" gate at all - since an
  absent result's `obtainedMarks` and a simply-missing result both read
  as `null` there, every student got a computed percentage AND a rank
  regardless of whether they were absent from one test or never marked
  in the first place. This silently violated the exact rule Set 15 was
  built to enforce ("absent is not zero, incomplete never gets a
  misleading rank"). Fixed by refactoring all three modes to call
  `computeSubjectResults`/`computeCombinedResults`
  (`features/results/data/result_calculator.dart`) directly - the same
  engine `TestResultScreen`/`CombinedResultScreen` use on-screen - so
  the export can never again drift out of sync with what "absent" and
  "incomplete" mean elsewhere in the app. `core/utils/marks_combiner.dart`
  is still used (internally, by `computeCombinedResults` itself), just
  no longer called directly by the export screen.
- **Fee Due Report is a new, separate screen** (`FeeDueReportScreen`,
  sections 4-5), built directly on Set 19's `allStudentFeeSummariesProvider`
  (never a new fee formula) rather than retrofitted into
  `StudentReportExportScreen` - that screen has no concept of
  installment-aware Overdue status, and forcing it to grow one for a
  single report would have been a worse fit than a small, purpose-built
  screen reusing the same column-picker/format/orientation/template
  widgets. One screen, not two: section 5's "telecaller/staff print
  report" is the exact same report with a different column selection
  (two one-tap presets - `defaultFeeDueKeys`/`defaultStaffContactKeys` -
  are offered, but the full `ColumnPicker` still applies), not a second
  competing implementation.
- **Payment Report is new** (`PaymentReportScreen`, section 6) -
  necessarily so, since Set 19's `feePayments` postdates Set 6's export
  work entirely. Filters and columns read directly off `FeePayment`
  (session/class/batch id fields are already snapshotted on the payment
  itself, so no student join is needed for filtering - only for
  resolving display names). Reversed payments are never filtered out by
  default - "reversed payments must remain visible with their status"
  (section 6) is the default, with an optional Active/Reversed toggle
  for when admin wants only one or the other.
- **Attendance reports gained export, without a new screen** (section
  20) - `StudentAttendanceReportScreen`/`TeacherAttendanceReportScreen`
  (Set 13) already computed everything needed via `computeAttendanceStats`;
  each gained a small AppBar export action that builds an `ExportDataset`
  from the exact rows already on screen (cached from the same `build()`
  that renders them, not recomputed) and hands it to `ExportService`.
  This is deliberately NOT a new export screen with its own filter UI -
  the existing screens' filters are reused as-is, avoiding a second,
  parallel attendance-report implementation. These two did not get the
  column-picker/format-picker/orientation-picker machinery the other
  reports have (a fixed 4-5 column shape -
  Name/Admission No./Present/Absent/Percentage - needs no column
  selection, and format choice is a simple popup (PDF/Excel/DOCX) rather
  than the full `FormatPicker`/`OrientationPicker` row, since orientation
  is never in question for this few columns). They did gain a
  `ReportLayoutPicker` in Set 21 (see "Report layout templates,
  completed (Set 21)" below) - the one piece of template machinery that
  was still a genuine gap.
- **`ReportModule` gained `paymentReport`** (`features/reports/data/report_template.dart`)
  for the new screen's saved-template support; `firestore.rules`'
  `newReportTemplateIsValid()` was updated to accept it. The Fee Due
  Report reuses the EXISTING `feeDuesExport` module value rather than a
  new one, so any templates saved under the old `FeeDuesExportScreen`
  still appear in the new screen's `TemplateBar` (their `config` shape
  differs, but every field is read defensively with a fallback - the
  same tolerance-of-missing-keys convention already used throughout this
  project - so an old template just falls back to defaults for whatever
  it doesn't recognize, never a crash).
- **No new Firestore collections, no changed read-access rules**: every
  report reads collections that already grant admin unconstrained
  `list` (`students`, `feePayments`, `tests`/`testResults`, `attendance`/
  `teacherAttendance`) - reports are pure reads, generated on demand, and
  never write anything back or cache a result server-side.

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
| Institute profile (name, logo, tagline, about, primary/secondary phone, email, address, website) | Admin → Configuration → Institute |
| Academic sessions (name, start/end date, which one is active) | Admin → Configuration → Academic session |
| Classes (name, display order, active) + which subjects each offers | Admin → Configuration → Classes |
| Boards (e.g. CBSE, BSEB, Others) | Admin → Configuration → Boards |
| Subjects | Admin → Configuration → Subjects |
| Report/export letterhead: logo (position/size), header text, footer/signature/page-number/date | Admin → Report templates |
| Saved export column/filter presets | Any export screen's "Save as template" |
| Admission enquiries / callback requests (status only) | Admin → Enquiries / Callback requests |

Academic session/class/board/subject were, as of Set 8, deliberately
*not yet* their own configurable entities (free-text fields typed per
record instead) - Set 9 built the master-data layer described here. See
"Admin configuration and academic master data (Set 9)" below for the
full shape and the explicit scope boundary (existing modules like
student admission/homework/tests still use their own free-text fields;
wiring them to read this master data is future work, not part of Set 9).

## Admin configuration and academic master data (Set 9)

No new business features - this set built the foundational master-data
layer other modules will reference in future sets, and extended the
institute-profile document that already existed (Set 5) into the
central institute-configuration record. See
docs/database-architecture.md's "Academic master data" section for the
exact schema.

- **Institute configuration**: `InstituteProfile` (already existed for
  the public site) gained `logoUrl`, `secondaryPhone`, and `website` -
  additive, backward-compatible fields on the same singleton document,
  not a new collection. The logo is a pasted URL, same as every other
  image field since Set 5 (Storage still isn't enabled).
- **Academic sessions**: a real `academicSessions` collection (previously
  a bare `academicSession` string field on `StudentProfile`/
  `UpcomingBatch` - those existing free-text fields are untouched; this
  is a new, separate master collection future modules can reference by
  id). Exactly one session is ever active - enforced by
  `AcademicSessionController.setActiveSession`'s atomic `WriteBatch`
  (flips the old active session off and the new one on in one commit),
  not by a Firestore rule (a rule can't inspect sibling documents to
  enforce a collection-wide invariant, and getting this wrong has no
  security consequence). Sessions are never deleted - `firestore.rules`
  denies `delete` outright on this collection, matching the project's
  existing "prefer deactivation over destructive deletion" convention.
- **Classes**: `SchoolClass` (named to avoid colliding with Dart's
  `class` keyword) - Class 5 through 12 initially, each with a
  `subjectIds` list naming which `Subject` documents apply to it.
- **Boards**: CBSE/BSEB/Others initially, plain entries with no special
  handling for "Others" in the data model - a future student-admission
  screen is expected to show a free-text override when the board named
  "Others" is selected, but that wiring is out of scope here (see below).
- **Subjects**: a flat master list (Hindi, English, Sanskrit,
  Mathematics, Social Science, History, Civics/Political Science,
  Economics, Science, Physics, Chemistry, Biology). Class-subject
  applicability lives on `SchoolClass.subjectIds`, not a separate join
  collection - the only lookup direction any future module needs is
  "which subjects does this class offer", so a field on the class is
  simpler and just as centralized as a join table at this project's
  scale.
- **One-time default seeding, not a silent migration**: `seedDefaults()`
  writes the initial classes/boards/subjects/class-subject mapping
  specified above, but only for entries that don't already exist
  (existence-checked before every write, keyed by deterministic ids like
  `class9`/`cbse`/`mathematics`) - it never overwrites a name/active
  flag/subject list an admin has since edited. It's triggered by an
  explicit admin button on `AcademicConfigHubScreen` (with a confirmation
  dialog explaining what it does), not run automatically on app launch -
  consistent with this project's "no collection is populated with
  sample/fake data" convention, since this is the real initial master
  data an admin would otherwise have to type in by hand.
- **All four collections read like `batches`**: `allow get, list: if
  isSignedIn()` (a shared reference catalogue, not personal data) with
  `allow create, update: if isAdmin()` and `allow delete: if false` -
  same "unconstrained `watchAll()` is safe because the rule has no
  per-document dependency" reasoning documented in Set 8's "Firestore
  query-shape requirement".
- **What this set deliberately does NOT do**: wire any *existing* module
  to read this new master data. Student admission's `className`/`board`/
  `academicSession` fields, and homework/assignment/test's `subject`
  field, are all still free text, exactly as Sets 3-4 left them -
  changing those screens to use dropdowns sourced from
  `activeSchoolClassesProvider`/`activeBoardsProvider`/
  `activeSubjectsProvider` is future work explicitly out of scope for
  "build the master-data layer, don't touch Student Admission/Teacher
  Management/Attendance/Fees/Results/Tests/Public Gallery" (Set 9's own
  scope boundary). The providers are ready and centrally located for
  whichever future set does that wiring. (Student admission was wired to
  this master data in Set 11, tests in Set 14, homework/assignments -
  unified into `academic_work/` - in Set 16 - see below.)

## Teacher assignments (Set 22)

Set 12 (teacher management) deliberately established `TeacherProfile.
subjectIds` as CAPABILITY ONLY - "which subjects this teacher is capable
of teaching", independent of any class or batch - and explicitly left
"teacher -> batch assignment" as future work. Set 22 builds that missing
layer: `TeacherAssignment` (`teacher_assignments/`), the ACTUAL current
teaching responsibility. The two concepts stay separate models, never
merged:

```
TeacherProfile.subjectIds        CAPABILITY  - "can teach Math/Science"
TeacherAssignment                 ASSIGNMENT  - "IS teaching Class 8 ->
                                    Batch A -> Science, in 2026-27"
```

- **Cascading identity, reusing every Set 9/10/12 master-data provider
  as-is**: an assignment is Teacher -> Academic Session -> Class -> Batch
  -> Subject. Nothing new was built for this cascade - `TeacherAssignment
  FormDialog` reuses `activeTeachersProvider` (Set 12),
  `allAcademicSessionsProvider`/`activeSchoolClassesProvider`/
  `allSubjectsProvider` (Set 9) and `activeBatchesProvider` +
  `batchesForSessionAndClass` (Set 10, the exact same "Session -> Class ->
  matching batches" lookup Student Admission's form already uses) without
  modification. The one genuinely new piece is `subjectOptionsForAssignment`
  - the INTERSECTION of "subjects this class offers"
  (`SchoolClass.subjectIds`) and "subjects this teacher can teach"
  (`TeacherProfile.subjectIds`) - so a Class-9-only subject can never be
  offered for a Class-5 assignment, and a teacher can never be assigned a
  subject outside their configured capability. No override exists (the
  spec said to stop and ask before inventing one; none was needed).
- **Selecting a new value clears what it invalidates**: changing Teacher
  clears the chosen Subject (capability may differ); changing Class
  clears both Batch and Subject (both depend on the class). Session/
  Teacher/Class/Batch/Subject are otherwise independent state, matching
  the same cascade-clearing behavior Student Admission's form already
  has.
- **Duplicate prevention is structural, not just a validation step**: the
  document id is deterministic - `TeacherAssignment.idFor` -
  `<teacherId>_<academicSessionId>_<batchId>_<subjectId>`, the exact same
  technique Set 13 used for `attendance` (`batchId_dateKey`) and
  `teacherAttendance` (`teacherUid_dateKey`). Two ACTIVE assignments for
  the same teacher+session+batch+subject cannot exist as separate
  documents - they would BE the same document. `isDuplicateAssignment`
  (checked before every create, both in the app and mirrored as
  `TeacherAssignmentController.createAssignment`'s own `getById` guard)
  gives a clear "this assignment already exists" message rather than a
  rule rejection, and refuses even when the existing record is currently
  inactive - re-enabling a lapsed assignment is done via Activate on the
  list (the same historical document), never by creating a second one.
- **No display names are snapshotted**, unlike `TestDefinition.subject`/
  `AcademicWork.subject`: this set builds the only two screens that read
  `teacherAssignments` (the admin management screen and the teacher's own
  read-only view), and both resolve teacher/class/batch/subject/session
  names live from their existing Set 9/10/12 providers - there is no
  existing consumer expecting a plain snapshotted string the way an
  already-generated PDF report or a closed homework item needs one. This
  keeps the model to the "smallest appropriate" shape instead of adding
  fields with no current reader.
- **Deactivate, never delete** (`TeacherAssignmentController.setActive`):
  the same convention as Batch/Teacher/Student/TestDefinition. Only
  `active`/`updatedBy`/`updatedAt` ever change after creation -
  `firestore.rules`' `teacherAssignmentUpdateIsValid` pins every identity
  field (teacherId/session/class/batch/subject/createdBy/createdAt) to
  its original value, so an assignment's own history can never be
  rewritten - not by an edit, not by the teacher later changing
  capability, not by the class's subject configuration changing, not by
  the batch or teacher being deactivated, not by a new academic session
  starting. `TeacherFormController.setActive` (deactivating a teacher
  overall) was inspected and confirmed to already leave
  `teacherAssignments` completely untouched - it only ever writes to the
  `teachers`/`users` documents.
- **Assignments never carry forward between sessions automatically**:
  each is tied to one `academicSessionId`; starting a new session and
  wanting the same teacher/batch/subject combination requires a new
  assignment (a new document, since the id embeds the session) - no
  auto-copy step exists, matching the spec's explicit "do not assume
  assignments carry forward" instruction.
- **Rules cross-validate the batch relationship server-side, not just
  client-side** (section 19's "validate in Firestore rules where
  feasible"): `assignmentBatchIsConsistent` performs one extra `get()` on
  the referenced `batches/{batchId}` document and rejects a write whose
  `academicSessionId`/`classId` don't match the batch's own - the same
  `get()`-inside-a-rule technique `isStudentOfBatch` already uses. A
  client cannot construct an assignment that claims a batch belongs to a
  session/class it doesn't.
- **Reusable query layer** (section 22): `allTeacherAssignmentsProvider`
  (admin, unconstrained `watchAll()` - safe, since the admin caller's own
  rule branch has no per-document dependency, exactly like
  `allStudentAttendanceProvider`), `ownTeacherAssignmentsProvider`
  (teacher's own, server-side `.where('teacherId', ==, uid)` via
  `watchWhere` - required, since a teacher's rule branch DOES depend on
  `teacherId` per document, the same reasoning as
  `teacherOwnAttendanceProvider`), plus derived, client-side
  `assignmentsForTeacherProvider`/`assignmentsForBatchProvider`/
  `assignmentsForSubjectProvider` and the pure `assignmentsMatching`
  filter function - all available for a future teacher-scoped
  attendance/homework/test module to consume, without this set wiring
  any of them into those modules itself (see below).
- **Deliberately NOT wired into attendance/homework/tests/notices/results
  in this set** (sections 12-16, read literally): admin attendance
  marking, `academicWork` creation, and `tests`/`testResults` writes stay
  exactly as admin-only as Set 13/14/16 left them - no rule was narrowed,
  no teacher write access was opened, no automatic notice/result side
  effect was added. The spec's own words were "make assignments available
  as a trusted source for FUTURE teacher-scoped operations" - this set
  delivers that trusted source (the model, the rules, and the query
  layer above), not a retrofit of every module that could theoretically
  use it.
- **Two small UI surfaces, reusing every existing pattern**:
  `TeacherAssignmentsScreen` (admin: search + teacher/session/class/
  batch/subject/status filters, an "Add assignment" FAB, an Activate/
  Deactivate `PopupMenuButton` per row) is the same shape as
  `BatchListScreen`/`TeacherListScreen`; `TeacherAssignmentFormDialog` is
  the same `AlertDialog` + cascading-dropdown shape as
  `BatchFormDialog`/`CreateAcademicWorkDialog`. `MyAssignmentsScreen`
  (teacher-facing, read-only - "only Admin manages assignments," section
  10) is a plain list, reached from a new "My assignments" `NavTile` on
  `TeacherHomeScreen`; admin reaches the management screen from a new
  "Teacher assignments" `NavTile` on `AdminDashboardScreen`, right after
  "Batches".
- **No "Edit" beyond Activate/Deactivate**: teacherId/session/class/batch/
  subject together ARE an assignment's identity (embedded in its document
  id) - there is nothing else on the model to edit, so section 8's "Edit
  Assignment where appropriate" resolves to "the only appropriate edit is
  its active status," already covered by Activate/Deactivate. Changing
  any identity field is, by definition, a different assignment - create a
  new one instead.

## Teacher-scoped academic operations (Set 23)

Set 22 built `TeacherAssignment` (Teacher -> Session -> Class -> Batch ->
Subject) as a standalone module with nothing consuming it yet. Set 23
connects it to the three operational modules that were previously
admin-only for writes - Attendance (Set 13), Homework & Assignments (Set
16), Tests & Marks (Set 14) - so a teacher can act, but ONLY within a
scope an active assignment actually grants. `TeacherProfile.subjectIds`
(Set 12) is NEVER consulted for this - a teacher capable of teaching
Mathematics has zero operational access to any Mathematics class/batch
until an admin creates an actual assignment for it.

- **One authorization primitive, reused by three modules**: `firestore.
  rules`' `teacherIsAssignedTo(academicSessionId, classId, batchId,
  subjectId)` builds the exact deterministic `teacherAssignments`
  document id (`TeacherAssignment.idFor`, Set 22) from the record being
  written and performs ONE `exists()` + `get()` pair to confirm it's
  active and its `classId` matches. This works cleanly for `academicWork`
  and `tests`/`testResults` because all three already carry (or can look
  up via their parent) a `subjectId` - no query, no loop, no bounded
  guesswork needed. The Dart-side mirror is `teacherCanOperateOn`
  (`features/teacher_assignments/data/teacher_assignment_repository.dart`),
  a pure function used to decide what the UI shows - kept intentionally
  parallel to the rule so the client never offers an action the rule
  would then reject.
- **Attendance is the one documented exception.** It has no `subjectId`
  field at all (Set 13's own design - Set 23 section 4 explicitly forbids
  inventing one just to make this check easier), so
  `teacherIsAssignedTo`'s technique doesn't apply: there is no way to
  build "the" assignment id without knowing which subject to plug in, and
  checking "any of this teacher's assignments, for an unknown subject"
  would need either a query (Firestore rules cannot run one inside a
  write's authorization check - only fixed `get()`/`exists()` calls on
  known paths) or enough `get()`/`exists()` calls to cover every subject a
  class might offer, which can exceed Firestore's confirmed 10-document-
  access-call budget per single-document request at this project's own
  configured scale (Set 9 seeds classes with up to 10 subjects each) - or
  a second, denormalized index of assignment data (explicitly
  prohibited), or Firebase Auth custom claims (needs the Admin SDK /
  Cloud Functions - explicitly prohibited on this Spark-plan project).
  None of those are safe or permitted. See docs/database-architecture.md's
  "Teacher-scoped Firestore rules (Set 23)" for the full writeup and
  exactly what IS and isn't enforced for this one collection - in short,
  `attendance` writes are gated by role (`isTeacher()`, the same broad
  grant this project already documents for `students`/`tests`/
  `academicWork` reads since Set 8/14/16) plus full shape validation,
  with the APPLICATION (not the rules) restricting which batch a teacher
  can pick from - real protection against an accidental UI mistake, not a
  hard boundary against a deliberately crafted direct write.
- **Assignment-derived selection, never free typing** (section 6): both
  `CreateAcademicWorkDialog` and `CreateTestDialog` render the SAME
  cascading Session -> Class -> Batch -> Subject picker they always did
  for admin, unchanged - but when the signed-in caller is a teacher, that
  block is replaced with ONE dropdown built from
  `ownTeacherAssignmentsProvider` (Set 22's rule-constrained self-read),
  each option fully determining session/class/batch/subject in a single
  choice. `MarkStudentAttendanceScreen`'s teacher path does the same,
  using `distinctActiveBatchScopes` to collapse multiple subject-
  assignments to the same batch into one dropdown entry (section 5 - a
  teacher teaching both Mathematics and Science to Class 9 - Batch A
  should see that batch once in an attendance picker, not twice, since
  attendance has no subject dimension to distinguish them by anyway).
- **Detail/list screens gained a `canManage` check, not a role swap**:
  `AcademicWorkDetailsScreen`'s Edit/status buttons and
  `TestDetailsScreen`'s Publish/Activate buttons + `EnterMarksScreen`'s
  editability now read `isAdmin || teacherCanOperateOn(ownAssignments,
  ...)` instead of `isAdmin` alone - admin behavior is provably unchanged
  (the `isAdmin` branch of that `||` is identical to before), and a
  teacher without a matching assignment sees the exact same read-only
  view a student or unrelated teacher already saw. `TestListScreen`/
  `AcademicWorkListScreen`'s "New" FAB uses the same `||` to decide
  whether to show at all.
- **No ownership check, only scope**: whether a teacher may update an
  existing `academicWork`/`test`/mark set depends on whether their OWN
  currently active assignment matches that record's (immutable)
  session/class/batch/subject - not on whether they personally created
  it. This is deliberate: `TeacherAssignment` is stated to be the
  authoritative operational scope (section 1), and two teachers holding
  assignments to the same batch/subject (unusual but not prevented by Set
  22) should both be able to manage the same academic work/test, exactly
  as admin always could regardless of who created what.
- **Lifecycles are completely unchanged**: `AcademicWorkController`/
  `TestController` were not modified at all - both were already generic
  (they resolve the acting user from `currentUserAccountProvider`, not a
  hardcoded admin assumption), so widening who may call them was purely a
  `firestore.rules` and UI-gating change, never a controller rewrite.
  Draft -> Published -> Closed (reversible) and the absent-vs-zero/
  `resultPublished` (one-way) semantics are exactly what Set 16/14 built.
- **Deactivating an assignment (or the teacher) takes effect immediately,
  non-destructively**: nothing here stores a cached "can this teacher act"
  flag anywhere - `teacherCanOperateOn`/`teacherIsAssignedTo` both read
  the CURRENT `active` state of the assignment (and, transitively, of the
  teacher - `TeacherFormController.setActive` deactivating a teacher's
  `users` document already blocks them from claiming a session at all, a
  Set 2 mechanism reused unchanged) on every check. Historical
  attendance/homework/tests/marks/results are never touched by a
  deactivation - only future authorization changes (sections 15-16, 18).
- **Results (Set 15) were not touched at all** - no new provider, no new
  screen, no rule change. `computeSubjectResults`/`computeCombinedResults`/
  `rankByPercentage` are pure, admin-only-reached functions over
  `tests`/`testResults`; Set 23 widens who may WRITE marks, never who may
  read/compute results, so this layer needed nothing.
- **Provider layer**: no new Firestore queries were introduced.
  `teacherCanOperateOn`/`distinctActiveBatchScopes` are plain functions
  over whatever `ownTeacherAssignmentsProvider(teacherId)` (Set 22)
  already returns; every screen that needed a teacher's own assignments
  was already able to reach that one provider. `assignmentsForTeacherProvider`/
  `assignmentsForBatchProvider`/`assignmentsForSubjectProvider` (Set 22)
  remain available for any future admin-side use but were not needed by
  this set.

## What's deliberately not here yet

- An online payment gateway/checkout (Razorpay/Stripe/PayPal/UPI deep-
  link/webhook/subscription billing) - Set 19 is explicitly a MANUAL
  fee-recording module; admin records a payment after receiving it
  outside the app, exactly like every other "no paid services" boundary
  in this project.
- A printed fee receipt/statement (PDF or otherwise) - Set 19 section 20
  deliberately stops at "structure payment data so a future receipt is
  straightforward" (`FeePayment` already carries a unique
  `paymentNumber` and every figure a receipt would need), not at
  building the A4 report designer integration itself.
- A fee summary card on the admin dashboard (Set 19 section 27's own
  "if the current Admin dashboard has suitable summary cards" is
  conditional - `AdminDashboardScreen` is a plain list of `NavTile`s with
  no summary-card section at all to extend, unlike the student
  dashboard's stat-card grid, so nothing was added rather than
  introducing a new dashboard-summary pattern for one figure).
- Automated payment reminders or payment notifications beyond the
  existing `recordFeePaymentNotification` hook (Set 5, reused as-is by
  `FeePaymentController.recordPayment` - a payment being recorded is
  already a notification-worthy event exactly like it always was; Set 19
  adds no NEW notification integration).
- Every public-content image (gallery/banner/advertisement/upcoming-batch
  poster) - Storage isn't enabled on this project (see
  docs/firebase-setup.md), so as of Set 5 every such field is a plain
  `imageUrl`/`posterUrl` string the admin pastes (external hosting -
  e.g. any image host URL). Student photos (Set 11,
  `StudentProfile.photoUrl`) and teacher photos (Set 12,
  `TeacherProfile.photoUrl`) both follow the identical pasted-URL
  pattern. Every other admission/profile/content field is in place, so
  switching to real uploads later is an isolated
  addition, not a rework.
- Actual push notification *delivery* - `notifications` documents are
  written (see docs/database-architecture.md's "Notification event
  hooks") and, as of Set 5, read back by a shared `NotificationsScreen`
  per role, but nothing sends an FCM push yet - there are no Cloud
  Functions in this project to trigger one from. "Fee due/reminder"
  notifications specifically are also not implemented, since a
  *scheduled* reminder needs a cron-like trigger, which needs server-side
  compute this project deliberately doesn't have. Set 17's admin-authored
  `notices` are in-app only for the identical reason - the model already
  carries everything a future push sender would need (title/message/
  audience/scope/type), so adding delivery later is additive, not a
  rework (see docs/database-architecture.md's "Notices (Set 17)").
- Automatic `notices` creation from other modules (Tests/Results/
  Attendance/Homework/Fees) - Set 17's own scope boundary. Those modules
  may call into `NoticeController` in a later set; nothing does yet.
- Enforcing "teacher may only manage their *assigned* class/subject" at
  the rules level - RESOLVED for `academicWork` and `tests`/`testResults`
  by Set 23 (see "Teacher-scoped academic operations (Set 23)" above):
  a teacher may now create/update those only within a session/class/
  batch/subject an active `TeacherAssignment` actually grants, checked
  server-side via `teacherIsAssignedTo`. Reads on all three stay exactly
  as broad as before (any active teacher). `attendance` writes are the
  ONE remaining, explicitly documented exception - Firestore Rules cannot
  safely check "any active assignment, for an unknown subject" for a
  batch-level (non-subject) record without an unsafe/oversized rule or
  duplicated data, so that collection's write rule stays role-based
  (`isAdmin() || isTeacher()`), with the application (not the rules)
  restricting which batch a teacher's UI ever offers - see
  docs/database-architecture.md's "Teacher-scoped Firestore rules (Set
  23)" for the full reasoning.
- A telecaller role - enquiry/callback management is admin-only by
  explicit requirement (Set 5).
- An enquiry-to-admission conversion workflow (Set 18's own scope
  boundary: "do not implement conversion workflow in Set 18 unless it
  already exists safely" - it doesn't). Submitting a visitor enquiry or
  callback request never creates a Firebase Auth user, a `users`/
  `students` document, a batch enrollment, or a fee agreement - the only
  way a visitor becomes a student remains the existing, fully manual
  Set 11 Student Admission flow, run by an admin from the admin app.
- A `publicVisible`-style field on the real `batches` collection - Set 18
  inspected the existing architecture first and found `upcomingBatches`
  (Set 5) already solves "let admin choose which batches the public
  sees" more safely (a separate curated marketing collection, never
  auto-synced from real enrollment data) - see docs/database-
  architecture.md's "Public batch visibility (Set 18)".
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
