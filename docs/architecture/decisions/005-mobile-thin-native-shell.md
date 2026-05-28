# ADR 005: Mobile delivery via thin native shell

**Status:** Superseded by [ADR-011](011-mobile-via-responsive-web.md) on 2026-05-28
**Date:** 2026-05-26

## Context

The product is consumed on:

1. Desktop web (facility admins, kitchen chefs, Aid applicants).
2. Mobile web (relatives — secondary surface).
3. Mobile app (relatives — primary surface, plus caregivers on facility tablets).

Building three rendering targets independently triples the work. The choice is whether to:

- ship a single LiveView surface and wrap it in a thin native shell that brokers OS APIs (camera, gallery, audio, push, biometric, deep links), or
- adopt React Native / Capacitor / Flutter and re-implement the surface natively.

## Decision

**Thin native shell.** LiveView is the canonical UI; native code owns only the OS-API bridge.

- **iOS:** Swift + WKWebView + a `WKScriptMessageHandler` bridge.
- **Android:** Kotlin + WebView + a `@JavascriptInterface` bridge.
- The bridge exposes a small, stable JS surface: `Bridge.takePhoto`, `Bridge.pickFromGallery`, `Bridge.recordAudio`, `Bridge.registerPushToken`, `Bridge.unlockBiometric`, `Bridge.openDeepLink`, `Bridge.setStatusBarStyle`. Frozen in `docs/recon/mobile-surface.md`.

React Native, Capacitor, and Flutter are explicitly rejected:

- React Native fragmenter the codebase and adds a JS runtime maintenance burden.
- Capacitor's plugin ecosystem is fine but introduces a coupling to Ionic's release cadence.
- Flutter rewrites the entire UI in Dart, undoing the LiveView investment.

## Consequences

**Gains:**

- Smallest binary (≈ 1–2 MB total shell on each platform).
- One UI codebase. A button moved in `feed.compose` ships to web, iOS, and Android in the same deploy.
- The native bridge surface is small enough that one iOS and one Android engineer can each own it without a shared codebase.

**Costs:**

- LiveView's network dependency means offline support is limited. Mitigation: cache the last N feed items in the WebView and let read-only browsing degrade gracefully.
- Status-bar tinting, safe-area insets, and push permission prompts must be wired through the bridge — one extra surface to test on every nav transition.
- App Store / Play Store reviewers can flag pure-WebView apps as "not native". Mitigation: ensure native splash, native push UX, native biometric prompt, and `Bridge.takePhoto` invokes the OS camera (not a `<input type="file">`).

## Alternatives considered

- **PWA only.** Rejected: iOS push notifications via PWA are unreliable; App Store presence is non-negotiable for elder-care market trust.
- **React Native / Expo.** Rejected: see above.
- **Capacitor.** Rejected: see above.
