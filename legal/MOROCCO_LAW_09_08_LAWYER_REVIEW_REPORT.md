# Morocco Law 09-08 / CNDP — Dribex Lawyer Review Report

**Date:** 2026-08-17  
**Application:** Dribex marketplace (Morocco)  
**Status:** Technical controls implemented; **legal compliance NOT confirmed**  
**Prepared by:** Engineering audit (not legal counsel)

---

## A. Executive Compliance Report

This report audits Dribex against **Law No. 09-08** (promulgated by Dahir 1-09-15, BO 5714) using **official CNDP sources** (cndp.ma PDF, formalités, notifier-un-traitement). It corrects common oversimplifications and documents **what was verified, implemented, and what remains for Moroccan counsel and CNDP**.

**Key findings:**

1. **Article 4 does NOT mean “all processing requires consent.”** Law 09-08 Art. 4 lists five exceptions (legal obligation, contract, vital interests, public interest, legitimate interest). Dribex core marketplace processing likely maps to **contract / pre-contractual measures (Art. 4(b))**; **marketing** requires **consent (Art. 4, 9, 10)**.
2. **Profile photographs (seller logos) are personal data but NOT sensitive/biometric data** under Art. 1 §3 unless used for biometric identification — Dribex does not perform facial recognition.
3. **CNDP prior declaration (F211/F214) is generally required** for automated processing (Art. 12–14; cndp.ma/formalites), with **authorization (F112)** for sensitive categories. **Whether production is legally blocked without a récépissé is a counsel/CNDP determination**, not assumed here.
4. **International transfers (Art. 43–44)** require case-by-case analysis; **“EU = adequate, notify only” is NOT verified** as a universal rule. Transfers to non-adequate states may require **express consent and/or CNDP authorization (Art. 44 §3)**.
5. **Technical improvements implemented** in this audit: privacy request workflow, versioned marketing consent sync, expanded data export, processing registry, legal-gate exemption for privacy endpoints.

**This document does NOT certify legal compliance or CNDP approval.**

---

## B. Corrected Moroccan Legal Matrix

| Article | Common claim | Verified requirement (official source) | Correct? | Source | Dribex impact | Implementation status |
|---------|--------------|----------------------------------------|----------|--------|---------------|----------------------|
| **Art. 1** | Names, emails, phones, photos = personal data | “Données à caractère personnel” includes any info on identifiable natural person, **including sound and image** (not limited to biometrics) | Partially oversimplified | Loi 09-08 Art. 1 §1 (CNDP PDF) | All listed fields are personal data; seller logo = image personal data, **not sensitive data** unless Art. 1 §3 categories | VERIFIED |
| **Art. 1** | Dribex is always sole controller | Controller = entity determining purposes and means; subprocessors are processors | Incomplete | Art. 1 §5–6 | Dribex controller for platform; Stripe/Azure/SMTP may be processors | LAWYER REVIEW REQUIRED |
| **Art. 3** | Article 3 covers all data quality + retention | Art. 3 §1: lawful/fair processing, purpose limitation, adequacy, accuracy, **storage limitation** | Correct scope | Art. 3 | Processing registry added (`legal/config/processing_registry.yaml`) | PARTIALLY IMPLEMENTED |
| **Art. 4** | All processing needs express consent | **Default rule is consent**, but Art. 4 lists **five exceptions** (a–e) | **Incorrect if stated absolutely** | Art. 4 | Account/marketplace = likely Art. 4(b); marketing = consent | IMPLEMENTED (unbundled consents) |
| **Art. 5** | Privacy Policy link is enough | Must inform **at collection**: controller ID, purposes, recipients, mandatory/optional fields, **access/rectification/opposition rights**, **CNDP récépissé/autorisation number** | Often incomplete in apps | Art. 5; CNDP site web guide | Privacy policy v2.0.0 exists; **CNDP number still placeholder** | PARTIALLY IMPLEMENTED |
| **Art. 7** | Export button = full compliance | Right to confirmation, intelligible communication, origins; controller may seek CNDP delays for abusive requests | Partial | Art. 7 | Expanded JSON export + privacy request workflow | IMPLEMENTED (partial) |
| **Art. 8** | Delete account = erase everything | Rectification/erasure **without undue delay (10 days)** but **retention exceptions** exist (billing, legal holds) | **Incorrect if absolute** | Art. 8 | Soft-delete + anonymization; billing/security retained per policy | PARTIALLY IMPLEMENTED |
| **Art. 9** | Users can object to all algorithms | Opposition for **legitimate motives**; **free opposition to prospection commerciale** | Oversimplified | Art. 9 | Marketing opposition wired; fraud/security not opposable | IMPLEMENTED (marketing) |
| **Art. 10** | Same as GDPR email rules | Moroccan-specific prospection rules (consent, opt-out on each email for analogous products) | Must not assume GDPR | Art. 10 | Marketing consent default **false** | IMPLEMENTED |
| **Art. 12** | All automated processing must be declared | **Authorization** for sensitive data etc.; **declaration** for other cases; exemptions exist | Oversimplified | Art. 12–18; cndp.ma/formalites | Multiple distinct treatments likely need **separate F211** filings | LAWYER REVIEW REQUIRED |
| **Art. 23** | Encrypt fields = compliant | **Appropriate technical and organizational measures** proportionate to risk | Oversimplified | Art. 23 | TLS, hashing, RBAC, rate limits exist; at-rest encryption depends on infra | PARTIALLY IMPLEMENTED |
| **Art. 43–44** | EU adequate = notify only | Transfers only if adequate protection; Art. 44 lists **consent + authorization** paths for non-adequate states | **Incorrect if simplified** | Art. 43–44 | Azure/Sentry/SMTP destinations must be mapped | LAWYER REVIEW REQUIRED |
| **Art. 51–66** | “Massive fines” | Specific penalties: e.g. Art. 52 **10k–100k DH** undeclared processing; Art. 52 al.2 **20k–200k DH** refusing Art. 7–9 rights | Often exaggerated | Art. 52–61 | Risk table below | VERIFIED |

---

## C. CNDP Requirements (Verified Procedure)

| Processing operation | CNDP procedure (official) | Submission required? | Approval/receipt before production? | Production impact |
|---------------------|----------------------------|----------------------|-------------------------------------|-------------------|
| Core user accounts (email, profile) | Declaration normale **F211** (or F214 if eligible) | Yes, pre-implementation | Récépissé within 24h; possible reclassification to authorization within 8 days | **LAWYER REVIEW REQUIRED** — do not assume universal hard blocker |
| Seller storefront + messaging | Likely separate F211 (distinct purpose) | Yes | Same | LAWYER REVIEW REQUIRED |
| Marketing email list | F211 + consent evidence | Yes | Same | Consent implemented; CNDP filing pending |
| Sensitive data (health, religion, etc.) | **Authorization F112** | Yes | CNDP opinion within 2 months | **NOT APPLICABLE** — Dribex does not process Art. 1 §3 sensitive categories |
| Biometric / facial recognition | Authorization | N/A | N/A | **NOT APPLICABLE** — no biometric processing |
| International transfer (e.g. US cloud) | Transfer formalities + Art. 43–44 | Yes, when applicable | Authorization may be required | LAWYER REVIEW REQUIRED |
| Public register only | F115 | If applicable | Notification of controller identity | NOT APPLICABLE |

**Official forms (cndp.ma/notifier-un-traitement):** F211, F214 (declaration); F112, F113 (authorization). **F118 was NOT verified** as a current universal form — do not cite without confirmation.

**Required attachments (CNDP):** proof of information to data subjects, consent copies where applicable, subprocessors contracts, signatory authority.

---

## D. Data Inventory (Actual Dribex Collection)

| Data category | Collected? | Purpose | Storage | Retention (documented) |
|---------------|-----------|---------|---------|------------------------|
| Name (display_name) | Yes | Account / display | `users` | Account lifetime |
| Email | Yes | Auth, comms | `users` | Account + legal exceptions |
| Phone | Yes | Optional contact | `users`, signup OTP | Account lifetime |
| Password | Yes (hash) | Auth | `users.password_hash` | Until deletion |
| Seller business info | Yes (sellers) | Storefront | `seller_profiles` | Until deletion |
| Seller logo/cover image | Yes | Branding (**not biometric**) | Object storage + URL | Until deletion (**blob purge NOT automated**) |
| Messages | Yes | Marketplace comms | `messages` | Deleted on account deletion (peer) |
| Reviews | Yes | Trust | `reviews` | Deleted/anonymized per workflow |
| Favorites / behavioral | Yes | UX / optional personalization | Various | Deleted on account deletion |
| IP / user-agent | Yes | Security, legal evidence | logs, `legal_acceptances`, `user_consents` | Policy-defined |
| Marketing consent | Yes (optional) | Prospection | `user_consents` | Evidence retained |
| Payment/subscription | Yes (premium) | Billing | `subscriptions`, Stripe | Up to 7 years (policy) — counsel confirm |
| Buyer profile photo | **No dedicated field** | N/A | N/A | N/A |
| Analytics SDK | **Not found in code** | N/A | N/A | N/A |

---

## E. International Transfer Map

| Provider | Data | Purpose | Likely country | DPA | Art. 43–44 action |
|----------|------|---------|----------------|-----|-------------------|
| PostgreSQL (hosting) | All DB fields | Primary storage | **Deployment-dependent** (Morocco if on-prem) | Infra contract | Confirm adequacy / authorization |
| Azure Blob (optional) | Media files | Image storage | **Microsoft region-dependent** | Azure DPA | LAWYER REVIEW REQUIRED |
| MinIO (on-prem) | Media | Self-hosted | Morocco (if local) | N/A | Lower transfer risk if in Morocco |
| SMTP provider | Email, name | Transactional email | Provider-dependent | SMTP contract | LAWYER REVIEW REQUIRED |
| Stripe | Billing metadata | Payments | US/EU entities | Stripe DPA | Art. 44 analysis required |
| Sentry (optional mobile) | Crash traces | Error monitoring | US (default) | Sentry DPA | Consent/authorization if transfer to non-adequate state |
| Azure App Insights (optional) | Telemetry | APM | Region-dependent | Microsoft | LAWYER REVIEW REQUIRED |
| Google Maps SDK | Location queries | Maps display | US | Google terms | Device permission + transfer analysis |

**Correction:** Do **not** assume EU adequacy alone satisfies Moroccan law without CNDP list and procedure.

---

## F. Privacy Controls Implemented

| Control | Location | Evidence |
|---------|----------|----------|
| Privacy request workflow | `privacy_requests` table, `/privacy/requests` API | Migration 027; tests `test_privacy_compliance.py` |
| Versioned marketing consent | `user_consents` table, `/privacy/consents/*` | Timestamp, policy version, IP/UA |
| Expanded data export (Art. 7) | `app/services/data_export.py`, `/auth/me/export` | Includes messages, reviews, consents, legal acceptances |
| Privacy endpoints exempt from legal gate | `app/auth.py` | Users can exercise rights during policy re-acceptance |
| Processing purpose registry | `legal/config/processing_registry.yaml` | Counsel-facing inventory |
| Mobile consent sync | `privacy_settings_screen.dart` → API | Server-side evidence |
| In-app access request | `your_data_screen.dart` | POST `/privacy/requests` type=access |

---

## G. Security Controls Implemented (Art. 23 — Existing + Verified)

| Control | Status | Evidence |
|---------|--------|----------|
| Password hashing (bcrypt/passlib) | IMPLEMENTED | `security.py` |
| JWT + refresh rotation | IMPLEMENTED | Auth routers |
| MFA (TOTP) | IMPLEMENTED | Migration 014 |
| Rate limiting | IMPLEMENTED | SlowAPI |
| RBAC (admin/support/seller) | IMPLEMENTED | `auth.py` |
| Admin IP allowlist | IMPLEMENTED | Middleware |
| TLS (production requirement) | IMPLEMENTED | Mobile release check |
| Structured logging + request ID | IMPLEMENTED | `logging_config.py` |
| Upload path isolation `{user_id}/` | IMPLEMENTED | `uploads.py` |
| Encryption at rest (DB/disk) | **Infrastructure-dependent** | NOT VERIFIED in all deployments |

---

## H. Legal Documents Still Required (Counsel)

1. Replace placeholders: **legal entity name, address, RC/ICE, DPO contact, CNDP récépissé/autorisation number** in `legal/config/entity.yaml` and privacy policy HTML.
2. Finalize **CNDP F211** (and additional filings per distinct processing purpose).
3. **Transfer impact assessments** for each non-Moroccan subprocessor (Art. 43–44).
4. **Seller terms / subscription terms** acceptance enforcement review (manifest marks consent_required; only ToS+Privacy enforced at onboarding).
5. **Cookie/consent banner** for web properties if tracking cookies used (no in-app banner today).
6. **Retention schedule** with legal citations (not invented periods).

---

## I. Remaining Legal Risks

| Risk | Severity | Notes |
|------|----------|-------|
| No CNDP récépissé on file | High | Art. 52 — 10k–100k DH undeclared processing; production legality for counsel |
| Placeholder CNDP status in privacy policy | High | Art. 5 requires récépissé/autorisation characteristics |
| Cloud subprocessors outside Morocco | Medium–High | Art. 43–44 |
| Marketing without synced consent (legacy users) | Medium | Mitigated by new `user_consents` — historical gap may remain |
| Media blobs not purged on deletion | Medium | Art. 8 erasure vs retention exceptions |
| No automated retention enforcement | Medium | Art. 3(e), Art. 55 |
| Admin audit logs not exposed in UI | Low | Operational/compliance visibility |

---

## J. Production Blockers (Evidence-Based Only)

| Blocker | Supported by authoritative source? | Engineering assessment |
|---------|-----------------------------------|------------------------|
| Missing CNDP declaration | **Art. 12–14 + CNDP formalités** require prior declaration for most processing | **Likely legal requirement** — confirm with counsel before public launch |
| Missing privacy policy CNDP number | **Art. 5** | Must be updated before collection at scale |
| Undocumented international transfers | **Art. 43–44** | Block production use of US-only services until analyzed |
| **NOT a verified universal blocker:** missing cookie banner | Only if cookies/trackers used | Conditional |

---

## K. Lawyer Review Items

1. Confirm **controller/processor** roles for Stripe, Azure, SMTP, Sentry, Firebase.
2. Map each processing activity to **legal basis** (consent vs contract vs legitimate interest).
3. Determine **number of CNDP F211 filings** required (clients, sellers, marketing, security logs, etc.).
4. Confirm whether **seller logo images** trigger any special formalities (engineering: ordinary personal data, not sensitive).
5. Validate **retention periods** in account-deletion policy against tax/commercial law.
6. Approve **international transfer** mechanism for each deployment target (Morocco-only vs Azure EU vs US).
7. Confirm **account deletion** workflow satisfies Art. 8 with lawful retention carve-outs.
8. Review **prospection commerciale** implementation against Art. 9–10.
9. Confirm whether **personalized recommendations** require consent or qualify under legitimate interest.
10. Insert actual **CNDP récépissé/autorisation** into Art. 5 notices.

---

## L. Implementation Evidence

| Change | File | Why | Privacy/security effect | Tests |
|--------|------|-----|-------------------------|-------|
| Migration 027 | `alembic/versions/027_privacy_compliance.py` | Store requests + consent evidence | Audit trail for Art. 7–9 | Alembic upgrade |
| Privacy service | `app/services/privacy_compliance.py` | Business logic | Unbundled consent, opposition | 5 pytest cases |
| Privacy API | `app/routers/privacy.py` | User-facing rights | Authenticated, rate-limited | `test_privacy_compliance.py` |
| Data export expansion | `app/services/data_export.py` | Art. 7 intelligible copy | More complete export | Export test in privacy suite |
| Legal gate exemption | `app/auth.py` | Rights during re-consent | Fail-closed elsewhere | Gate test |
| Mobile consent sync | `privacy_settings_screen.dart` | Server evidence | Marketing not local-only | Manual |
| Access request UI | `your_data_screen.dart` | Art. 7 self-service | Links to export workflow | Manual |
| Processing registry | `legal/config/processing_registry.yaml` | Purpose limitation doc | Prevents silent repurposing | N/A |

**Backend tests:** 168 passed (including 5 new privacy tests).  
**Migration head:** 027.

---

## Sanctions Table (Art. 51–66 — Verified Penalties)

| Article | Violation | Penalty | Applies to Dribex? |
|---------|-----------|---------|-------------------|
| Art. 52 al.1 | Processing without declaration/authorization | 10,000–100,000 DH | Yes, if undeclared |
| Art. 52 al.2 | Refusing Art. 7–9 rights | 20,000–200,000 DH per offense | Yes |
| Art. 54 | Fraudulent/unfair collection; incompatible purpose | 3 months–1 year + 20k–200k DH | If misrepresented |
| Art. 55 | Excessive retention | 3 months–1 year + 20k–200k DH | If no justification |
| Art. 56 | Art. 4 consent violation | 3 months–1 year + 20k–200k DH | Marketing without consent |
| Art. 57 | Sensitive data without consent | 3 months–1 year + 50k–300k DH | Not applicable (no sensitive processing) |
| Art. 59 | Opposition violation (marketing) | 3 months–1 year + 20k–200k DH | If marketing after opt-out |
| Art. 60 | Illegal international transfer | 3 months–1 year + 20k–200k DH | If cloud transfers non-compliant |
| Art. 64 | Legal person | Fines doubled | Applicable to corporate operator |

---

## Consent / Legal Basis Matrix (Dribex)

| Processing | Legal basis (candidate) | Consent required? | How collected | Withdrawal |
|------------|------------------------|-------------------|---------------|------------|
| Account creation | Art. 4(b) contract | No (counsel confirm) | Registration form + privacy notice | Account deletion |
| Marketplace messaging | Art. 4(b) contract | No | Using feature | Delete messages / account |
| Security / fraud logs | Art. 4(e) legitimate interest / legal | No | Implicit in service | N/A (limited) |
| Terms + Privacy acceptance | Contract / legal obligation | Acknowledgment (not marketing consent) | Legal acceptance screen | N/A — must accept to use service |
| Marketing email | Art. 4 + Art. 9–10 | **Yes** | Opt-in toggle (default off) | Toggle off / opposition request |
| Personalized recommendations | Consent (implemented as opt-in) | **Yes (technical default: on locally — counsel review)** | Privacy settings | Toggle off |
| Seller logo upload | Art. 4(b) contract | No | Seller onboarding | Delete image / account |
| Premium billing | Art. 4(b) + legal retention | No | Checkout | Cancel + retention exceptions |

---

## Profile Photograph Classification

**Verified:** Law 09-08 Art. 1 §1 includes **image** in personal data.  
**Verified:** Art. 1 §3 **sensitive data** covers racial origin, political opinions, religion, union membership, **health/genetic** — **not ordinary photographs**.  
**Dribex:** Seller logo images only; **no biometric processing** (no facial recognition, embeddings, liveness).  
**Conclusion:** Treat as **ordinary personal data**, not sensitive data; **no Art. 12(1)(a) authorization** for sensitive categories — **counsel to confirm**.

---

## Disclaimer

> The following **technical controls** have been implemented based on verified statutory text and CNDP procedural sources. **Legal compliance, CNDP authorization, and production legality** remain subject to **Moroccan qualified counsel** and **CNDP decisions**. This report is **not legal advice**.
