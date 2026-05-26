# ADR 006: Multi-image post storage on S3-compatible object storage

**Status:** Accepted
**Date:** 2026-05-26

## Context

Phase 3 introduces multi-media posts: photo grids (1–9 images), video clips (≤ 60 s), voice notes (≤ 5 min), PDF documents. Storing this in Postgres would balloon the database and cost a fortune in backups. The right home is object storage.

Two deployment shapes need to work:

1. **Production-on-this-box** — no AWS, no Fly. Object storage is **MinIO** (self-hosted, S3-compatible) running as a sibling container in `docker-compose.prod.yml`, or a remote S3-compatible host.
2. **Future cloud** — straight S3 (eu-central-1 / Frankfurt) when the deployment expands.

Both speak the S3 API. We code against the API, not the vendor.

## Decision

- `Attachment` is a child resource of `Post` with `kind ∈ {:photo, :video, :audio, :document}`, `s3_key`, optional `thumbnail_s3_key`, `mime_type`, `bytes`, `duration_sec`.
- Uploads are direct-to-S3 via pre-signed PUT URLs issued by an Ash action `Feed.Attachment.upload_url/2`. The browser POSTs the bytes to S3 directly; Phoenix never touches the file body.
- Thumbnailing for photos runs as an Oban worker (`Caredeck.Workers.Thumbnailer`) on the `:thumbnails` queue.
- Video transcoding deferred to Phase 7+ — until then, we keep the original and play it raw (most modern devices handle MP4/H.264 fine).

ex_aws + ex_aws_s3 are already in deps from ADR-001. `S3_ENDPOINT`, `S3_BUCKET`, `S3_REGION` come from `.env.prod`.

## Consequences

**Gains:**

- Database remains lean.
- Uploads scale to any size without saturating the Phoenix request pipe.
- Same code path works for MinIO (this box) and real S3 later.

**Costs:**

- Pre-signed URLs require careful expiry tuning (currently 10 minutes).
- The native shell must POST multipart-form-data to S3 via `Bridge.uploadToUrl` rather than to a Phoenix endpoint. Documented in ADR-005's bridge spec.
- Thumbnailing failures don't block the post but require a re-queue path. Oban Pro's unique-job feature would help; we stick with OSS Oban + manual idempotency for Phase 0.
