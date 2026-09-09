# Omega Education Centre V2

A coaching-institute management application for Omega Education Centre —
Flutter + Riverpod on the frontend, Firebase (Auth, Firestore, Storage,
Cloud Messaging, Crashlytics) on the backend.

The product is being built phase-by-phase. This repository currently
contains the **project foundation** only: architecture, Firebase wiring,
Firestore/Storage security posture, and the base app theme. See
[docs/architecture.md](docs/architecture.md) for what exists and why.

## Getting started

1. Install [Flutter](https://docs.flutter.dev/get-started/install)
   (this project targets Flutter 3.44+, Dart 3.12+).
2. Connect the project to a real Firebase project — follow
   [docs/firebase-setup.md](docs/firebase-setup.md) step by step.
3. Install dependencies and run:

   ```bash
   flutter pub get
   flutter run
   ```

## Documentation

- [docs/architecture.md](docs/architecture.md) — folder structure and the
  reasoning behind it.
- [docs/firebase-setup.md](docs/firebase-setup.md) — exact steps to
  connect a real Firebase project.
- [docs/database-architecture.md](docs/database-architecture.md) —
  planned Firestore collections and Storage layout.
- [docs/development-rules.md](docs/development-rules.md) — rules this
  codebase is built to.
