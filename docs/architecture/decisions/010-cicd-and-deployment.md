# ADR 010: CI/CD + deployment on this box via docker-compose + NPM

**Status:** Accepted
**Date:** 2026-05-26

## Context

The portfolio target is "deployable from a public URL on day one, behind TLS, with rollback in under a minute." The host this project runs on is a single Linux box that already runs Nginx Proxy Manager (NPM) for TLS termination + reverse-proxy of other portfolio projects.

There's no cloud budget for this artefact. Fly.io, AWS, and Heroku are explicitly rejected.

## Decision

- **CI** — GitHub Actions on push + PR. Steps: `mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix credo --strict`, `mix sobelow --config`, `mix deps.audit`, `mix test`. Postgres service container for the test job. No deploy step from CI — deploys are explicit and manual.

- **Prod deploy** — `docker compose -f docker-compose.prod.yml up -d` on this box. Three services: `web` (Phoenix release), `db` (Postgres 16), `worker` (same image as web, with `ROLE=worker` for Oban queue startup).

- **Bind ports** — `web` binds to `127.0.0.1:4080`. Nothing else exposes a host port. The host's Nginx Proxy Manager proxies the public hostname (e.g. `caredeck.example.com`) to that local port over plain HTTP, with NPM doing TLS termination and Let's Encrypt cert issuance.

- **Migrations** — run via a one-shot container (`docker compose run --rm web /app/bin/caredeck eval 'Caredeck.Release.migrate()'`). No automatic migration on container start.

- **Rollback** — re-tag the previous image, `docker compose up -d`. Documented in `docs/operations/deployment-runbook.md`.

- **Backups** — nightly host cron entry runs `pg_dump` from the `db` container, gzips to `/var/backups/caredeck/`, retains 14 days. Mitigation: a quarterly off-site copy.

## Consequences

**Gains:**

- Deploy is a single `docker compose up -d` after image build.
- Zero cloud cost.
- NPM's UI handles TLS issuance, renewal, and per-host proxy config without touching nginx conf files.

**Costs:**

- Single point of failure — this box goes down, the app goes down. Acceptable for a portfolio artefact; not acceptable for a real production deployment.
- NPM's WebSocket toggle must be enabled on the proxy host — easy to forget; LiveView breaks silently if missed. Mitigated by a verification curl in the runbook.
- No CDN, no autoscaling. Acceptable for portfolio traffic.

## Alternatives considered

- **Fly.io.** Rejected: explicit cost constraint.
- **Direct nginx config on the host (no NPM).** Rejected: NPM is already configured and its UI is fast; bypassing it adds operational friction.
- **systemd unit + `mix release` on the host.** Rejected: containerised release is simpler to rollback and matches the existing portfolio's deployment pattern.
