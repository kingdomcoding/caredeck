# Phase 10 — Checkpoint

**Date:** 2026-05-29
**Tag:** `v0.10.0-phase-10-complete`

## What shipped

- **`Caredeck.Aid`** domain registered alongside Accounts / Org / People / Feed / Notifications / Kitchen / Services.
- **4 DB resources + 4 paper-trail siblings** — all multitenant on `facility_id`, all using the `Caredeck.Resource` base, all with `default_pub_sub: false`.
  - `Application` — top-level application; `state` is a real `AshStateMachine` (`draft → missing_documents → ready_to_submit → submitted → approved`); `submitted_at` / `decided_at` / `outcome`; `progress_percent` is a `calculate` field driven by two Ash aggregates (`total_sections`, `sections_done`).
  - `ApplicationSection` — 13 rows materialised per application via `SectionSeeder.materialise!/1`; composite-unique on `(application_id, section_key)`; `:transition` action accepts `:not_started | :in_progress | :complete | :skipped`.
  - `SectionAnswer` — per (application × section × field) answer; 5 polymorphic value columns (`value_text`, `value_date`, `value_bool`, `value_decimal`, `value_atom`) routed by the field's `kind` from `SectionSchema`; upsert `:create` action keyed on the composite identity.
  - `UploadedDocument` — `verification_status` (column name `:state`) is a real `AshStateMachine` (`pending → verifying → verified | failed`); pub_sub on per-application topic for realtime pill updates.
- **4 static schema modules** —
  - `SectionSchema` — 13 sections (+ conditional `:spouse`) with ordered field lists; per-field `kind ∈ [:string, :text, :date, :integer, :decimal, :boolean, {:enum, _}]`; `parse/2`, `value_column/1`, `required_fields/1`, `complete?/2` helpers.
  - `FieldRationale` — plain-language English paragraphs keyed by `{section_key, field_key}`.
  - `RequiredDocuments` — required-document slots per section with legal-note descriptions (6 sections).
  - `MaritalStatus` — 9-state enum + `requires_spouse_section?/1`.
- **5 LiveViews** —
  - `/aid` `Aid.ListLive` — list applications visible to the current actor; "Start new application" CTA.
  - `/aid/:application_id/overview` `Aid.OverviewLive` — 13-tile section grid + global progress bar + right-rail support card.
  - `/aid/:application_id/section/:section_key` `Aid.SectionLive` — kind-aware form driven by `SectionSchema`; plain-language rationale paragraph beside each field; sticky Skip / Continue; bottom Next-section card; Required-documents link.
  - `/aid/:application_id/section/:section_key/documents` `Aid.DocumentsLive` — per-slot uploads through the existing `Feed.S3` pipeline; pubsub-driven verification pill that flips `Pending → Verifying → Successfully verified` in real time.
  - `/aid/:application_id/submit` `Aid.SubmitLive` — read-only review of every section's answers; primary CTA disabled until `state == :ready_to_submit`.
- **Status state machines wired together** —
  - `SectionWriter.save_answers!/3` upserts answers, transitions the section's status (`:in_progress` / `:complete`), then calls `Aid.Applications.recompute_status/1` which flips the application between `:draft` / `:missing_documents` / `:ready_to_submit`.
  - Skipping a section also runs `recompute_status/1`.
  - Document verification (`AidDocumentVerifier` after `:mark_verified`) also runs `recompute_status/1`.
- **Document verification stub (ADR-008)** — `Caredeck.Workers.AidDocumentVerifier` on Oban queue `:aid`. Stub engine sleeps 1 s in dev/prod (skipped in test), runs `:start_verification → :mark_verified`, stamps `verified_at`. `:ocr` / `:llm` engines raise. Startup warning logged when running in prod with `engine: :stub`.
- **Conditional `:spouse` section** — `Aid.Applications.refresh_conditional_sections/1` adds (or removes) the spouse section row whenever the `:person_needing_care.marital_status` answer changes to / from a value that requires a spouse section.
- **`Caredeck.Notifications.Notification`** — `:verb` widened to include `:submitted`; `:target_kind` widened to include `:application`. `Phrasebook` gains the `:submitted` clause; `NotificationsLive.target_path/1` routes the new target_kind to `/aid/:id/overview`.
- **`Caredeck.Workers.NotificationFanout`** — new `perform/1` clause for `application_submitted`: fans out to other relatives of the application's resident + `:caregiver`-role facility members (excluding the requester).
- **Top header + mobile nav** — **Aid** link added to top header, visible only to relatives (`@current_user`). Mobile bottom nav for relatives now: Home / Aid / Profile / Services / Inbox / Sign out.
- **`<.aid_footer>`, `<.aid_back_link>`, `<.next_section_card>`, `<.aid_status_pill>`, `<.section_pill>`, `<.verification_pill>`** — shared core components in `CaredeckWeb.AidComponents`, imported automatically by `lib/caredeck_web.ex`.
- **Seeds** — one demo `Aid.Application` per facility, opened by `demo-relative@example.test` for their first linked resident, with the `:person_needing_care` section auto-completed from resident attributes and the `:applicant` section partially filled.

## Demo credentials

| Type | Identifier | Password |
|---|---|---|
| Relative (Aid's primary surface) | `demo-relative@example.test` | `phase1-demo-pass` |
| Team Care | `team-care` | `phase1-demo-pass` |
| Team Kitchen | `team-kitchen` | `phase1-demo-pass` |
| Team Pharmacy / Laundry / Hairdresser / Doctor | `team-pharmacy` etc. | `phase1-demo-pass` |

## Verification matrix

| Check | Result |
|---|---|
| `mix compile --warnings-as-errors` | clean |
| `mix test` | 199 / 199 green |
| Cross-tenant read of `Application`, `ApplicationSection`, `SectionAnswer`, `UploadedDocument` | empty (multitenancy enforced) |
| `SectionSeeder.materialise!/1` | idempotent — re-running keeps 13 sections |
| Section schema unit tests | 11 / 11 green (parse/2 across all kinds, complete?/2, required_fields/1) |
| Section writer save-then-recompute-status flow | 4 / 4 green |
| Documents pubsub: upload → verifying → verified | covered by `AidDocumentVerifier` worker spec |
| Submit transitions state machine to `:submitted` | green |
| Conditional `:spouse` appears/disappears with marital_status | 3 / 3 green |
| Notifications fan out on `:submitted` | green |
| `aid_verification_engine: :ocr` → verifier raises | green |
| Progress calculation: 0% / ~54% / 100% / `:complete + :skipped` mix | 4 / 4 green |

## Files added / changed

- `lib/caredeck/aid.ex` — new domain (4 resources + 4 paper-trail siblings).
- `lib/caredeck/aid/{application,application_section,section_answer,uploaded_document}.ex` — 4 resources.
- `lib/caredeck/aid/{section_schema,field_rationale,required_documents,marital_status,section_key,section_seeder,section_writer,applications}.ex` — static schema + helpers.
- `lib/caredeck/workers/aid_document_verifier.ex` — Oban worker for verification stub.
- `lib/caredeck/workers/notification_fanout.ex` — new `application_submitted` clause.
- `lib/caredeck/notifications/{notification,phrasebook}.ex` — enum widening + new render clause.
- `lib/caredeck_web/live/aid/{list,overview,section,documents,submit}_live.ex` — 5 LiveViews.
- `lib/caredeck_web/live/notifications_live.ex` — `:application` target_kind path.
- `lib/caredeck_web/components/aid_components.ex` — shared UI components.
- `lib/caredeck_web/components/layouts.ex` — Aid nav entry.
- `lib/caredeck_web/router.ex` — 5 Aid routes inside `:authenticated` live_session.
- `lib/caredeck_web.ex` — import the new AidComponents.
- `lib/caredeck/application.ex` — stub-engine startup warning.
- `lib/caredeck/release/seeds.ex` — demo Aid seed.
- `priv/repo/migrations/{20260529074844_install_aid_domain,20260529075238_add_section_answers,20260529080245_add_uploaded_documents}.exs` — 3 migrations.
- `priv/resource_snapshots/repo/aid_*/` — snapshots for each Aid table.
- `test/caredeck/aid/{cross_tenancy,section_schema,section_writer,conditional_spouse,progress_calculation}_test.exs` — 5 spec files.
- `test/caredeck/workers/{aid_document_verifier,aid_submitted_notification}_test.exs` — 2 worker spec files.
- `test/caredeck_web/live/aid/{list,overview,section,submit}_live_test.exs` — 4 LV spec files.

## Decisions and divergences from the plan

- **`SectionAnswer` upsert** — Originally the plan described a `:put_value` polymorphic helper action; we folded the polymorphic dispatch into `SectionWriter.save_answers!/3` instead so all routing logic lives in one place.
- **`Application.progress_percent`** — Originally an inline Postgres `fragment` expression; refactored to two Ash aggregates + an arithmetic calculation, which is portable across drivers and read in the LV without fragment escaping.
- **`recompute_status/1` ignores skipped sections' document requirements** — A section that the user explicitly skipped doesn't need its documents uploaded for the application to flip to `:ready_to_submit`.
- **`:caregiver` (not `:care`)** in the `FacilityMembership` role filter — the existing `FacilityMembership.role` enum is `[:admin, :caregiver, :relative, :clinician]` from earlier phases; the Aid plan's reference to `:care` was a stale alias.
- **Submit confirm modal deferred** — the submit handler runs the transition directly and flashes confirmation. Adding an explicit modal is a future polish.
- **Seeded `UploadedDocument` rows deferred** — the demo seed seeds the application + answers but not pre-existing document uploads. The verification pill can be observed by uploading any photo in the demo session.
- **`SectionLive` does not yet branch on the conditional `:spouse` rendering** — the section is added/removed by `refresh_conditional_sections/1` but rendering uses the same field list as base sections.

## Risks the next phase inherits

- **Verification stub** — must NOT be deployed to real applicants. Per ADR-008, a feature-flag flip to `:ocr` / `:llm` would surface `RuntimeError` until those engines exist.
- **Document storage shares the existing MinIO bucket** under prefix `aid-documents/`. Bucket lifecycle / retention policy unchanged.
- **No field-level encryption** — application data lives in plaintext in Postgres (ADR-009 covers the posture).
- **`outcome` is a free-text string** — Phase 11 (Aid admin) may formalise it.

## Acceptance scenario

1. Relative signs in as `demo-relative@example.test`.
2. Clicks **Aid** in the top nav → `/aid` shows the seeded application.
3. Opens the overview → 13-tile grid, "Person Needing Care" already `:complete`, "Applicant" `:in_progress`.
4. Clicks into any incomplete section → fills the required fields → **Continue**. Progress bar advances.
5. Visits any section's **Required documents** link → uploads a PDF/JPEG. Pill flips from **Pending** → **Verifying** → **Successfully verified** within ~1 second.
6. Once all sections are `:complete`/`:skipped` and required documents are `:verified`, application state flips to `:ready_to_submit`.
7. Visits `/aid/:id/submit` → reviews every section's answers → presses **Submit application** → state machine transitions to `:submitted`.
8. A second relative of the same resident (or a `:caregiver`-role user) sees a "Demo Relative submitted a long-term-care assistance application" notification at `/notifications`.
