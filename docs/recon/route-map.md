# Route Map

English route slugs for the clone, mapped to the source product's German equivalents. Used by Phase 13 to drive the marketing-site build.

## Marketing site

| Clone route | Source route on myo.de | Purpose |
|---|---|---|
| `/` | `/` | Homepage — hero, customer-logo strip, 3-up feature cards, testimonials, CTA |
| `/communication` | `/kommunikation`, `/module-kommunikation` | Communication module landing |
| `/kitchen` | `/kueche`, `/module-kueche` | Kitchen module landing |
| `/services` | `/module-dienstleister` | Service-Providers module landing |
| `/aid` | `/formfix-digitale-antragshilfe` | Aid (Long-Term Care Assistance) landing |
| `/references` | `/referenzen` | Case-study hub |
| `/blog`, `/blog/:slug` | `/blog/...` | Static blog posts |
| `/about` | `/ueber-uns` | Company / team |
| `/careers` | `/karriere` | Careers |
| `/contact` | `/kontakt` | Contact |
| `/security` | `/sicherheit` | Security & GDPR posture |
| `/privacy` | `/datenschutz` | Privacy policy |
| `/legal` | `/impressum` | Required legal-entity disclosure |
| `/my-data` | `/meine-daten` | GDPR self-service: data export + deletion |

## App routes (Phase 1+)

| Clone route | Phase | Purpose |
|---|---|---|
| `/sign-in` | 1 | Login screen |
| `/sign-up` | 1 | Self-registration (relatives only — gated behind invitation token in Phase 5) |
| `/feed` | 3 | Home feed |
| `/feed/:post_id` | 3 | Post detail |
| `/feed/compose` | 3 | New post composer |
| `/notifications` | 6 | Notifications inbox |
| `/profile` | 5 | Family graph (Relatives / Caregivers tabs) |
| `/profile/edit` | 5 | Edit own profile |
| `/services` | 9 | Service providers tile grid |
| `/services/:provider_id` | 9 | Provider detail (per-kind UI) |
| `/kitchen/weekly-menu` | 8 | Weekly menu builder |
| `/kitchen/weekly-menu/:day` | 8 | Day editor |
| `/kitchen/order/:resident_id` | 8 | Mobile order capture |
| `/kitchen/summary` | 8 | Today's orders roll-up |
| `/aid/:application_id/overview` | 10 | Aid application overview |
| `/aid/:application_id/section/:section_id` | 10 | Section detail |
| `/aid/:application_id/section/:section_id/documents` | 10 | Required documents |
| `/aid/:application_id/submit` | 10 | Review and submit |
| `/aid/admin` | 11 | Aid admin dashboard |
| `/design-system` | 0 | Living style guide |
| `/healthz` | 0 | Health check (no auth) |
