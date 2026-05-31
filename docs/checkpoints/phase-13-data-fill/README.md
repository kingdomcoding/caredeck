# Phase 13 — Data-fill Checkpoint

**Date:** 2026-05-31
**Tag:** `v0.13.0-data-rich`
**Plan:** [plan.md](./plan.md)

## What shipped

Closing the 14 data-richness gaps from `caredeck-data-gaps.md` so the live
demo site has weighty, realistic content instead of stub rows.

- **`Caredeck.Release.Assets`** — single seed-asset loader. 19 named groups
  cover avatars, feed photos, videos, audio, facility shots, and the demo
  PDF. `upload!/1` is idempotent against MinIO, `upload_with_meta!/1`
  returns the Attachment-ready map with `ffprobe`-derived dimensions and
  duration. `strip_exif/1` shells out to `mogrify -strip` and falls back
  to raw bytes if ImageMagick is missing.
- **`Caredeck.Release.Seeds.refresh!/0`** — orchestrates the full
  refresh: avatars → feed → services → caregivers → kitchen →
  formfix → notifications → invitations. Uses raw SQL for table wipes
  because the Ash archive extension soft-archives and the paper-trail
  shadow tables hold FK references.
- **87 binary assets** under `priv/static/` — 9 team / 15 resident /
  20 relative / 6 caregiver avatars, 22 feed photos, 4 videos with
  posters, 4 LibriVox audio clips, 2 facility photos, 1 demo PDF.
- **Feed** — wipes the 5 stub posts and seeds 12 backdated posts with
  media attachments, audience tags, comments, reactions, and the demo
  resident roster.
- **Services** — 12 service requests (pharmacy/doctor/salon/laundry) +
  25 messages inserted via raw `Repo.query` to bypass the
  ValidatePayload change pipeline.
- **Caregivers** — 6 `CaregiverProfile` rows with German role labels.
- **Kitchen** — 6 `ResidentDietProfile` rows + 15 today / 8 tomorrow /
  6 day-after orders.
- **Notifications** — re-runs `NotificationFanout.perform/1`
  synchronously over the refreshed posts/comments/reactions so the
  demo-relative's inbox is populated.
- **Formfix** — 7 extra applications across all 5 states (draft 12% /
  67% / 85%, missing_documents, ready_to_submit, submitted, approved
  with outcome). State transitions via raw SQL UPDATE to skip the
  state-machine validation chain; create bypasses authorization with
  `authorize?: false` because the demo-relative isn't linked to every
  seeded resident.
- **Pending invitations** — 3 outstanding invites
  (Edward / Audrey / Doris) created through the Ash action with the
  after-action token signing intact.
- **UI** — `/residents/:id` gains a "Recent activity" tab pulling the
  most recent 5 posts tagged with the resident.
- **UI** — `/residents` rows now show `NN yo` age chip + a
  ` · N days ago` last-activity suffix derived from
  `ResidentTagOnPost`.
- **UI** — Formfix monetary fields render with a `€` prefix, German
  thousands separator, and ` /Monat` suffix on monthly fields via
  `Caredeck.Formfix.Money`.
- **EXIF** — `mogrify -strip` runs on every uploaded photo (seed and
  user uploads). The runtime Docker image now installs `imagemagick`
  and `ffmpeg` so this works in prod.

## Demo data totals after refresh

```
avatars     : 15 residents · 20 relatives · 9 teams
feed        : 12 posts
services    : 12 requests + 25 messages
caregivers  : 6
kitchen     : 6 diet profiles · 29 orders (15 + 8 + 6)
formfix     : 7 extra applications + 1 existing = 8 total
notifications: 12 posts · 21 comments · 62 reactions fanned out
invitations : 3 pending
```

## Verification

| Check | Result |
|---|---|
| `mix compile --warnings-as-errors` | clean |
| `mix test` | 237 / 237 green |
| `Caredeck.Release.refresh_demo_data()` end-to-end | succeeds, all 8 stages report ✓ |
| `curl /healthz` on prod | 200 |
| `/feed /residents /services /kitchen/summary /formfix` | all 200 |

## Commits in this phase

```
0014d6e chore: mix format pass after the data-fill sweep
53bf59c invitations: seed 3 pending invitations for Edward/Audrey/Doris
e131189 roster: age + last-activity badges on /residents rows
1af2484 exif: strip EXIF from photo uploads (seed + LV)
9edd07a currency: € prefix + thousands separator + /Monat suffix
c1014a7 recent-activity: 3rd tab on /residents/:id
d93998f formfix: seed 7 more applications across all 5 states
4f38568 notifications: re-run fanout for posts/comments/reactions in refresh
66ef89e kitchen: seed 6 diet profiles + 15 today + 8 tomorrow + 6 day-after orders
e4e8876 caregivers: seed 6 profiles with German role labels + avatars
80dea9e services: seed 12 requests + 19 messages across 4 providers
f3474e6 feed: rebuild — 12 realistic posts with media, reactions, comments
fc65d6d avatars: assign 9 team + 15 resident + 20 relative avatars in refresh
d63b723 Phase 1: Caredeck.Release.Assets — seed-asset loader
033125a Phase 0: seed binary assets — 87 files, 30MB
```

Post-deploy hardening (after first prod refresh crashed):

```
800d7b1 exif: fall back gracefully when mogrify not on path
0edfe1c docker: install imagemagick + ffmpeg in runtime image
4e60c1a seeds: stringify CiString handle when keying teams map
6a48a44 seeds: bypass policy when creating formfix demo apps
```

## Asset provenance

| Group | Source |
|---|---|
| Adult portraits (team, relative, caregiver) | thispersondoesnotexist.com |
| Elderly portraits (resident) | Pexels free-licence |
| Feed photos | Pexels free-licence |
| Videos | Pixabay free-licence (re-encoded `ffmpeg -crf 30 -maxrate 2500k`) |
| Audio | Archive.org LibriVox (public domain) |
| Facility shots | Pexels free-licence |
| Demo PDF | hand-authored |
