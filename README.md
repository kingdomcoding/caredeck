# Caredeck

Portfolio reproduction of the myo elder-care platform. English-only. UI/UX patterns inspired by https://myo.de; implementation is original.

## Dev

```bash
mix setup
mix phx.server
# → http://127.0.0.1:4000
```

Visit `/design-system` to see the living style guide.
Visit `/healthz` to verify the DB connection.

The dev database lives on the host's Postgres (see `config/dev.exs`). No Docker is needed for development.

## Prod deploy (on this box)

1. Copy `.env.prod.example` → `.env.prod` and fill in the secrets:
   ```bash
   cp .env.prod.example .env.prod
   # Generate the two signing secrets:
   mix phx.gen.secret  # → paste as SECRET_KEY_BASE
   mix phx.gen.secret  # → paste as TOKEN_SIGNING_SECRET
   # Pick a strong POSTGRES_PASSWORD (32+ random bytes).
   ```
2. Build and start the prod stack:
   ```bash
   docker compose -f docker-compose.prod.yml build
   docker compose -f docker-compose.prod.yml up -d
   ```
3. Run migrations:
   ```bash
   docker compose -f docker-compose.prod.yml run --rm web /app/bin/caredeck eval 'Caredeck.Release.migrate()'
   ```
4. Confirm health:
   ```bash
   curl http://127.0.0.1:4080/healthz   # → ok
   ```
5. In Nginx Proxy Manager → **Proxy Hosts** → **Add Proxy Host**:
   - Domain: `caredeck.josboxoffice.com` (substitute your hostname)
   - Scheme: `http`
   - Forward Hostname / IP: `127.0.0.1`
   - Forward Port: `4080`
   - Enable **Block Common Exploits**.
   - Enable **Websockets Support** — *required for Phoenix LiveView*.
   - **SSL tab:** request a new Let's Encrypt cert, Force SSL, HTTP/2.
   - **Advanced tab:** paste:
     ```nginx
     client_max_body_size 25M;
     proxy_read_timeout 300;
     ```
6. Visit `https://caredeck.josboxoffice.com/design-system` from a public browser.

## Backups

Add to host crontab (`crontab -e`):

```cron
0 3 * * * docker exec caredeck-db-1 pg_dump -U caredeck caredeck_prod | gzip > /var/backups/caredeck/$(date +\%F).sql.gz && find /var/backups/caredeck/ -mtime +14 -delete
```

## Tests + checks

```bash
mix precommit        # full pre-commit pipeline
mix test             # tests only
mix credo --strict   # static analysis
mix sobelow --config # security scan
mix dialyzer         # type checking (first run warms the PLT)
```

## Docs

- `docs/architecture/decisions/` — ADRs (read these before changing anything load-bearing)
- `docs/recon/` — UI/UX recon: screen inventory, route map, sampled tokens, reference frames
- `docs/operations/deployment-runbook.md` — deploy + rollback procedure
- `AGENTS.md` — code conventions for human and AI contributors
