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
    admin/                  Admin account-management foundation.
      application/          AdminAccountController (create account via
                             Cloud Function; reset session / toggle active
                             via direct rule-gated Firestore writes).
      presentation/         AdminHomeScreen (account list), CreateAccountScreen.
    teacher/                presentation/TeacherHomeScreen - placeholder only.
    student/                presentation/StudentHomeScreen - placeholder only
                             (covers both Student and Parent).
    public/                 presentation/PublicHomeScreen - the one public,
                             no-login-required screen for now.
```

Every feature folder above is populated with only what Set 2 actually
needed. Folders for students, teachers (as a managed *record*, distinct
from the teacher app area), batches, fees, attendance, homework, etc. are
intentionally **not** created yet — they are added when the phase that
implements them starts.

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

- Full admin/teacher/student dashboards - Set 2 only proves role-based
  auth + routing with placeholder screens.
- The public website/content system (gallery, announcements, enquiries).
- Any feature folder beyond `auth`, `admin`, `teacher`, `student`,
  `public` (students-as-records, teachers-as-records, batches, fees,
  attendance, homework, assignments, tests, notifications, enquiries,
  reports, exports, settings).
- Changing a role after account creation, or deleting an account (admin
  deactivates via `active: false` instead).
- Firebase App Check.

These are built phase-by-phase in later sets.
