# Sampled Design Tokens

Raw colour samples taken from the reference frames in `./reference-frames/`. Source of truth for the `@theme {}` block in `assets/css/app.css`. Update both files in lockstep.

## Brand teal scale

Sampled from the primary accent across login (`auth-login.png`), feed (`feed-home.png`), and Aid overview (`aid-overview.png`).

| Step | Hex | Where it appears |
|---|---|---|
| teal-50 | #e6faf8 | page wash behind device mockups |
| teal-100 | #c2f2ec | subtle hover backgrounds |
| teal-200 | #8be6db | secondary chip backgrounds |
| teal-300 | #4cd6c5 | active tab underline |
| teal-400 | #2bcab6 | hovered FAB |
| teal-500 | #1fbfaa | primary CTA, FAB, wordmark |
| teal-600 | #18a392 | pressed state |
| teal-700 | #138072 | dark hover-pair |
| teal-800 | #0f5e54 | high-contrast text on light bg |
| teal-900 | #0a3c35 | reserved (unused in current screens) |

## Engagement

| Token | Hex | Source |
|---|---|---|
| like-red | #ef4444 | filled heart on post-detail |

## Neutrals

| Token | Hex | Use |
|---|---|---|
| ink-900 | #0f1115 | headline text |
| ink-700 | #2a2f37 | body text |
| ink-500 | #5b6470 | secondary text |
| ink-300 | #97a0ad | placeholder, disabled |
| card | #ffffff | post card background |
| page | #f6f8fa | app background wash |
| divider | #e5e8ec | hairline rules |

## Aid status badges (5 tuples)

Sampled from `aid-digest-email.png` (the digest table rows).

| State | bg | border | text |
|---|---|---|---|
| draft | #fef9c3 | #facc15 | #854d0e |
| missing | #ffedd5 | #fb923c | #9a3412 |
| ready | #dbeafe | #3b82f6 | #1e3a8a |
| submitted | #ede9fe | #8b5cf6 | #5b21b6 |
| approved | #dcfce7 | #22c55e | #166534 |

## Type ramp

| Token | Size | Line-height | Weight | Use |
|---|---|---|---|---|
| display-xl | 4.5rem | 1.05 | 700 | marketing hero |
| display-lg | 3rem | 1.1 | 700 | section headers |
| display-md | 2rem | 1.15 | 600 | page titles |
| display-sm | 1.5rem | 1.2 | 600 | sub-section headers |
| base | 1rem | 1.5 | 400 | body |
| sm | 0.875rem | 1.5 | 400 | captions |

Font family: Figtree variable (weight range 400–700), with system-sans fallback.

## Radii

| Token | Value | Use |
|---|---|---|
| chip | 9999px | resident tag chips, status badges |
| card | 1.25rem | post cards, modal panels |
| button | 0.75rem | primary CTAs, inputs |
| fab | 9999px | the NEW FAB |

## Shadows

| Token | Value | Use |
|---|---|---|
| card | `0 1px 2px rgba(15,17,21,.04), 0 4px 12px rgba(15,17,21,.06)` | feed cards |
| fab | `0 8px 24px rgba(31,191,170,.35)` | the NEW FAB elevation |
