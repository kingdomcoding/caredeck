# ADR 011: Mobile delivery via responsive web only — no PWA, no native shell

**Status:** Accepted
**Date:** 2026-05-28
**Supersedes:** [ADR-005](005-mobile-thin-native-shell.md)

## Context

ADR-005 committed to a thin native shell (Swift + WKWebView, Kotlin + WebView)
because at the time we believed:

- iOS push notifications via PWA were unreliable.
- App Store presence was non-negotiable for elder-care market trust.
- A native shell would be needed for camera, audio, biometric, and deep-link
  capabilities.

Three things changed between ADR-005 and this decision:

1. **Scope is portfolio, not product.** Caredeck is a senior-engineer
   portfolio piece, not a market-bound application. App Store / Play Store
   listings, store-review cycles, and store-trust signals are not part of
   the success criteria. A working demo URL on a phone is.
2. **Modern web platform covers the original native-only goals.**
   - Camera: `<input type="file" accept="image/*" capture="environment">`
     opens the rear camera on iOS Safari and Android Chrome.
   - Audio recording: `MediaRecorder` + `getUserMedia` works on iOS Safari
     14.1+ and every other browser worth supporting.
   - Biometric: WebAuthn / passkeys could hit the same Face ID / Touch ID
     prompt as a native binary, but see "Decision changes" below.
   - Deep-link: the existing `/invitations/:token` route opens in the
     browser; with PWA install it opens in the PWA shell.
3. **Phase 6 shipped LiveView PubSub for in-tab realtime.** The bell badge
   updates within ~1 second of a comment, like, or post. The remaining
   delta vs. native push is "reach the user when the app is closed" — which
   we accept as a missing feature for v1.

## Decision

**Mobile delivery is responsive web only.** No PWA install, no service
worker, no native binary.

What ships in Phase 7:

- Camera and audio capture in `/feed/compose` via `<input capture>` and
  `MediaRecorder` respectively.
- A mobile-only bottom nav (Home / Profile / Inbox / Sign out) rendered by
  `Layouts.app/1` only at `md:` and below.
- ~~WebAuthn passkey registration and sign-in via a new `UserPasskey`
  resource and a `wax_`-backed `PasskeyController`.~~ Reverted on 2026-05-28
  — see "Decision changes" below.
- Responsive audit at 360 / 414 / 768 viewport widths.

What is explicitly out of scope (deferred or dropped):

- Service worker, `manifest.json`, "Add to Home Screen" install flow.
- Web Push (out-of-tab notifications).
- Offline cache.
- iOS Swift project, Android Kotlin project, APNs / FCM keys, TestFlight,
  Play Store internal track.
- The `Bridge.*` JS surface frozen in `docs/recon/mobile-surface.md` (kept
  for historical reference; not implemented).

## Consequences

**Gains:**

- One repo, one deploy. No Xcode, no Android Studio, no parallel codebases.
- No service-worker bug class (stale caches, broken updates,
  WebSocket-upgrade interception).
- No Apple Developer Account, no provisioning profiles, no review cycle.
- Phase 7 ships in ~3 days instead of 5–7.

**Costs:**

- Relatives only see notifications inside the browser tab. Out-of-tab
  reach falls back to email (Phase 5 invitation mail is precedent).
- No home-screen icon. Users navigate via URL or browser bookmark.
- No App Store listing for portfolio reviewers. Mitigated by a screen
  recording of the mobile-web flow on a real iPhone.

## Alternatives reconsidered

- **PWA without native.** Considered. Adds a service worker (bug magnet)
  and offline cache (untested) for the upside of an installable icon + iOS
  push for installed PWAs. Rejected for v1 because the install UX on iOS
  is buried (Share → scroll → Add to Home Screen) and the install rate
  would cap push reach anyway. Revisit in a future "Phase 14: PWA install
  polish" if portfolio reviewers ask for the install flow.
- **Native shell as in ADR-005.** Rejected — see Context.
- **React Native / Capacitor / Flutter.** Still rejected for the reasons
  in ADR-005.

## Decision changes

**2026-05-28 — WebAuthn passkeys removed.** Day 3 of Phase 7 shipped a
`UserPasskey` resource + `PasskeyController` + JS hooks against the
`wax_` library. Removed before sign-off real-device QA on the call that
the portfolio scope doesn't need an alternative auth path. The password
flow (Phase 1) is sufficient for the demo, and removing the dep + the
table reduces audit surface area. The `user_passkeys` table is dropped
via `20260528143804_drop_user_passkeys.exs`. If a future phase wants
biometric unlock back, the implementation pattern is reachable from
git history at the `v0.7.0-phase-7-complete` tag.

## Cross-references

- Phase 7 plan: `myo-clone-phase-7-implementation.md` (in the `myo/`
  parent directory).
- Master plan §8 is updated to reflect this scope shift.
