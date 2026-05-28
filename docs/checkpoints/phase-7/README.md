# Phase 7 — Checkpoint

**Date:** 2026-05-28
**Tag:** `v0.7.0-phase-7-complete`
**Supersedes scope:** ADR-005 (native shell) → [ADR-011](../../architecture/decisions/011-mobile-via-responsive-web.md) (responsive web only)

## What shipped

- **Camera affordance in `/feed/compose`** — a second **Take photo** button beside **Add from gallery** wires `<input type="file" accept="image/*" capture="environment">` and a `ShareCameraInput` JS hook that funnels the camera-captured file into the existing `@uploads.photos` LiveView upload. On iPhone Safari and Android Chrome this opens the rear camera directly; on desktop it falls back to a file picker.
- **Audio capture in `/feed/compose`** — an `AudioRecorder` JS hook driving `MediaRecorder` + `getUserMedia({audio: true})`, with a 60-second hard cap. Format auto-selects between `audio/webm;codecs=opus`, `audio/webm`, and `audio/mp4`. On stop the blob is PUT to a presigned MinIO URL (`Caredeck.Feed.Attachment.:request_upload_url` action), then a LiveView event materialises the `Attachment` row of `kind: :audio`.
- **Audio playback in `FeedLive` and `PostLive`** — `<.audio_attachments>` component renders `<audio controls preload="metadata">` for any `kind: :audio` attachment. The existing `/attachments/*key` proxy serves the bytes tenant-scoped; no controller change.
- **Mobile bottom nav in `Layouts.app/1`** — fixed 4-tab nav at `md:` and below: **Home / Profile / Inbox / Sign out**. Inline SVG icons, `pb-[env(safe-area-inset-bottom)]` for iPhone home-indicator clearance, `pb-16` on `<main>` so content doesn't disappear under the nav. The desktop header's duplicate Profile / Edit / Inbox / Sign out items hide behind `hidden md:inline-block` so the mobile UI isn't double-rendered.
- **Responsive header polish** — `px-6 → px-4 sm:px-6` and `gap-6 → gap-3 sm:gap-6`; `@current_user.email` truncated to `max-w-[18ch]`; `@current_team.name` to `max-w-[14ch]`. No horizontal scroll at 360px.
- **WebAuthn passkey** — `Caredeck.Accounts.UserPasskey` resource (multi-row per user, `credential_id` binary, sensitive `public_key`, `sign_count`, `aaguid`, `nickname`, `last_used_at`) backed by the `wax_` library (resolves to 0.7.0). 4 routes under `/passkey/...` (not `/auth/passkey/...` — see "Decisions and divergences"): `register/options`, `register/finish`, `sign-in/options`, `sign-in/finish`. JS hooks (`PasskeyRegister`, `PasskeySignIn`) drive `navigator.credentials.create/get`. UI: a **Passkey sign-in** section in `/profile/edit` lists registered devices + a **Register this device** button; `/sign-in` gains a **Use a passkey** button below the password form.

## Demo credentials (unchanged)

| Type | Identifier | Password |
|---|---|---|
| Relative | `demo-relative@example.test` | `phase1-demo-pass` |
| Team Care | `team-care` | `phase1-demo-pass` |
| Team Activities | `team-activities` | `phase1-demo-pass` |
| Team Therapy | `team-therapy` | `phase1-demo-pass` |

## Verification matrix

| Check | Result |
|---|---|
| `mix format --check-formatted` | ✅ |
| `mix compile --warnings-as-errors` | ✅ |
| `mix credo --strict` | ✅ (510 mods/funs, 0 issues) |
| `mix sobelow --config` | ⚠️ 4 inherited Phase 3/5 findings; no new ones |
| `mix deps.audit --ignore-advisory-ids GHSA-g2wm-735q-3f56` | ✅ no vulnerabilities |
| `mix test` | ✅ 98/98 (88 inherited + 3 audio capture + 2 bottom nav + 3 UserPasskey + 5 PasskeyController – minus retired post_fanout_test) |
| iOS Safari camera input opens rear camera | *(manual)* |
| iOS Safari audio record produces `audio/mp4`, plays back | *(manual)* |
| Android Chrome audio record produces `audio/webm`, plays back | *(manual)* |
| `/feed/compose` send with audio attached → `Attachment` row of `kind: :audio` materialised | ✅ (LV test) |
| Audio in `/feed` and `/feed/:post_id` renders as `<audio controls>` and plays | *(manual)* |
| Bottom nav visible at 414px viewport, hidden at 1024px | ✅ structurally (`md:hidden` guard, LV test) |
| Bell badge inside bottom-nav Inbox tab matches the header badge value | *(manual)* |
| WebAuthn register on iPhone (Face ID) creates a `UserPasskey` row | *(manual)* |
| WebAuthn sign-in on iPhone (Face ID) stores a session and lands on `/feed` | *(manual)* |
| WebAuthn sign-in on a device with no passkey shows a clean error; password fallback works | *(manual)* |
| `/profile/edit` lists registered passkeys with nickname + date | *(manual)* |
| Remove passkey from `/profile/edit` destroys row + breaks subsequent assertion | *(manual)* |

## Decisions and divergences

- **ADR-011 supersedes ADR-005.** No iOS Swift project, no Android Kotlin project, no APNs / FCM, no PWA install, no service worker. The Phase 7 plan document spells out the trade — out-of-tab notifications are dropped; LiveView pub/sub from Phase 6 covers in-tab realtime; email is the email-style reach.
- **Routes mounted at `/passkey/*`, not `/auth/passkey/*`.** AshAuthentication's `auth_routes(...)` macro registers `forward "/auth", AshAuthentication.Phoenix.StrategyRouter`, which swallows anything under `/auth/...` regardless of registration order. Moving the routes one level up dodges the catch-all cleanly and the public URL stays short.
- **Single `:passkey_api` pipeline.** A new pipeline (`accepts: ["json"]`, session, CSRF, secure headers, `load_from_session`) hosts the four endpoints. Reusing the `:browser` pipeline would have required adding `"json"` to its `:accepts`, which would loosen browser routes too.
- **No `transports` column on `UserPasskey`.** The plan called for one; in practice `Wax.authenticate/6` only needs `[{credential_id, cose_public_key}]` to verify an assertion, and the JS hook can request authentication without disclosing transport hints. Saves a row + spares us a "USB hardware key gives `[]`" edge case in v1.
- **JS hooks use raw `fetch` not LiveView events.** Passkey sign-in is initiated from a static `<button id="sign-in-passkey">` that has no live channel yet (the sign-in LV is in `:no_user` live_session). Using `fetch` against the JSON endpoints keeps the flow simple. On the registration side `EditProfileLive` does push a `passkey_registered` event so the LV reloads the list inline.
- **WebAuthn fixtures deferred.** End-to-end controller tests for the happy path (`register/finish` + `sign-in/finish` against a captured attestation / assertion) require real authenticator output. The shipped suite covers the no-challenge + unauthorized branches; happy-path coverage waits on hand-curated fixtures (Phase 13 or earlier).
- **Audio sits at `position: 99`.** Photo positions are 0..N. Audio at 99 keeps it at the end of the strip without colliding with photo reorderings — simpler than introducing a separate `kind`-aware position scope.

## What Phase 8 inherits

1. **Audio attachment kind** — Phase 9 (Service Providers) can reuse the audio capture + playback path for **Pharmacy → Send a question** voice notes without revisiting the model.
2. **Mobile bottom-nav slot** — Phase 8 (Kitchen) can swap in a **Kitchen** tab once the module ships, or add a new bottom-nav tab via `<.nav_tab>` without restructuring `Layouts.app/1`.
3. **WebAuthn passkey primitives** — Phase 9+ can re-use the `UserPasskey` resource + `PasskeyController` for caregiver step-up auth (e.g. confirming a medication dispense) by extending the policies + adding step-up actions.
4. **ADR-011 baseline** — Phase 8+ stays web-only unless explicitly revisited. The mobile-web responsive baseline is the default canvas for any new LiveView surface.
5. **`/passkey/*` JSON pipeline** — Phase 9+ can host other small JSON endpoints (web push, file uploads, deep links) by reusing the `:passkey_api` pipeline.

## Outstanding (deferred)

- **PWA install + service worker** — gated by ADR-011. Push remains in-tab only.
- **Offline cache** — none. Page needs network on every load.
- **Background push when the tab is closed** — dropped from Phase 7 scope. LiveView pub/sub covers in-tab realtime; email covers out-of-tab reach for high-signal events.
- **Cross-device passkey via QR / Bluetooth (CTAP2 hybrid transport)** — Phase 14 if needed. Today's flow registers per-device.
- **WebAuthn happy-path test fixtures** — Phase 13 or earlier. Capture an attestation + assertion JSON from real browser sessions and commit under `test/fixtures/passkey/`.
- **Audio chunked upload to survive backgrounding** — Phase 13 or later. The widget warns the user to stay in the tab; long recordings on iOS will die if the user switches apps.
- **Audio waveform / scrubber UX** — out of scope; native `<audio controls>` is sufficient.
- **In-app camera live preview + canvas snapshot** — current flow uses the native picker dialog; in-app preview would need `getUserMedia` + canvas, deferred.
- **Screenshots** — `bottom-nav-feed.png`, `bottom-nav-notifications.png`, `compose-take-photo.png`. Deferred to manual capture from a real device.
