# ADR 002: Authentication with AshAuthentication, tenancy boundary = Facility

**Status:** Accepted
**Date:** 2026-05-26

## Context

Phase 1 must deliver three things at once:

1. Real authentication that AshAuthentication's password strategy can drive end-to-end (register, confirm email, sign in, reset password, sign out).
2. The organisational hierarchy every later phase scopes against: District → Facility → Ward → Team, with users joined to facilities via FacilityMembership.
3. The tenant boundary that Phase 2+ multi-tenant resources will hang off.

The wrong choice on any of these locks in churn for the rest of the project.

## Decisions

### 1. Use AshAuthentication for everything auth-related

`AshAuthentication` 4.13+ with `AshAuthentication.Phoenix`. Password strategy with email confirmation required. `session_identifier :jti` and `require_token_presence_for_authentication? true` so revocation works on logout.

Confirmation strategy uses `require_interaction? true` per the AshAuthentication security advisory — confirmation links POST via an interstitial page so email previewers and AV scanners can't auto-confirm an account.

`Caredeck.Accounts.Secrets` reads `TOKEN_SIGNING_SECRET` from env. Returns `:error` (the atom) when missing — that's what the `AshAuthentication.Secret` protocol expects.

### 2. The tenant boundary is `Facility`, not `District`

99% of authorisation is facility-scoped: "which residents can this caregiver see?", "which posts are visible to this relative?", "raise an Aid application for this resident". District is the organisational parent — a small number of super-admins need cross-facility visibility, but the read path is overwhelmingly "everyone in my facility".

Concretely:

- Phase 1 Accounts-domain resources (User, TeamIdentity, Token, District, Facility, Ward, FacilityMembership) **do not** declare a `multitenancy` block — they span facilities.
- Phase 2+ resources (Resident, Post, Comment, KitchenOrder, AidApplication, …) **will** declare `multitenancy do strategy :attribute; attribute :facility_id end`.
- Callers derive the tenant via `Caredeck.Tenancy.to_tenant/1`, which accepts a `%Facility{}`, a `%FacilityMembership{}`, a map with `:current_facility`, or a `facility_id` binary, and **raises** on `nil`.

### 3. User is cross-tenant, joined via FacilityMembership

A relative can belong to multiple facilities (multiple residents in different homes); a district admin can sweep many. Membership carries the role enum (`:admin | :caregiver | :relative | :clinician`) and a source enum (`:manual | :invited`).

The session stores `current_facility_id`. The `CaredeckWeb.LiveUserAuth` `on_mount` hook resolves it on every authenticated LiveView mount.

### 4. Policies use Ash.Policy.FilterCheck for cross-resource gates

Cross-resource checks return an `Ash.Expr` filter rather than gating wholesale. A district admin gets back the filtered set in one query; an unauthorised caller gets `NotFound` (no existence leak).

## Consequences

**Gains:**

- Auth flow ships in ~1 day instead of 2-3.
- The `Tenancy.to_tenant/1` helper + the no-multitenancy-on-Accounts decision means Phase 2 starts clean: declare `multitenancy ...`, pass tenant on every query, scoping is enforced at the data layer.
- AshPaperTrail covers User, District, Facility, Ward, FacilityMembership — every change to org structure lands in audit storage.

**Costs:**

- The `.Version` mixin pattern (deny-all policies on auto-generated paper-trail resources) is non-obvious — reviewers will see `policies do` appearing on a resource they didn't write.
- District/Facility/Ward write actions are deny-all at first; all bootstrapping uses `authorize?: false` in seeds. A real super-admin role lands later.
