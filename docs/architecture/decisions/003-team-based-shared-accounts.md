# ADR 003: Team-based shared accounts for caregivers

**Status:** Accepted
**Date:** 2026-05-26

## Context

Caredeck is used by shift workers on shared, facility-owned Android tablets. Per-person credentials would require every caregiver to sign in/out at every handover — operationally impossible. The reference product (myo) solves this with **team-level identities** (`Team Care`, `Team Activities`, `Team Therapy`) signed in once per device.

## Decision

Model the caregiver-facing auth as a separate entity from the individual-user model:

- `User` — individual humans (relatives, super-admins, optionally the "actor stamp" on a team post).
- `TeamIdentity` — `id, facility_id, name, role_kind (∈ :care | :activities | :therapy | :housekeeping | :kitchen | :service | :custom), avatar`. Has its own credential set.
- A `TeamSession` carries the optional `actor_user_id` — the human currently holding the tablet, captured at sign-in for audit. Optional, because not every facility staffs that workflow.

Both auth surfaces share `AshAuthentication` machinery but with distinct strategies:

- `User` → password + email confirmation.
- `TeamIdentity` → password only, locked to facility scope.

Posts authored by a TeamIdentity surface `Team Care · Maria` in the audit trail if the actor stamp is set; otherwise just `Team Care`.

## Consequences

**Gains:**

- Operationally realistic — tablets stay signed in for an entire shift.
- The TeamIdentity primary author + optional actor stamp gives us both display ("Team Care posted…") and audit accountability.
- Relatives don't need to know individual caregivers — they see consistent "Team Care" attribution.

**Costs:**

- Two auth surfaces to maintain instead of one. Phase 1 must deliver both.
- The "actor stamp" is optional, which creates two ingestion paths for the audit trail.
- A compromised tablet exposes the team's posting credential — mitigations: enforce facility-network binding, MDM-friendly device profile, biometric unlock layer in the native shell (Phase 7).
