# Omega Education Centre V2

A coaching-institute management application (ERP) for Omega Education
Centre — students, teachers, teacher assignments, attendance,
tests/marks, results, homework, notices, fees, reports/exports, an A4
report-letterhead designer, and a public institute website with
admission enquiries. Built with Flutter + Riverpod on the frontend and
Firebase (Auth + Firestore only) on the backend, on the free Spark plan
for roughly 200 users.

The product is feature-complete as of Set 26 (see
[docs/architecture.md](docs/architecture.md) for the full set-by-set
history of what was built and why) and has gone through a production-
readiness pass (Set 27). This is a real, running application, not a
foundation/scaffold.

**Firebase, Cloud Functions, Storage, FCM**: this project deliberately
uses only Firebase Authentication and Firestore. There is no Cloud
Functions, Firebase Storage, or push notification (FCM) integration
anywhere, and none is planned — see docs/architecture.md's "Why no Cloud
Functions" and "What's deliberately not here yet" for the reasoning.
Every image field (institute logo, gallery, banners, student/teacher
photos) is a plain pasted external URL, not an upload.

## Getting started

1. Install [Flutter](https://docs.flutter.dev/get-started/install) (this
   project targets Flutter 3.44+, Dart 3.12+).
2. This repository is already connected to a real Firebase project
   (`omega-education-centre-9a3b3` — see `.firebaserc`,
   `lib/firebase_options.dart`). To point it at a **different** Firebase
   project instead, follow [docs/firebase-setup.md](docs/firebase-setup.md)
   step by step.
3. Install dependencies and run:

   ```bash
   flutter pub get
   flutter run -d chrome
   ```

## Testing and release build

```bash
flutter analyze
flutter test
flutter build web --release   # output: build/web/ — host as static files
```

Deploying a `firestore.rules` change:

```bash
firebase deploy --only firestore:rules
```

See [docs/production-checklist.md](docs/production-checklist.md) before
a real production deployment or a significant production change.

## Documentation

- [docs/architecture.md](docs/architecture.md) — folder structure, every
  feature module, and the reasoning behind each set's decisions.
- [docs/database-architecture.md](docs/database-architecture.md) —
  every Firestore collection's shape, security rules, and the
  reasoning behind the data model.
- [docs/firebase-setup.md](docs/firebase-setup.md) — how to connect the
  app to a Firebase project (already done for this repository; needed
  again only for a different project or a lost local config).
- [docs/development-rules.md](docs/development-rules.md) — the ground
  rules this codebase is built to.
- [docs/production-checklist.md](docs/production-checklist.md) — the
  practical checklist to run through before/after a production
  deployment.
