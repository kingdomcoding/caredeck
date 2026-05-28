# Phase 6 — Checkpoint

**Date:** 2026-05-28
**Tag:** `v0.6.0-phase-6-complete`

## What shipped

- **`Caredeck.Notifications`** — new Ash domain alongside Feed/People/Org/Accounts.
- **`Caredeck.Notifications.Notification`** — multi-tenant resource (`facility_id`, `user_id`, `actor_kind` ∈ {`:user`, `:team`}, `actor_id`, `verb` ∈ {`:posted`, `:commented`, `:liked`, `:joined`}, `target_kind` ∈ {`:post`, `:comment`, `:reaction`, `:resident`}, `target_id`, `thumbnail_url`, `read_at`). Composite-unique identity `(user_id, actor_kind, actor_id, verb, target_kind, target_id)` makes the `:create` action an idempotent upsert. `:mark_read` / `:mark_unread` actions; policies gate reads / updates / destroys to `user_id == ^actor(:id)`; per-user pub_sub topic `user:{user_id}:notifications`.
- **`Caredeck.Notifications.Recipients`** — `for_post/2` loads a post and returns `{post, user_ids}` walking `audience → relative_links → relative`; `for_resident/2` returns all relative user_ids linked to a resident.
- **`Caredeck.Notifications.Phrasebook`** — verb-keyed sentence rendering with a friendly degraded fallback (`"Someone interacted with a post"`) for unknown verbs / nil input.
- **`Caredeck.Workers.NotificationFanout`** — rewritten as a 4-arm dispatcher on the `event` job arg: `post_created`, `comment_created`, `reaction_created`, `invitation_accepted`. Each clause computes recipients, excludes the originator (comment author / reactor / joiner), and upserts one Notification per recipient. The `:invitation_accepted` arm resolves the joiner via `Accounts.User` lookup on the invitation email so multi-relative families don't false-positive an existing relative as the joiner.
- **After-action wiring** — `Feed.Post.:create`, `Feed.Comment.:create`, `Feed.Reaction.:create`, and `People.RelativeInvitation.:accept` each enqueue a `NotificationFanout` job with the event tag in args.
- **`CaredeckWeb.NotificationsLive`** at `/notifications` — subscribes to the per-user topic, lookup maps for user / team / resident display, "Mark all read" toggle, click-to-open marks-read + push_navigates to the target (`/feed/:post_id` or `/residents/:resident_id`), Recent (< 7 days) / Older time-bucket split, empty-state SVG illustration.
- **Bell badge in `Layouts.app/1`** — unread count summed across the user's `FacilityMembership` rows, rendered as a red badge on a bell that links to `/notifications`; clamps at "99+"; hidden when count == 0 or when no `@current_user` (anonymous + team-only sessions don't see the bell).
- **`Caredeck.Workers.PruneOldNotifications`** — Oban cron worker, 90-day retention, per-facility scan, soft-archive via `Ash.destroy!`. Scheduled `15 3 * * *` in `config/runtime.exs` alongside `ExpireStaleInvitations`.
- **Migration `20260528123102_install_notifications`** — creates `notifications` table, `notifications_versions` paper-trail table, and the `notifications_unique_event_per_user_index`.

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
| `mix test` | ✅ 85 / 85 (67 inherited + 6 fanout + 3 multitenancy + 5 notifications_live + 1 prune + 3 phrasebook) |
| IEx: `Ash.read!(Notification)` without tenant | ✅ raises `Ash.Error.Invalid` |
| Cross-user `Ash.get(Notification, ..., actor: other_user)` | ✅ `{:error, ...}` (policy denies) |
| Cross-facility read of same `user_id` from other facility | ✅ 0 rows |
| `Post.create` → fanout → 1 Notification per audience relative | ✅ |
| `Comment.create` → fanout → audience minus author notified | ✅ |
| `Reaction.create` → fanout → audience minus reactor notified | ✅ |
| `RelativeInvitation.accept` → fanout → existing family minus joiner notified | ✅ |
| Re-run same fanout job twice | ✅ second run no-ops (upsert) |
| `/notifications` empty for new user | ✅ empty-state SVG + "No notifications yet" |
| `/notifications` with rows | ✅ desc order, Recent + Older buckets |
| Bell badge | ✅ unread count, "99+" past 99 |
| Mark all read | ✅ drops badge + Mark-all-read button to 0 |
| Click row | ✅ marks read + push_navigates to target |
| PubSub real-time | ✅ `Endpoint.broadcast("user:..:notifications", ...)` re-renders the list |
| Cron `PruneOldNotifications` | ✅ listed in Oban.config crontab at `15 3 * * *` |
| PruneOldNotifications worker | ✅ removes > 90 day rows, preserves recent |

## Decisions and divergences

- **Two-layer fan-out (ADR-007 confirmed)** — synchronous PubSub on the source domain (Feed posts/comments/reactions) for the inflight LiveView refresh plus a durable Oban `NotificationFanout` job that materialises rows. The two layers are independent: PubSub failures don't lose Notifications and Oban failures don't block the live feed render.
- **Idempotent upsert keyed on the event tuple** — `(user_id, actor_kind, actor_id, verb, target_kind, target_id)`. Oban's at-least-once delivery and reaction-toggle re-fires both become no-ops; the worker doesn't need its own dedupe table.
- **Soft-archive on retention cleanup (v1)** — `PruneOldNotifications` calls `Ash.destroy!` which goes through `AshArchival` (sets `archived_at`). Hard-delete via `Repo.delete_all` is deferred to Phase 13; v1 prefers consistency with the rest of the Notification CRUD over physical row removal.
- **Joiner resolution via email lookup, not Relative scan** — the first cut of the `invitation_accepted` clause picked any non-inviter relative as the "joiner", which false-positived in multi-relative families. The shipped clause resolves the User via the invitation's email and then finds their Relative row. Reason: the only durable signal connecting the invitation to the new user is the email.
- **Bell-badge query fires on every layout render** — for v1 the dataset is small (a few facility memberships per user, modest unread counts) and the cost is negligible. Phase 7 may cache the count in a process-state assign or via a LiveComponent that subscribes to the user's notification topic.
- **`unread_count/1` doesn't update mid-session** — layout is rendered once per dead render and stays static during a connected session. `/notifications` itself updates live via PubSub. The badge refreshes on navigation, which is acceptable for v1.
- **No push notifications in v1** — Phase 7 adds web-push subscriptions on top of the existing per-user pub_sub topic; the resource shape stays the same.

## What Phase 7 inherits

1. **`Notification` resource** — the idempotent upsert pattern + composite-unique identity become the seed shape for web-push payload generation.
2. **`NotificationFanout` worker** — Phase 7's web-push dispatcher hooks in as an additional after-effect on the same per-recipient loop; no rework of the resource model.
3. **`NotificationsLive` + bell-badge layout helper** — the read/unread model and time-bucket UX are the seed for a Phase 7 dropdown bell with inline rows.
4. **`PruneOldNotifications`** Oban cron — Phase 13 adds per-facility retention overrides; the worker shape stays the same.
5. **PubSub topic `user:{user_id}:notifications`** — Phase 7's web-push dispatcher subscribes here too and forwards to the user's registered subscriptions.

## Outstanding (deferred)

- **Web-push subscriptions** (Phase 7) — current v1 only updates the in-app inbox; no native browser push.
- **Per-facility retention** (Phase 13) — current global 90-day default; high-volume facilities may want a shorter window.
- **Unread-count caching** (Phase 7) — current layout helper queries on every render.
- **Hard-delete on cleanup** (Phase 13) — current `Ash.destroy!` soft-archives via AshArchival; `Repo.delete_all` would actually free row space.
- **Mid-session badge refresh** (Phase 7) — the bell badge currently only updates on navigation; a LiveComponent subscribed to the user's topic could keep it live.
- **Phrasebook localisation** (Phase 14) — current English-only sentences inline in `Phrasebook.render/1`.
