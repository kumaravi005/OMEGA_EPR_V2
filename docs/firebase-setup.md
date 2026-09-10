# Firebase Setup

This project has **not** been connected to a real Firebase project. No
Firebase values (API keys, project ID, app IDs, etc.) have been invented
or guessed anywhere in this codebase — `lib/firebase_options.dart` is a
placeholder that intentionally throws until you generate the real file.

Follow these steps in order. Steps 1-5 and 7 are one-time, done once by
whoever owns the Firebase project. Step 6 (`flutter run`) is what anyone
building the app runs locally each time.

## 1. Create the Firebase project

1. Go to <https://console.firebase.google.com/>.
2. Click **Add project**.
3. Name it (suggestion: `Omega Education Centre`). Firebase will generate a
   project ID such as `omega-education-centre-xxxxx` — note it down.
4. When asked about Google Analytics, either option is fine for this app;
   disabling it keeps the setup shorter.
5. Click **Create project** and wait for it to finish provisioning.

## 2. Register your app platforms

You can skip this — `flutterfire configure` in step 4 registers the
Android, iOS and Web apps for you automatically (using the package
name/bundle ID it detects from this project). It's only worth doing by
hand if you want to pre-register an app under a different identifier than
what's already in the project:

- **Android**: `android/app/build.gradle.kts` → `applicationId` (currently
  `com.omegaeducation.omega_epr_v2`).
- **iOS**: `ios/Runner.xcodeproj` → currently
  `com.omegaeducation.omegaEprV2`.

## 3. Enable the products this project uses

All from the Firebase console, left sidebar → **Build**:

| Product | Where | What to click |
|---|---|---|
| Authentication | Build → Authentication | **Get started**, then enable the **Email/Password** sign-in method (more providers can be added later) |
| Firestore Database | Build → Firestore Database | **Create database** → **Production mode** → pick a region close to your users (e.g. `asia-south1` for India) |
| Storage | Build → Storage | **Get started** → **Production mode** → same region as Firestore |
| Crashlytics | Build → Crashlytics | **Enable Crashlytics** (Android/iOS only — there is no web SDK for Crashlytics) |

The `firebase_messaging` package was removed in Set 8 (zero real call
sites anywhere in the app — there is no push-notification *sending*
feature, see docs/architecture.md's "What's deliberately not here yet"),
so there's nothing Cloud Messaging-specific to enable here.

**Storage requires the Blaze (pay-as-you-go) plan.** Since late 2024,
Firebase blocks creating a new Storage bucket on the free Spark plan —
the console will prompt you to **Upgrade project** first. This needs a
payment method on the account, so it's a deliberate decision, not
something to click through by default. Blaze still has a free-tier quota
(5GB stored, 1GB/day downloads) — you're only billed beyond that.

You can safely skip Storage entirely for now and come back to it later:
nothing in this codebase uploads or reads files yet (photos, gallery,
banners, etc. are future-phase features), so `storage.rules` simply won't
be deployed until Storage is enabled. Authentication and Firestore are
unaffected either way.

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
- write `ios/Runner/GoogleService-Info.plist` (macOS only — see the note
  below if you're running this on Windows/Linux).

These generated files are safe to commit — Firebase client configuration
is not a secret; access is controlled by the security rules in
`firestore.rules` / `storage.rules`, not by hiding these values. (`.env*`
and any `*service-account*.json` — real server-side credentials — are
already excluded via `.gitignore` and must never be added.)

If `flutterfire` isn't found after activating it, add Dart's global pub
bin directory to your `PATH` (e.g. `%LOCALAPPDATA%\Pub\Cache\bin` on
Windows) and restart your terminal. `flutterfire configure` also shells
out to `firebase --version` internally, so the Firebase CLI itself
(installed via `npm install -g firebase-tools`, typically at
`%APPDATA%\npm` on Windows) needs to be on `PATH` too — if it isn't,
`flutterfire configure` reports "Found 0 Firebase projects" and offers to
**create a new project**. Answer **no** if you ever see that prompt and
fix `PATH` instead; it means the CLI can't see your existing project, not
that one doesn't exist.

**iOS note (building on Windows):** `flutterfire configure` writes
`ios/Runner/GoogleService-Info.plist` by editing the Xcode project file,
which requires Xcode tooling that only exists on macOS. On Windows, the
command still succeeds and correctly fills in the iOS values inside
`lib/firebase_options.dart`, but the physical `.plist` file is not
created. This doesn't block Android/Web development. Before building for
iOS on a Mac, either re-run `flutterfire configure` there, or download
`GoogleService-Info.plist` manually from **Project settings → Your apps →
(iOS app)** in the console and drag it into the `Runner` target in Xcode.

## 5. Link the CLI to the project and deploy the security rules

```bash
firebase use --add
# select the project you created, give it the alias "default"

firebase deploy --only firestore:rules
# add ",storage:rules" once Storage has been enabled (see the note above)
```

This publishes the default-deny rules in `firestore.rules` (and
`storage.rules` once Storage exists — see docs/database-architecture.md
for what they cover).

## 6. Run the app

```bash
flutter pub get
flutter run -d chrome   # or an Android emulator / device
```

With Firebase configured, the app's foundation screen should show
**"Signed out — sign-in screens are added in the authentication phase."**
instead of the "Unable to reach authentication service" error you'd see
without a real Firebase project connected.

## 7. Create the first admin account

There is no sign-up screen anywhere in the app, by design (see
docs/database-architecture.md). Every account after this one is created
from inside the app itself, by an admin - but the very first admin has
to be created manually, once, here in the console. No Cloud Functions,
billing upgrade, or command-line tooling needed for this step.

Pick an Account ID (e.g. `admin1` - lowercase, 3-24 characters, letters/
numbers/`.`/`_`/`-`) and a password (8+ characters) before you start.

1. **Authentication -> Users tab -> Add user.**
   - Email: `<your accountId>@omegaerp.local` (e.g. `admin1@omegaerp.local`
     - must match exactly, including the `omegaerp.local` part).
   - Password: the password you picked.
   - Click **Add user**. The new row shows a **User UID** - copy it, you
     need it in the next step.
2. **Firestore Database -> Data tab -> Start collection** (or **+ Add
   document** if a `users` collection already exists).
   - Collection ID: `users`.
   - Document ID: paste the **User UID** from step 1 (not auto-ID).
   - Add these fields (use the type picker next to each field name):

     | Field | Type | Value |
     |---|---|---|
     | `uid` | string | the same User UID |
     | `accountId` | string | the accountId you picked, lowercase (e.g. `admin1`) |
     | `role` | string | `admin` |
     | `displayName` | string | your name |
     | `active` | boolean | `true` |
     | `createdAt` | timestamp | current date/time |
     | `updatedAt` | timestamp | current date/time |
     | `lastLoginAt` | null | (select the "null" type) |
     | `session` | null | (select the "null" type) |
   - Click **Save**.
3. In the app, sign in with the Account ID and password you picked. You
   should land on the admin screen and be able to create further
   admin/teacher/student accounts from there - see
   docs/database-architecture.md for exactly how that works.

## Deploying an update (Set 8)

Two independent things get deployed - do both whenever a change touches
`firestore.rules`, and always rebuild before distributing a new app
build:

```bash
# 1. Firestore rules - whenever firestore.rules changes
firebase deploy --only firestore:rules

# 2. The app itself - production builds
flutter build web --release      # output: build/web/ - host as static files
flutter build apk --release      # output: build/app/outputs/flutter-apk/app-release.apk
```

There is no CI/CD pipeline in this project - deployment is these two
manual commands, run by whoever has `firebase login` access to the
project. Rules changes take effect within seconds of deploying; an app
rebuild only affects users the next time they load the web app or
install the new APK (nothing auto-updates a running session).

**Before every rules deploy**, run `firebase deploy --only firestore:rules`
first against your own account for a quick sanity check - the CLI
refuses to release rules that fail to compile, so a syntax mistake is
caught before it reaches production, but a *logic* mistake (the wrong
role check, a missing `.where()` clause the client needs - see
docs/database-architecture.md's "Firestore query-shape requirement")
is not caught by the compiler and needs an actual signed-in test per
role to catch.

## Not set up yet, by design

- **Cloud Functions / the Blaze plan**: deliberately avoided. The project
  stays on the free Spark plan - account creation and single-device
  session enforcement are both done with Firestore rules + a client-side
  technique instead (see docs/architecture.md's "Why no Cloud
  Functions"). Nothing in this project needs Blaze.
- **Cloud Storage**: deferred until it's actually needed, since enabling
  it requires upgrading the project to the Blaze plan (see the note in
  step 3). The `firebase_storage` package was removed in Set 8 (it had
  no real call sites - every image field in this app is a plain pasted
  URL, not an upload); `storage.rules` still exists and denies
  everything, but there's no bucket to deploy it to yet either way. Only
  install the package again when a feature actually needs it.
- **Firebase App Check**: deferred to a later security-hardening phase.
  It requires reCAPTCHA/Play Integrity/DeviceCheck registration per
  platform, which only makes sense once there are real endpoints beyond
  the default-deny rules to protect.
- **Push notification sending**: `firebase_messaging` was removed in Set
  8 for the same reason as Storage above - no feature calls it.
  In-app notification *records* exist (see docs/database-architecture.md's
  "Public content, enquiries, callback requests and notifications") and
  are read back by a shared feed; nothing pushes them to a device yet.
  Re-adding the dependency is a one-line pubspec change if/when that's
  built.
