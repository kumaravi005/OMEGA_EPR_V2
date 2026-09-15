# Production Checklist

A practical, run-through-it checklist for putting Omega Education Centre
V2 in front of real staff/students, and for any significant change
afterward. This is not a CI pipeline — there isn't one (see
docs/firebase-setup.md) — it's a manual sequence for whoever has
`firebase login` access to the project.

## 1. Firebase project verification

- [ ] `.firebaserc` points at the intended project
      (`omega-education-centre-9a3b3` for this repository's own project —
      confirm this is still the project you mean to deploy to before
      running any `firebase deploy`).
- [ ] `firebase projects:list` shows you're logged in as an account with
      access to that project (`firebase login` if not).
- [ ] Firebase Console → the project → **Authentication** has the
      **Email/Password** sign-in method enabled.
- [ ] Firebase Console → **Firestore Database** exists and is in
      **Production mode** (not "test mode," which allows open read/write
      regardless of `firestore.rules`).
- [ ] Confirm the project is still on the **Spark (free) plan**, unless a
      deliberate, informed decision was made to upgrade — nothing in this
      app requires Blaze; an unexpected upgrade prompt anywhere is a sign
      something (accidentally) needs a Blaze-only feature and should be
      investigated before proceeding, not clicked through.

## 2. Authentication verification

- [ ] At least one `admin` account exists in `users/{uid}` (see
      docs/firebase-setup.md step 7 if not — this is the one manual,
      Console-only step; every other account is created from inside the
      app by an admin).
- [ ] Sign in as that admin from the actual production build (not just
      `flutter run` in debug) and confirm you land on the admin
      dashboard.
- [ ] Confirm an inactive account (`users/{uid}.active == false`) cannot
      sign in / gets signed out promptly if made inactive mid-session.
- [ ] Confirm signing in on a second device forces the first device's
      session to end (single-active-device policy) — this is intentional
      behavior, not a bug to work around.

## 3. Firestore rules verification

- [ ] `firestore.rules` compiles: `firebase deploy --only firestore:rules`
      refuses to publish a rules file with a syntax error, so a
      successful deploy already confirms this.
- [ ] The rules actually deployed are the ones in this repository — after
      deploying, open Firebase Console → Firestore Database → **Rules**
      tab and compare the "last published" timestamp/content against
      your local `firestore.rules`.
- [ ] Spot-check with real accounts, not just admin: sign in as a teacher
      and a student and confirm each can only reach what their role
      should (their own dashboard's modules) — a permission-denied
      surfaces as a friendly in-app message, never a raw exception.

## 4. Production build

```bash
flutter pub get
flutter analyze          # must report "No issues found!"
flutter test             # every test must pass
flutter build web --release
```

- [ ] All three commands succeed with no errors.
- [ ] `build/web/` was regenerated (check its timestamp) — an old build
      directory from a previous change is not a valid release artifact.

## 5. Deployment

**Firebase Hosting is not configured in this repository** (confirmed
again as of Set 28 — no `hosting` key in `firebase.json`, and no
`.firebase/` cache directory). `build/web/` is a plain static site that
can be served by **any** static web host (Firebase Hosting, Netlify, a
plain nginx/Apache server, GitHub Pages, etc.) — nothing about the app
itself requires Firebase Hosting specifically.

**Running `firebase init hosting` or `firebase deploy --only hosting` is
a one-time setup step and a user-facing production action — it must be
explicitly requested by you before it is run. It is not something to do
as a side effect of a code change.** When you're ready, the steps are:

1. `firebase init hosting` (choose the existing project,
   `omega-education-centre-9a3b3`; when asked for the public directory,
   enter `build/web`; answer "No" to configuring as a single-page app
   rewrite unless you know you want that; answer "No" to setting up
   automatic builds/deploys with GitHub unless wanted).
2. `firebase deploy --only hosting`
3. Verify the printed Hosting URL (`https://omega-education-centre-9a3b3.web.app`
   or similar) loads the app and Login works.
4. **Custom domain (optional)**: if you want the app on your own domain
   instead of the default `*.web.app`/`*.firebaseapp.com` one, that's a
   separate step done from Firebase Console → Hosting → **Add custom
   domain**, which will ask you to add a DNS record at your domain
   registrar — this needs you to own/control a domain already; nothing
   here invents or assumes one.

### Before the very first production deployment

- [ ] The real institute logo has been provided and the web/PWA icon
      files updated (see this file's "Known, accepted limitations"
      section below, and docs/architecture.md's Set 28 notes, for
      exactly what was still outstanding as of the last audit).
- [ ] Section 1-4 of this checklist all pass.
- [ ] You have explicitly decided (and, if Firebase Hosting, explicitly
      authorized) which host will serve `build/web/`.

Whichever host is used:

- [ ] The deployed URL loads the public home page without signing in.
- [ ] The deployed URL's Login screen successfully authenticates a real
      account.
- [ ] `firestore.rules` for this same project has already been deployed
      (see section 3) — a new app build does **not** deploy rules; they
      are two independent steps (see docs/firebase-setup.md's "Deploying
      an update").

## 6. Account verification (admin / teacher / student)

- [ ] **Admin**: can reach every admin module (students, teachers,
      teacher assignments, batches, attendance, tests, results,
      homework, notices, fees, reports, configuration) and cannot be
      blocked by a rule mistake — if any admin screen shows a
      permission error, stop and investigate before wider rollout.
- [ ] **Teacher**: create one real teacher account, assign it to at least
      one class/batch/subject via Teacher Assignments, sign in as that
      teacher, and confirm My Assignments/attendance/homework/tests only
      show that scope.
- [ ] **Student/Parent**: create one real student admission, sign in with
      its account, and confirm attendance/results/homework/notices/fees
      show only that student's own data.

## 7. Public site verification

- [ ] The public home page (no login) shows institute info, banners,
      upcoming batches, gallery, and public notices as currently
      configured by admin.
- [ ] Submitting the admission-enquiry form and the callback-request
      form both succeed and the new entries appear under Admin →
      Visitor enquiries / Callback requests.
- [ ] No student, teacher, fee, attendance, marks, or internal-notice
      data is visible anywhere on the public site or in its network
      requests.

## 8. Backup / recovery

This project has **no automated backup service** — adding one (e.g.
scheduled Cloud Functions exports) is explicitly out of scope (it would
require Cloud Functions / Blaze). Firestore itself keeps your data
durable against hardware failure, but that is not the same as protection
against a **mistake** (an admin bulk-editing the wrong records, a bad
`firestore.rules` deploy, an accidental client bug). Practical, free
options:

- **Before any bulk/administrative data change** (correcting many fee
  records, re-running `seedDefaults()`, editing `firestore.rules`): use
  Firebase Console → Firestore Database → **Import/Export** (or the
  `gcloud firestore export` CLI, which is free — you only pay the small
  Cloud Storage cost of *storing* the export, not for the export
  operation itself) to take an on-demand export first. Keep the export
  path/date noted somewhere so you know what it covers.
- **What's critical to have a recent export of**: `students` (+ their
  `admissions`/`payments` subcollections), `feePayments`, `teachers`,
  `teacherAssignments`, `attendance`, `teacherAttendance`, `tests`,
  `testResults`, `academicWork`, `notices`. These are the collections
  with no built-in "undo" beyond the app's own deactivate/reverse
  operations.
- **Firestore rules changes**: keep `firestore.rules` in this Git
  repository as the single source of truth (it already is) — `git log
  -- firestore.rules` is itself a complete history of every rules
  change, which doubles as a rollback path (`git show
  <commit>:firestore.rules`, then redeploy that content).
- **What NOT to expect**: point-in-time recovery, automatic daily
  backups, or an "undo" button - none of these exist without paid
  infrastructure this project deliberately doesn't use. If the
  institute's data grows valuable enough to need this, revisit as a
  deliberate future decision (e.g. Firestore's paid Point-in-Time
  Recovery feature), not something silently added.

## 9. Post-deployment smoke test

After every deployment (app build, rules change, or both):

- [ ] Public home page loads.
- [ ] Admin login works and the dashboard renders.
- [ ] Teacher login works and My Assignments renders.
- [ ] Student login works and the dashboard renders.
- [ ] One real write succeeds end-to-end for each role that can write
      (admin: e.g. toggle a batch active/inactive and back; teacher: mark
      attendance for an assigned batch if applicable) — a write is the
      one thing a stale/misdeployed rules file would break even though
      every read still looks fine.
- [ ] No browser console errors on the public home page (an anonymous
      visitor hitting a permission-denied read would show here).

## Known, accepted limitations (not release blockers)

- **Teacher attendance authorization**: a teacher's Firestore write
  access to `attendance` is role-based (`isAdmin() || isTeacher()`), not
  narrowed to their specific assigned batch at the rules level — Set
  23/24 investigated this in depth and confirmed Firestore Security
  Rules cannot safely check "any of this teacher's assignments, for an
  unknown subject" within the platform's document-access-call budget
  without duplicating assignment data or requiring Cloud Functions, both
  explicitly out of scope. The application UI only ever offers a
  teacher's own assigned batches; a deliberately crafted direct API call
  bypassing the app is the only way this could be exploited. See
  docs/database-architecture.md's "Teacher-scoped Firestore rules (Set
  23-24)" for the complete reasoning. This is a deliberate, documented
  trade-off, not an oversight.
- **Web/PWA icons are still Flutter's default placeholder logo**
  (`web/favicon.png`, `web/icons/*.png`) - the institute's real logo is
  already configurable at runtime (Admin → Configuration → Institute
  Profile, used on the public site and in generated report letterheads),
  but the static browser-tab/home-screen icon files were never replaced
  with real branding, since no local logo artwork file exists anywhere
  in this repository to generate them from (Set 27 and Set 28 both
  confirmed this by inspection). `web/manifest.json`'s `theme_color`/
  `background_color` were corrected in Set 28 to match the app's actual
  primary color (`#1E5AA8`, was Flutter's default `#0175C2`), but the
  icon PNGs themselves still need the institute's real logo artwork -
  see the Set 28 report for exactly what's needed and where to send it.
- **Android/iOS are registered in Firebase but were never the actual
  development target** - every screen in this app was built and tested
  as a web dashboard. The Firebase project has Android/iOS apps
  registered (`flutterfire configure` was run for all three platforms
  early on) and `android/app/google-services.json` exists, so
  `flutter build apk` would compile, but no screen has been reviewed for
  a phone-sized layout or touch-first interaction. Treat mobile app
  distribution as unstarted work, not a near-complete platform.
