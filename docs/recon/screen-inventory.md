# Screen Inventory

Living document — every distinct screen the clone must implement. Add a row when a new screen is identified; never delete rows.

| ID | English screen name | Source frame | Feature | One-line behaviour |
|---|---|---|---|---|
| `feed.home` | Home feed | `feed-home.png` | Communication | Chronological list of posts the viewer can see; bell icon top-right with unread count badge; FAB bottom-right labelled `NEW`. |
| `feed.post.detail` | Post detail | `69.webp` (source) | Communication | Single post with full caption, audience chips, and a relation-labelled comment thread. |
| `feed.compose` | New post composer | `feed-compose.png` | Communication | Caption + media triplet (Camera/Gallery/Audio) + `Internal post` lock toggle + `All residents` master toggle + per-resident checkboxes with avatars. |
| `notifications.inbox` | Notifications | `25.png`, `30.png` (source) | Notifications | Reverse-chronological list of actor-verb-target rows with thumbnails and read state. |
| `profile.family.list` | Profile / family graph | `profile-family.png` | Family graph | Two sub-tabs — Relatives / Caregivers — listing every person connected to the current resident; `Me` marker on own row; person+ FAB invites a new relative. |
| `profile.edit` | Edit profile | `72.webp` (source) | Family graph | Photo + first name + last name + phone + Relationship-to-resident dropdown. |
| `services.tile_grid` | Services tab | implied by Phase 12 nav | Service Providers | Grid of provider tiles per facility. |
| `services.pharmacy` | Pharmacy | `service_apotheke-1.png` (source) | Service Providers | Upload prescription / Medication inquiry / Send a question — three intents. |
| `services.laundry` | Laundry | `service_laundry_v2.png` (source) | Service Providers | Photo-based complaint with structured Service + Reason fields. |
| `services.hairdresser` | Hairdresser | `service_hairdresser-1.png` (source) | Service Providers | Produces a Communication post on the feed instead of a service ticket. |
| `auth.login` | Sign-in | `auth-login.png` | Auth | Logo + heading + username + password + Sign in. |
| `auth.help` | Sign-up help | implied by footer | Auth | Onboarding instructions for newly invited relatives. |
| `kitchen.weekly` | Weekly menu builder | `kitchen_calendar_v3.png` (source) | Kitchen | 7-day strip + meal accordion editor + product typeahead. |
| `kitchen.order_mobile` | Mobile order capture | `kitchen_app-order_v3.png` (source) | Kitchen | Per-resident-per-day quantitative ordering with stepper controls. |
| `kitchen.summary` | Today's orders | implied by `kitchen_overview_v2.png` (source) | Kitchen | Aggregated counts for the kitchen-facing side. |
| `aid.overview` | Application overview | `aid-overview.png` | Aid | 13-section progress dashboard with per-section progress bars. |
| `aid.section.detail` | Section detail | `04.png`, `05.png` (source) | Aid | Sidebar of sub-sections + main form panel. |
| `aid.section.field` | Field question | `06.png`, `07.png` (source) | Aid | Radio-list or text field + per-question rationale paragraph. |
| `aid.section.documents` | Required documents | `aid-documents-done.png` | Aid | List of named documents with `Upload file` action; progress bar during upload; `Successfully verified` micro-label on completion. |
| `aid.admin.dashboard` | Aid admin dashboard | derived from `aid-digest-email.png` | Aid | Per-facility table — Resident / Relative / Status / Progress — with the 5-state colour-coded status column. |
| `aid.digest.email` | Status digest email | `aid-digest-email.png` | Aid | Weekly facility-admin email digest. |
| `design-system` | Design system reference | (Phase 0 deliverable) | Internal | Living style guide rendered from the `@theme` block — proves the token system works. |

Reference frames live in `./reference-frames/`. Source frames listed `(source)` refer to the raw screenshots in `myo/new_screenshots/`.
