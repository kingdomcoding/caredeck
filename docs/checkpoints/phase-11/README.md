# Phase 11 — Checkpoint

**Date:** 2026-05-29
**Tag:** `v0.11.0-phase-11-complete`

## What shipped

- **`Caredeck.Formfix.ApplicationNote`** — admin-only, append-only note resource. Multi-tenant on `facility_id`. Policies: read/create require `:admin` role; destroy requires `:admin` AND authorship. Paper-trail mirror. Composite index on `(facility_id, application_id, inserted_at)`.
- **`TeamIdentity.role_kind`** widened with `:admin`. New `team-admin` seeded per facility.
- **`Caredeck.Formfix.Application` `:read` policy** widened to allow `:admin` alongside `:care` — read-only access; admins do not create, submit, approve, or mark-missing.
- **`CaredeckWeb.LiveUserAuth.on_mount(:live_team_admin_required, ...)`** — redirect-on-non-admin guard.
- **`/formfix/admin` (`Formfix.AdminLive`)** — facility-scoped table of Resident · Relative · Status · Progress · Notes, with an inline per-row note-add form. PubSub-driven reload on note creation. Mobile fallback as stacked cards (`md:hidden`).
- **`Caredeck.Workers.FormfixDigestDispatch`** + **`Caredeck.Workers.FormfixDigest`** — two-job cron pattern. Dispatcher fires Monday 09:00 UTC, enqueues one digest job per facility on the `:mailers` queue.
- **`Caredeck.Formfix.DigestEmail`** — Swoosh email builder. Inline-styled HTML status pills (5 distinct hex pairs) + plaintext fallback + `Note:` rows under each application + green ✓ celebration line per application approved in the last 7 days.
- **Top-nav admin link** — desktop-only; conditional on `current_team.role_kind == :admin`.
- **`Caredeck.Mailer`** test adapter set to `Swoosh.Adapters.Test` in `config/test.exs`.

## Demo credentials

| Type | Identifier | Password |
|---|---|---|
| Team Admin | `team-admin` | `phase1-demo-pass` |
| Relative (existing) | `demo-relative@example.test` | `phase1-demo-pass` |
| Team Care | `team-care` | `phase1-demo-pass` |

## Verification matrix

| Check | Result |
|---|---|
| `mix compile --warnings-as-errors` | clean |
| `mix test` | 229 / 229 green |
| Admin LiveView redirect non-admin → `/` | 1 spec green |
| Admin sees only their facility's applications | 1 spec green |
| `render_submit("add-note", …)` creates row + re-renders | 1 spec green |
| Empty body submit is no-op | 1 spec green |
| `ApplicationNote` admin create + cross-tenant read + author-only destroy | 6 specs green |
| `FormfixDigest` delivers, contains all residents + celebration line | 3 specs green |
| `FormfixDigestDispatch` enqueues one job per facility | 1 spec green |
| `DigestEmail.inline_pill_style/1` returns 5 distinct hex pairs | 3 specs green |
| Cross-facility note read returns empty | covered |
| Append-only (no `:update` action) | by construction |

## Files added / changed

- `lib/caredeck/formfix/application_note.ex` — new resource.
- `lib/caredeck/formfix/digest_email.ex` — Swoosh email builder + hex tables.
- `lib/caredeck/formfix.ex` — register `ApplicationNote` + `ApplicationNote.Version`.
- `lib/caredeck/formfix/application.ex` — `:read` policy widened to include `:admin`.
- `lib/caredeck/accounts/team_identity.ex` — `role_kind` enum widened with `:admin`.
- `lib/caredeck/workers/formfix_digest.ex` — digest worker.
- `lib/caredeck/workers/formfix_digest_dispatch.ex` — dispatcher.
- `lib/caredeck_web/live/formfix/admin_live.ex` — `/formfix/admin` LiveView.
- `lib/caredeck_web/live_user_auth.ex` — `:live_team_admin_required` on_mount.
- `lib/caredeck_web/router.ex` — `:authenticated_team_admin` live_session + `/formfix/admin` route.
- `lib/caredeck_web/components/formfix_components.ex` — `notes_strip/1` component.
- `lib/caredeck_web/components/layouts.ex` — admin top-nav link.
- `lib/caredeck/release/seeds.ex` — `Team Admin` per facility + idempotent demo notes.
- `config/runtime.exs` — `FormfixDigestDispatch` cron entry.
- `config/test.exs` — Swoosh test adapter.
- `priv/repo/migrations/20260529120855_add_formfix_application_notes.exs` — table + paper-trail mirror + composite index.
- `priv/resource_snapshots/repo/formfix_application_notes/` + `_versions/` — new.
- `priv/resource_snapshots/repo/formfix_application_sections/20260529120858.json` — incidental refresh.
- `test/caredeck/formfix/application_note_test.exs` — 6 specs.
- `test/caredeck_web/live/formfix/admin_live_test.exs` — 4 specs.
- `test/caredeck/workers/formfix_digest_test.exs` — 3 specs.
- `test/caredeck/workers/formfix_digest_dispatch_test.exs` — 1 spec.
- `test/caredeck/formfix/digest_email_test.exs` — 3 specs.
- `docs/architecture/decisions/012-formfix-admin-digest.md` — ADR.

## Decisions and divergences from the plan

- **No `@theme` token migration for status pill colours.** The plan suggested moving the 5 status hex pairs into `@theme` so the dashboard pill and email body share the same CSS variable. Kept the existing tailwind utility classes on the pill and synced hex constants between the pill clauses and `DigestEmail.inline_pill_style/1`. Same outcome; lighter touch.
- **`Application` `:read` widened, not a parallel `:read_admin` action.** Simpler and matches the existing pattern for `:care` access.
- **`relative_name/1` and a fallback chain** instead of a stored "primary applicant name" column — relative resolution reads from `applicant_user.name`, then `applicant_team.name`, then `—`.
- **Recipient mailbox derived from facility slug** — see ADR-012. Per-facility admin email column is stretch.
- **Mobile admin nav link deferred.** The bottom-nav is already 4-wide; adding admin would require a redesign and admins typically work on desktop. Documented in the checkpoint.
- **No timezone awareness on the cron.** Monday 09:00 UTC for every facility. See ADR-012.

## Risks the next phase inherits

- **Digest cron fires in UTC** — when real facilities arrive, the timezone column + per-facility cron pattern will need to land.
- **No per-facility admin email column** — slug-derived mailbox works for the demo and as a plus-addressing trick for an ops team, but real facility admins will want their own.
- **No edit on notes** — append-only by design; destroy + create is the workaround.
- **No notification-bell mirror** for new notes — admins see notes only by visiting the dashboard.
- **No filter / sort / search** on the admin table — fine at <50 applications; will need adding sooner than that.

## Acceptance scenario

1. Sign in as `team-admin` / `phase1-demo-pass`. Top nav shows **Admin** link (desktop).
2. Click **Admin** → `/formfix/admin` lists every Formfix application in the facility with colour-coded status pill, blended progress bar, and a 2-line note preview per row.
3. Type into the inline "Add a note…" form on any row, hit **Save** — the note appears immediately above the input without page reload.
4. From IEx: `Caredeck.Workers.FormfixDigest.perform(%Oban.Job{args: %{"facility_id" => fid}})` — email arrives in Swoosh local viewer (`/dev/mailbox` in dev) or in `Swoosh.Adapters.Test`'s mailbox in tests. Verify the table renders one row per application, each status badge has the right colour, and notes appear under their parent rows.
5. Approve an application via IEx (`Ash.Changeset.for_update(app, :approve, %{outcome: "Approved"})`), re-run the digest, confirm **"✓ Anne Smith's application was successfully approved!"** appears below the table.
6. `mix compile --warnings-as-errors` clean. `mix test` green (229 / 229).
7. Tag `v0.11.0-phase-11-complete`.
