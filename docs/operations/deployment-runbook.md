# Deployment Runbook

Single-host deployment via `docker compose` behind Nginx Proxy Manager. Phase 13 hardens this; Phase 0 ships the skeleton.

## Pre-deploy checks

- [ ] `mix precommit` clean locally.
- [ ] CI green on the commit you intend to ship.
- [ ] `git status` clean.
- [ ] You can `ssh` to the box and reach `127.0.0.1:81` (NPM admin) and `127.0.0.1:4080` (current `web`).
- [ ] `.env.prod` exists on the box and is not in git.

## Migration policy

Migrations run in a one-shot container, never automatically on `web` startup:

```bash
docker compose -f docker-compose.prod.yml run --rm web \
  /app/bin/caredeck eval 'Caredeck.Release.migrate()'
```

Migrations must be backward-compatible with the previous release (so rollback works without a down-migration).

## Deploy

```bash
git pull
docker compose -f docker-compose.prod.yml build
docker compose -f docker-compose.prod.yml up -d
curl http://127.0.0.1:4080/healthz   # expect "ok"
```

## Rollback

```bash
git checkout <previous-tag>
docker compose -f docker-compose.prod.yml build
docker compose -f docker-compose.prod.yml up -d
curl http://127.0.0.1:4080/healthz
```

If a migration is in flight that the previous tag can't read, restore from the latest `pg_dump` first.

## On-call

- App logs: `docker compose -f docker-compose.prod.yml logs -f web worker`
- DB logs: `docker compose -f docker-compose.prod.yml logs -f db`
- NPM logs: NPM admin UI → Audit Log + per-host access/error logs.
- Sentry / Honeybadger dashboards (Phase 13).

## NPM proxy-host config (one-time)

In NPM admin UI:

1. **Proxy Hosts → Add Proxy Host**
2. Domain Names: `caredeck.example.com`
3. Scheme: `http`, Forward Hostname / IP: `127.0.0.1`, Forward Port: `4080`
4. Toggle on: **Block Common Exploits** and **Websockets Support** (LiveView requirement).
5. **SSL tab:** request a new Let's Encrypt cert; Force SSL on; HTTP/2 on.
6. **Advanced tab:** paste:
   ```
   client_max_body_size 25M;
   proxy_read_timeout 300;
   ```
7. Save. Wait ~30 seconds for the certificate.

Verify with `curl -I https://caredeck.example.com/healthz` from a public network.

## Backups

Nightly `pg_dump` cron on the host:

```cron
0 3 * * * docker exec caredeck-db-1 pg_dump -U caredeck caredeck_prod | gzip > /var/backups/caredeck/$(date +\%F).sql.gz && find /var/backups/caredeck/ -mtime +14 -delete
```

Retention: 14 days local, quarterly off-site copy (manual for now).

## Disaster recovery

1. Restore the most recent `pg_dump` into a fresh `db` container:
   ```bash
   gunzip -c /var/backups/caredeck/<date>.sql.gz | docker exec -i caredeck-db-1 psql -U caredeck caredeck_prod
   ```
2. Bring `web` and `worker` back up.
3. Confirm `/healthz` and a couple of sentinel routes.
