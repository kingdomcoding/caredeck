# Phase 9 — Checkpoint

**Date:** 2026-05-29
**Tag:** `v0.9.0-phase-9-complete`

## What shipped

- **`Caredeck.Services`** domain registered alongside Accounts / Org / People / Feed / Notifications / Kitchen.
- **3 resources + 3 paper-trail siblings** — `ServiceProvider`, `ServiceRequest`, `ServiceMessage`. All multitenant on `facility_id`, all using the `Caredeck.Resource` base, all with `default_pub_sub: false` so each declares its own pub_sub block.
  - `ServiceProvider` — typed external/internal provider; `kind` enum is one of `pharmacy | laundry | podiatry | hairdresser | doctor | physio | florist`; composite-unique on `(facility_id, kind)`; optional `team_identity_id` FK to the seeded provider team.
  - `ServiceRequest` — `subkind` (string), `payload` (jsonb), `state` ∈ `:open | :in_progress | :resolved | :cancelled`, `resolved_at` stamped by the `:transition` action; pub_sub on per-id + per-facility-inbox topics.
  - `ServiceMessage` — chat thread message under a request; pub_sub on the per-request topic.
- **`ProviderKind`** shared module — `all/0`, `label/1`, `subkinds_for/1`, `default_subkind/1`.
- **`PayloadSchema`** + **`ValidatePayload`** resource-change — payload jsonb is validated server-side at create time for every kind+subkind, default-raising on unknown shapes.
- **`Caredeck.Feed.Attachment` retrofit** — two new nullable FKs (`service_request_id`, `service_message_id`) on `feed_attachments`; `post_id` made nullable; existing photo-upload pipeline reused for prescription and laundry photos.
- **5 LiveViews** —
  - `/services` `Services.IndexLive` — tile grid of providers per facility.
  - `/services/:provider_id` `Services.ProviderLive` — provider detail + "New request" CTA + recent-requests list.
  - `/services/:provider_id/new` `Services.NewRequestLive` — kind-aware form with subkind switcher; Day 2 wired Pharmacy (3 subkinds); Day 3 added Laundry (complaint w/ photo) and Hairdresser (appointment w/ post_to_feed checkbox).
  - `/services/requests/:request_id` `Services.RequestLive` — payload card per subkind + chat thread + composer + team-only Resolve / Cancel / Mark-in-progress transitions; subscribes to `services:<rid>` pubsub and reloads on broadcast.
  - `/services/inbox` `Services.InboxLive` — `:care` / `:service` triage list; subscribes to `services:inbox:<facility_id>` and re-lists on broadcast.
- **Hairdresser → Feed side-effect** — when `payload["post_to_feed"]` is true, the LV creates a `Feed.Post` authored by the hairdresser's `team_identity_id` and tags the resident via `ResidentTagOnPost`; the post appears on `/feed` for families. Non-fatal: if the Post create fails, the ServiceRequest still stands.
- **`Caredeck.Notifications.Notification`** — `:verb` enum widened to include `:requested, :replied`; `:target_kind` widened to include `:service_request, :service_message`. `Phrasebook` gains two new clauses; `NotificationsLive.target_path/1` routes the new target_kinds to `/services/requests/:rid`.
- **`Caredeck.Workers.NotificationFanout`** — two new `perform/1` clauses for `service_request_created` and `service_message_created`. Request fan-out hits every relative of the request's resident (except the requester). Message fan-out hits the requester + every relative of the resident, except the author. `NewRequestLive` and `RequestLive` enqueue the jobs on submit.
- **Top header + bottom nav** — **Services** link visible to every authenticated subject at `md:`+; **Inbox** link visible only to `:care` teams; bottom nav grid widened to 5 columns with a new `:briefcase` icon for Services.
- **Seeds** — 4 provider TeamIdentities per facility (`team-pharmacy`, `team-laundry`, `team-hairdresser`, `team-doctor`, all `role_kind: :service`, all on `phase1-demo-pass`) and one `ServiceProvider` row each, linked back via `team_identity_id`.

## Demo credentials

| Type | Identifier | Password |
|---|---|---|
| Relative | `demo-relative@example.test` | `phase1-demo-pass` |
| Team Care | `team-care` | `phase1-demo-pass` |
| Team Kitchen | `team-kitchen` | `phase1-demo-pass` |
| **Team Pharmacy** | **`team-pharmacy`** | **`phase1-demo-pass`** |
| **Team Laundry** | **`team-laundry`** | **`phase1-demo-pass`** |
| **Team Hairdresser** | **`team-hairdresser`** | **`phase1-demo-pass`** |
| **Team Doctor** | **`team-doctor`** | **`phase1-demo-pass`** |

## Verification matrix

| Check | Result |
|---|---|
| `mix compile --warnings-as-errors` | ✅ |
| `mix test` | ✅ 154 / 154 (was 122 entering Phase 9 — 32 net-new specs) |
| Cross-tenant read of `ServiceProvider` / `ServiceRequest` / `ServiceMessage` | ✅ returns `[]` |
| `ServiceProvider.one_per_kind_per_facility` identity enforced | ✅ automated |
| `PayloadSchema.validate!/2` — happy + missing-field cases per subkind | ✅ automated (11 cases) |
| `/services` tile grid renders 4 seeded providers | ✅ Playwright |
| Pharmacy `prescription_upload` form — photo upload, attachment link, summary derived | ✅ automated |
| Pharmacy `medication_inquiry` form — text-only path | ✅ automated |
| Laundry `complaint` form — photo upload + reason select | ✅ automated |
| Hairdresser `appointment_request` with `post_to_feed=false` → no Post created | ✅ automated |
| Hairdresser `appointment_request` with `post_to_feed=true` → Post + ResidentTagOnPost created | ✅ automated |
| `Services.RequestLive` mount + chat composer + Resolve transition | ✅ automated |
| Relative cannot see transition buttons but can post messages | ✅ automated |
| `Services.InboxLive` lists open requests for `:care` team | ✅ automated |
| `Services.InboxLive` redirects non-`:care`/non-`:service` teams to `/services` | ✅ automated |
| `service_request_created` fan-out — relatives except requester | ✅ automated |
| `service_message_created` fan-out — requester + relatives except author | ✅ automated |
| Prod deployed at `caredeck.josboxoffice.com` and tile grid Playwright-verified | ✅ |

## Decisions and divergences

- **`payload` is jsonb keyed by `subkind`**, validated by a single `PayloadSchema.validate!/2` module rather than a per-subkind embedded resource. Trades schema rigour for kind-extensibility. Adding new subkinds = one new clause in `PayloadSchema` + one new arm in `NewRequestLive.render/1` + one new arm in `RequestLive.payload_card/1`.
- **Provider team identities reuse the existing `:service` `role_kind`** rather than minting per-provider enum values. The `TeamIdentity` enum already included `:service` from Phase 1.
- **`Feed.Attachment.post_id` made nullable + 2 new nullable FKs**, instead of building a parallel attachment table. Existing upload pipeline (S3 + Thumbnailer) is reused.
- **Hairdresser → Feed side-effect uses `authorize?: false`** for the Post create + ResidentTagOnPost create, since the requesting user may not be the hairdresser team identity. The post is a "facility happening" announcement.
- **No `state_pill` extracted to a shared module** despite being used in both `ProviderLive` and `RequestLive` — kept per-module so each LV owns its visual contract. Cheap to extract later if a third caller emerges.
- **`:management` role split is deferred**. Provider CRUD requires `:care` for now; a future phase can split out `:management`.
- **No SLA enforcement** — `response_time_target_hours` is displayed but not acted on. Phase 13 (operations) can add a cron that surfaces breaches.

## Files added

```
lib/caredeck/services.ex
lib/caredeck/services/provider_kind.ex
lib/caredeck/services/service_provider.ex
lib/caredeck/services/service_request.ex
lib/caredeck/services/service_message.ex
lib/caredeck/services/payload_schema.ex
lib/caredeck/services/validate_payload.ex
lib/caredeck_web/live/services/index_live.ex
lib/caredeck_web/live/services/provider_live.ex
lib/caredeck_web/live/services/new_request_live.ex
lib/caredeck_web/live/services/request_live.ex
lib/caredeck_web/live/services/inbox_live.ex
priv/repo/migrations/20260529063625_add_services_module.exs
test/caredeck/services/cross_tenancy_test.exs
test/caredeck/services/payload_schema_test.exs
test/caredeck/workers/services_notification_fanout_test.exs
test/caredeck_web/live/services/index_live_test.exs
test/caredeck_web/live/services/new_request_live_test.exs
test/caredeck_web/live/services/laundry_complaint_test.exs
test/caredeck_web/live/services/hairdresser_feed_test.exs
test/caredeck_web/live/services/request_live_test.exs
test/caredeck_web/live/services/inbox_live_test.exs
docs/checkpoints/phase-9/README.md
```

## Files changed

```
config/config.exs                                  # +Caredeck.Services in :ash_domains
lib/caredeck/feed/attachment.ex                    # post_id nullable + 2 new FKs + policy clauses
lib/caredeck/notifications/notification.ex         # widen :verb + :target_kind enums
lib/caredeck/notifications/phrasebook.ex           # +:requested, +:replied phrases
lib/caredeck/workers/notification_fanout.ex        # +service_request_created, +service_message_created clauses
lib/caredeck/release/seeds.ex                      # +seed_services/1
lib/caredeck_web/router.ex                         # +5 service routes
lib/caredeck_web/components/layouts.ex             # +Services link, +Inbox link, +briefcase nav icon, grid-cols-5
lib/caredeck_web/live/notifications_live.ex        # +:service_request / :service_message target_path
```
