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

## Attendance, homework, assignments, tests and results (Set 4)

```
attendance/{batchId}_{dateKey}          one record per batch/date - NEVER
                                          split by subject
  batchId, dateKey ("2026-09-10"), date
  records    { studentUid: "present" | "absent", ... }   every student in
                                                           the batch, in one map
  markedBy, createdAt, updatedAt

teacherAttendance/{teacherUid}_{dateKey}   one record per teacher/date
  teacherUid, dateKey, date, status ("present" | "absent")
  markedBy, createdAt, updatedAt

homework/{homeworkId}                   shared by the whole batch
  batchId, subject, date, description, dueDate
  completionStatus ("pending" | "completed"), remark
  createdBy, createdAt, updatedAt

assignments/{assignmentId}              same shape/access as homework
  batchId, subject, title, description, assignedDate, dueDate
  status ("active" | "closed"), teacherRemark
  createdBy, createdAt, updatedAt

tests/{testId}                          metadata only - the test is
                                          conducted on paper, offline
  batchId, subject, title, chapterTopic, date, totalMarks
  testType ("objective" | "subjective" | "mixed"), description
  resultPublished (bool)
  createdBy, createdAt, updatedAt

testResults/{testId}_{studentUid}       one document per test+student
  testId, studentUid, batchId
  obtainedMarks, totalMarks   (percentage computed client-side, never stored)
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

**"Do not expose unpublished marks to students"** is enforced in
`firestore.rules`, not just the UI: a student's `get` on `testResults` is
only allowed once the *parent test's* `resultPublished` field is `true`
(checked via a `get()` on `tests/{testId}` from inside the rule). Test
*metadata* (title, date, subject) is visible to the batch as soon as it's
created - only the marks are gated.

**Why homework/assignments/tests aren't restricted to "only the assigned
teacher"**: a teacher's `subjectIds` (see `teachers/{uid}` above and
"Teacher/subject relationship (Set 12)") names *subjects* a teacher is
capable of teaching, while homework/assignments/tests reference a
*batch id* - there is still no link from a teacher to a specific batch
(Set 12 deliberately didn't build one - see that section). Rather than
build a fragile cross-reference, any active teacher may manage any
batch's homework/assignments/tests; the create screens still only offer
batches that exist, so this is a scope decision (documented, not a bug),
not a security gap - the real boundary that matters (teacher vs. student
vs. admin) is still fully enforced.

**Notification event hooks**: `recordNotificationEvent()`
(`core/services/notification_hook.dart`) writes one `notifications`
document whenever homework/an assignment/a test is created or a result is
published. This is *not* a push-delivery mechanism - there are no Cloud
Functions in this project (see docs/architecture.md), so nothing turns
these into an actual FCM push yet. It's a durable, queryable trail in the
exact shape a future push sender or in-app notifications feed would
consume. No UI reads this collection yet, so read access is admin-only
for now (tightened/opened up once a consuming feature exists).

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
- `homework`/`assignments`/`tests`: admin or any active teacher may
  create/update; a student may read only their *current* batch's.
- `testResults`: admin/teacher create and read all; a student may `get`
  only their own, and only once published (see above).
- `notifications`: admin/teacher create; readable by admin/teacher and by
  whichever student(s) it targets (see "Notification targeting" above).
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
  `batchHomeworkProvider`, `batchAssignmentsProvider`,
  `batchTestsProvider`) now calls this with a `.where('batchId'/'teacherUid', isEqualTo: ...)`
  matching what the rule checks, instead of `watchAll()` + a client-side
  `.where()` on the Dart list.
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
