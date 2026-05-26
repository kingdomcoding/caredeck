# ADR 001: Build on Ash Framework

**Status:** Accepted
**Date:** 2026-05-26

## Context

Caredeck rebuilds the myo elder-care platform as a portfolio artefact. The domain has several traits that drive the framework choice:

- **Multi-tenant** (district → facility → resident scoping) where a cross-tenant leak is a GDPR incident, not just a bug.
- **Rich authorization** — caregivers see their facility's residents, relatives see only their own resident's data, district admins see across the org.
- **Auditability** — GDPR-grade edit history on every resident-, post-, and applicant-touching resource.
- **Many computed fields** — Aid section progress, post engagement counts, notification fan-out.
- **Heavy CRUD surface** — feed posts, comments, reactions, attachments, profiles, kitchen orders, service requests, Aid sections.
- **Background jobs tied to domain events** — notification fan-out, document verification, weekly digest emails.

Plain Phoenix with hand-rolled contexts can do all of this, but each concern becomes its own hand-written layer: scoping plugs, policy modules, audit hooks, calculation helpers, form wrappers, Oban workers.

## Decision

Build on **Ash 3.x** with the full first-party extension suite:

- `AshPostgres` as the data layer
- `AshPhoenix` for form integration
- `AshAuthentication` + `AshAuthentication.Phoenix` for auth (Phase 1)
- `AshOban` for trigger-based background jobs
- `AshPaperTrail` for GDPR audit trails
- `AshArchival` for soft delete with 30-day retention
- `AshStateMachine` for the Aid application lifecycle and post moderation states
- `AshAdmin` for the baseline back-office UI

Every resource uses `Caredeck.Resource`, a base macro that wires `AshPaperTrail`, `AshArchival`, `Ash.Notifier.PubSub`, and `Ash.Policy.Authorizer` by default — so the safety defaults can't be forgotten.

## Consequences

**Gains:**

- Policies are declarative and co-located with the resource. A reviewer verifies GDPR scoping by reading the resource file.
- Multi-tenancy is attribute-enforced at the data layer. Forgetting to scope a query becomes architecturally impossible.
- Calculations and aggregates replace one-off query helpers.
- AshPaperTrail is on from day one — audit log is a free query.
- CRUD-heavy phases (3, 4, 5, 8, 9, 10) accelerate significantly.

**Costs:**

- ~20 additional deps across the Ash ecosystem.
- Learning curve for reviewers unfamiliar with the Ash DSL.
- Escape-hatch complexity — multi-step orchestration reaches for `Ash.Reactor` rather than plain Elixir functions.

## Conventions

1. **Encapsulate all logic inside actions** — never pipeline into `Ash.read`/`Ash.create`. Side effects live in `change` modules, `after_action` hooks, or `Ash.Notifier`.
2. **Code interfaces live on the domain**, not on the resource. Callers invoke `Caredeck.Org.register_facility!(...)` via the domain's `resources do … end` block.

## Alternatives considered

- **Plain Phoenix + Ecto + hand-rolled contexts.** Simpler first read; heavier ongoing maintenance; GDPR/audit/scoping burden falls on reviewer discipline rather than the framework.
- **Event-sourcing with Commanded.** Overkill for the CRUD-heavy product surface; AshPaperTrail + Phoenix.PubSub + AshStateMachine cover the audit/event-driven needs with a fraction of the cost.
