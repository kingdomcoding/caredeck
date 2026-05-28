# Phase 5 — Checkpoint

**Date:** 2026-05-28
**Tag:** `v0.5.0-phase-5-complete`

## What shipped

- **`Caredeck.People.RelativeInvitation`** — multi-tenant resource (`inviter_user_id`, `resident_id`, `email`, `suggested_relationship`, `token`, `expires_at`, `accepted_at`) with `unique_pending_per_resident_email` partial-unique identity. `Phoenix.Token.sign/verify` helpers, 7-day expiry, `:create` after_action signs and emails, `:accept` action stamps `accepted_at`.
- **`Caredeck.Accounts.RelativeInvitationNotifier`** — Swoosh-based mailer sending HTML + text invitation emails referencing the inviter, the resident, the facility, and the magic-link URL.
- **`Caredeck.Workers.ExpireStaleInvitations`** — Oban cron worker scheduled at `0 3 * * *` (daily 03:00 UTC) that destroys past-due unaccepted invitations across all facilities.
- **`CaredeckWeb.InviteRelativeLive`** at `/residents/:resident_id/invite` — form gated on the inviter being in the resident's family graph (`inviter_in_graph?/3` check), email input + relationship dropdown + Send.
- **`CaredeckWeb.AcceptInvitationLive`** at `/invitations/:token` — verifies token, branches new-vs-existing user, idempotent `ensure_user / ensure_relative / ensure_membership / ensure_relationship` calls, marks `accepted_at`. Tampered / expired / already-accepted tokens flash + redirect.
- **`CaredeckWeb.ProfileLive`** at `/residents/:resident_id` — two-tab graph view (Relatives + Caregivers) with switch_tab handler, "Me" badge on the current user's row, `<.avatar>` component (image-or-initials fallback), `+` floating action button linking to the invite form.
- **`CaredeckWeb.EditProfileLive`** at `/profile/edit` — loads current user's `Relative` row plus their primary `RelativeOfResident` link; updates display_name, phone, avatar (via `Feed.S3` under `avatars/` prefix), and the relationship on the primary link.
- **Avatar serving** — `/attachments/*key` proxy now matches `Relative.avatar_url` and `CaregiverProfile.avatar_url` in addition to `Feed.Attachment.{s3_key, thumbnail_s3_key}`. Each query is `tenant: facility.id`-scoped so cross-facility avatar leaks are impossible.
- **`Relative.:update` policy** — `authorize_if expr(user_id == ^actor(:id))` so signed-in relatives can edit their own row (with `require_atomic? false` so the policy runs in process).
- **Resident-name links** — `/feed` tag-popover resident names now navigate to `/residents/:id`. Header nav surfaces **Profile** (first connected resident) and **Edit** (own profile) when `@current_user` is set.

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
| `mix test` | ✅ 67 / 67 (58 inherited + 5 accept_invitation + 3 profile + 1 invitation_flow) |
| `mix ecto.reset` | ✅ unchanged seed counts (Phase 5 adds no seed data) |
| IEx: `Ash.create!(RelativeInvitation, ..., actor: inviter)` | ✅ token signed, email enqueued |
| IEx: `RelativeInvitation.verify_token(token)` round-trip | ✅ returns invitation_id |
| IEx: duplicate pending invitation for `(resident_id, email)` | ✅ rejected by partial-unique identity |
| `/invitations/<tampered>` | ✅ redirect to /sign-in with flash |
| `/invitations/<valid>` | ✅ registration form pre-fills email + relationship |
| Accept new-user flow | ✅ creates User + Relative + FacilityMembership(:invited) + RelativeOfResident + sets accepted_at |
| Accept existing-user flow | ✅ re-uses User, just adds RelativeOfResident |
| `/residents/:id` Relatives tab | ✅ shows family graph with "Me" badge |
| `/residents/:id` Caregivers tab | ✅ shows facility caregivers |
| `/profile/edit` round-trip | ✅ display_name + phone + relationship + avatar all save |
| `/attachments/avatars/<key>` cross-facility | ✅ 404 |
| `/attachments/avatars/<key>` in-facility | ✅ 200 with image bytes |
| Tagged resident name in `/feed` chip popover | ✅ navigates to `/residents/:id` |

## Decisions and divergences

- **Auto-sign-in deferred** — after a successful accept the user is redirected to `/sign-in` with a welcome flash. AshAuthentication's `store_in_session/2` expects a `:token` in the user's metadata, which is populated by the sign-in action pipeline but not by the manual `Ash.create!` we do during invite acceptance. Phase 6 wires this tighter once the magic-link strategy is hardened.
- **Single-resident relationship edit** — `/profile/edit` updates the relationship on the user's **primary** RelativeOfResident link only (ordered by `is_primary_contact DESC, inserted_at ASC`). Relatives connected to multiple residents get a Phase 6 per-resident relationship picker.
- **Avatar proxy via `/attachments/*key`** — instead of a separate `/avatars/*key` route. Same MinIO bucket under `avatars/` prefix, same multi-tenancy guard. The controller now matches three resources (`Feed.Attachment`, `People.Relative`, `People.CaregiverProfile`) all tenant-scoped.
- **Inviter must already be in the resident's family** — `inviter_in_graph?/3` blocks signed-in users who don't have a `RelativeOfResident` row for the target resident. This prevents random "spray" invites for any resident in the facility.
- **`Relative.update` policy added** — Phase 4 left writes on People resources deny-all. Phase 5 opens `:update` for the actor's own row (with `require_atomic? false` so the policy runs in process).
- **Profile nav link picks first connected resident** — `Layouts.app/1` finds the user's earliest `RelativeOfResident` link by `inserted_at` and links there. Phase 6 introduces a picker if a user is connected to multiple residents.

## What Phase 6 inherits

1. **`RelativeInvitation` + token helpers** — Phase 6 hooks the `:accept` action's after-effects into the Notification fan-out ("Family member joined").
2. **`ProfileLive` + `EditProfileLive`** — Phase 6 layers notification dots on the Profile nav link and per-resident relationship editing.
3. **`avatars/` prefix on the existing MinIO bucket + extended `/attachments/*key` proxy** — Phase 6+ adds a "thumbnailer" path that resizes avatars; the contract stays the same.
4. **`Caredeck.Workers.ExpireStaleInvitations`** Oban cron — Phase 6 adds notification cleanup alongside it.
5. **Accept-invitation flow** — `ensure_*` helpers are the seed for Phase 6's invitation-driven Notification rows.

## Outstanding (deferred)

- **Auto-sign-in after accept** (Phase 6) — currently redirects to `/sign-in` with welcome flash.
- **Per-resident relationship edit** (Phase 6) — current EditProfile only touches the primary link.
- **Avatar cropping / preview UX** (Phase 7 polish) — current upload accepts any image up to 5MB without client-side cropping.
- **Multi-resident relative landing page** (Phase 6) — currently the header "Profile" link picks the first connected resident by `inserted_at`.
- **Token resend / expiry warning** (Phase 6) — current invite UI just sends once; no UI to resend or check expiry status.
- **Notification fan-out for "family member joined"** (Phase 6 mainline) — `accept` sets `accepted_at` but no Oban job yet uses that signal.
