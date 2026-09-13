# Database Architecture

Cloud Firestore, accessed through the generic repository pattern in
`lib/data/`. No collection is populated with sample/fake data — Firestore
creates a collection automatically on its first write.

## Reusable pattern

```
FirestoreDataSource   raw CRUD + streams on ONE collection (cloud_firestore calls only)
        ↓
FirestoreRepository<T>  converts Map<String, dynamic> <-> a model T
        ↓
Feature repository (future)  e.g. StudentRepository extends/wraps
                              FirestoreRepository<Student>
```

A future feature repository looks like this (illustrative — no `Student`
model exists yet, this is not implemented in Set 1):

```dart
final studentRepositoryProvider = Provider<FirestoreRepository<Student>>((ref) {
  return FirestoreRepository<Student>(
    firestore: ref.watch(firestoreProvider),
    collectionPath: FirestoreCollections.students,
    fromFirestore: Student.fromMap,
    toFirestore: (student) => student.toMap(),
  );
});
```

Every future collection reuses `FirestoreRepository<T>` — no per-feature
Firestore boilerplate.

## Planned collections

Defined as constants in `lib/core/constants/firestore_collections.dart` so
every future repository references the same string. Declaring the name
here does **not** create the collection or any documents.

| Collection | Purpose (future phase) |
|---|---|
| `institutes` | Institute-level profile/settings (name, branding, contact info) |
| `academicSessions` | Academic year/term definitions |
| `batches` | Class/batch groupings students are enrolled into |
| `subjects` | Subject catalogue |
| `teachers` | Teacher profiles |
| `students` | Student profiles |
| `users` | Auth-linked account records (role, linked student/teacher id) |
| `enquiries` | Admission/visitor enquiries |
| `attendance` | Student attendance records |
| `teacherAttendance` | Teacher attendance records |
| `fees` | Fee structure/dues per student |
| `payments` | Recorded fee payments |
| `homework` | Homework assigned to a batch/student |
| `assignments` | Assignments (graded work) |
| `tests` | Test/exam definitions |
| `testResults` | Student results for a test |
| `notifications` | In-app/push notification records |
| `gallery` | Public gallery images |
| `advertisements` | Promotional content |
| `announcements` | Institute announcements |
| `reportTemplates` | Report/certificate templates |
| `auditLogs` | Administrative action audit trail |

Field-level schemas for each collection are defined when the phase that
uses them is implemented, not in advance — this avoids guessing
requirements that later turn out to be wrong.

## Storage layout

Mirrors the same idea for Firebase Storage, via
`lib/core/constants/storage_paths.dart`:

| Path prefix | Purpose |
|---|---|
| `student_photos/` | Student profile photos |
| `teacher_photos/` | Teacher profile photos |
| `gallery/` | Gallery images |
| `banners/` | Home/marketing banners |
| `advertisements/` | Advertisement assets |
| `institute_logo/` | Institute logo/branding assets |
| `report_assets/` | Assets used when generating reports/certificates |

## `users` collection (Set 2)

Every account - admin, teacher, or student/parent - is one document in
`users`, keyed by the account's Firebase Auth `uid`:

```
users/{uid}
  uid           string    same as the document id
  accountId     string    the login ID (lowercase, e.g. "stu2026001")
  role          "admin" | "teacher" | "student"
  displayName   string
  active        bool      admin can deactivate without deleting
  createdAt     timestamp
  updatedAt     timestamp
  lastLoginAt   timestamp | null
  session       { deviceId, loginAt, lastSeenAt } | null
```

`role` is security-authoritative here (there are no Cloud Functions /
custom claims in this project - see "Why no Cloud Functions" in
docs/architecture.md). A client can never change its *own* `role` and
have that mean anything: `firestore.rules`' `update` rule never allows
`role` to change for anyone, ever, after the account is created (see
below) - the only document a `role` value is ever set on comes from the
`create` rule, which requires the caller to already be an admin.

### How login maps an Account ID to Firebase Auth

Firebase Authentication is identity-based on email/password under the
hood. To let people sign in with a short Account ID instead of an email,
the app deterministically computes `"<accountId>@omegaerp.local"` (see
`AppConstants.accountEmailDomain`) and uses that as the Firebase Auth
email, both when creating and when signing in. `omegaerp.local` never
receives real mail; it's just a stable, syntactically-valid identifier.
Firebase Auth's own email-uniqueness check is what guarantees Account IDs
can't collide - no separate lookup collection needed.

### How admin-created accounts work

`firestore.rules`' `allow create` on `users` requires the caller to
already be an admin - so there is no client-side path to self-register.
Creating an account (`AdminAccountController.createAccount`, driven by
`AdminAccountsScreen -> CreateAccountScreen`) does two things in sequence:

1. Creates the Firebase Auth user via a **throwaway secondary
   `FirebaseApp` instance** (`Firebase.initializeApp(name: '...')`,
   reusing the same project config) and immediately tears it down. This
   is what keeps the admin's own primary session untouched - calling
   `createUserWithEmailAndPassword` on the *primary* instance would
   otherwise sign the app in as the newly-created user.
2. Writes the `users/{uid}` document using the admin's own (primary,
   still signed-in) session. `firestore.rules`' `newAccountIsValid()`
   requires the exact expected shape (`active: true`, `session: null`,
   no extra fields, `role` one of the three valid values) - so even a
   modified client can't smuggle in a privileged or malformed account.

If step 2 fails after step 1 succeeded, the just-created Auth user is
deleted again (best effort) rather than left as an orphaned credential
with no Firestore profile.

### Bootstrapping the first admin

The very first admin account can't be created through the app (there's
no admin yet to authorize it, and there's deliberately no sign-up
screen). It's created **once, manually, in the Firebase Console** - see
docs/firebase-setup.md for the exact steps (add a user under
Authentication, then add the matching document under Firestore). This
uses the Console's own privileged access, which - like the Admin SDK -
bypasses `firestore.rules` entirely, so no special bootstrap carve-out
rule is needed.

### Single-device session enforcement

`session` is the mandatory "only one active device" mechanism, enforced
entirely by `firestore.rules` (no Cloud Function needed - rules run
server-side and can't be bypassed by a modified client):

- **Login** (self-write): a device may claim `session` (login) only if
  the account is `active` AND the existing session is either absent,
  already this same device, or **stale** (`lastSeenAt` older than 30
  minutes - e.g. the app crashed or lost network without a clean
  logout). A device that loses this check gets a Firestore
  `permission-denied`, which the app turns into "This account is already
  active on another device."
- **Heartbeat**: while signed in, the app refreshes `session.lastSeenAt`
  every 5 minutes so a genuinely active session never goes stale under a
  competing device.
- **Logout** (self-write): a device may always clear its own `session` to
  `null`, regardless of `active` status.
- **Detection while running**: the app listens to its own `users/{uid}`
  document. If `session.deviceId` ever stops matching this device (taken
  over after going stale, or reset by admin) or `active` turns `false`,
  the app forces a local sign-out with a clear explanation - it does not
  wait for the user to notice.
- **Admin reset** (a legitimate device replacement, e.g. a lost phone):
  from `AdminAccountsScreen`, "Reset session" writes `session: null` directly
  - allowed because `firestore.rules` lets an admin update
  `active`/`session` on *any* account, but never fabricate a session for
  someone else (it can only be nulled, never set to an arbitrary value)
  and never touch `role`/`accountId`/`uid`. This is a direct, rule-gated
  Firestore write from the admin's signed-in session - no server needed.

### Role authorization, generally

`firestore.rules` gates the whole `users` collection: a user may always
`get` their own document; only an admin (checked via a `get()` lookup of
the caller's *own* document and its `role`/`active` fields) may `get`
someone else's, `list` the collection, `create` a new account, or
`update` fields other than their own session. Every other collection
still defaults to deny (see below) until the phase that implements it
defines its own rules.

## `teachers`, `students`, `batches` and payments (Set 3)

Teacher management, student admission, batch-based fee configuration,
payments and fee dues. All admin-managed - see "Role authorization,
generally" below for exactly what a teacher/student can read of their
own record (nothing more).

```
teachers/{uid}                  keyed the same as the matching users/{uid}
  uid, accountId                 same account the teacher logs in with
  name, dateOfBirth, gender, qualification, address
  photoUrl       string | null   a pasted external image URL - same
                                  pattern as student/gallery/banner/logo
                                  images (Storage isn't enabled - see
                                  docs/firebase-setup.md)
  primaryMobile, secondaryMobile (optional)
  subjectIds     [subjectId, ...]   references subjects/{subjectId}
                                     (Set 9) by stable id - a flat
                                     TEACHING CAPABILITY list, e.g. a
                                     teacher capable of Hindi, Social
                                     Science and Science all at once.
                                     Independent of any class/batch (see
                                     "Teacher/subject relationship
                                     (Set 12)" below); '' (empty list) on
                                     a pre-Set-12 document
  active         bool             defaults to true on read for a
                                    pre-Set-12 document, which predates
                                    this field
  createdAt, updatedAt

students/{uid}                  keyed the same as the matching users/{uid} -
                                  the student's STABLE identity + a
                                  denormalized snapshot of their CURRENT
                                  admission (see "Student admission
                                  (Set 11)" below for why these two are
                                  kept as separate concepts)
  uid, accountId
  admissionNumber   string   stable, unique, assigned once at admission
                              (Set 11 - see "Admission numbers" below);
                              '' on a pre-Set-11 document
  name, fatherName, dateOfBirth, gender, address
  photoUrl       string | null   a pasted external image URL - same
                                  pattern as gallery/banner/logo images
                                  (Storage isn't enabled - see
                                  docs/firebase-setup.md)
  className, board, batchId, academicSession   display strings, resolved
                                  from master data at admission/transfer
                                  time (Set 11) - never hand-typed
  academicSessionId, classId    string   the authoritative references
                                  (Set 11) - references academicSessions/
                                  classes (Set 9); '' on a pre-Set-11
                                  document (see Batch's identical
                                  `isLinkedToMasterData` convention)
  boardId        string | null   references boards/{boardId} (Set 9)
  boardCustomText string | null  the actual name when boardId's board is
                                  "Others"
  primaryMobile, secondaryMobile (optional)
  standardFee    number   snapshot of the CURRENT admission's standard
                           fee - reference only, never used in
                           calculations
  finalFee       number   the figure actually agreed - THIS is what every
                           payment/due calculation uses (see "Fee model"
                           below)
  feeReason      string | null   required whenever finalFee != standardFee;
                                  permanently stored, never silently dropped
  paymentPlan    "monthly" | "installment"
  admissionDate  timestamp   date of the CURRENT admission (initial
                              admission, or the most recent batch
                              transfer) - not this document's own
                              createdAt, which never changes
  currentAdmissionId  string   points at the students/{uid}/admissions
                                document these fields were last synced
                                from; '' on a pre-Set-11 document
  active         bool
  createdAt, updatedAt

  students/{uid}/payments/{paymentId}      append-only - never edited/deleted
    amount     number
    date       timestamp
    mode       "cash" | "upi" | "bankTransfer" | "cheque" | "other"
    remark     string | null
    createdAt  timestamp
    createdBy  string (admin's uid)

  students/{uid}/admissions/{admissionId}   one record per admission EVENT
                                              (initial admission, or a later
                                              batch transfer) - see "Student
                                              admission (Set 11)" below.
                                              Immutable once created except
                                              for `active` being flipped off
                                              when superseded - never
                                              deleted.
    studentUid, academicSessionId, classId, batchId
    boardId, boardCustomText     (both optional, same meaning as above)
    standardFee, finalFee, feeReason, paymentPlan   a full snapshot of the
                                                      fee agreement at the
                                                      time of THIS admission
    installments   [{ label, amount, dueDate, status }, ...]   only
                    populated when paymentPlan == "installment"
                    (InstallmentScheduleItem - see Batch fee
                    configuration (Set 10))
    admissionDate  timestamp
    active         bool   true for the current admission; false once a
                           later admission supersedes it
    configuredByUid   string (the admin who configured this admission)
    createdAt, updatedAt

batches/{batchId}
  name
  batchCode                string | null   optional short code, e.g. "C8-MOR"
  description              string | null
  academicSessionId        string          required - references
                                             academicSessions/{sessionId}
                                             (Set 9). Same batch name can
                                             legitimately repeat across
                                             different sessions - the
                                             session link is what keeps
                                             them distinguishable.
  classId                  string          required - references
                                             classes/{classId} (Set 9)
  boardId                  string | null   optional - references
                                             boards/{boardId} (Set 9).
                                             When the chosen board is
                                             "Others", boardCustomText
                                             carries the actual free-text
                                             board name instead of being
                                             discarded.
  boardCustomText          string | null
  standardMonthlyFee       number
  standardInstallmentFee   number
  studentCount             int             denormalized counter, defaults
                                             to 0 on create; not written by
                                             anything yet in Set 10 - kept
                                             so a future Student Admission
                                             set can increment/decrement it
                                             on admission/transfer without
                                             a schema change.
  active                   bool
  createdAt, updatedAt
```

### Teacher/subject relationship (Set 12)

`TeacherProfile.subjectIds` replaces the old free-text `assignments`
(`[{ className, subject }, ...]`) field from Set 3. That field was
confirmed unused everywhere outside the teacher feature itself (never
read by homework/assignments/tests/attendance - see below), so
replacing it with a proper reference to `subjects/{subjectId}` (Set 9)
closes the "uncontrolled comma-separated text field" gap directly rather
than layering a second, competing subject concept on top of it.

`subjectIds` is a flat multi-select over `activeSubjectsProvider` (only
subjects that exist in the configured master data are selectable, via
a checkbox-list dialog that mirrors `ClassesScreen`'s own subject
picker exactly) and represents teaching **capability**, not an
assignment to any particular class or batch - a teacher capable of
"Science" can be capable of it for every class that offers Science, and
a teacher may hold several subjects at once (e.g. Hindi + Social
Science + Science). `TeacherFormController` normalizes every write
through `dedupeSubjectIds()` (a pure, order-preserving de-duplication
helper) so "no duplicate subject ids" holds regardless of how a caller
assembled the list, on top of the `Set<String>`-backed picker UI already
preventing it by construction.

**Deliberately NOT built here** (Set 12 spec: "do NOT implement
teacher-to-batch assignment yet"): nothing links a `TeacherProfile` to a
specific `Batch`/`SchoolClass`. `subjectIds` only has to not *prevent*
that future relationship - it doesn't need to model it. A future
teacher-batch-subject assignment set can reference a teacher by `uid`, a
batch by `batchId`, and a subject by `subjectId` (validating that the
subject is one of the teacher's `subjectIds` and one of the batch's
class's `SchoolClass.subjectIds`) without this set's schema changing.
`activeTeachersProvider` (mirroring `activeBatchesProvider`) is already
in place as the "don't offer an inactive teacher" lookup that picker
will need.

This does **not** change why homework/assignments/tests still let any
active teacher manage any batch's records (see "Why homework/
assignments/tests aren't restricted to 'only the assigned teacher'"
below) - that reasoning was about a *batch* cross-reference, which
remains exactly as unresolved as before; `subjectIds` never claimed to
solve it.

`academicSessionId`/`classId` were added in Set 10; batches created before
Set 10 don't have them on the stored document. `Batch.fromMap` defaults
both to `''` on read (`isLinkedToMasterData` reports whether a batch is
actually linked), and `batchUpdateIsValid()` in `firestore.rules`
explicitly tolerates their absence so that a partial `.update()` (e.g.
toggling `active`) on such a historical batch keeps working unchanged; a
full edit-form re-save naturally migrates the document once an admin
opens and saves it, since the form always supplies every field.

### Standard fee vs. final agreed fee

`standardMonthlyFee`/`standardInstallmentFee` on a batch are the
**template** figures for that batch, not tied to any one student - they
must never be edited to reflect a single student's discount. Every
`students/{uid}/admissions/{admissionId}` record keeps its own snapshot
(`standardFee`, `finalFee`, `feeReason`) precisely so a discount never
touches the batch (see "Fee model" below).

`Batch.standardFeeFor({required bool isInstallment})` is the one shared
lookup `StudentFormScreen` (new admission), `ChangeBatchDialog` (a batch
transfer) and any future admission-adjacent screen call, rather than
duplicating the monthly-vs-installment branch. `InstallmentScheduleItem`
(`label`, `amount`, `dueDate`, `status`) is embedded directly in
`StudentAdmission.installments` - see "Student admission (Set 11)" below.

### Student admission (Set 11)

Two Firestore-backed models cover a student:

- `StudentProfile` (`students/{uid}`) - the student's STABLE identity
  (name, DOB, gender, photo, father's name, contacts, address,
  `admissionNumber`, `active`) plus a denormalized **snapshot of their
  CURRENT admission** (session/class/batch/board, standard/final fee,
  payment plan, admission date). This is what every existing screen
  (list, profile, fee dues, payment due calculation) reads - no N+1
  subcollection reads needed for the common case of "what is this
  student's current situation".
- `StudentAdmission` (`students/{uid}/admissions/{admissionId}`) - one
  **immutable-once-created** record per admission event: the initial
  admission, or a later batch transfer. This is the durable history a
  student who returns in a future academic session, or moves batches,
  needs - without ever creating a duplicate person record or silently
  rewriting a past fee agreement.

`StudentFormController` keeps both in sync:

- `admitStudent(...)` creates the Firebase Auth account (via the same
  `AccountProvisioningService` secondary-Firebase-app pattern already
  used for teacher accounts - a throwaway secondary app instance avoids
  signing the admin out of their own session), the `students/{uid}`
  profile, and its first `students/{uid}/admissions/{admissionId}`
  record together, then increments the chosen batch's `studentCount`.
- `updateStudent(...)` edits identity/contact fields and the board only
  - it never touches `academicSessionId`/`classId`/`batchId`/the fee
    agreement, so a casual profile edit can never rewrite admission
    history (Set 11 spec: "do not silently rewrite historical admission
    financial values").
- `changeBatch(...)` is the only way session/class/batch/fee change
  after admission: it flips the previous admission's `active` to
  `false` (preserved, never rewritten or deleted), writes a brand-new
  `StudentAdmission` with its own fee snapshot/remark/installments,
  updates the profile's denormalized fields to match, and adjusts both
  batches' `studentCount` (`FieldValue.increment` - no read-modify-write
  race, since Firestore resolves the increment server-side before the
  security rule sees `request.resource.data.studentCount`).
- `setActive(...)` toggles both `students/{uid}.active` and the matching
  `users/{uid}.active` together, so a deactivated student can no longer
  start a new login session (`selfSessionUpdateIsValid` already requires
  `resource.data.active == true` to claim one) - their historical
  admission/payment records are never touched or hidden from an admin.

`firestore.rules`' `studentUpdateIsValid()` tolerates the ABSENCE of
every Set-11-added field, exactly like `batchUpdateIsValid()` (Set 10):
a pre-Set-11 student document has none of them, so `setActive`'s partial
`.update()` keeps working on an old document unchanged, while a full
admission/edit save (which always supplies every field) is fully
validated.

### Admission numbers

`admissionNumber` is generated once, at admission, by `SequenceService`
(`lib/core/services/sequence_service.dart`) - a small reusable "hand out
the next integer for a named sequence" helper backed by one counter
document at `counters/students` (`{ nextNumber, updatedAt }`), read and
incremented in a single Firestore client-side transaction (no Cloud
Function needed) so two admissions submitted at nearly the same moment
can never collide. `formatAdmissionNumber(n)` turns the raw integer into
`"STU0001"`-style text - a separate pure function so the format is
tested without touching Firestore. `firestore.rules` only lets
`nextNumber` increase, never decrease or repeat.

### Fee model

A batch carries two standard fees (`standardMonthlyFee`,
`standardInstallmentFee`). Which one applies to a student is decided by
their `paymentPlan`: choosing "Monthly" auto-populates `standardFee` from
`standardMonthlyFee`, choosing "Installment" from
`standardInstallmentFee` (`_recomputeStandardFee` in
`StudentFormScreen`, re-run whenever either the batch or the plan
changes). Admin may still override `finalFee` down (or up) from there -
that's the discount/adjustment workflow - but doing so **requires**
`feeReason` to be filled in, enforced client-side in the form. Example:
standard fee 9000, final fee 7500, reason "approved discount" - both
figures and the reason are stored permanently on the student record.

Every payment/due calculation (`totalPaid`, `due`, `dueLabel` in
`student_repository.dart`) uses `finalFee`, never `standardFee` - this is
what "future fee calculations must use the student's final agreed fee"
means in practice. `due` can go negative (student has paid more than
`finalFee`); `dueLabel` renders that as "Advance ₹X" rather than a
confusing negative "Due". As of Set 11 these top-level `standardFee`/
`finalFee`/`feeReason`/`paymentPlan` fields are always the CURRENT
admission's values (kept in sync by `admitStudent`/`changeBatch`) -
payments themselves are never split per-admission, since a student only
ever has one active admission at a time.

### Why payments and admissions are their own subcollections, not top-level collections

`students/{uid}/payments` and `students/{uid}/admissions` both scope
naturally to rules (`isAdmin() || isSelf(studentId)`, same as the
student's own document) and to queries (the fee-dues screen never needs
to query payments *across* students - it filters `students`, then reads
each matching student's own payment subcollection; nothing ever needs to
list admissions across every student either). No composite index is
needed anywhere for either: every list is fetched whole and
filtered/sorted client-side, which is fine at this project's scale
(~200 students).

### Call / WhatsApp

Not a messaging feature - `core/utils/contact_actions.dart` just opens
the device's native phone dialer (`tel:`) or WhatsApp
(`https://wa.me/<digits>`) pre-filled with the student's `primaryMobile`.
Android 11+ needs the `<queries>` entries in
`android/app/src/main/AndroidManifest.xml` for these intents to resolve
(already added) - iOS needs no equivalent for plain `tel:`/`https:`
links.

## Attendance, homework, assignments, tests and results (Set 4, attendance extended Set 13)

```
attendance/{batchId}_{dateKey}          one record per batch/date - NEVER
                                          split by subject
  batchId, dateKey ("2026-09-10"), date
  academicSessionId, classId   snapshot of the batch's own session/class
                                 at marking time (Set 13) - '' on a
                                 pre-Set-13 record (never a live join;
                                 see "Attendance identity and snapshots"
                                 below)
  records    { studentUid: "present" | "absent", ... }   every student in
                                                           the batch, in one map
  createdBy, updatedBy, createdAt, updatedAt

teacherAttendance/{teacherUid}_{dateKey}   one record per teacher/date
  teacherUid, dateKey, date, status ("present" | "absent")
  createdBy, updatedBy, createdAt, updatedAt

academicWork/{workId}                   homework AND assignments,
                                          unified (Set 16) - shared by
                                          the whole batch, never one
                                          document per student
  type ("homework" | "assignment")
  academicSessionId, classId, batchId, subjectId   the batch/subject's
                                                     own references,
                                                     snapshotted at
                                                     creation and
                                                     immutable after -
                                                     same rationale as
                                                     Test's Set 14 fields
  subject      string   resolved subject display name
  title, description (string | null)
  assignedDate, dueDate   dueDate >= assignedDate, enforced both
                           client-side and in firestore.rules
  status ("draft" | "published" | "closed")   freely reversible in
                                                either direction (unlike
                                                Test's one-way
                                                resultPublished)
  createdBy, createdAt, updatedAt

tests/{testId}                          metadata only - the test is
                                          conducted on paper, offline
  batchId, title, chapterTopic, date, totalMarks
  academicSessionId, classId, subjectId   snapshot of the batch/subject
                                            at creation time (Set 14) -
                                            '' on a pre-Set-14 test (see
                                            "Test/subject wiring" below)
  subject      string   resolved subject display name - kept for
                          existing consumers (student results, the
                          test-result export), never hand-typed as of
                          Set 14
  testType ("unitTest" | "monthlyTest" | "weeklyTest" | "halfYearly" |
            "finalTest" | "other"), otherTestTypeLabel (string | null -
            only meaningful when testType == "other")
  description (string | null)
  active (bool)   defaults to true on read for a pre-Set-14 document
  resultPublished (bool)
  createdBy, createdAt, updatedAt

testResults/{testId}_{studentUid}       one document per test+student
  testId, studentUid, batchId
  isAbsent (bool)   Set 14 - true means "did not attempt", never a
                     stand-in for a zero score
  obtainedMarks (number | null)   null whenever isAbsent is true;
                                   percentage computed client-side, never
                                   stored
  totalMarks
  remark, enteredBy, createdAt, updatedAt

notifications/{notificationId}          event hooks only - see below
  type ("homework" | "assignment" | "test" | "result")
  batchId, studentUid (optional), title, body, relatedId, createdAt
```

Both attendance collections use a **deterministic document id**
(`<batchId>_<dateKey>` / `<teacherUid>_<dateKey>`) instead of an
auto-generated one - marking the same batch/date (or teacher/date) twice
always updates the *same* document, so a duplicate attendance record is
structurally impossible, not just discouraged. `testResults` uses the
same trick (`<testId>_<studentUid>`) so re-entering a mark can never
create a second record either, and so a student can fetch their own
result with a plain `get()` instead of needing `list` permission on the
whole collection.

### Attendance identity and snapshots (Set 13)

The spec's duplicate-prevention identity is "Academic Session + Batch +
Date" for students - the id doesn't need a separate session segment
because a batch belongs to exactly one academic session (Set 10's
"a batch always belongs to exactly one session and one class" invariant),
so `<batchId>_<dateKey>` already uniquely determines session+batch+date;
adding `academicSessionId` into the id itself would be redundant, not
more correct.

`academicSessionId`/`classId` on the record ARE still worth storing
despite that redundancy, for a different reason: they're a **snapshot**
of the batch's session/class at the moment attendance was marked, not a
live join. If a batch's own session/class assignment were ever edited
later (rare, but the batch edit form allows it), a live join through
`batchId` would retroactively change which session/class a *past*
attendance record appears to belong to - exactly the kind of historical
rewrite Sets 10/11 already established snapshots to prevent for fee
data. The admin attendance history screen still falls back to resolving
session/class via the batch for any pre-Set-13 record that predates the
snapshot (`academicSessionId`/`classId` read back as `''`).

`createdBy`/`updatedBy` replace the single `markedBy` field Set 4 used
for both - `markedBy` is preserved as a read-only fallback
(`StudentAttendanceRecord.fromMap`/`TeacherAttendanceRecord.fromMap`) so
a record marked before Set 13 still reports a sensible value for both,
but every write from Set 13 onward always populates the new pair and
never re-emits `markedBy`.

### Efficient bulk save (Set 13)

Student attendance was always a single write per batch/date (`records`
already covers every student in one document) - nothing to batch.
Teacher attendance is one document *per teacher* per date (so each
teacher can `get`/`list` their own independently - see "Role
authorization" below), which meant marking a whole day's staff used to
take one write per teacher-tap. `AttendanceController.
markTeacherAttendanceBulk` now stages every teacher's status locally in
the UI and commits them all in a single Firestore `WriteBatch` when
admin taps Save - one atomic network round-trip for the whole day's
staff, matching the spec's "do not make one unnecessary network write
per record if the architecture can safely batch them" while keeping
each teacher's record independently queryable exactly as before.

### Test/subject wiring, status and future result compatibility (Set 14)

`TestDefinition.subject` was free text through Set 4-13 (the same gap
Set 9's own scope boundary flagged and left for a future set). Set 14
adds `subjectId` referencing `subjects/{subjectId}` (Set 9) by stable
id, only ever offered from the *selected class's* own
`SchoolClass.subjectIds` (never a flat, unconstrained subject list) -
"Class 5 with Science" and "Class 9 with Physics/Chemistry/Biology" stay
impossible to mix up because the subject dropdown is built from the
class's own configured list, not every subject in the institute.
`academicSessionId`/`classId` are added alongside for the same snapshot
reason as attendance's Set 13 fields (see above): a batch's own
session/class could technically be edited later, and a snapshot keeps a
past test's academic context from silently drifting if that happens.
`subject` itself remains a resolved display string (not removed) so the
student-results screen and the Set 6 test-result export keep reading a
plain name unchanged.

`TestType`'s values changed from the Set 4 question-FORMAT axis
(objective/subjective/mixed) to the Set 14 spec's occasion-CATEGORY axis
(Unit Test/Monthly Test/Weekly Test/Half-Yearly/Final/Other) - a
different concept the spec asks "Test type" to mean, not an additional
field alongside the old one. A pre-Set-14 test's stored
objective/subjective/mixed value is migrated on read
(`TestDefinition.fromMap`) to `TestType.other` with the original word
preserved in `otherTestTypeLabel` (e.g. "Objective") - it is never
lost, and reading an old test never crashes.

**Status**: rather than a bespoke draft/published/closed lifecycle,
Set 14 adds one `active` boolean reusing the exact convention already
established for Batch/Teacher/Student ("prefer deactivation over
destructive deletion"). Combined with the existing `resultPublished`
boolean, this already distinguishes every state the spec asks for -
active+unpublished ("marks still being entered"), active+published
("finalized"), and inactive ("archived") - without a third status
field. `testUpdateIsValid()` in `firestore.rules` was widened from
"only `resultPublished` may ever change" to also allow `active`,
independently and in both directions (unlike `resultPublished`, which
still only ever goes `false` -> `true`); every other field on a test
remains fixed after creation - "the offline test already happened,
there's nothing else to edit" still holds.

**Future Result/Reports compatibility (Set 14 spec, not built here)**:
a test's `academicSessionId`/`classId`/`batchId`/`subjectId` and a
result's `testId`/`studentUid` are exactly the references a future
Result set needs to compute a subject-wise mark, a combined multi-
subject total (several tests -&gt; one student -&gt; one row - see
`combineMarks` in `core/utils/marks_combiner.dart`, already built and
already reused by the Set 6 test-result export screen), a rank, or a
batch-wide result - nothing here is redesigned to serve that later, it
already fits.

### Absent vs. zero (Set 14)

`TestResult.isAbsent` distinguishes three states the spec requires kept
apart: **not yet entered** (no `TestResult` document exists for that
student at all - the marks-entry screen shows an empty field),
**absent** (`isAbsent: true`, `obtainedMarks: null` - a real record
saying the student did not attempt it, not a hidden zero), and
**present with a score** (`isAbsent: false`, `obtainedMarks` a number
`0..totalMarks`). `firestore.rules`' `marksAreValid()` enforces exactly
this either/or shape server-side, not just in the UI. `combineMarks`
(used by multi-test/multi-subject exports) already treats a `null`
mark - whether from "not entered" or "absent" - as contributing `0` to
the combined total while still counting the test's max marks in the
denominator, so an absence still lowers a combined percentage rather
than being silently excluded from it; a future Result set is free to
treat "absent" differently from "not entered" since the two remain
distinguishable on the record itself.

### Bulk marks save (Set 14)

`EnterMarksScreen` now stages every student's mark/absent toggle
locally and saves the whole sheet in one `TestController.saveMarksBulk`
call, which commits every changed `TestResult` in a single Firestore
`WriteBatch` - the same "one write batch per Save tap, not one write
per student" pattern Set 13 established for teacher attendance. Marks
range validation (`0 &lt;= marks &lt;= totalMarks`, per student) runs
against every staged entry before any write is attempted, so an invalid
sheet fails as a whole rather than partially saving - "do not display
success unless the complete intended operation succeeded" (Set 14
spec).

**"Do not expose unpublished marks to students"** is enforced in
`firestore.rules`, not just the UI: a student's `get` on `testResults` is
only allowed once the *parent test's* `resultPublished` field is `true`
(checked via a `get()` on `tests/{testId}` from inside the rule). Test
*metadata* (title, date, subject) is visible to the batch as soon as it's
created - only the marks are gated.

**Why tests aren't restricted to "only the assigned teacher"**: a
teacher's `subjectIds` (see `teachers/{uid}` above and "Teacher/subject
relationship (Set 12)") names *subjects* a teacher is capable of
teaching, while a test references a *batch id* - there is still no link
from a teacher to a specific batch (Set 12 deliberately didn't build
one - see that section). Rather than build a fragile cross-reference,
any active teacher may *read* any batch's tests (writes are admin-only
as of Set 14 regardless); the create screen still only offers batches
that exist, so this is a scope decision (documented, not a bug), not a
security gap - the real boundary that matters (teacher vs. student vs.
admin) is still fully enforced. Homework/assignments (Set 16) make the
same missing-link observation but land on a different, stricter answer
for *writes* specifically - see below.

## Homework and assignments, unified (Set 16)

The separate `homework`/`assignments` collections from Set 4 predate
this project's subject/session/class master data entirely - free-text
`subject`, no `academicSessionId`/`classId`, and two near-identical
schemas (`completionStatus` "pending"/"completed" vs. `status`
"active"/"closed", one with a `title` field and one without) for what
is, functionally, the same kind of record. Set 16 replaces both with a
single `academicWork` collection carrying a `type` field - "do not
create two completely duplicated database structures" (spec) - rather
than wiring master data into two parallel structures that would still
need to agree with each other.

### Why teacher creation is disabled, not merely "unrestricted" like tests

This is the one place Set 16 makes a **stricter** call than every
collection before it (tests, attendance, homework/assignments as they
existed pre-Set-16) that shares the identical missing-link problem:
`TeacherProfile.subjectIds` (Set 12) says which **subjects** a teacher
may teach; nothing anywhere says which **batches** they may write to,
because Teacher -> Batch assignment has never been built (Set 12's own
explicit scope boundary, still true today). Every earlier collection
resolved this by granting *any* active teacher broad write access
regardless of batch (a deliberate, documented scope decision, not an
oversight - see "Why tests aren't restricted..." above). Set 16's own
spec explicitly asks for the opposite fallback instead: *"if the
current architecture cannot safely determine teacher batch
authorization, allow Admin creation and keep teacher creation disabled
until the dedicated teacher assignment module exists."* So
`academicWork`'s `create`/`update` rules are `isAdmin()`-only, full
stop - no `isTeacher()` branch at all (matching exactly how Set 14
already narrowed `tests`/`testResults` writes to admin-only, but this
time also true for the initial *reads-only* framing teachers get here:
teachers keep the same broad `get`/`list` access as before, so they can
still see homework/assignments for their subjects, published/closed
tests, etc., but the "create" door is closed until a real teacher-batch
assignment module exists to open it safely). Building a fake batch
authorization scheme just to unblock teacher-side creation would be
worse than not having the feature - a wrong permission model is a
security bug, a missing feature is not.

### Status lifecycle: freely reversible, unlike Test's one-way `resultPublished`

`draft` -&gt; `published` -&gt; `closed`, and back again in either direction -
deliberately not one-way like Set 14's `resultPublished` (which only
ever flips `false` -&gt; `true`, since an offline test's result, once
shared, shouldn't un-happen). Homework/assignments are more mutable in
practice - an admin may need to unpublish a mistake, or reopen a closed
item - so `academicWorkUpdateIsValid()` allows any of the three values
in `status` on every update, while the four *academic reference* fields
(`academicSessionId`/`classId`/`batchId`/`subjectId`) plus `type`/
`createdBy`/`createdAt` stay permanently locked once created (only
`subject`/`title`/`description`/`assignedDate`/`dueDate`/`status`/
`updatedAt` may ever change) - the same "preserve the historical
reference, allow editing the content" split already used for Batch/
Test.

### Student/parent visibility and the query-shape requirement, again

A student may only ever see their current batch's **published or
closed** work, never a draft (Set 16 spec, enforced in
`firestore.rules`, not just hidden in the UI). This repeats the exact
"Firestore query-shape requirement" lesson documented below for
attendance: a `list` rule with a per-document condition (here,
`resource.data.status in ['published', 'closed']`, on top of the usual
`isStudentOfBatch(resource.data.batchId)`) can only be satisfied by a
query that is *itself* constrained the same way - an unconstrained scan,
or one filtered by `batchId` alone, is rejected outright for that rule
branch regardless of what the actual data holds. `studentVisibleAcademicWorkProvider`
therefore always issues `.where('batchId', '==', ...).where('status',
whereIn: ['published', 'closed'])` together, never separately - two
plain equality-family filters on different fields, which Cloud
Firestore's automatic indexing already covers without a manually
defined composite index (this project's `firestore.indexes.json` stays
empty, as it has through every earlier set). A single-document `get()`
by known id has no such constraint (there's no query to shape), so the
`get` branch of the same rule uses the simpler `status != 'draft'`.

### Overdue is calculated, never stored

`AcademicWork.isOverdue(now)` is a plain method (`status ==
AcademicWorkStatus.published && now.isAfter(dueDate)`), never a
persisted field - "do not let an outdated stored flag become incorrect"
(spec). A draft or closed item is never "overdue" - overdue only means
something for work that's still actively published and unmet.

### No paid storage, and future submission-system compatibility

`description` is plain text - no attachments, no file upload, exactly
as the spec requires ("text-based homework/assignment content is
sufficient... do NOT introduce Firebase Storage or another paid
storage service"). Nothing here prevents a future set from adding a
real submission system (a `submissions` subcollection keyed by
student uid, say) - `academicWork`'s own shape doesn't need to change
for that, matching the same "design doesn't block the future feature,
without building it now" philosophy already used for Batch's
`NegotiatedFee`-adjacent groundwork and Teacher's `subjectIds`.

**Notification event hooks**: `recordNotificationEvent()`
(`core/services/notification_hook.dart`) writes one `notifications`
document whenever homework/an assignment/a test is created or a result is
published. This is *not* a push-delivery mechanism - there are no Cloud
Functions in this project (see docs/architecture.md), so nothing turns
these into an actual FCM push yet. It's a durable, queryable trail in the
exact shape a future push sender or in-app notifications feed would
consume. No UI reads this collection yet, so read access is admin-only
for now (tightened/opened up once a consuming feature exists).

## Results & ranking (Set 15)

**No new collection.** Every Results screen re-derives its table from
the exact same `tests`/`testResults` documents Set 14 already writes,
in memory, on load - the spec's own "prefer calculated/derived result
data" and "do not create a second independent marks database". This
also means a result is only ever as stale as the underlying marks: there
is no separate "final result" record that could drift out of sync with
a later marks correction.

### Absent vs. incomplete vs. complete

`result_calculator.dart` (`lib/features/results/data/`) models exactly
three states per student per subject/test, via `SubjectCell`/
`CellStatus`:

- **present** - a `TestResult` exists, `isAbsent` is `false`, a numeric
  `obtainedMarks` - the only state that contributes a real percentage.
- **absent** - a `TestResult` exists with `isAbsent: true` (Set 14) -
  never treated as a zero score.
- **missing** - no `TestResult` document exists yet for that
  student/test - marks simply haven't been entered.

`ResultStatus.fromCells` rolls one or more cells up into a single
overall status - `complete` only when every cell is `present`; `absent`
if any cell is `absent` (checked first: a deliberate absence is a more
definite outcome than a merely not-yet-entered mark, so it takes
priority when a student is both absent in one subject and missing marks
in another); otherwise `incomplete`. A subject-wise result table
(`computeSubjectResults`) has exactly one cell per row, so its
`ResultStatus` is just that cell's own state; a combined result
(`computeCombinedResults`) rolls up several cells (one per selected
subject/test) into one status per student.

### Why an absent/incomplete row's total, percentage and rank are all `null` (not partial numbers)

For a `complete` row, `totalObtained`/`totalMaximum`/`percentage` are
computed via the same `combineMarks` helper the Set 6 test-result export
already used (`core/utils/marks_combiner.dart`) - sum of obtained marks
over sum of each test's own `totalMarks` (never assumed equal across
subjects). For an `absent`/`incomplete` row, all three are left `null`
rather than computed with the missing subject(s) counted as zero - "do
not calculate a misleading final percentage/rank" (Set 15 spec) is
enforced by never computing one in the first place, not by hiding a
computed value after the fact. The per-subject `cells` on a
`CombinedResultRow` still report exactly what is known for each
subject (a real mark, "Absent", or "-") even when the overall row can't
be finalized - only the row-level summary is suppressed.

### Ranking and ties

`rankByPercentage` (`core/utils/ranking.dart`) is `competitionRanks`
made null-aware: percentages are ranked with standard competition
ranking (92%, 92%, 88% -> 1, 1, 3, never 1, 2, 3 - Set 15 spec), and any
`null` percentage (absent or incomplete) is excluded from ranking
entirely and gets `null` back, rather than tying for the lowest rank or
receiving a placeholder number. This is the exact generalization of a
private helper the Set 6 export screen already had
(`_ranksFor`) - extracted into the shared utility and reused by both,
so the ranking rule is written and tested exactly once (Set 15 spec:
"do not duplicate calculation logic across multiple screens").

### Result context and eligibility

Every Results screen follows the same Session -> Class -> (matching
active batches) cascade as Attendance (Set 13) and Test creation
(Set 14), using `batchesForSessionAndClass` - no free-text session/
class/batch/subject matching anywhere. The student roster for a result
is the batch's active students, plus - exactly like the attendance and
marks-entry screens - any student who already has a `TestResult` for
the relevant test(s) but has since left the batch or gone inactive, so
a historical result never silently disappears because of an unrelated
later status change (Set 15 spec: "historical results must remain
understandable even if a student becomes inactive").

### Combined result: real per-subject tests, never a fabricated shared id

A Set 14 test belongs to exactly one subject - there is no "assessment"
concept spanning subjects. `CombinedResultScreen` reflects this
directly: admin checks which subjects to combine, and for each one
independently picks which of that subject's own tests to use (defaulting
to its most recent one). `computeCombinedResults` takes a plain list of
real `TestDefinition`s - one per selected subject - and never assumes or
invents a shared test id across them (Set 15 spec: "do not fabricate a
shared Test ID when the database has separate tests").

### Security

Results screens are admin-only routes (`/admin/results/...`) - not
reachable from any teacher or student route - and read the same
`tests`/`testResults` collections through the exact rules Set 14 already
established (`isAdmin() || isTeacher()` for `list`, gated per-student
publish check for a student's own `get`). No rule changes were needed
for Set 15: nothing here writes anything, and the existing read rules
already have no per-document dependency for the admin/teacher branches
that this feature actually uses, so every list here is a plain
unconstrained `watchAll()`, exactly like `allBatchesProvider`/
`allStudentsProvider` elsewhere.

## Public content, enquiries, callback requests and notifications (Set 5)

```
institutes/main                          singleton - the id is always
                                           "main", never a generated one
  name, tagline, about, contactPhone, contactEmail, address (all optional
  except name)
  updatedAt

gallery/{itemId}
  imageUrl, title, description, category (all but imageUrl/title optional)
  active, createdAt, updatedAt

banners/{bannerId}
  imageUrl, title, description, ctaText, ctaUrl (optional)
  active, displayFrom, displayUntil (optional - see "isLive" below)
  createdAt, updatedAt

upcomingBatches/{upcomingBatchId}
  posterUrl (optional), title, className, board, academicSession
  startDate, timing, description (optional)
  admissionStatus   string, free text (e.g. "Admission open") - not an
                     enum, since the wording is the admin's call, not a
                     fixed state machine
  active, createdAt, updatedAt

advertisements/{advertisementId}
  posterUrl, title, description (optional), buttonText, buttonUrl (optional)
  active, startDate, endDate (optional - see "isLive" below)
  createdAt, updatedAt

announcements/{announcementId}
  title, body, active, createdAt, updatedAt

enquiries/{enquiryId}                    created by an unauthenticated
                                           visitor - see "Public writes"
  name, guardianName (optional), className, board (optional)
  primaryPhone, secondaryPhone (optional), message (optional)
  status   "newEnquiry" | "contacted" | "followUp" | "admissionDone" |
            "notInterested"   admin-managed only
  createdAt, updatedAt

callbackRequests/{callbackRequestId}     same visitor-write shape as enquiries
  name, phone, message (optional)
  status   "newRequest" | "contacted"
  createdAt, updatedAt

notifications/{notificationId}           extended from Set 4 - now also
                                           read back by NotificationsScreen
  type ("homework" | "assignment" | "test" | "result" | "feePayment" |
        "announcement")
  batchId (nullable - null means "broadcast", e.g. an announcement)
  studentUid (optional - a payment notification targets one student
              directly, independent of batch membership)
  title, body, relatedId, createdAt
```

**`isLive(now)`**: a banner/advertisement is only shown on the public site
while `active == true` AND (no display/active window is set, or `now`
falls inside it) - `displayFrom`/`displayUntil` and `startDate`/`endDate`
are both optional, so content without a configured window is simply
always live while active.

### Why images are plain URL strings, not Storage uploads

Firebase Storage is still not enabled on this project (see
docs/firebase-setup.md - staying on the free Spark plan is an explicit,
repeated decision). Every gallery/banner/advertisement/upcoming-batch
image field is therefore a plain string the admin pastes after hosting
the image elsewhere, exactly like every other "future Storage upload"
field in this project (teacher/student photos). Swapping in real uploads
later only touches the admin form (an upload widget replacing a text
field) - the model, rules, and public-facing rendering (`Image.network`)
don't change.

### Public writes: enquiries and callback requests

Both collections allow `create` with **no authentication required** -
this is the one deliberate exception to "every write requires a signed-in
account" in this project, because the whole point is letting a website
visitor who has no account submit one. The trade-off is contained
narrowly: `newEnquiryIsValid()`/`newCallbackRequestIsValid()` require the
exact expected field shape and `status` to start at the initial value
(`newEnquiry`/`newRequest`) - a submission can't smuggle in an arbitrary
status or extra fields. `get`/`list`/`update` stay admin-only, and
`delete` is never allowed on either collection (same append-then-manage
shape as everything else in this project - nothing is ever hard-deleted).

### Public reads: gallery/banners/upcomingBatches/advertisements/announcements/institutes

Each of the six content collections above allows `get`/`list` to anyone -
signed in or not - but only for documents where `active == true` (an
admin viewing their own admin screens always passes, via `isAdmin()`, so
they can still see inactive/draft content while managing it).
`institutes/main` has no `active` field at all - it's a singleton
profile, always meant to be visible, so it's simply `allow get, list: if
true`. Every `create`/`update` on all six requires `isAdmin()`; `delete`
is never allowed anywhere in this group either.

### The "once per session" ad popup

`AdPopupTrigger` (`features/public/presentation/ad_popup.dart`) picks the
first *live* advertisement and shows it in a dialog, but only once: a
plain in-memory Riverpod `StateProvider<bool>` (`adPopupShownProvider`)
flips to `true` the moment it's shown and is never reset until the app
actually restarts/reloads - which *is* a new session. This is
deliberately **not** `SharedPreferences` - that would persist "shown"
across restarts too, making it "once per install" instead of "once per
session," which is a different (and not what was asked for) rule. The
dialog always has a visible close `X` (`IconButton` positioned via
`Stack`), matching "must appear only once per app session... there must
be a visible close X."

### Notification targeting (extended)

`isTargetOfNotification()` in `firestore.rules` now covers three shapes
of `notifications` document, since Set 5 adds a payment-triggered
notification alongside Set 4's batch-wide ones:

- `batchId == null` - a broadcast (currently: announcements) - visible to
  every signed-in user.
- `studentUid` set and it's the caller's own uid - a personal notification
  (currently: fee payment recorded) - visible only to that student,
  independent of batch.
- otherwise, `batchId` set and the caller is an active student of that
  batch (homework/assignment/test/result events, same as Set 4).

Admin and teacher can always `get`/`list` every notification (needed for
oversight and to have created them in the first place); `update`/`delete`
stay denied to everyone - a notification is either created correctly or
not created, never edited after the fact.

## Saved export templates (Set 6)

```
reportTemplates/{templateId}
  name       string    e.g. "Basic Student List"
  module     "studentExport" | "feeDuesExport" | "testResultExport"
  config     map       free-form - whatever the owning export screen put
                        there (selected columns, filters, sort, format,
                        orientation); not interpreted or validated by
                        rules, since its shape varies per module and
                        carries no access-control meaning of its own
  createdAt, updatedAt
```

Admin-only, and - unlike every other collection in this project so far -
genuinely deletable: a saved template is a personal preference an admin
might want to remove, not a durable record like a payment or an
attendance mark. See docs/architecture.md's "The export/report engine"
for what actually goes into `config` per module, and why test-result
mode/batch/subject/test selections are deliberately *not* saved (they're
one-off per report, not a reusable preference).

## Report layout templates (Set 7)

```
reportLayoutTemplates/{templateId}
  name         string
  header:
    logoUrl                string | null    pasted URL - no Storage, same
                                              as every other image field
                                              since Set 5
    logoXFraction, logoYFraction, logoWidthFraction   number, 0..1 -
      fractions of the header area, set by dragging/resizing the logo in
      the designer (see LogoPlacement in core/export/report_branding.dart)
    instituteName, showInstituteName        string, bool
    tagline, showTagline                    string, bool
    address, showAddress                    string, bool
    contact, showContact                    string, bool
    otherText, showOtherText                string, bool
  footer:
    footerText, showFooterText              string, bool
    showSignature                           bool
    signatureLabel                          string  (e.g. "Authorized Signatory")
    showPageNumber                          bool
    showDate                                bool
    contactText, showFooterContact          string, bool
  createdAt, updatedAt
```

Text and its show/hide flag are stored separately (not "empty string
means hidden") so toggling something off doesn't lose what was typed -
`ReportLayoutTemplate.toBranding()` is what actually collapses each pair
to a single nullable field (null exactly when hidden or genuinely empty),
producing the plain `ReportBranding` snapshot every export builder
renders from. See docs/architecture.md's "Report layout templates" for
the full designer -> template -> branding -> PDF pipeline, and why
editing a template afterward can't change a report already generated
with it.

Admin-only, and - like `reportTemplates` (Set 6) - genuinely deletable:
a saved letterhead is a reusable asset the admin manages, not a durable
record. `header`/`footer` are validated only as maps at the rules level;
their nested shape carries no access-control meaning (same reasoning as
`reportTemplates.config`).

## Institute configuration, extended (Set 9)

```
institutes/main   (unchanged shape, three fields added)
  ...same fields as Set 5's institute profile...
  logoUrl          string | null   pasted URL - no Storage, same as
                                     every other image field
  secondaryPhone   string | null
  website          string | null
```

Additive only - the document is still the same Set 5 singleton, still
keyed `main`; existing readers of `name`/`tagline`/`about`/`contactPhone`/
`contactEmail`/`address` are unaffected.

## Academic master data (Set 9)

```
academicSessions/{sessionId}
  name        string            e.g. "2026-27"
  startDate   timestamp
  endDate     timestamp
  isActive    bool              exactly one session is ever true - see
                                  "Only one active session" below
  createdAt, updatedAt

classes/{classId}                deterministic id for seeded rows (e.g.
                                   "class9"), auto-id for admin-added ones
  name         string            e.g. "Class 9"
  sortOrder    number            display order, admin-editable
  active       bool
  subjectIds   list<string>      Subject document ids this class offers -
                                   the class-subject applicability link
                                   (see "Why subjectIds lives on the
                                   class" below)
  createdAt, updatedAt

boards/{boardId}                 deterministic id for seeded rows (e.g.
                                   "cbse"), auto-id for admin-added ones
  name      string                e.g. "CBSE", "BSEB", "Others" - "Others"
                                   is not special-cased in the schema
  active    bool
  createdAt, updatedAt

subjects/{subjectId}             deterministic id for seeded rows (e.g.
                                   "mathematics"), auto-id for admin-added
                                   ones
  name      string
  active    bool
  createdAt, updatedAt
```

### Why `subjectIds` lives on the class, not a join collection

The only lookup direction any future module needs is "which subjects
does this class offer" (e.g. a homework/test subject dropdown, once
those modules are wired to read this - see docs/architecture.md's Set 9
section for why that wiring isn't done yet). A field on `classes`
answers that directly with a `get()`; a separate
`classSubjects/{classId}_{subjectId}` join collection would need an
extra query for the exact same answer, with no offsetting benefit at
this project's scale (a handful of classes, a dozen subjects). Subject
*documents* stay their own collection (not embedded in each class)
because the same subject is referenced by multiple classes and is
managed independently (renamed/deactivated once, not per class).

### Only one active academic session

`AcademicSessionController.setActiveSession` performs an atomic
`WriteBatch`: it flips every other session's `isActive` to `false` and
the chosen one to `true` in a single commit. This is enforced
client-side, not by a Firestore rule - a rule evaluates one document
write at a time and cannot inspect sibling documents in the same
collection to enforce a collection-wide "at most one" invariant, and
getting this wrong has no security consequence (a display
inconsistency if two ever ended up active, never unauthorized data
access), so client-side atomicity is the right amount of engineering
for this, not a missing security control.

### Deterministic vs. auto-generated ids

Every seeded default (`seedDefaults()` in `AcademicConfigController`)
uses a deterministic id derived from its English name (`class9`, `cbse`,
`mathematics`, ...) so `subjectIds` and any future reference can name a
subject/class/board by a stable id that survives a display-name rename,
per Set 9's "use stable ids rather than relying on display names as
database identifiers". An admin-added entry beyond the seeded defaults
gets a normal auto-generated id (via `add()`), same as every other
admin-created collection in this project (batches, teachers, ...) - only
the *seeded* rows need predictable ids, since `seedDefaults()` has to be
able to tell "does this already exist" before writing.

### Data safety: no delete, ever

`firestore.rules` denies `delete` outright on all four collections above
(and on the extended `institutes/main`) - "prefer deactivation/archiving
over destructive deletion" for master data that a future record could
reference. As of Set 10, `batches` is the first live consumer
(`academicSessionId`/`classId`/`boardId`, above) - deactivating a
session/class/board instead of deleting it is what keeps a batch that
references it from ever pointing at a vanished document; `students`
still uses its own free-text `className`/`board` fields (see
docs/architecture.md) and is unaffected either way.

## Security posture (this phase)

`storage.rules` still **denies all reads and writes** - Storage itself
isn't enabled yet (see docs/firebase-setup.md), so teacher/student
**photos are not implemented** in Set 3 - deferred until Storage is
enabled; every other field is in place, so adding photos later is an
isolated change (a field + an upload widget), not a rework.

`firestore.rules` denies everything **except** the collections described
above:

- `users`, `teachers`: a signed-in user may always `get` their own
  document; only an admin may `get` someone else's, `list` the
  collection, `create`, or `update`. A teacher can read their own record
  but never write to it.
- `students`: `get`/`list` allow `isAdmin() || isTeacher() || isSelf(studentId)`
  (Set 8 - a teacher genuinely needs the roster to enter marks/mark
  attendance for a batch, same "any active teacher may work with any
  batch" scope decision already made for homework/assignments/tests, not
  a per-assignment restriction). Only admin may `create`/`update` - a
  teacher (or the student) can read but never write, including fee
  fields. **Known trade-off, flagged deliberately, not silently
  accepted**: because `finalFee`/`standardFee`/`feeReason` live on the
  same document, a teacher who can read a student's roster entry can
  also read that student's fee figures - there's no field-level
  redaction in Firestore rules (a rule is document-level allow/deny).
  Splitting fee data into an admin-only subcollection would close this,
  but wasn't done in Set 8 (the "no new business features" / "refactor
  only where justified" boundary for this phase - a bigger data-model
  change than fits "final hardening"). If this needs to be closed, do it
  as its own change: revisit the roster problem this rule exists for
  first, since removing `isTeacher()` outright would break mark entry
  and attendance marking again (see "Firestore query-shape requirement"
  below for why that broke once already).
- `students/{uid}/payments`: `isAdmin() || isSelf(studentId)` only - a
  teacher has **no** access to payment data at all, matching "teacher
  cannot modify fees" (and, more strongly, cannot even read them). Only
  admin may `create` (never update/delete - append-only).
- `students/{uid}/admissions` (Set 11): `isAdmin() || isSelf(studentId)`
  only - same "teacher has no fee access" posture as payments, stricter
  than the parent `students` document (which a teacher CAN read). Only
  admin may `create`; the only `update` ever allowed is flipping `active`
  to `false` when a newer admission supersedes this one - every
  financial/academic figure is otherwise permanent once created.
- `counters` (Set 11): admin-only `get`/`create`/`update`, `list` denied
  outright (nothing ever needs to enumerate counters, only read one by
  its known id) - see "Admission numbers" above. `nextNumber` may only
  ever increase.
- `batches`: any signed-in account may read (it's a shared reference
  catalogue, not personal data); only admin may write.
- `attendance`: admin-only to write; a student may `get`/`list` only
  records for their **current** batch (`isStudentOfBatch(resource.data.batchId)`
  - Set 8 changed this from a `records` map-membership check; see
  "Firestore query-shape requirement" below for why), a teacher any
  batch's, matching the homework/assignments/tests pattern.
- `teacherAttendance`: admin-only to write; a teacher may `get`/`list`
  only their own (`resource.data.teacherUid == request.auth.uid`).
- `academicWork` (Set 16, replacing `homework`/`assignments`):
  admin-only to create/update - teacher creation is deliberately
  disabled (see "Why teacher creation is disabled..." above), a
  stricter posture than every earlier collection with the same missing
  teacher-batch link; a teacher may still `get`/`list` broadly, same as
  tests. A student may read only their current batch's `published`/
  `closed` items, never a `draft`.
- `tests`/`testResults`: admin-only to create/update as of Set 14 (the
  spec's explicit "admin remains the sole authority... teachers must
  not automatically receive write access"); a teacher may still read
  all of both, same as before. A student may read only their current
  batch's tests, and their own `testResults`, only once published (see
  above).
- `notifications`: admin/teacher create; readable by admin/teacher and by
  whichever student(s) it targets (see "Notification targeting" above).
- `notices` (Set 17, NOT the same collection as `notifications` above -
  see "Notices (Set 17)" below): admin-only `create`/`update`, `delete`
  never allowed. Admin `get`/`list` unconstrained; a teacher only
  `published` notices with `targetKey in ['all', 'teachers']`; a
  student/parent only `published` notices whose `targetKey` matches
  their own current class/batch/broadcast. `users/{uid}/noticeReadStates`
  is `isSelf(userId)`-scoped `get`/`list`/`create` only - never `update`
  (immutable once created) - so one user can never see or change
  another's read state.
- `gallery`/`banners`/`upcomingBatches`/`advertisements`/`announcements`/
  `institutes`: public read of active content (see "Public reads" above);
  admin-only write.
- `enquiries`/`callbackRequests`: public, unauthenticated `create`;
  admin-only read/update; `delete` never allowed (see "Public writes"
  above).
- `reportTemplates`/`reportLayoutTemplates`: admin-only read/create/
  update **and** delete (see "Saved export templates" and "Report layout
  templates" above - the two collections in this project where
  client-side delete is actually allowed).
- `academicSessions`/`classes`/`boards`/`subjects` (Set 9): any signed-in
  account may read (shared reference catalogues, like `batches`);
  only admin may `create`/`update`; `delete` is never allowed (see
  "Academic master data" above).
- Every other planned collection (`fees`, `auditLogs`, ...) stays fully
  closed until the phase that implements it, so access rules are never
  written against guessed requirements.

## Firestore query-shape requirement (Set 8 - found and fixed)

A `list` (collection query) security rule is evaluated against the
**query itself**, not against results after the fact. If a rule's
non-privileged branch depends on a document field (`resource.data.X`),
Firestore can only allow the query when the query carries a matching
`.where()` clause on that same field - it can't run an unconstrained
scan and filter out the documents that fail the rule, because it can't
prove in advance that *every possible* result would pass. An
unconstrained `list` under such a rule is rejected outright with
`permission-denied`, even for a caller who could legitimately see some
of the collection.

This project had exactly that bug, systemically, since the sets that
introduced each collection: every "one batch's records/one teacher's
own records/one student's own notifications" provider did
`FirestoreRepository.watchAll()` (an unconstrained `collection.snapshots()`)
and filtered the result **client-side** in Dart. That only worked for an
admin caller (`isAdmin()` is a role-only check with no per-document
dependency, so Firestore can prove it unconditionally) - it silently
failed for the roles the screens were actually built for: a teacher's
own attendance history, a student's attendance/homework/assignments/
tests/notifications, and even the anonymous public site's
gallery/banners/upcoming-batches/advertisements/announcements (whose
`list` rule is `resource.data.active == true || isAdmin()` - a public
visitor, not being an admin, hits the exact same wall). Every "find my
own profile" lookup that `list`ed the whole `students` collection and
filtered to the caller's own uid had the identical problem, since
`students`' `list` rule was admin-only with no self-branch at all.

**The fix**, applied everywhere this pattern occurred:

- `FirestoreRepository.watchWhere(builder)` (`lib/data/repositories/firestore_repository.dart`) -
  a query-constrained sibling to `watchAll()`. Every batch-scoped
  provider (`batchAttendanceProvider`, `teacherOwnAttendanceProvider`,
  `batchTestsProvider`, `studentVisibleAcademicWorkProvider` - Set 16,
  `myNoticesProvider` - Set 17) now calls this with `.where(...)` clauses
  matching exactly what the rule checks, instead of `watchAll()` + a
  client-side `.where()` on the Dart list.
- `ownStudentProfileProvider(uid)` (`features/student/data/student_repository.dart`) -
  resolves the signed-in student's own record via `.watchById(uid)` (a
  `get`, always allowed for `isSelf`), replacing every "list all
  students, filter to my uid" call site across the student-facing
  screens (dashboard, fees, attendance/homework/assignments/results).
  `allStudentsProvider` itself is now documented admin/teacher-only.
- `activeGalleryItemsProvider`/`activeBannersProvider`/
  `activeUpcomingBatchesProvider`/`activeAdvertisementsProvider`/
  `activeAnnouncementsProvider` (`features/public/data/public_content_repositories.dart`) -
  `.where('active', isEqualTo: true)` variants for the public site;
  the original `allXProvider`s stay unconstrained for the admin
  management screens (where `isAdmin()` makes any query shape fine).
- `myNotificationsProvider` (moved to `features/notifications/data/`,
  since it now needs `currentUserAccountProvider` - `core/` can't import
  `features/`): admin/teacher get an unconstrained scan; a student gets
  **three** simple single-field queries (`batchId isNull`, `batchId ==`
  their batch, `studentUid ==` them) merged client-side via
  `package:async`'s `StreamGroup.merge`, deduplicated by event id. This
  was deliberately built as three simple queries rather than one
  `Filter.or(...)` composite query across two different fields - Cloud
  Firestore often requires a manually-created composite index for that
  shape, and a notification feed silently failing until someone
  remembers to create an index in the Console isn't an acceptable
  failure mode for this project.
- `students/{studentId}`'s rule gained an `isTeacher()` branch (see the
  security posture list above) so `enterMarksScreen`/`markStudentAttendanceScreen`-
  style roster lookups (by a teacher, now also query-constrained the
  same way admin's already were) actually work.
- `attendance/{recordId}`'s student branch changed from
  `resource.data.records.keys().hasAny([uid])` (a map-membership check
  with no clean query equivalent) to `isStudentOfBatch(resource.data.batchId)`
  (directly queryable via `.where('batchId', ==, ...)`, matching every
  other batch-scoped collection). Trade-off: this now reflects the
  student's **current** batch, not batch membership at the time
  attendance was taken - a student moved to a different batch loses
  access to the superseded batch's attendance history. Accepted:
  correctness of "can this query even run" beats preserving access to a
  batch the student is no longer in.

**Lesson for any future collection with a per-user or per-batch access
rule**: the provider that reads it must build the query with a
`.where()` matching what the rule checks, not `watchAll()` plus a
client-side filter - the latter looks correct in every manual admin
test (since admin bypasses the whole problem) and only fails for the
actual target user, which is exactly how this went unnoticed across
several sets.

**Two different "combine two fields" shapes, and why only one is used
for a single query**: `myNotificationsProvider`'s three-simple-queries
design above avoids `Filter.or(...)` across two different fields
(`batchId`/`studentUid`) - a logical OR, which commonly needs a
manually-created composite index. `studentVisibleAcademicWorkProvider`
(Set 16) and `myNoticesProvider` (Set 17) instead chain two `.where()`
calls - a logical AND (`batchId == ... AND status in [...]`, or
`targetKey in [...] AND status == 'published'`) - which Cloud Firestore
satisfies via its own automatic single-field indexes without a manual
composite index, the same "index merging" that already covers
equality-only queries. These are not the same query shape, and one
being safe doesn't imply the other is: reach for the three-queries-
merged-in-Dart pattern for an OR across fields, and a single chained
`.where()` for an AND.

## Notices (Set 17)

```
notices/{noticeId}
  title, message
  type          "general" | "academic" | "examTest" | "homework" |
                 "attendance" | "fee" | "event" | "important" | "other"
  otherTypeLabel (only when type == "other")
  audience      "all" | "students" | "parents" | "teachers"   - how the
                 admin describes who this is for
  scope         "institute" | "class" | "batch"   - how far it reaches;
                 always "institute" for audience "all"/"teachers"
  academicSessionId (nullable)   display-only snapshot of the session
                 active at creation time - NEVER part of targeting, see
                 "Current vs historical context" below
  classId (nullable)    set for scope "class" and "batch"
  batchId (nullable)    set only for scope "batch"
  targetKey      the ONE field every visibility check and every
                 recipient query actually depends on - see "Targeting:
                 one derived field, not four" below
  status         "draft" | "published" | "closed"   - one-way only,
                 see "Lifecycle" below
  createdBy, createdAt, updatedAt
  publishedAt (nullable)   set once, the moment status first becomes
                 "published" (immediately, if created already published)
  expiresAt (nullable)   display/"active list" concern only, never a
                 rules dependency - see "Expiry" below

users/{uid}/noticeReadStates/{noticeId}
  readAt         presence of this document means "read"; absence means
                 unread - nothing is ever written for an unread notice
```

### Notices (Set 17) vs the Set 4/5 notification event log

This project already had a `notifications` collection and a shared
`NotificationsScreen` before Set 17 (see "Public content, enquiries,
callback requests and notifications (Set 5)" above) - but that system is
a narrow, **auto-generated, read-only event trail**: other features'
controllers call `recordNotificationEvent`/`recordFeePaymentNotification`/
`recordAnnouncementNotification` (`core/services/notification_hook.dart`)
whenever something notification-worthy happens, and nobody ever creates,
edits, publishes, or reads-vs-unreads one of those events directly. Set
17 asks for something categorically different: an admin **authors**
content, chooses an **audience**, **publishes** it on their own schedule,
can **close** it later, and every recipient gets their own **read/unread**
state. Building that on top of (or by renaming) the existing collection
would have meant bolting a lifecycle, targeting model, and per-user read
state onto documents that other already-shipped controllers write in a
completely different, much narrower shape - a real risk of breaking Sets
4-16's existing notification hooks for a benefit (schema reuse) that
doesn't materialize, since the two feed opposite directions (one is
system-to-user, the other is admin-to-user). So Set 17 is a new,
separate collection (`notices`, not `notifications`) and a new, separate
feature folder (`features/notices/`, not `features/notifications/`) -
the two coexist, neither reads nor writes the other, and each role sees
both as two distinct dashboard entries ("Notifications" and "Notices").
Per Set 17's own section 25, nothing was added to make any existing
module (Tests/Results/Attendance/Homework/Fees) call into
`NoticeController` automatically - that stays a manual admin action.

### Audience targeting, and why there is no separate parent login

Set 17 asks for `NoticeAudience.students` and `NoticeAudience.parents`
to be independently selectable ("All Students", "All Parents", "Class 9
Students", "Class 9 Parents", ...). This project has never had a
separate parent account or login (see `users` collection's `role` enum:
`admin | teacher | student` only, and the Student/parent's own account
in "Role authorization, generally") - a parent uses the same account and
device session as their child. Consequently `NoticeAudience.students`
and `NoticeAudience.parents` are delivered **identically**: both resolve
to the exact same `targetKey` at the same scope (see below), so a
"Class 9 Parents" notice and a "Class 9 Students" notice targeting the
same class land in the exact same inbox for the exact same signed-in
accounts. `audience` only changes how the notice is *labelled* on the
admin's list and the recipient's details screen ("Intended for:
Parents") - it is never a second, narrower access boundary layered on
top of "student." This is a deliberate, explicit application of Set 17's
own instruction: "Do not create a separate parent profile architecture
in this set if it does not already exist. Reuse the current
authentication/access model."

### Targeting: one derived field, not four

A notice's eligibility depends on up to four fields at once (`audience`,
`scope`, `classId`, `batchId`), but Firestore can only prove a `list`
rule when the query is constrained to match every field the rule
depends on (see "Firestore query-shape requirement" below). Rather than
require a query with four separate `.where()` clauses (some of them
conditionally present depending on scope - a shape that changes per
notice and can't be expressed as one static query), `Notice.computeTargetKey`
collapses all four into one string, computed identically in Dart and in
`firestore.rules`' `expectedNoticeTargetKey` (there is no shared-code
path between the two, so they're kept in sync by hand and cross-
referenced in comments on both sides):

- `"all"` - the `all` audience, always institute-wide.
- `"teachers"` - the `teachers` audience, always institute-wide.
- `"students"` - `students`/`parents` audience, institute-wide.
- `"students:class:<classId>"` - `students`/`parents` audience, scoped
  to one class.
- `"students:batch:<batchId>"` - `students`/`parents` audience, scoped
  to one batch.

A recipient's whole feed is then a single query: `.where('targetKey',
whereIn: [the caller's own finite set of applicable keys]).where('status',
isEqualTo: 'published')` - two fields, but both equality-family (see the
"index merging" note above), the same shape already proven safe for
`studentVisibleAcademicWorkProvider`. A teacher's applicable keys are
always `['all', 'teachers']`; a student/parent's are `['all', 'students',
'students:class:<their current classId>', 'students:batch:<their
current batchId>']`, built from their own `students/{uid}` document via
`callerStudentDoc()` in rules and `ownStudentProfileProvider` in Dart.
Admin's own management list (`allNoticesProvider`) is an unconstrained
scan instead - `isAdmin()` is role-only, so any query shape is safe for
that branch, matching every other admin list in this project.

### Lifecycle: one-way, unlike `AcademicWorkStatus`

Draft -> Published -> Closed, but **one-way** - unlike Set 16's
`AcademicWorkStatus` (freely reversible in either direction, since that
spec explicitly allowed "un-publishing a mistake" or "reopening a closed
item"). Set 17's own spec only ever lists forward admin actions ("edit
draft / publish draft / close published notification" - never "reopen"
or "unpublish"), so this instead mirrors Set 14's one-way
`resultPublished`: `noticeEditIsValid` only allows content changes while
`status` stays `draft` (so a notice's title/message/type/expiry can
never change once anyone might have already seen it), `noticePublishIsValid`
only allows `draft -> published` (freezing content, stamping
`publishedAt`), and `noticeCloseIsValid` only allows `published ->
closed` (freezing content further, nothing else changes). A notice is
never deleted (`allow delete: if false`, matching "do not allow
dangerous destructive deletion of published notifications") - closing is
the only way a published notice stops being active, and it remains
fully visible in the admin's own history list afterward, exactly like a
closed `AcademicWork` item.

### Read/unread architecture

A massive per-notice array of recipient uids, or a write touching every
recipient's document whenever one notice is published, doesn't scale
and isn't needed at this project's size (~200 users total). Instead,
read state is a **per-user subcollection**: `users/{uid}/noticeReadStates/{noticeId}`,
one tiny document created **only** the moment that user opens that
notice (`NoticeDetailsScreen` calls `markNoticeRead` once, guarded by a
`_markedRead` flag so re-renders of the same screen don't retry the
write). Absence of a document means unread - nothing is ever written for
a notice the user hasn't opened yet, so publishing a notice to "all
students" is exactly one write (the notice itself), not one per
student. The read-state document is immutable once created
(`firestore.rules` denies `update` on it entirely) - there is no need to
ever "unread" something, so `markNoticeRead` checks
`myNoticeReadStatesProvider`'s current value first and skips the write
entirely if already marked, rather than relying on the rule to reject a
harmless no-op update.

`unreadNoticeCountProvider` is a plain derived `Provider<int>`:
`myNoticesProvider`'s current list minus whatever ids appear in
`myNoticeReadStatesProvider`'s current set - recalculated live from two
already-open streams, not a stored counter anywhere. At ~200 users and
at most a few hundred notices total, scanning the caller's own (tiny,
already-loaded) read-state subcollection in full is simpler and more
correct than maintaining a counter that could drift, matching Set 17's
own instruction to "prioritize correctness and simplicity over
premature optimization" at this scale.

### Security

- Admin: full `create`/`update` (subject to `newNoticeIsValid`/
  `noticeUpdateIsValid`'s one-way-lifecycle rules above) and unconstrained
  `get`/`list` (role-only, safe for any query shape). Never `delete`.
- Teacher: `get`/`list` only where `status == 'published'` and
  `targetKey in ['all', 'teachers']` - narrower than this project's usual
  "any active teacher may read broadly" (Tests/Attendance/AcademicWork),
  because Set 17's own spec explicitly scopes teacher visibility to
  "notifications intended for teachers," not everything. No `create`/
  `update` branch exists for `isTeacher()` at all - notice authoring is
  admin-only, full stop, with no analogue to Set 16's "no Teacher ->
  Batch module yet" fallback discussion, since Set 17 never asks for
  teacher authoring in the first place.
- Student/parent (one shared account - see above): `get`/`list` only
  where `status == 'published'` and `targetKey` is one of their own
  current class/batch/broadcast keys (`studentNoticeTargetKeys()`).
  Never a draft, never another class/batch's notice.
- Every role's read-state write is scoped to `isSelf(userId)` on the
  `users/{userId}/noticeReadStates` path segment itself - a per-path
  check, not a per-document one, so it needs no query-shape reasoning at
  all and one user can never touch another's read state.
- No rule anywhere lets a non-admin change `title`/`message`/`type`/
  `audience`/`scope`/`academicSessionId`/`classId`/`batchId`/`targetKey`
  - `noticeUpdateIsValid` is reachable by `isAdmin()` only, and even the
  admin branch keeps every targeting/identity field pinned to its
  original value via `noticeIdentityUnchanged`.

### Current vs historical context

A notice's own `academicSessionId`/`classId`/`batchId` are snapshotted
at creation and never change afterward, matching this project's usual
historical-integrity philosophy (Batch/Attendance/Test/AcademicWork all
do the same) - but unlike those collections, a notice's *visibility* is
deliberately based on the recipient's **current** class/batch, not a
snapshot of who was enrolled when it was created. A "Class 9" notice
reaches whoever is *currently* in Class 9 (via their live
`students/{uid}.classId`), for as long as it stays `published` - a
student who moves from Class 9 to Class 10 the next day stops matching
it immediately, and a student who newly joins Class 9 starts matching
it immediately, with no re-targeting step required. If a student moves
from Batch A to Batch B, the notice itself still says "Batch A" forever
(the snapshot), but that student simply stops seeing it, exactly as if
it had never targeted Batch B - "choose a clear and consistent rule and
document it" (Set 17 section 20). This is different from Set 16's
`AcademicWork`, where a moved student loses access to their *old*
batch's homework/attendance history entirely (an accepted trade-off
there); here there is no "history" question at all, because a notice's
audience is always evaluated against whoever is currently eligible, not
who was eligible when it was published.

### Expiry

`expiresAt` is optional and purely a display/"active list" concern -
`Notice.isExpired(now)` is computed on demand from the current time,
exactly like `AcademicWork.isOverdue`, never a stored boolean that could
drift stale. It is **not** a `firestore.rules` dependency: an
expired-but-still-`published` notice was legitimately visible to its
recipients and stays fully readable (via `get`/`list`) - expiry only
affects which section of `MyNoticesScreen` it renders in (the active
feed filters expired items out client-side), never Firestore access
itself. This keeps the query shape unchanged from the no-expiry case
(still just `targetKey`/`status`), avoiding a third field the rule and
every recipient query would otherwise need to agree on.

### Why push notifications are not implemented, and future compatibility

Set 17 explicitly asks for in-app notifications only, and this project
has no Cloud Functions (Spark plan, see "Why no Cloud Functions") to
trigger an actual FCM push from - the same reason `notifications`/
`NotificationEvent` (Set 4/5) never grew push delivery either (see "What's
deliberately not here yet" in docs/architecture.md). `Notice` is already
shaped so that adding push delivery later is additive, not a rework: it
already carries exactly what a push payload needs (`title`, `message`,
`type`, and enough targeting information - `audience`/`scope`/`classId`/
`batchId` - to know who to notify) the moment `status` becomes
`published`. A future Cloud Function (once/if this project moves to
Blaze) could watch for that transition and fan out FCM messages using
the very same `targetKey` grouping this document already computes -
nothing about the current model would need to change to support that.
