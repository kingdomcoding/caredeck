# Phase 3 — Checkpoint

**Date:** 2026-05-28
**Tag:** `v0.3.0-phase-3-complete`

## What shipped

- **`Caredeck.Feed` domain** — fourth multi-tenant domain after `Accounts`, `Org`, `People`.
- **`Caredeck.Feed.Post`** — multi-tenant (`facility_id`), `team_identity_id` author, `body`, `is_internal`, `published_at`, `edited_at`. Explicit `pub_sub` block publishing `post_created`/`post_updated`/`post_deleted` to topic `facility:{facility_id}:feed`.
- **`Caredeck.Feed.PostAudience`** — multi-tenant Post↔Resident join with `unique_post_resident` identity. Controls who *receives* a post in their feed.
- **`Caredeck.Feed.ResidentTagOnPost`** — multi-tenant Post↔Resident join for named-chip tagging. Separate from audience so a future "social-only" tag without notifications is foreseeable.
- **`Caredeck.Feed.Comment`** — multi-tenant, `author_user_id` belongs_to `Accounts.User`, `edited_at` stamp on update.
- **`Caredeck.Feed.Reaction`** — multi-tenant, `kind ∈ {:like, :heart}`, identity `one_reaction_per_user_per_post`.
- **`Caredeck.Feed.Attachment`** — multi-tenant, `kind ∈ {:photo, :video, :audio, :document}`, `s3_key`, `thumbnail_s3_key`, `position` for grid ordering. Generic `:request_upload_url` action returns pre-signed PUT URLs.
- **MinIO sidecar** — `docker-compose.yml` (dev, ports 9000/9001 bound to 127.0.0.1) and `docker-compose.prod.yml` (internal network only, healthcheck). Bucket: `caredeck-attachments`.
- **`Caredeck.Feed.S3`** — thin ex_aws wrapper: `bucket/0`, `ensure_bucket!/0`, `put_object/3`, `get_object/1`, `presigned_put_url/2`, `generate_key/2`.
- **`Caredeck.Workers.Thumbnailer`** — Oban worker on `:thumbnails` queue. Stub writes a placeholder `thumbnail_s3_key`; gated by `:thumbnailer_mode` config (`:async` enqueues, `:sync` runs inline, `:off` skips). Phase 7 swaps for real image processing.
- **`Caredeck.Workers.NotificationFanout`** — Oban worker on `:fanout` queue. Stub loads the audience + relatives and logs the unique recipient count. Enqueued via `Post.create` `after_action`. Phase 6 fills in the actual `Notification` resource.
- **`/attachments/*key`** — Phoenix controller behind the `:authenticated_browser` pipeline (which composes `:browser` + `LoadCurrentFacility` plug). Multi-tenancy guard reads the Attachment with `tenant: current_facility.id`; cross-tenant requests return 404 (not 401 — we don't leak existence).
- **`CaredeckWeb.Plugs.LoadCurrentFacility`** — conn-side mirror of `LiveUserAuth.resolve_facility/1`: resolves `@current_facility` from `current_team_identity.facility_id` or first `FacilityMembership` for the user.
- **`CaredeckWeb.FeedLive`** — Phase 2 stub replaced. Reads posts sorted `inserted_at: :desc` with `:team_identity`, `:attachments`, `:resident_tags`, `comments: [:author]`, `:reactions`. Subscribes to `"facility:#{id}:feed"` on mount; handles `post_created` / `post_updated` / `post_deleted` events. Multi-photo grid (1/2/3/4+ overflow). Tag-chip row with "and N more". Engagement line ("❤ N likes · 💬 N comments"). "+" floating action button gated by `@current_team`.
- **`CaredeckWeb.PostLive`** — `/feed/:post_id` detail. Full comment list with relationship labels resolved by joining `Comment.author` → `Relative` → `RelativeOfResident` for any resident in the post's audience. Comment composer at the bottom.
- **`CaredeckWeb.PostComposeLive`** — `/feed/compose` (new) and `/feed/compose/:edit_post_id` (edit). Edit-mode mount guards on `post.team_identity_id == current_team.id`. `allow_upload(:photos)` with 9-file / 10MB caps. "All residents" master toggle with partial-state indicator. Per-resident audience checkboxes. Server-side upload pipes to S3 via `Feed.S3.put_object/3`.
- **`on_mount` `:live_user_or_team_required`** — admits either signed-in users or team identities. `/feed` is now gated (Phase 2's `:live_signed_in_optional` removed). Anonymous → redirect to `/sign-in`.
- **Cross-tenant isolation tests** for `Feed.Post` — verify that `Ash.read!(Post, tenant: B)` never returns Facility A's rows and that no-tenant raises.
- **`AttachmentController` cross-tenant tests** — anonymous 401, cross-tenant 404, in-facility hit passes the guard.
- **`NotificationFanout` enqueue test** — every `Post.create` adds a job with the right args.
- **Sandbox seed expanded** — `Feed.S3.ensure_bucket!()`, 3 demo posts (team-care 3 photos / team-activities 4 photos / team-therapy 2 photos), 9 attachments, 2 comments, 3 reactions, 10 resident tags.

## Demo credentials

| Type | Identifier | Password |
|---|---|---|
| Relative | `demo-relative@example.test` | `phase1-demo-pass` |
| Team Care | `team-care` | `phase1-demo-pass` |
| Team Activities | `team-activities` | `phase1-demo-pass` |
| Team Therapy | `team-therapy` | `phase1-demo-pass` |
| 80× generated relatives | `<first>.<last>.<n>@example.test` | `phase2-bulk-pass` |

## Verification matrix

| Check | Result |
|---|---|
| `mix format --check-formatted` | ✅ |
| `mix compile --warnings-as-errors` | ✅ |
| `mix test` | ✅ 29 / 29 (18 inherited + 3 Feed multi-tenancy + 1 fanout + 2 attachment_controller + 2 FeedLive + 3 PostCompose) |
| `mix ecto.reset` | ✅ seeds 3 posts + 9 attachments + 2 comments + 3 reactions + 10 tags in ~10s |
| `Ash.read!(Feed.Post)` without tenant | ✅ raises `Ash.Error.Invalid` |
| `Ash.read!(Feed.Post, tenant: facility_a)` cross-tenant leak | ✅ 0 rows from Facility B returned |
| PubSub broadcast on `Post.create` | ✅ subscriber receives `post_created` event within a tick |
| Oban `:thumbnails` queue | ✅ 9 jobs ran on `mix ecto.reset` + `mix phx.server`, each Attachment got `thumbnail_s3_key` |
| Oban `:fanout` queue | ✅ enqueued on every Post.create (worker logs recipient count) |
| `/feed` anonymous | ✅ 302 to `/sign-in` |
| `/feed` signed-in relative | ✅ 200, 3 posts with photo grids + tag chips + engagement line |
| `/feed` signed-in team | ✅ 200, plus "+" FAB |
| `/feed/compose` signed-in team | ✅ 200, body + uploader + "All residents" toggle + per-resident checkboxes |
| `/feed/compose` signed-in user (no team) | ✅ 302 to `/team/sign-in` |
| Cross-tenant 404 on `/attachments/*key` | ✅ (controller test) |
| Anonymous 401 on `/attachments/*key` | ✅ (controller test) |

## Decisions and divergences

- **`Caredeck.Resource` macro `default_pub_sub:` opt** — added so `Post` can declare its own per-facility topic instead of inheriting the generic `prefix("resource")` from the base macro. All existing resources still get the default block by passing nothing.
- **Server-side upload chosen over pre-signed PUT for v1** — simpler dev loop; the `:request_upload_url` action ships the contract for the native shell (Phase 5+) to use direct uploads later.
- **Thumbnailer is a stub** — writes a placeholder `thumbnail_s3_key` and logs. Phase 7 swaps in real image processing (vips/Image).
- **NotificationFanout is a stub** — logs the unique recipient count but does not write `Notification` rows. Phase 6 ships the `Notification` resource and push delivery.
- **`Feed.Post` policies are still deny-all** — Phase 3 explicitly defers authorization to Phase 4. Every Ash call in LiveViews/seeds uses `authorize?: false`. **Security debt point** — must be addressed before any real PII goes through this surface.
- **Hackney pin: `~> 1.20`** — kept the existing pin to stay compatible with `phoenix_swoosh ~> 1.2`. Configured ex_aws to use `ExAws.Request.Req` as its HTTP client instead of the hackney default. Same outcome; one less version-conflict risk.
- **`/feed` `on_mount` tightened to `:live_user_or_team_required`** — Phase 2's `:live_signed_in_optional` was deliberately permissive when the page was a resident-list stub. Phase 3's feed has real PII, so anonymous viewers are redirected.
- **Route ordering** — `/feed/compose` is declared before `/feed/:post_id` so Phoenix dispatches the literal route first (otherwise `post_id="compose"` matches).

## Outstanding (deferred)

- **Real thumbnailing** (Phase 7) — `Caredeck.Workers.Thumbnailer` currently writes a placeholder key. Real vips/Image call needed before the UI starts loading thumbnails.
- **`Notification` resource + push delivery** (Phase 6) — `NotificationFanout` already computes the recipient set; just needs the resource to write into and the push dispatch job.
- **Pre-signed PUT direct uploads** (Phase 7) — `:request_upload_url` action exists; native shell from Phase 5+ wires it up.
- **Video transcoding** (Phase 7+) — `Attachment.kind == :video` is accepted but stored raw; Phase 7+ transcodes via Oban.
- ~~**Real policies on `Feed.Post` / `Comment` / `Reaction`**~~ — shipped in Phase 4 (see `docs/checkpoints/phase-4/README.md`).
- ~~**Comment edit window + thumbs-up shortcut**~~ — shipped in Phase 4.

## What Phase 4 inherits

1. `Caredeck.Feed.Post` — `:create`, `:update`, `:read`, `:destroy` actions + PubSub publishing on all three write actions.
2. `Caredeck.Feed.Comment` — Phase 4 layers policies + 5-minute edit window.
3. `Caredeck.Feed.Reaction` — Phase 4 adds a `:toggle` action + one-tap UI.
4. `Caredeck.Feed.ResidentTagOnPost` — Phase 4 wires the in-composer tagger.
5. `/attachments/*key` proxy route — Phase 4+ adds video range requests.
6. `CaredeckWeb.{FeedLive, PostLive, PostComposeLive}` — Phase 4 hooks policies + the relationship-labeled comment composer.
7. `Caredeck.Workers.NotificationFanout` — Phase 6 fills in the real `Notification` resource.
