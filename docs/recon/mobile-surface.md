# Mobile Surface

JS bridge that the thin native shell (iOS WKWebView, Android WebView) must expose to the LiveView surface. Frozen here in Phase 0; consumed by Phase 7.

Every Bridge call returns a `Promise<T>` and rejects with `{code, message}` on failure. The LiveView code never invokes a native API directly — it only awaits these promises and pushes results back via `phx-hook` events.

| Call | Input | Output | Notes |
|---|---|---|---|
| `Bridge.takePhoto(opts)` | `{ maxBytes: number, allowVideo: boolean }` | `{ kind: "photo" \| "video", blobUrl: string, mimeType: string, bytes: number }` | Opens the system camera. `maxBytes` rejects oversized captures before upload. |
| `Bridge.pickFromGallery(opts)` | `{ multi: boolean, kinds: ("photo" \| "video")[] }` | `Array<{ kind, blobUrl, mimeType, bytes }>` | Returns one item when `multi:false`. |
| `Bridge.recordAudio(opts)` | `{ maxDurationSec: number }` | `{ blobUrl: string, mimeType: string, durationSec: number, bytes: number }` | Voice notes for posts and comments. |
| `Bridge.registerPushToken(platform, token)` | `platform: "ios" \| "android"`, `token: string` | `void` | Called on app launch + after permission grant. Backend stores per-user. |
| `Bridge.unlockBiometric(reasonText)` | `reasonText: string` | `{ ok: boolean }` | Face ID / Touch ID gate before sensitive screens. |
| `Bridge.openDeepLink(url)` | `url: string` | `void` | Native shell handles invitation magic-links and `caredeck://` URLs. |
| `Bridge.setStatusBarStyle(style)` | `style: "light" \| "dark"` | `void` | LiveView nudges the native status-bar tint per route. |

## Stability contract

These signatures are part of the cross-platform API contract. Changing any input/output type requires:

1. An ADR documenting the change.
2. A version bump on the bridge's `Bridge.version` constant (added in Phase 7).
3. A migration path for already-installed apps — old shells must still work against the new LiveView.
