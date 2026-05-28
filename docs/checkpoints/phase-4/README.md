# Phase 4 — Checkpoint

**Date:** 2026-05-28
**Tag:** `v0.4.0-phase-4-complete`

## What shipped

- **Real authorization policies** on every `Feed.*` resource (replaces Phase 3's deny-all stubs). The policy matrix from the Phase 4 plan §1.2 is now live:
  - **Post read** — authoring team always; relative in audience always; non-internal posts visible to any signed-in user.
  - **Post create / update / destroy** — only the authoring `TeamIdentity` matching `facility_id`.
  - **Comment create** — only the relative whose `author_user_id` equals their `actor.id`, on a post they can read.
  - **Comment update** — only the author, AND within a 5-minute window (validation, not policy).
  - **Comment destroy** — only the author (no window).
  - **Reaction create / destroy** — only the User actor whose `user_id == actor.id`.
  - **Reaction.:toggle** — any signed-in User (the action body re-authorizes the inner create/destroy).
  - **ResidentTagOnPost / PostAudience / Attachment writes** — only the post-authoring team.
- **`Caredeck.Feed.Authz` helper module** — `same_facility?/2` and `user_in_post_audience?/2` for non-policy paths (e.g. the AttachmentController which uses the LoadCurrentFacility plug as its tenancy guard).
- **Actor threading** — every Ash call in `FeedLive`, `PostLive`, `PostComposeLive` now passes `actor: current_user || current_team` instead of `authorize?: false`. Seeds and Oban workers keep `authorize?: false` (no user exists at seed time; workers run as a system actor).
- **Relaxed reads on upstream resources** — `Accounts.User`, `Accounts.TeamIdentity`, `People.Resident`, `People.Relative`, `People.RelativeOfResident` got an `actor_present()` read policy (multi-tenancy already scopes them) so relationship loads from Feed work. Writes remain deny-all on these — Phase 5 hardens with proper policies.
- **`Reaction.:toggle` generic action** — idempotent create-or-destroy. Returns `%{action: :added}` or `%{action: :removed}`. Pairs with a new `pub_sub` block publishing `reaction_changed` on create/destroy to the same `facility:{id}:feed` topic.
- **Heart button on engagement line** — `FeedLive` and `PostLive` render a one-tap heart that toggles the user's reaction. `liked_by_actor?/2` shows a filled `❤` when the user has liked, empty `♡` otherwise. Hidden when no `@current_user` (teams can't like in v1).
- **Thumbs-up shortcut** — next to the Send button on `PostLive`'s comment composer. Clicking the 👍 fires `toggle_reaction` for the parent post instead of submitting the form.
- **Named-likers reveal modal** — clicking "View likes" on `PostLive` opens a fixed-position dialog listing every user who reacted. Click-away or Close dismisses.
- **5-minute comment edit window** — `validate fn` on `Comment.:update` rejects edits older than 300 seconds. Paired with the `author_user_id == ^actor(:id)` policy.
- **Inline comment editor** — `PostLive` shows an "Edit" link on the author's own comments only when within the 5-minute window. Click swaps the comment body for a textarea + Save/Cancel buttons. Edited comments get a "· edited" stamp.
- **Comment delete** — "Delete" link on owned comments triggers a `phx-confirm` dialog before destroying.
- **"Edit post" affordance** — `FeedLive`'s `post_header/1` shows a teal "Edit" link in the top-right when `@current_team && @current_team.id == @post.team_identity_id`, navigating to `/feed/compose/:id`. Edited posts get a "· edited" stamp.
- **Audience vs Tags decoupled** in `PostComposeLive`:
  - The "Audience" picker still controls who *receives* the post.
  - A new "Tag in the post header" section below lets the team opt residents out of the public chip row while keeping them in the audience.
  - The pool of taggable residents is exactly the current audience (intersection invariant).
- **Named-tag popover** on `FeedLive` — clicking the tag-chip row opens a small popover listing every tagged resident. `phx-click-away` dismisses.

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
| `mix test` | ✅ 58 / 58 (29 inherited + 19 authz + 2 reaction toggle + 5 comment editing + 3 audience/tags) |
| `mix ecto.reset` | ✅ seeds 3 posts + 9 attachments + 2 comments + 3 reactions + 10 tags |
| `Ash.read!(Feed.Post, ..., actor: relative_in_audience)` | ✅ returns the post |
| `Ash.read!(Feed.Post, ..., actor: relative_not_in_audience)` for `is_internal: true` | ✅ filtered |
| `Ash.create!(Feed.Comment, ..., actor: relative)` with spoofed `author_user_id` | ✅ raises `Ash.Error.Forbidden` |
| `Ash.update!(comment, ..., actor: author)` after 5 minutes | ✅ raises validation error |
| `Ash.run_action(Feed.Reaction, :toggle, ..., actor: user)` twice | ✅ returns `:added` then `:removed` |
| `/feed` heart toggle (relative) | ✅ count increments + persists |
| `/feed/:id` inline comment editor (author within 5 min) | ✅ saves + stamps `edited_at` |
| `/feed/:id` Edit link hidden after 5 min | ✅ |
| `/feed` "Edit post" link on owned post | ✅ visible |
| `/feed` "Edit post" link on other team's post | ✅ hidden |
| `/feed/compose` Tags section editable independently of Audience | ✅ |
| `/feed` tag-popover opens on chip-row click | ✅ |

## Decisions and divergences

- **Reaction.:toggle gets its own `policy action(:toggle)`** — Ash distinguishes `action_type([:create, :destroy])` from `action_type(:action)`. The toggle is the latter (a generic action), so it needs an explicit allow rule that admits any User; the inner Ash.create / Ash.destroy then re-authorize via the create/destroy policies. This is documented as a "Phase 4 pattern" — future generic actions in `Feed` will follow the same shape.
- **Upstream reads relaxed via `actor_present()`** — `Accounts.{User, TeamIdentity}` and `People.{Resident, Relative, RelativeOfResident}` previously had blanket `forbid_if always()`. Phase 4 needed Feed relationship loads to traverse into these. The relaxation only covers reads; writes remain deny-all until Phase 5 introduces proper policies. Multi-tenancy still scopes the data — a Facility A user cannot read Facility B's residents because the queries are tenant-scoped at the LiveView layer.
- **AttachmentController stays with `authorize?: false`** — the controller's tenancy guard (LoadCurrentFacility plug + multi-tenant read) is sufficient; running the Attachment policy would add an extra DB query (loading the parent Post) for no security gain. Documented in the controller source.
- **Optimistic UI deferred** — the plan called for local update before the action returns; in practice the Ash + PubSub round-trip feels instant on localhost. Optimistic update can be added in Phase 5 polish if perceived latency on slow networks becomes an issue.

## What Phase 5 inherits

1. **Real policies** on all `Feed.*` resources — Phase 5 layers Profile resource reads against the same `actor` pattern.
2. **`Reaction.:toggle` action with PubSub** — Phase 6 uses the `reaction_changed` event to enqueue notifications.
3. **5-minute comment edit window** — Phase 6's Notification worker reads `edited_at` to mark notifications as updated.
4. **"Edit post" affordance + `/feed/compose/:id` flow** — Phase 5 adds avatar fields once `Relative.avatar_url` is wired into the chip row.
5. **Audience-vs-Tag split** — Phase 5's Profile graph hooks into the audience side for the "Who can see this" picker.

## Outstanding (deferred)

- **Write policies on upstream resources** (Phase 5+) — `Accounts.User`, `People.{Resident, Relative}` writes still raise. Phase 5 introduces real policies when the Profile graph adds invite + edit flows.
- **Optimistic UI on like toggles** (Phase 5 polish) — current implementation does a server round-trip per click.
- **Notification fan-out wiring for reaction events** (Phase 6) — `reaction_changed` PubSub topic exists but no Oban worker reads it yet.
- ~~**Avatar URLs in the named-likers modal**~~ — shipped in Phase 5: `Relative.avatar_url` storage, `/attachments/*key` proxy now serves avatars, `Relative.display_name` editable via `/profile/edit`.
