# Firebase Setup

This project has **not** been connected to a real Firebase project. No
Firebase values (API keys, project ID, app IDs, etc.) have been invented
or guessed anywhere in this codebase — `lib/firebase_options.dart` is a
placeholder that intentionally throws until you generate the real file.

Follow these steps in order. They only need to be done once per
environment (you, and later anyone else building the app, run steps 8–10
locally).

## 1. Create the Firebase project

1. Go to <https://console.firebase.google.com/>.
2. Click **Add project**.
3. Name it (suggestion: `Omega Education Centre`). Firebase will generate a
   project ID such as `omega-education-centre-xxxxx` — note it down.
4. When asked about Google Analytics, either option is fine for this app;
   disabling it keeps the setup shorter.
5. Click **Create project** and wait for it to finish provisioning.

## 2. Register your app platforms

Do this from **Project settings → Your apps** (gear icon, top left) —
add one entry per platform you intend to ship:

- **Android**: package name must match `android/app/build.gradle.kts` →
  `applicationId` (currently `com.omegaeducation.omega_epr_v2`).
- **iOS**: bundle ID must match `ios/Runner.xcodeproj` → currently
  `com.omegaeducation.omegaEprV2`.
- **Web**: register a web app (no extra values needed up front).

You don't need to download any config files by hand here — step 4 does
that for you.

## 3. Enable the products this project uses

All from the Firebase console, left sidebar → **Build**:

| Product | Where | What to click |
|---|---|---|
| Authentication | Build → Authentication | **Get started**, then enable the **Email/Password** sign-in method (more providers can be added later) |
| Firestore Database | Build → Firestore Database | **Create database** → **Production mode** → pick a region close to your users (e.g. `asia-south1` for India) |
| Storage | Build → Storage | **Get started** → **Production mode** → same region as Firestore |
| Crashlytics | Build → Crashlytics | **Enable Crashlytics** (Android/iOS only — there is no web SDK for Crashlytics) |

Cloud Messaging needs no separate "enable" step — it activates once you
register a platform in step 2. Uploading an APNs key for iOS push is only
needed once notification *features* are built, not for this foundation.

## 4. Install the tooling and generate `firebase_options.dart`

Run these from the project root (`OmegaV2/`):

```bash
# One-time global installs
npm install -g firebase-tools
dart pub global activate flutterfire_cli

# Log in to the Google account that owns the Firebase project
firebase login

# Generate lib/firebase_options.dart + platform config files
flutterfire configure
```

`flutterfire configure` will:
- ask you to pick the Firebase project you created in step 1,
- ask which platforms to configure (choose Android, iOS, Web),
- **overwrite `lib/firebase_options.dart`** with real values,
- write `android/app/google-services.json`,
- write `ios/Runner/GoogleService-Info.plist`.

These generated files are safe to commit — Firebase client configuration
is not a secret; access is controlled by the security rules in
`firestore.rules` / `storage.rules`, not by hiding these values. (`.env*`
and any `*service-account*.json` — real server-side credentials — are
already excluded via `.gitignore` and must never be added.)

If `flutterfire` isn't found after activating it, add Dart's global pub
bin directory to your `PATH` (e.g. `%LOCALAPPDATA%\Pub\Cache\bin` on
Windows) and restart your terminal.

## 5. Link the CLI to the project and deploy the security rules

```bash
firebase use --add
# select the project you created, give it the alias "default"

firebase deploy --only firestore:rules,storage:rules
```

This publishes the default-deny rules in `firestore.rules` and
`storage.rules` (see docs/database-architecture.md for what they cover).

## 6. Run the app

```bash
flutter pub get
flutter run -d chrome   # or an Android emulator / device
```

With Firebase configured, the app's foundation screen should show
**"Signed out — sign-in screens are added in the authentication phase."**
instead of the "Unable to reach authentication service" error you'd see
without a real Firebase project connected.

## Not set up yet, by design

- **Firebase App Check**: deferred to a later security-hardening phase.
  It requires reCAPTCHA/Play Integrity/DeviceCheck registration per
  platform, which only makes sense once there are real endpoints beyond
  the default-deny rules to protect.
- **Cloud Functions**: none exist yet — nothing in Set 1 requires
  server-side logic.
- **Push notification sending**: Cloud Messaging is registered as a
  dependency/foundation only; composing and sending notifications is a
  future feature.
