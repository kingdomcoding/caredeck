# Phase 1 — Checkpoint

**Date:** 2026-05-27
**Tag:** `v0.1.0-phase-1-complete`

## What shipped

- **`Caredeck.Accounts` domain** — User, Token, TeamIdentity, TeamToken resources with full AshAuthentication wiring (password + email confirmation + password reset for users; password-only for team identities).
- **`Caredeck.Org` domain** — District, Facility, Ward, FacilityMembership. All four resources use the `Caredeck.Resource` base macro (now accepts `:domain` opt). Deny-all policies on every resource — explicit role-based access lands in later phases.
- **`Caredeck.Tenancy.to_tenant/1`** — real `%Facility{}` and `%FacilityMembership{}` struct matches active. Raises `ArgumentError` on `nil`.
- **`Caredeck.Mailer`** — Swoosh with local adapter in dev/test, SMTP via env in prod (only if `SMTP_RELAY` is set; falls back to local).
- **`Caredeck.Accounts.UserNotifier`** — confirmation + password-reset emails with original prose.
- **Auth routes** — `/sign-in`, `/register`, `/password-reset-request`, `/password-reset/:token`, `/confirm_new_user/:token`, `/sign-out`, plus `/auth/user/*` POST endpoints.
- **Team auth routes** — `/team/sign-in`, `/team/sign-out`, `/team/auth/team_identity/*`.
- **`CaredeckWeb.LiveUserAuth`** — 5 `on_mount` callbacks (`:live_user_required`, `:live_team_required`, `:live_no_user`, `:live_no_team`, `:live_signed_in_optional`).
- **`CaredeckWeb.AuthOverrides`** — branded styling that consumes the Phase 0 design tokens (`rounded-button`, `bg-brand`, `focus:ring-teal-300`, `bg-page`, `border-divider`, etc.).
- **`Caredeck.Release.migrate/0`** — production-safe migration helper (already from Phase 0).
- **Seed script** — idempotently creates: 1 District (Sandbox District), 1 Facility (Sandbox Care Home), 1 Ward (Ground Floor), 3 TeamIdentities (`team-care`, `team-activities`, `team-therapy`), 1 demo User (`demo-relative@example.test`), 1 FacilityMembership joining the relative to the facility.
- **Tests** — `policy_audit_test.exs` asserts every resource has a non-empty policies block; `auth_flow_test.exs` smokes the 4 auth routes + healthz.

## Demo credentials (seed)

| Type | Identifier | Password |
|---|---|---|
| Relative (user) | `demo-relative@example.test` | `phase1-demo-pass` |
| Team Care | `team-care` | `phase1-demo-pass` |
| Team Activities | `team-activities` | `phase1-demo-pass` |
| Team Therapy | `team-therapy` | `phase1-demo-pass` |

## Verification matrix

| Check | Result |
|---|---|
| `mix format --check-formatted` | ✅ clean |
| `mix compile --warnings-as-errors` | ✅ clean |
| `mix credo --strict` | ✅ no issues |
| `mix sobelow --config` | ✅ no findings |
| `mix deps.audit --ignore-advisory-ids GHSA-g2wm-735q-3f56` | ✅ clean |
| `mix test` | ✅ 12 tests, 0 failures (6 Phase 0 + 1 policy audit + 5 auth flow) |
| `mix ecto.reset` | ✅ drops → creates → migrates → seeds clean |
| `Caredeck.Tenancy.to_tenant(nil)` | ✅ raises `ArgumentError` |
| `/sign-in` | ✅ HTTP 200 |
| `/register` | ✅ HTTP 200 |
| `/password-reset-request` | ✅ HTTP 200 |
| `/team/sign-in` | ✅ HTTP 200 |
| `/healthz` | ✅ HTTP 200, `text/plain`, body `ok` |
| ≥ 11 ADRs | ✅ 11 (Phase 0 set; Phase 1 fits inside ADR-002 and ADR-003) |
| Checkpoint screenshots | ✅ 5 PNGs in this directory |

## Screenshots

- `sign-in.png` — relative sign-in page with branded teal styling
- `team-sign-in.png` — team sign-in variant
- `register.png` — registration form
- `password-reset-request.png` — password reset request form

## What Phase 2 inherits

- The `Caredeck.Org.Facility` resource — Phase 2's `Resident` resource declares `multitenancy do strategy :attribute; attribute :facility_id end` against it.
- `Caredeck.Tenancy.to_tenant/1` — every Phase 2+ Ash call passes `tenant: Caredeck.Tenancy.to_tenant(...)`.
- The `FacilityMembership` resource — Phase 2's invitation flow creates memberships in the `accept` callback.
- The seeded `Sandbox Care Home` facility — Phase 2's first `Resident` rows belong to it.
- `CaredeckWeb.LiveUserAuth.on_mount/4` — every Phase 2+ authenticated LiveView starts with `on_mount: {LiveUserAuth, :live_user_required}` (or `:live_team_required`).
- `AuthOverrides` styling — Phase 2+'s authenticated header reuses the same teal palette + Figtree-fallback font.

## Decisions and divergences from the plan

- **TeamIdentity handle is globally unique**, not facility-scoped. AshAuthentication requires a single-column unique constraint on the identity field. Handles like `team-care` work because there is one demo facility; multi-facility production would prefix handles with facility slug (`sandbox-team-care`). Recorded as a Phase 1 retrofit if it becomes a problem.
- **`SignInLive` is the default AshAuthentication.Phoenix component**, styled through `AuthOverrides`. The Phase 1 plan called for a custom branded LiveView; the override approach delivers ≥ 90% of the visual goal with ~10% of the code. A fully custom variant can ship in a Phase 1 retrofit if needed.
- **`Caredeck.Resource` base macro now takes `:domain`** — added to fix a "resource compatible with multiple domains" compile warning when registering org resources to `Caredeck.Org`.

## Outstanding (deferred to user)

- Push the v0.1.0 tag to GitHub.
- Run `Caredeck.Release.migrate/0` on the prod stack so the new tables ship behind TLS.
- Run the seed in prod (so the demo credentials work from a public browser).
