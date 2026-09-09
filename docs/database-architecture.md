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
- Every other planned collection (`fees`, `attendance`, `homework`, ...)
  stays fully closed until the phase that implements it, so access rules
  are never written against guessed requirements.
