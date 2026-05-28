# ADR 009: Audit and GDPR posture

**Status:** Accepted
**Date:** 2026-05-26

## Context

The product handles personal data of an elderly, often-vulnerable population — resident identity, photographs, medical context (Aid applications cite care levels and disability status), and family-relationship metadata. The legal regime is GDPR (the EU analogue of FERPA for the German source product).

The posture has to cover:

1. **Audit** — every change to a resident-, post-, or applicant-touching record needs an immutable history with actor + timestamp.
2. **Soft delete + retention** — deletion isn't immediate; a 30-day grace window lets accidental deletes be recovered.
3. **Right to access** (Art. 15) — a relative can export everything we hold about their resident's record.
4. **Right to erasure** (Art. 17) — a verified deletion request hard-removes the data after the retention window.
5. **Right to rectification** (Art. 16) — covered by ordinary edit flows.
6. **Subject lookup** — given an email, list every record involving that user.

## Decision

- **AshPaperTrail on every resident-, post-, applicant-, and member-touching resource.** `change_tracking_mode :changes_only` (diff per action). `ignore_attributes [:hashed_password]`. The Version resource gets deny-all policies via mixin so paper-trail data is not browsable through the API.
- **AshArchival on every user-data resource.** Soft delete writes `archived_at`; a nightly Oban cron sweeps rows older than 30 days into hard delete.
- **Data export endpoint** `/my-data` (Phase 13). Returns a JSON dump of every paper-trail Version row plus current rows tied to the requesting user. Authenticated, rate-limited.
- **Data deletion request** flows through `Caredeck.Accounts.request_deletion/1`. Marks the user account `pending_deletion: true`; a 30-day Oban job hard-deletes once the window elapses unless cancelled.
- **Subject lookup** is an internal IEx-only query against the Repo (Phase 13 introduces a hardened admin LiveView for this).
- **Data residency** — production database lives on this box, which is geographically in Germany. No third-party data processors except where contractually bound (email relay).

## Consequences

**Gains:**

- The audit story is built-in, not bolted-on.
- GDPR rights become Ash actions, each individually testable.
- A reviewer or auditor can read the resource file to verify which fields are tracked.

**Costs:**

- AshPaperTrail roughly doubles write volume on tracked resources.
- The `.Version` mixin pattern (deny-all policies on auto-generated resources) is non-obvious to new readers — mitigated by a short note in AGENTS.md.
- The 30-day soft-delete window means a user who requests immediate deletion has to wait. We document this on `/my-data`.
