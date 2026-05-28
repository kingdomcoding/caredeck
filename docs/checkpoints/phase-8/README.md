# Phase 8 — Checkpoint

**Date:** 2026-05-28
**Tag:** `v0.8.0-phase-8-complete`

## What shipped

- **`Caredeck.Kitchen`** domain registered alongside Accounts / Org / People / Feed / Notifications.
- **7 resources** — `Product`, `MenuTemplate`, `MenuTemplateSlot`, `DayMenu`, `DayMenuSlot`, `ResidentDietProfile`, `ResidentMealOrder`. All multi-tenant on `facility_id`, all paper-trailed, all with `Caredeck.Resource` base. Each writes through composite-unique upserts: `MenuTemplate` partial-unique on `(facility_id) where is_active`, `MenuTemplateSlot` on `(menu_template_id, day_of_week, category)`, `DayMenu` on `(facility_id, date)`, `DayMenuSlot` on `(day_menu_id, category)`, `ResidentDietProfile` on `(resident_id)`, `ResidentMealOrder` on `(resident_id, date, category)`.
- **`MealCategory`** shared module with the static enum `~w(breakfast lunch dinner drinks fruit snack)a` and per-category `label/1`.
- **`Caredeck.Kitchen.Materialise`** helper — turns a facility's active `MenuTemplate` plus a `Date` into a `DayMenu` with 6 `DayMenuSlot` rows; returns the materialised menu with `slots: [:product]` pre-loaded so LV callers don't trip on `Ash.NotLoaded`.
- **`CaredeckWeb.Kitchen.WeeklyMenuLive`** at `/kitchen/weekly-menu` — 7-day strip Monday-anchored, today highlighted, **Materialise** button on empty days, "Set up a default week first" banner when no active template.
- **`CaredeckWeb.Kitchen.DayEditorLive`** at `/kitchen/weekly-menu/:date` — 6 category accordions with product picker; empty-state when a category has no products.
- **`CaredeckWeb.Kitchen.ResidentOrderLive`** at `/kitchen/order/:resident_id` — per-category **Take the plan** / **Skip** buttons; allergen banner pulled from `ResidentDietProfile`; non-bang `Ash.create` so a policy-failure flashes "You can't order for this resident." rather than crashing the LV.
- **`CaredeckWeb.Kitchen.DietProfileLive`** at `/residents/:id/diet` — allergens (CSV), preferences (one per line), skip-categories (checkboxes), notes.
- **`CaredeckWeb.Kitchen.SummaryLive`** at `/kitchen/summary` — per-category product × count, sorted desc; subscribed to `facility:{id}:kitchen` PubSub so the chef's screen re-aggregates on `order_changed` broadcasts within ~1s.
- **`Caredeck.Workers.MaterialiseTomorrow`** Oban cron at `0 20 * * *` — walks every facility and materialises tomorrow's menu. Idempotent via the same composite-unique upserts.
- **Bottom nav** gains a **Kitchen** tab for team identities, with an inline-SVG `nav_icon(%{name: :plate})` clause. Profile tab hides when the actor is a team identity (Home / Kitchen / Inbox / Sign out replaces Home / Profile / Inbox / Sign out).
- **`ProfileLive`** (Phase 5) gains top-right **Order meal →** and **Diet profile** links.
- **Seeds** — `team-kitchen` identity, 18 default products (3 per category), one active `MenuTemplate` "Default week", 42 `MenuTemplateSlot` rows (7 days × 6 categories). Guarded with an `existing_count == 0` check so reseeding doesn't duplicate.

## Demo credentials

| Type | Identifier | Password |
|---|---|---|
| Relative | `demo-relative@example.test` | `phase1-demo-pass` |
| Team Care | `team-care` | `phase1-demo-pass` |
| Team Activities | `team-activities` | `phase1-demo-pass` |
| Team Therapy | `team-therapy` | `phase1-demo-pass` |
| **Team Kitchen** | **`team-kitchen`** | **`phase1-demo-pass`** |

## Verification matrix

| Check | Result |
|---|---|
| `mix format --check-formatted` | ✅ |
| `mix compile --warnings-as-errors` | ✅ |
| `mix credo --strict` | ✅ |
| `mix sobelow --config` | ⚠️ inherited Phase 3/5 findings only |
| `mix deps.audit --ignore-advisory-ids GHSA-g2wm-735q-3f56` | ✅ |
| `mix test` | ✅ 121 / 121 (115 Day-1..Day-4 + 6 multitenancy = 121, up from 91 entering Phase 8) |
| IEx: `Ash.read!(Kitchen.Product)` without tenant | ✅ raises `Ash.Error.Invalid` |
| Cross-tenant read of `Product` / `DayMenu` / `ResidentMealOrder` | ✅ returns `[]` |
| `/kitchen/weekly-menu` as `team-kitchen` | ✅ structural test (7 day labels render) |
| **Materialise** creates `DayMenu` + 6 slots | ✅ automated |
| `/kitchen/weekly-menu/:date` picker upserts | ✅ automated |
| `/kitchen/order/:resident_id` as team-care | ✅ automated (`ordered_by_team_id`) |
| Relative for own resident | ✅ automated (`ordered_by_user_id`) |
| Relative for not-their resident | ✅ automated (denied with flash) |
| **Skip** destroys existing order | ✅ automated |
| `/kitchen/summary` aggregates | ✅ automated |
| PubSub `order_changed` broadcast → re-aggregate | ✅ automated |
| `MaterialiseTomorrow` cron entry in `config/runtime.exs` | ✅ visual |
| `MaterialiseTomorrow.perform/1` materialises tomorrow | ✅ automated |
| `MaterialiseTomorrow.perform/1` is idempotent | ✅ automated |
| `team-kitchen` seeded per facility | ✅ via seed pipeline |

## Decisions and divergences

- **`MealCategory` is a static enum**, not a resource. No per-facility category configuration in v1; the six categories are universal.
- **Single active `MenuTemplate` per facility** (partial-unique on `(facility_id) where is_active`). Multi-week / month-rotating templates deferred.
- **`DayMenuSlot`, `MenuTemplateSlot`, `DayMenu`, `ResidentMealOrder` use upserts** keyed by their composite-unique identities. Re-running the materialisation or re-ordering on the same `(resident, date, category)` is safe and overwrites the slot/order rather than raising.
- **`ResidentMealOrder` upsert overwrites state to `:ordered` by default.** If a team marked an order as `:served` and a caregiver then re-orders for that resident-date-category, the row goes back to `:ordered`. v1 accepts this; a future phase can branch to `:update` when an existing row's state is `:served`.
- **Order-failure path uses `Ash.create/2` (non-bang)** in `ResidentOrderLive` so policy failures flash rather than crash the LV. Test coverage exercises both the success and denied paths.
- **PubSub topic `facility:{id}:kitchen`** — dedicated to kitchen events. The `pub_sub` block on `ResidentMealOrder` publishes `"order_changed"` on create / update / destroy. `SummaryLive` is the only subscriber today.
- **`MaterialiseTomorrow` runs at UTC 20:00.** That's local 21:00 / 22:00 in DACH (UTC+1/+2) — the kitchen sees a fresh plan when starting the next morning's prep.
- **Allergen warning, not hard-block.** v1 displays a red banner on `/kitchen/order/:resident_id` when the diet profile lists allergens; it doesn't disable product buttons. Phase 9 may add the hard-block.
- **Bottom nav layout when a team identity is signed in**: Home / Kitchen / Inbox / Sign out (Profile tab is dropped for team identities; team identities don't have a personal resident profile).
- **Cron worker uses `Caredeck.Org.Facility |> Ash.read!(authorize?: false)`** — system-level read, not actor-gated. Same pattern as `PruneOldNotifications` (Phase 6).
- **No notification fan-out on meal events.** A caregiver ordering for a resident doesn't trigger a Phase 6 `Notification` to other relatives. Deferred — Phase 10+ may add a "Family alerts on diet change" loop.

## What Phase 9 inherits

1. **Multi-row composite-unique upsert pattern** (`ResidentMealOrder` per `(resident_id, date, category)`) — Phase 9's `ServiceRequest` can use the same approach for per-resident-per-day uniqueness if desired.
2. **PubSub fan-out → LiveView re-aggregation** (`SummaryLive`) — Phase 9's per-provider inbox can mirror the same broadcast → re-render pattern on a `facility:{id}:services` topic.
3. **`MaterialiseTomorrow` cron + `Materialise` helper** — Phase 9 can defer scheduled materialisations (e.g. weekly laundry pickup reminders) by copying the pattern.
4. **Per-team-role policy clauses** (`role_kind in [:kitchen, :care]`) — Phase 9 will add `:reception` (or per-provider roles) similarly.
5. **Bottom nav slot pattern** — Phase 9 can add a **Services** tab alongside **Kitchen** via the same `<.nav_tab :if={@current_team}>` guard.

## Outstanding (deferred)

- **Family alerts on meal change** — when a relative orders or a team overrides, the resident's other relatives don't get a Phase 6 notification. Phase 10+ may add this loop.
- **Allergen hard-block** — v1 displays a warning banner; disabling product buttons that contain the resident's allergens is a future polish.
- **Multi-week templates** — v1 supports one active template per facility. Multi-week (e.g. month-rotating) requires a `MenuTemplate.start_week_offset` + a materialisation algorithm.
- **Product images** — v1 is text-only. Adding photos via the existing `/attachments/*key` proxy is a one-day follow-up.
- **Order printing** — chefs may want a printable shopping list. v1 only shows on-screen aggregates.
- **Bulk ordering** — team selects 10 residents, picks the day's plan for all of them in one tap. v1 requires per-resident navigation.
- **Mid-session badge refresh** — kitchen summary updates via PubSub, but the bell badge in `Layouts.app/1` still only refreshes on navigation.
- **Mobile screenshots** — `weekly-menu.png`, `day-editor.png`, `resident-order.png`, `summary.png` deferred to manual capture from a real device or browser DevTools at 414px.
