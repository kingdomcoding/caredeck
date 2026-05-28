# ADR 004: Five core domains

**Status:** Accepted
**Date:** 2026-05-26

## Context

Ash projects benefit from grouping resources into domain modules — each domain is one source of code interfaces, one place to find the resources, and one boundary for downstream tooling (AshGraphql, AshJsonApi).

The product surface has clear clusters:

- Organisational scaffolding (District / Facility / Ward / Team).
- People (Resident / Relative / Caregiver-Profile / FacilityMembership).
- The communication feed (Post / Comment / Reaction / Tag / Attachment / Notification).
- Operations workflows (Kitchen menus & orders / Service-provider tickets).
- The Aid (Long-Term Care Assistance) wizard.

## Decision

Five domains, named for their purpose:

| Domain | Module | Resources (illustrative) |
|---|---|---|
| `Org` | `Caredeck.Org` | District, Facility, Ward, TeamIdentity, FacilityMembership |
| `People` | `Caredeck.People` | Resident, Relative, RelativeOfResident, CaregiverProfile |
| `Feed` | `Caredeck.Feed` | Post, PostAudience, Attachment, Comment, Reaction, ResidentTag, Notification |
| `Operations` | `Caredeck.Operations` | MealCategory, Product, MenuTemplate, DayMenu, ResidentMealOrder, ServiceProvider, ServiceRequest, ServiceMessage |
| `Aid` | `Caredeck.Aid` | Application, ApplicationSection, SectionField, FieldRationale, RequiredDocument, UploadedDocument |

`Accounts` resources (User, Token) live under `Caredeck.Accounts` per AshAuthentication convention. That makes six total namespaces; "five domains" is the count of *product* domains.

## Consequences

**Gains:**

- Module names map cleanly to feature areas, easing onboarding.
- Code interfaces accumulate on the domain — callers don't import resources directly.
- Cross-domain references are explicit at the resource level (e.g. `Feed.Post` has `belongs_to :resident, People.Resident`).

**Costs:**

- A resource that straddles two domains forces a judgement call. The rule: it lives in the domain where it's *modified*; foreign keys point inwards from other domains.
- The `Accounts` vs `Org` split duplicates the user-vs-team distinction. We accept that, because AshAuthentication wants to own its `User` resource.
