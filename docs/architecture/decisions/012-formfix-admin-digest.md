# ADR-012 — Formfix admin dashboard + weekly digest

**Status:** Accepted
**Date:** 2026-05-29

## Context

Phase 11 introduces a facility-admin-only surface for the Formfix module. Two things needed shape decisions:

1. A weekly digest email per facility, summarising every application's status.
2. A note thread on each application, authored by admins.

## Decisions

### Two-job cron pattern (dispatcher → per-facility worker)

The cron entry fires a single `FormfixDigestDispatch` job once a week. The dispatcher reads the `Facility` table and enqueues one `FormfixDigest` job per facility.

Why not a single fat cron job that emits all emails inline?

- **Failure isolation.** A bad facility (no admins, malformed data, mailer hiccup) doesn't block other facilities. Each per-facility job has its own retry budget.
- **Parallelism.** Oban's `:mailers` queue runs jobs concurrently. With N facilities and queue limit M, the digest finishes in roughly N/M intervals instead of N×interval.
- **Observability.** Per-facility jobs make Oban's UI / job logs read naturally — one row per email sent.

### Append-only `ApplicationNote`

The resource has `:create`, `:read`, `:destroy` but no `:update`. To edit, an admin destroys and re-creates.

Why no edit?

- **Audit posture.** Notes are evidence of admin attention. An editable note means a note that says different things to different readers at different times — bad for the GDPR-aware posture established in ADR-009.
- **Implementation cost.** Paper-trail already captures destroys; an editable note would need its own version history UX and add a class of "this note was edited 3 times" affordances we don't actually need.
- **Reversibility.** If editability becomes a hard requirement, adding it is non-breaking. Removing it after launch would be.

### Recipient resolution by facility slug, not a stored column

The digest sends to `admin+<facility.slug>@caredeck.example`. There is no `admin_email` column on `Org.Facility` (yet).

Why not a column?

- **Demo speed.** Adding a column means a migration, a UI to set it, a default-value story, and a validation. None of that is on Phase 11's critical path.
- **Real-world prod will need it.** Documented as an explicit stretch item; the column will arrive when an actual facility's admin mailbox needs to differ from the slug pattern.
- **The plus-addressing trick.** `admin+<slug>@caredeck.example` is a single mailbox a real ops team can route per facility via plus-address filters — useful even in production until the column lands.

## Consequences

- The `:authenticated_team_admin` `live_session` is the access-control boundary; the on_mount enforces `current_team.role_kind == :admin`.
- `TeamIdentity.role_kind` widens to include `:admin` (Phase 1's role enum). The default stays `:care`.
- `Application` `:read` policy widens to allow `:admin` role alongside `:care`. No write paths widen.
- The digest cron fires Monday 09:00 UTC — not facility-local. Acceptable for demo; tracked as a stretch item.

## Alternatives considered

- **Inline cron with one job:** rejected for the failure-isolation reasons above.
- **Per-facility timezone-aware cron:** rejected as out-of-scope; would need a `timezone` column and cron-per-facility scheduling, neither of which Phase 11 was sized for.
- **Edit-with-history on notes:** rejected; see "Append-only" above.
- **Notification-bell mirror for new notes:** rejected; admins work in the dashboard, not the bell feed. Documented as a stretch item.
