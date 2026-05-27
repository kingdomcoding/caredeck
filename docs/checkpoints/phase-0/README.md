# Phase 0 — Checkpoint

**Date:** 2026-05-26
**Tag:** `v0.0.0-phase-0-complete`

## What shipped

- **Recon artefacts** — screen inventory (22 screens), route map (14 marketing + 17 app routes), mobile-surface bridge spec (7 calls), 7 canonical reference frames.
- **Phoenix 1.8 + Ash 3.26 bootstrap** — full Ash extension suite (postgres, phoenix, authentication, oban, paper_trail, archival, state_machine, admin). Base `Caredeck.Resource` macro. Multi-tenancy helper `Caredeck.Tenancy.to_tenant/1`. Health endpoint at `/healthz`.
- **Tailwind v4 design tokens in `@theme`** — brand teal scale, like-red, ink neutrals, 5 Aid status badge tuples (bg/border/text each), 4 type-display sizes, 4 radii, 2 shadow tokens.
- **Original brand mark** — two-overlapping-circles SVG in teal-300 + teal-500, paired wordmark, lockup.
- **`/design-system` LiveView** — living style guide rendered from the `@theme` block. The screenshot below is the Phase 0 deliverable.
- **10 ADRs** in `docs/architecture/decisions/` — Ash framework, auth + tenancy, team accounts, five domains, thin native shell, multi-image storage, notification fan-out, Aid verification stub, GDPR posture, CI/CD.
- **Tooling** — `.credo.exs`, `.sobelow-conf`, `.formatter.exs` with Spark plugin, GitHub Actions CI workflow, `mix precommit` alias.
- **Deployment** — `docker-compose.prod.yml` with `web` + `db` + `worker` containers; multi-stage Dockerfile; `.env.prod.example` template. The `web` container binds to `127.0.0.1:4080`, ready for Nginx Proxy Manager to proxy. `Caredeck.Release.migrate/0` helper for one-shot migrations.

## Verification matrix

| Check | Result |
|---|---|
| `mix compile --warnings-as-errors` | ✅ clean |
| `mix format --check-formatted` | ✅ clean |
| `mix credo --strict` | ✅ no issues |
| `mix sobelow --config` | ✅ no findings (CSP header added to `:browser` pipeline) |
| `mix deps.audit` | ✅ clean (one acknowledged advisory ignored: cowlib GHSA-g2wm-735q-3f56 — no upstream patch) |
| `mix test` | ✅ 6 tests, 0 failures |
| `mix precommit` | ✅ full pipeline pass |
| `docker compose -f docker-compose.prod.yml build` | ✅ |
| `docker compose -f docker-compose.prod.yml up -d` | ✅ all 3 services healthy |
| Prod migrations | ✅ `Caredeck.Release.migrate/0` runs |
| `curl http://127.0.0.1:4080/healthz` | ✅ 200 ok |
| `curl http://127.0.0.1:4080/design-system` | ✅ 200, tokens rendered |
| 10 ADRs present | ✅ (template + 10 = 11 files) |
| Checkpoint screenshot | ✅ `design-system.png` (dev) + `design-system-prod.png` (prod) |
| `mix dialyzer` | ⚠️ deferred — first PLT build is slow; runs in Phase 1 CI |

## Screenshots

- `design-system.png` — `/design-system` rendered from the dev server (Playwright + headless Chromium, 1280×1600).
- `design-system-prod.png` — same page rendered from the prod compose stack on `127.0.0.1:4080`. Pixel-identical to dev.

## What Phase 1 inherits

- The `@theme` token system — `auth.login` (first real screen) consumes these directly.
- The `Caredeck.Resource` base macro — the `Accounts` domain's `User` and `TeamIdentity` start with `use Caredeck.Resource`.
- `Caredeck.Tenancy.to_tenant/1` — Phase 2's first multi-tenant resource is the first real caller.
- Container stack running on this box — Phase 1's auth flow can be hammered from a public browser once NPM is wired.
- ADR practice — Phase 1's spike outcomes get appended as ADR-011, ADR-012, ….

## Outstanding pre-prod tasks (user action)

- [ ] Reserve DNS `caredeck.josboxoffice.com` (or chosen hostname) and point at this box.
- [ ] In NPM admin UI: add Proxy Host with WebSocket Support + Let's Encrypt cert, per `docs/operations/deployment-runbook.md`.
- [ ] Add nightly `pg_dump` cron entry on the host.
- [ ] Push the repo to GitHub so CI can run.
