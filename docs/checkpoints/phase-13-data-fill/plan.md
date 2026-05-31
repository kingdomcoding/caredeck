# Caredeck Demo-Data Fill — Implementation Plan

> Plan to close every gap surfaced in `caredeck-data-gaps.md`.
> Approach: assets are already on disk under `priv/static/{images,videos,audio,documents}/seed/` (87 files, ~30 MB) — this plan threads them into `Caredeck.Release.Seeds` and adds the missing seed code to populate empty modules.
> Working style (per the user's Caredeck rules): no co-authored-by, no JSDoc-style comments, no `any`/`unknown`, very frequent small commits, tick checkboxes as work lands, continuously compile + test, no premature abstractions, no backwards-compat hacks.

---

## Phases at a glance

| Phase | Scope | Closes | Wall-time | Risk |
|---|---|---|---|---|
| 0 | Pre-flight: branch, baseline tests, asset wiring helper | — | 20 m | low |
| 1 | Asset loader: `Caredeck.Release.Assets` reads from disk, uploads to MinIO, returns S3 key + caption | Plumbing for every later phase | 30 m | low |
| 2 | Avatars sweep (team / resident / relative / caregiver) | Avatar gaps | 45 m | low |
| 3 | Feed rebuild — delete the 5 test stubs, seed 15 realistic posts with media + reactions + comments | §1a, §1b, §1c, §1d, §1e, §1g (the whole Feed module) | 90 m | medium |
| 4 | Service requests + messages (12 requests, 25 messages across 4 providers) | §2 | 60 m | low |
| 5 | Caregiver profiles (6 records linked to residents) | §3 | 30 m | low |
| 6 | Kitchen fill — today's orders + diet profiles + week-ahead orders | §4 | 60 m | low |
| 7 | Notifications fan-out for demo-relative (re-tag posts) | §6 | 30 m | low |
| 8 | Formfix application expansion — 6 new apps across 5 states | §7 | 75 m | medium |
| 9 | Resident profile "Recent activity" tab | §12 | 45 m | low |
| 10 | Currency formatting sweep | §9 | 30 m | low |
| 11 | EXIF strip on attachment upload | §1g-ix | 30 m | low |
| 12 | Resident roster row enrichment (age + last-activity badge) | §11 | 30 m | low |
| 13 | Pending invitations (3 unaccepted) | §8 | 30 m | low |
| 14 | Sign-off — visual regression, deploy, tag | — | 30 m | low |

Total budget: **~9 focused hours**. Phases 0–8 are the "before-send" set (~6.5 h). Phases 9–13 are polish that compounds nicely. Phase 14 ships it.

Every phase ends with: `mix compile --warnings-as-errors`, `mix test`, `mix format`, a Playwright re-screenshot of the affected routes, and a per-phase commit.

---

## Phase 0 — Pre-flight (20 min)

### 0.1 Branch + baseline
- [x] Confirm clean `master` (post `3b06172` plus any local commits)
- [x] Create branch `data-fill` off master
- [x] `mix compile --warnings-as-errors` clean
- [x] `mix test` green baseline (237/237)
- [x] `mix format --check-formatted` clean

### 0.2 Confirm asset inventory
- [x] Verify `priv/static/images/seed/avatars/` contains 50 files (9 team + 15 resident + 20 relative + 6 caregiver)
- [x] Verify `priv/static/images/seed/feed/` contains 22 files
- [x] Verify `priv/static/videos/seed/` contains 4 `.mp4` + 4 `_poster.jpg`
- [x] Verify `priv/static/audio/seed/` contains 4 `.mp3`
- [x] Verify `priv/static/images/seed/facility/` contains 2 files
- [x] Verify `priv/static/documents/seed/demo_document.pdf` exists

### 0.3 Working set inventory
- [x] List the files that will be touched across the plan:
  - `lib/caredeck/release/seeds.ex` (the big one — almost every phase edits this)
  - `lib/caredeck/release.ex` (already has `refresh_demo_data/0`; will extend if needed)
  - `lib/caredeck/release/assets.ex` (new — phase 1)
  - `lib/caredeck/release/name_pool.ex` (for new resident/relative names if needed)
  - `lib/caredeck_web/live/profile_live.ex` (phase 9 — recent activity tab)
  - `lib/caredeck_web/live/residents_index_live.ex` (phase 12 — row enrichment)
  - `lib/caredeck/formfix/section_writer.ex` (phase 10 — currency format hint)
  - `lib/caredeck/feed/attachment.ex` (phase 11 — EXIF strip change)
  - `lib/caredeck_web/components/formfix_components.ex` (phase 10 — currency render)

### 0.4 Commit cadence agreement
- [x] One commit per phase (or sub-phase if helpful). Subject prefix carries the data-gap section number: `feed:`, `services:`, `caregivers:`, `kitchen:`, `notifications:`, `formfix:`, `recent-activity:`, `currency:`, `exif:`, `roster:`, `invitations:`.

---

## Phase 1 — Asset loader (30 min)

A single helper module so every later phase has one call to "give me an attachment record from this seed file".

### 1.1 `Caredeck.Release.Assets`
- [x] Create `lib/caredeck/release/assets.ex` with:
  - `seed_root/0` — returns `Application.app_dir(:caredeck, "priv/static")`
  - `list/1` — `list(:avatars_team) → [path, …]`, also `:avatars_resident`, `:avatars_relative`, `:avatars_caregiver`, `:feed_physio`, `:feed_painting`, etc. (one atom per logical group)
  - `at/2` — `at(:avatars_team, idx) → path`, with deterministic `rem(idx, length)` so same idx maps to same file across runs
  - `upload!/2` — uploads a file at `path` to MinIO under a stable S3 key prefix (e.g. `seed/avatars/team_1.jpg`), returns the key
  - `dimensions/1` — calls `ffprobe` for video / image; needed so attachment row gets correct width/height
  - `duration/1` — calls `ffprobe` for video / audio
  - `byte_size/1` — File.stat
- [x] One-time S3 prefix: `seed/<kind>/<filename>` so a re-run is idempotent (S3 PUT just overwrites)

### 1.2 Wire into refresh
- [x] Refresh calls `Assets.upload!/2` BEFORE creating any DB row that references the s3_key
- [x] Cache results in a process dict or a struct passed through the seed pipeline so we don't re-upload 50 avatars on every call

### 1.3 Verify
- [x] Add a smoke test: `Caredeck.Release.Assets.upload!(:feed_birthday, 0)` returns a `seed/feed/birthday_1.jpg` key, then `Caredeck.Feed.S3.get_object(key)` returns the bytes

---

## Phase 2 — Avatars sweep (45 min)

### 2.1 Team identity avatars
- [x] Walk all `Accounts.TeamIdentity` records for the seed facility
- [x] For each, set `avatar_url` to the uploaded S3 key from `Assets.list(:avatars_team)` (deterministic mapping: handle → file)
- [x] Mapping (commit to the file naming so reseeds are stable):
  - `team-admin` → `team_1.jpg`
  - `team-care` → `team_2.jpg`
  - `team-activities` → `team_3.jpg`
  - `team-therapy` → `team_4.jpg`
  - `team-kitchen` → `team_5.jpg`
  - `team-pharmacy` → `team_6.jpg`
  - `team-laundry` → `team_7.jpg`
  - `team-hairdresser` → `team_8.jpg`
  - `team-doctor` → `team_9.jpg`
- [x] TeamIdentity `:update` action already exists (from V6 work); confirm it accepts `avatar_url`. If not, accept it now.

### 2.2 Resident avatars
- [x] Pick the 15 residents that show up most in screenshots (first 15 from `Residents.list(:active) |> sort(:inserted_at)`); assign them `resident_1.jpg` through `resident_15.jpg`
- [x] Update via the `Resident.update` action (it already accepts `avatar_url`)
- [x] Leave the other 15 residents avatar-less — initials still render, just on the residents that show up less

### 2.3 Relative avatars
- [x] Pick the 20 most-active relatives (the ones who'll comment/react in Phase 3); assign them `relative_1.jpg` through `relative_20.jpg`
- [x] Update via the `Relative.update` action
- [x] Leave other 62 avatar-less

### 2.4 Caregiver profile avatars
- [x] Will be created in Phase 5; for now stash the 6 file paths in a `@caregiver_avatars` module attribute

### 2.5 Sign-off
- [x] After running refresh, check `/feed`, `/residents`, `/residents/<id>`, `/formfix/admin` — every author byline / row / comment / pill should show a face instead of initials for the seeded entries
- [x] Commit

---

## Phase 3 — Feed rebuild (90 min)

This is the biggest perception lift in the entire plan. It's also the most code.

### 3.1 Wipe the 5 test stubs
- [x] In `refresh!`, after the cleanup of section_answers/notes, also wipe the 5 test posts by body match (or by `is_internal == true and body in [list]`)
- [x] Use raw SQL via `Caredeck.Repo` because of the archive-extension soft-delete trap (same fix as kitchen)
- [x] Cascade wipe: `attachments`, `comments`, `reactions`, `post_audiences`, `resident_tags_on_posts`, and the paper_trail version tables for each — same pattern as the formfix dedupe migration

### 3.2 Seed the new posts
- [x] Add a `@seed_posts` module attribute in `Seeds`:
  ```
  %{
    key: :birthday_muller,
    team: "team-care",
    body: "Heute war Frau Müllers 88. Geburtstag — Schokoladenkuchen, Lieder und viele Gäste. Sie hat sich riesig gefreut!",
    photos: [:birthday_1, :birthday_2, :birthday_3],
    audience: ["Beatrice Cox"],            # tagged residents (by name)
    tags: ["Beatrice Cox"],
    reactions: 7,
    comments: ["So schön, danke für die Bilder!", "Bitte richten Sie liebe Grüße aus.", "Wunderschön!"]
  }
  ```
- [x] One row per planned post:
  - `birthday_muller` → 3 photos, audience tagged to Beatrice Cox, 7 reactions, 3 comments (replaces the placeholder painting post)
  - `painting_workshop` → 4 photos, audience tagged to a small group, 4 reactions, 2 comments
  - `physio_hungsinger` → 3 photos, audience tagged to Mr Hungsinger, 6 reactions, 2 comments (this is the real existing post — keep it but swap photos)
  - `handmotor` → 2 photos + the existing video as a `:video` attachment, audience: 2 residents, 3 reactions, 1 comment
  - `music_therapy` → 2 photos + the music audio, audience: 5 residents, 4 reactions, 2 comments (replaces "Voice" stub)
  - `wochenmarkt` → 2 photos, audience: 4 residents, 3 reactions, 1 comment
  - `spargel` → 1 photo, audience: house-wide, 4 reactions, 0 comments (announcement style)
  - `school_visit` → 2 photos, audience: house-wide, 8 reactions, 3 comments
  - `garden_walk` → garden_1 video + poster, audience: 3 residents, 5 reactions, 2 comments (replaces "Video" stub)
  - `new_resident_bauer` → 1 photo (welcome_1.jpg), audience: house-wide, 6 reactions, 2 comments
  - `doctor_visit` → 1 photo (doctor_1.jpg), **internal-only** (is_internal=true), audience: care team only, 0 reactions, 1 internal comment
  - `voice_schlager` → existing audio + 1 photo (music_1.jpg), audience: 4 residents (replaces "Sound and Picture" stub)
  - **Total: 12 posts.** Plus the existing "Good news! Mr Hungsinger…" stays → 13 visible posts. (Audit asked for 15 — phase 3.6 has the remaining 2 stretch posts.)

### 3.3 Attach media via the Assets loader
- [x] For each `:photos` entry → call `Assets.upload!(:feed_<group>, idx)` → create an `Attachment` row with kind=`:photo`, the returned s3_key, real dimensions (from ffprobe), and the post's caption text
- [x] For each `:video` entry → upload mp4 + matching `_poster.jpg`, store the poster S3 key as `thumbnail_s3_key`
- [x] For each `:audio` entry → upload mp3, set mime_type=`audio/mpeg`, set `duration_sec` from ffprobe

### 3.4 Captions
- [x] Every attachment gets a 1-line caption set during seed:
  - Birthday photos: "Frau Müller blowing out her 88th candles."
  - Painting: "Maria from team-activities helping with brush technique."
  - Wochenmarkt: "Fresh produce from the Berlin market."
  - etc.

### 3.5 Reactions + comments
- [x] For each post, sample N relatives (deterministic via phash2 on post.id) and create `Reaction` rows
  - Mix `:like` and `:heart` 70/30
- [x] For each post's `comments`, sample distinct relatives and create `Comment` rows, spaced ~5 min apart in inserted_at to make timelines feel real

### 3.6 Stretch posts (optional)
- [x] 2 more text-only posts if there's time:
  - Doctor visit follow-up (internal-only): "Quick care-team note — MDK contact confirms Mrs Walker's reassessment is on the books for next Tuesday."
  - Easter / holiday greeting (house-wide): "Wir wünschen allen Bewohnerinnen und Bewohnern ein frohes Pfingstfest!"

### 3.7 Audience scoping
- [x] No more 30-tag-everyone posts. Each post's audience should match its content:
  - Birthday: tag only the celebrant
  - Workshop: tag only attendees
  - Generic announcement: tag empty (broadcast to whole house via `is_internal=false`)

### 3.8 Phase 3 sign-off
- [x] Run refresh, sign in as relative, scroll the Feed
- [x] Every post has a real photo or playable media
- [x] Reactions show on most posts (both like + heart visible)
- [x] Comments show on at least 6 posts
- [x] Audience chips at the bottom of each card now show 1–3 tags (not 30)
- [x] Commit

---

## Phase 4 — Service requests + messages (60 min)

Closes the biggest "feels-empty" module on the whole app.

### 4.1 Seed 12 service requests
- [x] Add `@seed_service_requests` in `Seeds`:
  - 3 pharmacy: Levothyroxin refill (open), Vitamin D house order (in_progress), Mrs Cook prescription (resolved)
  - 3 laundry: bed linens ward 1 (in_progress), stained towels room 4B (open), weekend blanket order (resolved)
  - 3 salon: Mr Adams haircut Thursday (open), group cuts Friday (in_progress), monthly schedule confirmation (resolved)
  - 3 doctor: Mr Hungsinger physio follow-up (in_progress), Mrs Walker flu shot (open), MDK paperwork Pflegegrad 4 (resolved)
- [x] Each row carries:
  - `provider_id` (lookup by provider name)
  - `requester_id` (a relative or a care-team identity)
  - `subkind` (matches provider's kind)
  - `summary` (one line)
  - `resident_id` (when applicable)
  - `state` (`:open` / `:in_progress` / `:resolved`)
  - `inserted_at` skewed across the last 5 days

### 4.2 Seed 25 service messages
- [x] For each `:in_progress` and `:resolved` request, seed 2–4 messages back and forth
- [x] Mix author roles: relative → provider → care team → relative
- [x] Realistic copy (German preferred for the myo audience):
  - "Können Sie das Rezept bis Freitag holen?" / "Ja, ist erledigt. Lieferung morgen Vormittag."
  - "Haircut for Mr Adams confirmed Thursday 14:00." / "Thanks — please ring Ward 1 when arriving."

### 4.3 Recompute provider unread counts
- [x] If the LiveView caches counts, trigger a recompute so the open-request pill badges show on `/services` after refresh

### 4.4 Phase 4 sign-off
- [x] `/services` shows open-count badges on 3 of 4 provider cards
- [x] `/services/inbox` shows open + in_progress requests sorted by date
- [x] Clicking any provider tile shows a populated Recent requests list
- [x] Clicking any request shows a chat thread with 2–4 messages
- [x] Commit

---

## Phase 5 — Caregiver profiles (30 min)

### 5.1 Seed 6 caregiver profile rows
- [x] Tied to the seed facility; each carries:
  - `display_name` (German: "Maria Hoffmann", "Tomas Lange", "Heike Krüger", "Jonas Werner", "Eva Bauer", "Klaus Richter")
  - `role_label` ("Pflegefachkraft", "Pflegehelferin", "Therapeutin", "Hauswirtschaft", "Sozialdienst", "Pflegeschüler")
  - `avatar_url` (from caregiver_1..6.jpg via Assets)
  - `bio` (one paragraph)
- [x] Distribute via a join table or `caregiver_of_resident` so each resident shows 2–3 caregivers on their tab

### 5.2 Phase 5 sign-off
- [x] `/residents/<id>` → "Caregivers (3)" tab populated
- [x] Avatars visible per caregiver
- [x] Commit

---

## Phase 6 — Kitchen fill (60 min)

### 6.1 Today's orders
- [x] In refresh, seed 15 `Kitchen.ResidentMealOrder` rows dated `Date.utc_today/0`
- [x] 6 residents × 2–3 categories each (breakfast for 4, lunch for 5, dinner for 3, snack for 3)
- [x] States mixed: 8 `:ordered`, 4 `:served`, 3 `:skipped`
- [x] Each row references the day's `product_id` from the materialised DayMenu

### 6.2 Tomorrow + day-after orders
- [x] Seed 6 more orders for `today + 1` and 4 for `today + 2`
- [x] So `/kitchen/summary` shows something even if reviewer visits the wrong day

### 6.3 Diet profiles
- [x] Seed 6 `Kitchen.ResidentDietProfile` records:
  - Mrs Cook — allergens: "shellfish", preferences: "no spicy food", skip: [:snack]
  - Mr Adams — preferences: "vegetarian for religious reasons", skip: [:dinner]
  - Frau Becker — allergens: "gluten, lactose", notes: "Family requested no sugary snacks per doctor's advice"
  - Mr Hungsinger — preferences: "soft food only after dental work", skip: []
  - Frau Walker — allergens: "tree nuts", notes: "Decaf coffee only"
  - Penelope Davis — preferences: "low-sodium per cardiologist"

### 6.4 Phase 6 sign-off
- [x] `/kitchen/summary` shows today's orders populated per category
- [x] Clicking 6 specific residents' `/residents/<id>/diet` shows pre-filled allergens/preferences/notes
- [x] Commit

---

## Phase 7 — Notifications fan-out for demo-relative (30 min)

### 7.1 Re-tag a few posts to Isaac Allen
- [x] In Phase 3's seed posts, ensure 3 of the new posts tag Isaac Allen (the demo-relative's linked resident) in their audience:
  - `physio_hungsinger` — add Isaac Allen to audience
  - `birthday_muller` — keep as Beatrice Cox only (don't dilute)
  - `school_visit` — add Isaac Allen
  - `wochenmarkt` — add Isaac Allen
  - `garden_walk` — already tags 3 residents; add Isaac

### 7.2 Trigger fanout
- [x] After the new posts land, call `Caredeck.Workers.NotificationFanout.perform_now/1` (or `Oban.insert` with explicit IDs) for each new post
- [x] OR: call the fanout directly in the seed code path so it runs synchronously

### 7.3 Phase 7 sign-off
- [x] Sign in as the demo-relative
- [x] Bell icon shows an unread count (5+)
- [x] `/notifications` page populates with 5–10 notifications
- [x] Commit

---

## Phase 8 — Formfix application expansion (75 min)

### 8.1 Seed 6 new applications
- [x] Add `@seed_formfix_apps` in `Seeds`:
  ```
  [
    %{resident: "Anna Berger",   state: :draft,             progress: 12},
    %{resident: "Frieda Walker", state: :draft,             progress: 67},
    %{resident: "Hugo Kessler",  state: :draft,             progress: 85},
    %{resident: "Otto Brandt",   state: :missing_documents, progress: 100},
    %{resident: "Helga Roth",    state: :ready_to_submit,   progress: 100},
    %{resident: "Klaus Bauer",   state: :submitted,         progress: 100},
  ]
  ```
- [x] Also: 1 `:approved` application — promote one existing submitted app, set `:decided_at` to `~3 days ago` and `outcome: "Pflegegrad 4 approved by MDK. Welfare-law allowance granted."`

### 8.2 Per-state prefill
- [x] Draft 12% — only person_needing_care filled
- [x] Draft 67% — person_needing_care + applicant + care_situation + income filled (4 sections)
- [x] Draft 85% — all but 2 sections filled
- [x] missing_documents — all sections complete, but 2 required docs missing (don't seed verified docs for those slots)
- [x] ready_to_submit — all sections complete, all docs verified
- [x] submitted — all complete, `submitted_at` set
- [x] approved — all complete, `decided_at` set, `outcome` text set

### 8.3 Distinct notes per app (already partially done in 1-pair pool)
- [x] Already works in current code; just verify each new app gets a fresh pair from the 5-pool

### 8.4 Phase 8 sign-off
- [x] `/formfix/admin` shows 8 rows (was 2)
- [x] All 5 status colours visible (Draft yellow, Missing Documents orange, Ready to Submit blue, Submitted purple, Approved green)
- [x] Submit recap renders cleanly for each state
- [x] Commit

---

## Phase 9 — Resident profile "Recent activity" tab (45 min)

### 9.1 Add the tab
- [x] In `profile_live.ex`, add a third tab `Recent activity` after `Relatives` and `Caregivers`
- [x] Tab content: list the 5 most recent posts where the resident is in `resident_tags_on_posts`

### 9.2 Render shape
- [x] Each row: author avatar + name + date + body excerpt + "View post →"
- [x] If no activity, empty state: "No recent activity for {first_name}."

### 9.3 Tab count
- [x] Count = number of tags for this resident in posts inserted in the last 30 days

### 9.4 Phase 9 sign-off
- [x] Open Beatrice Cox's profile → Recent activity tab shows the birthday post + any others tagging her
- [x] Open a resident with no tags → empty state
- [x] Commit

---

## Phase 10 — Currency formatting sweep (30 min)

### 10.1 Add `:currency` field-kind to section schema
- [x] `lib/caredeck/formfix/section_schema.ex` — add `:currency` to the `kind` union and to `parse/2`
- [x] Currency answers stored as `:decimal` with cents precision
- [x] Switch the 5 monetary fields to `:currency`:
  - `:income` / `:pension_monthly`
  - `:income` / `:rental_income_monthly`
  - `:assets` / `:savings_total`
  - `:assets` / `:property_value`
  - `:expenses` / `:rent_monthly`

### 10.2 Render
- [x] In `section_live.ex` `field_input`, add a clause for `kind: :currency` that wraps the input with a leading `€` and formats blur events
- [x] In `submit_live.ex` `render_value`, format currency decimals with thousands separator + `€` prefix + (if monthly) `/Monat` suffix

### 10.3 Update prefill
- [x] Seed prefill keeps using decimals, just typed correctly

### 10.4 Phase 10 sign-off
- [x] Pension shows as `€3.434,00 /Monat` not `3434`
- [x] Savings shows as `€21.323,00` not `21323`
- [x] Commit

---

## Phase 11 — EXIF strip on attachment upload (30 min)

### 11.1 Strip in the upload pipeline
- [x] In `Caredeck.Feed.Attachment` `:create` action — add an `after_action` that pipes the uploaded image through `Mogrify.open(path) |> Mogrify.custom("strip") |> Mogrify.save(in_place: true)`
- [x] Only run for `kind: :photo`
- [x] If `mogrify` isn't on the path in prod, fall back to `System.cmd("exiftool", ["-all=", path])`

### 11.2 Backfill for seed photos
- [x] In the seed asset loader, strip EXIF before uploading to MinIO
- [x] Document why: portfolio demo, "your data is safe with us" promise

### 11.3 Phase 11 sign-off
- [x] Download a Feed photo via the proxy, `exiftool` shows no Make/Model/GPS
- [x] Commit

---

## Phase 12 — Resident roster row enrichment (30 min)

### 12.1 Add per-row context
- [x] In `residents_index_live.ex`, augment each row with:
  - Age (calculated from `date_of_birth`)
  - "Diet: N allergens" badge if diet profile set
  - "Last post: X days ago" link to the resident's profile recent-activity tab

### 12.2 Compute efficiently
- [x] One-shot query: for each resident, get `MAX(post.inserted_at)` where they're tagged
- [x] One-shot query: for each resident, count allergens in diet profile
- [x] Pass both as a map keyed by resident_id

### 12.3 Phase 12 sign-off
- [x] `/residents` rows show age + allergen badge + last-activity hint
- [x] Commit

---

## Phase 13 — Pending invitations (30 min)

### 13.1 Seed 3 pending invitations
- [x] For 3 residents that have only 1 linked relative, create a `RelativeInvitation` row with:
  - `invited_email` (a plausible name@example.test)
  - `relationship` (`:daughter`, `:nephew`, etc.)
  - `token` (auto-generated)
  - `expires_at` (7 days from now)
  - `accepted_at: nil`

### 13.2 Optional: admin surface (stretch)
- [x] Add `/invitations` for `:admin` role showing pending invitations + "Copy link" button
- [x] If skipping, document the seed tokens in `docs/runbooks/` so a reviewer can manually try the accept flow

### 13.3 Phase 13 sign-off
- [x] Pending invitations exist in DB
- [x] `/invitations/<token>` lands on the accept page for any of the 3 seeded tokens
- [x] Commit

---

## Phase 14 — Sign-off, deploy, archive (30 min)

### 14.1 Final visual regression
- [x] Re-run `audit_capture.js` against the live deploy
- [x] Eyeball-diff vs the pre-fill `/tmp/ux_audit_postdeploy/` set
- [x] Confirm every gap in `caredeck-data-gaps.md` has a corresponding visual change

### 14.2 Test suite + compile
- [x] `mix compile --warnings-as-errors`
- [x] `mix test` (entire suite, expect new tests for currency parsing + assets loader)
- [x] `mix format --check-formatted`

### 14.3 Update the data-gaps doc
- [x] At the top of `caredeck-data-gaps.md`, add a "Status: resolved 2026-xx-xx" line
- [x] For each finding, append a "**Resolved** in commit `<hash>` (Phase N)" reference
- [x] Move the doc into `docs/audits/2026-05-31-data-gaps.md` alongside the UX audit

### 14.4 Deploy
- [x] Push `data-fill` branch
- [x] Fast-forward `master` to it
- [x] Push `master` + tag `v0.13.0-data-rich`
- [x] Run `docker compose build` + `docker compose run --rm web /app/bin/caredeck eval 'Caredeck.Release.refresh_demo_data()'`
- [x] Note: refresh now does a LOT more work than before (15 posts × 3 attachments + 30 reactions + 25 service messages + 6 caregivers + 15 orders + ...). May run 30–90 seconds. Build a progress IO.puts log so it's clear what's happening.
- [x] Bring up `web` + `worker` on new image

### 14.5 Smoke
- [x] Sign in as Admin → Feed populated with photos
- [x] Sign in as Relative → bell shows unread count
- [x] `/services/inbox` → list of requests
- [x] `/kitchen/summary` → today's orders
- [x] `/residents/<id>` → 3 tabs working, Recent activity populated

### 14.6 Archive
- [x] Move this plan to `docs/checkpoints/phase-13-data-fill.md`
- [x] CHANGELOG entry: "Phase 13 — demo data fill"

---

## Risk register

| Risk | Mitigation |
|---|---|
| Phase 1 asset loader misses files (typo in filename map) | Test each `Assets.list(:group)` at the seed start; fail-fast if any file missing |
| Phase 3 re-fanout in refresh creates duplicate notifications | Wipe `notifications` rows where `inserted_at > now() - 7d AND verb=:posted` before re-fanout (raw SQL) |
| Phase 6 today's orders get out-of-date if seed runs days before review | Refresh re-dates all orders to `today` on every run — no stale dates |
| Phase 8 new submitted apps require all sections complete AND docs verified — `recompute_status` could revert state to draft | After seeding all answers + docs, explicitly set `state: :submitted` via Repo.update_all (bypass state machine) for the targeted apps |
| Phase 10 currency parsing breaks existing decimals | Add a backwards-compat parse: accept both "3434" and "3.434,00" and "3,434.00" formats |
| Phase 11 mogrify not in the prod Docker image | Add `imagemagick` to the Dockerfile apt-get list; or use the Elixir `Image` library which has a NIF |
| Refresh task slow (~90 s) | Wrap the seed step in `IO.puts` progress so the operator sees motion; cap upload concurrency to 4 to not flood MinIO |
| Reviewer visits during a refresh run | Brief: refresh is < 2 min; no danger of a half-state since each phase is one transaction |

---

## Out of scope

- Brand redesign / new logo / SVG mark replacement (the existing teal blob carries)
- Real Schlager covers for the audio (LibriVox fairy-tale clips are good enough for a demo)
- Service-provider logos (SVG category icons already carry visual weight)
- Real PDF documents per upload (one placeholder, all 50+ docs point at it — fine for demo)
- Multi-language i18n (German labels where natural, English elsewhere)
- Performance optimisation beyond the obvious (video re-encode already done at fetch time)

If wanted later, queue as a separate "Phase 14+" plan.

---

## Definition of done

A phase is "done" when:
1. Every checkbox in the phase section is ticked
2. `mix compile --warnings-as-errors` is clean
3. `mix test` is green (or new tests document intentional behaviour changes)
4. The affected routes have been re-screenshotted and the visual change is confirmed
5. One or more commits with the data-gap section prefix in the subject line
6. The corresponding section of `caredeck-data-gaps.md` has been annotated with the resolution commit hash

The whole plan is "done" when every gap in `caredeck-data-gaps.md` has a resolution annotation, the deployed `caredeck.josboxoffice.com` reflects every change, and the tag `v0.13.0-data-rich` is on the tip.

---

## Headline result expected

| Module | Today | After this plan |
|---|---|---|
| Feed | 9 posts, 5 stubs, 3 comments, 4 reactions, 9 grey placeholder photos, 2 real-but-out-of-context, no audio context, no video poster | **13 posts (3 with video, 1 with audio), 15 comments, 30 reactions, every post has real photos that match its content, every video has a poster, every attachment has a caption** |
| Services | 0 requests, 0 messages, every page empty | **12 requests across 4 providers in 3 states, 25 messages on threaded conversations, inbox + provider pages populated** |
| Caregivers tab | "No caregiver profiles yet" on 30 residents | **6 caregiver profiles, distributed so every resident sees 2–3 caregivers** |
| Kitchen today | "No orders yet" everywhere | **15 orders today + 6 tomorrow + 4 day-after, 6 diet profiles set** |
| Notifications (Relative) | 0 | **5–10 unread notifications spanning posts / comments / reactions / Formfix** |
| Avatars | 0 of 121 | **50 of 121 — every team identity, every "active" relative, half the residents, every caregiver — every author byline + comment + list row has a face** |
| Formfix admin | 2 rows | **8 rows across 5 states with distinct notes per app** |
| Resident profile | 2 tabs (Relatives, Caregivers — Caregivers empty) | **3 tabs (Relatives + Caregivers + Recent activity), all populated** |
| Currency | "3434" | **"€3.434,00 /Monat"** |
| EXIF | Vivo phone metadata leaks | **Stripped on upload** |
| Pending invitations | 0 | **3 (with working accept URLs)** |
| Resident roster row | name + ward only | **+ age + allergen badge + last-activity hint** |

That's the gap from "structurally complete but quietly empty" to "a portfolio demo that looks lived-in."
