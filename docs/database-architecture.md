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
  primaryMobile, secondaryMobile (optional)
  assignments   [{ className, subject }, ...]   a teacher may have many -
                                                  e.g. Class 5->Science AND
                                                  Class 7->Hindi
  createdAt, updatedAt

students/{uid}                  keyed the same as the matching users/{uid}
  uid, accountId
  name, fatherName, dateOfBirth, gender, address
  className, board, batchId, academicSession
  primaryMobile, secondaryMobile (optional)
  standardFee    number   snapshot of the batch's fee at admission time -
                           reference only, never used in calculations
  finalFee       number   the figure actually agreed - THIS is what every
                           payment/due calculation uses (see "Fee model"
                           below)
  feeReason      string | null   required whenever finalFee != standardFee;
                                  permanently stored, never silently dropped
  paymentPlan    "monthly" | "installment"
  active         bool
  createdAt, updatedAt

  students/{uid}/payments/{paymentId}      append-only - never edited/deleted
    amount     number
    date       timestamp
    mode       "cash" | "upi" | "bankTransfer" | "cheque" | "other"
    remark     string | null
    createdAt  timestamp
    createdBy  string (admin's uid)

batches/{batchId}
  name
  standardMonthlyFee       number
  standardInstallmentFee   number
  active                   bool
  createdAt, updatedAt
```

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
confusing negative "Due".

### Why payments are their own subcollection, not a top-level collection

`students/{uid}/payments` scopes naturally to rules (`isAdmin() ||
isSelf(studentId)`, same as the student's own document) and to queries
(the fee-dues screen never needs to query payments *across* students -
it filters `students`, then reads each matching student's own payment
subcollection). No composite index is needed anywhere in Set 3: every
list is fetched whole and filtered/sorted client-side, which is fine at
this project's scale (~200 students).

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
teacher"**: a teacher's `assignments` list (see `teachers/{uid}` above)
names *class* strings (e.g. "Class 5"), while homework/assignments/tests
reference a *batch id* - the two aren't the same concept in this system,
and there's no reliable server-side mapping between them yet. Rather than
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

## Security posture (this phase)

`storage.rules` still **denies all reads and writes** - Storage itself
isn't enabled yet (see docs/firebase-setup.md), so teacher/student
**photos are not implemented** in Set 3 - deferred until Storage is
enabled; every other field is in place, so adding photos later is an
isolated change (a field + an upload widget), not a rework.

`firestore.rules` denies everything **except** the collections described
above:

- `users`, `teachers`, `students`: a signed-in user may always `get`
  their own document; only an admin may `get` someone else's, `list` the
  collection, `create`, or `update`. A teacher/student can read their own
  record but can never write to it (including their own fee data) -
  matching "teacher cannot modify fee data" and "student can only access
  own account/data" exactly.
- `students/{uid}/payments`: same read access as the parent student
  document; only admin may `create` (never update/delete - append-only).
- `batches`: any signed-in account may read (it's a shared reference
  catalogue, not personal data); only admin may write.
- `attendance`/`teacherAttendance`: admin-only to write; a student may
  `get`/`list` only records that include their own uid (checked via the
  `records` map's keys), a teacher their own attendance only.
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
- Every other planned collection (`fees`, `subjects`, `academicSessions`,
  `reportTemplates`, `auditLogs`, ...) stays fully closed until the phase
  that implements it, so access rules are never written against guessed
  requirements.
