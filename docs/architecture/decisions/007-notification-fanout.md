# ADR 007: Notification fan-out via PubSub + Oban

**Status:** Accepted
**Date:** 2026-05-26

## Context

A single post can address a 20-resident audience, each with 4–6 connected relatives, each of whom expects:

- An in-app row in `/notifications` (the bell-icon inbox).
- A web-push notification (or APNs/FCM if the native shell is installed).
- A read/unread state synchronised across all devices.

That's ~100 notification rows per post and ~100 push deliveries, plus a real-time fan-out to any connected LiveView sessions.

## Decision

Two-layer fan-out:

1. **Synchronous, in-process:** On `Post.create` success, an `Ash.Notifier.PubSub` event publishes to topic `facility:{facility_id}:feed`. Any connected LiveView re-renders.
2. **Asynchronous, durable:** An Ash `after_action` enqueues a `Caredeck.Workers.NotificationFanout` Oban job on the `:fanout` queue. The worker materialises one `Notification` row per recipient and triggers a `Caredeck.Workers.PushDispatch` job for each (web-push, APNs, FCM).

`Notification` carries: `id, user_id, facility_id, actor, verb, target_kind, target_id, thumbnail_url, read_at, created_at`. Read-state writes go through an Ash action that updates the row and re-publishes via PubSub so other devices reflect the change.

## Consequences

**Gains:**

- Posters get a sub-100ms response — the heavy fan-out happens off-band.
- Notification creation is idempotent (composite uniqueness on `{actor, verb, target_kind, target_id, user_id}`); a re-run produces no duplicates.
- Push delivery failures don't block notification storage; the row exists and the in-app inbox still shows it.

**Costs:**

- Two layers means two failure modes. Mitigation: the PubSub event is fire-and-forget, the Oban job is the source of truth.
- Per-user notification rows balloon over time. Mitigation: AshArchival auto-prunes notifications older than 90 days (configurable per facility in Phase 6).
