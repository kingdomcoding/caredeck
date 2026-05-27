# Phase 2 — Checkpoint

**Date:** 2026-05-27
**Tag:** `v0.2.0-phase-2-complete`

## What shipped

- **`Caredeck.People` domain** — first multi-tenant domain. Four resources, four `.Version` variants, all scoped by `attribute :facility_id`.
- **`Resident`** — multi-tenant. Attributes: `first_name`, `last_name`, `birth_name`, `date_of_birth`, `avatar_url`, `lifecycle_state` (state machine), `admitted_at`, `discharged_at`, `deceased_at`. Belongs to `Facility` + `Ward`. Has many `:relative_links`, many-to-many `:relatives` through `RelativeOfResident`.
- **`Relative`** — multi-tenant. One row per `User` per `Facility`. Identity `:unique_user_per_facility`.
- **`RelativeOfResident`** — multi-tenant join. The 13-state `relationship` enum (`:daughter | :son | :niece | :nephew | :granddaughter | :grandson | :wife | :husband | :spouse | :partner | :sibling | :legal_guardian | :other`). `is_primary_contact` boolean for notification routing.
- **`CaregiverProfile`** — multi-tenant. Optional per-caregiver metadata (display name, role label, avatar). Identity `:unique_caregiver_per_facility`.
- **Resident lifecycle state machine** via `AshStateMachine`. Transitions: `:discharge` (admitted → discharged), `:mark_deceased` (admitted | discharged → deceased), `:readmit` (discharged → admitted). Invalid transitions (e.g. `:readmit` from `:deceased`) raise.
- **`Caredeck.Resource` macro upgrade** — accepts `paper_trail: [attributes_as_attributes: [...]]` (for Version-resource multi-tenancy) and `extensions: [...]` (opt-in AshStateMachine on Resident; other resources unaffected).
- **`Caredeck.Release.NamePool`** — small in-tree name pool (no Faker dep — Faker breaks compile on Elixir 1.20-rc).
- **Sandbox seed expanded**: 1 District + 1 Facility + 2 Wards (Ground Floor / First Floor) + 3 Team Identities + 81 Users (1 demo + 80 generated relatives) + 81 FacilityMemberships + 30 Residents + 80 Relatives + 80 RelativeOfResident rows. Full seed runs in ~9s with dev's `bcrypt log_rounds: 4`.
- **`CaredeckWeb.LiveUserAuth` upgrade** — `on_mount` callbacks now also resolve `:current_facility` from the user's first FacilityMembership or the team's `facility_id`.
- **`CaredeckWeb.FeedLive`** — Phase 2 stub LiveView at `/feed`. Lists residents sorted by surname, shows lifecycle state as a coloured badge. Phase 3 replaces this with the full chronological post feed.
- **Cross-tenant isolation tests** — verify that `Ash.read!(Resident, tenant: facility_b.id)` never returns Facility A's rows, and that missing-tenant raises.

## Demo credentials

| Type | Identifier | Password |
|---|---|---|
| Relative | `demo-relative@example.test` | `phase1-demo-pass` |
| Team Care | `team-care` | `phase1-demo-pass` |
| Team Activities | `team-activities` | `phase1-demo-pass` |
| Team Therapy | `team-therapy` | `phase1-demo-pass` |
| 80× generated relatives | `<first>.<last>.<n>@example.test` | `phase2-bulk-pass` |

After signing in as the demo relative or any team identity, `/feed` shows the 30-resident roster scoped to Sandbox Care Home.

## Verification matrix

| Check | Result |
|---|---|
| `mix format --check-formatted` | ✅ |
| `mix compile --warnings-as-errors` | ✅ |
| `mix test` | ✅ 18 / 18 (12 Phase 1 + 3 lifecycle + 3 multi-tenancy) |
| `mix ecto.reset` | ✅ seeds 30 residents + 80 relatives in ~9s |
| `Ash.read!(Resident)` without tenant | ✅ raises `Ash.Error.Invalid` |
| `Ash.read!(Resident, tenant: facility_a)` cross-tenant leak | ✅ 0 rows from Facility B returned |
| State machine invalid transition (`:deceased → :readmit`) | ✅ returns `{:error, _}` |
| `/feed` (signed-in relative) | ✅ shows 30 residents tagged with lifecycle state |
| `/feed` (signed-in team) | ✅ shows the same 30 residents, "Signed in as Team Care" flash |

## Screenshots

- `feed.png` — `/feed` rendered when signed in as `demo-relative@example.test`
- `feed-team.png` — `/feed` rendered when signed in as `team-care`

## Decisions and divergences

- **No Faker dep** — Faker 0.18 fails to compile on Elixir 1.20-rc because of charlist-syntax deprecations. Replaced with an in-tree `Caredeck.Release.NamePool` with ~70 first names + ~50 last names. Same outcome; one less external dep.
- **`/feed` uses `:live_signed_in_optional`** — both signed-in users *and* anonymous viewers can hit it. Anonymous viewers see "no facility / Residents (0)". Phase 3 hardens this to `:live_user_required` once the feed has content worth gating.
- **`require_token_presence_for_authentication?` is still off** (Phase 1 retrofit decision). Token revocation deferred to Phase 13.
- **`TeamAuthController.success/4` manually attaches the token to `team.__metadata__`** because the password strategy doesn't auto-populate it. Same pattern as Phase 1's retrofit.
- **`Caredeck.Resource` base macro now accepts `:extensions` opt-in** so AshStateMachine doesn't get force-included on every resource (it raises for resources that don't declare a state machine).

## What Phase 3 inherits

- `Caredeck.People.Resident` — Phase 3's `PostAudience` resource will FK to `Resident.id`.
- `Caredeck.People.RelativeOfResident` — Phase 3's comment rendering reads the join row to label comments with the relative's `relationship` to the resident.
- `Caredeck.People.CaregiverProfile` — Phase 3's per-post "actor stamp" joins to this.
- `CaredeckWeb.LiveUserAuth.on_mount/4` — Phase 3's `/feed` upgrade keeps the same on_mount but reaches into `@current_facility` to scope the feed query.
- `CaredeckWeb.FeedLive` itself — Phase 3 replaces the resident-list stub with the chronological post feed; the route and on_mount stay.
- The seeded sandbox facility with 30 residents and 80 relatives — Phase 3 creates the first posts against this data.

## Outstanding (deferred)

- Run prod migrations + re-seed in prod (next: `Caredeck.Release.migrate()` + `Caredeck.Release.seed()` in the prod container).
