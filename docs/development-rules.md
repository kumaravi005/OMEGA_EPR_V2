# Development Rules

Ground rules for working on this codebase, carried forward from how Set 1
was built.

## Scope discipline

- Build only what the current phase/set asks for. Don't add screens,
  collections, or dependencies "while we're at it."
- Don't create empty feature folders for work that hasn't started. Add a
  `features/<name>/` folder when that feature is actually implemented.
- If a requirement is unclear or a needed value (Firebase project,
  credentials, assets, API key) is missing, stop and ask rather than
  inventing a placeholder that looks real.

## Architecture

- `core/` = reusable, feature-agnostic code (theme, Firebase provider
  wrappers, generic widgets, utils). Never import a `features/*` file
  from `core/`.
- `data/` = generic Firestore access (`FirestoreDataSource`,
  `FirestoreRepository<T>`). Feature-specific models and repositories live
  under their own `features/<name>/` folder and build on top of these,
  they don't duplicate CRUD logic.
- `features/<name>/` = one folder per business module (auth, students,
  fees, attendance, ...). Keep a feature's UI, state, and
  feature-specific logic together under its own folder.
- All institute-specific *operational* data (fees, batches, students,
  settings, announcements, ...) is Firestore-driven. Nothing operational
  is hardcoded in Dart — only branding/display constants belong in
  `core/constants/app_constants.dart`.

## State management

- Riverpod (`flutter_riverpod`), plain providers — no code generation
  (`riverpod_generator`, `freezed`). Keep it introspectable without a
  build step, given the project's small scale.
- Firebase SDK singletons are only ever accessed through the providers in
  `core/services/firebase_providers.dart`, never via
  `FirebaseAuth.instance` etc. directly in feature code — this keeps
  everything overridable in tests.

## Security

- Firestore and Storage rules default to **deny all**. Any new access
  must be an explicit, reasoned rule — never widen to `if true` or an
  unauthenticated `allow` as a shortcut.
- Never commit real credentials, API secrets, or service-account keys.
  Firebase client config (`firebase_options.dart`, `google-services.json`,
  `GoogleService-Info.plist`) is the one exception — it is not a secret
  and is meant to be committed.

## Before considering a change done

1. `flutter pub get`
2. `flutter analyze` — zero issues
3. `flutter test` — all passing
4. The app actually builds/runs (not just "compiles" — launch it)
5. No invented Firebase/config values anywhere in the diff

## Documentation

Update `docs/architecture.md`, `docs/database-architecture.md`, or this
file when a decision they describe changes — keep them describing what's
actually implemented, not aspirational future work.
