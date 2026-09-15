# branding/

The institute's source logo artwork, kept here so the web/PWA icon files
can be regenerated later without asking for the logo again.

- `logo.png` — the real Omega Education Centre logo (provided Set 28).
  Square, transparent corners outside the rounded badge shape.

This folder is **not** a Flutter asset bundle (nothing here is loaded by
the running app - the in-app institute logo remains the admin-configured
URL at Institute Profile, per docs/database-architecture.md). It exists
only as the source file `web/favicon.png` and `web/icons/*.png` were
generated from - see docs/architecture.md's Set 28 notes for exactly how.
