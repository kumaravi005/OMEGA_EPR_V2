# Architecture

Omega Education Centre V2 is a Flutter app (Dart, Riverpod) backed by
Firebase (Auth, Firestore, Storage, Cloud Messaging, Crashlytics).

## Folder structure

```
lib/
  main.dart                 Entry point: Firebase init, runApp
  app.dart                  Root MaterialApp widget

  core/                     Cross-cutting, app-wide code. No business logic.
    constants/              Compile-time constants (collection names, storage
                             paths, branding). Never operational data.
    theme/                  Colors, typography, spacing, ThemeData.
    routing/                Route name constants (expanded as screens are added).
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
    auth/                   Firebase Authentication wiring (AuthGate) and,
                             in a later phase, sign-in screens + role-based
                             navigation.
```

Only `core/`, `data/` and `features/auth/` exist right now. Folders for
admin, teacher, student, batches, fees, attendance, homework, etc. are
intentionally **not** created yet — they are added when the phase that
implements them starts, so the tree never contains empty scaffolding for
features that don't exist.

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

## What's deliberately not here yet

- Sign-in / sign-up forms, password reset, role-based redirects.
- Admin, teacher, student, or public dashboards.
- Any feature folder beyond `auth` (students, teachers, batches, fees,
  attendance, homework, assignments, tests, notifications, enquiries,
  reports, exports, settings).
- A full router (`go_router` or similar) — there is one screen so far.

These are built phase-by-phase in later sets.
