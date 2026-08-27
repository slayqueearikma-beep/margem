# Morocco Law 53-05 — Dribex Lawyer Review Report

**Date:** 2026-08-17  
**Application:** Dribex marketplace (Morocco)  
**Primary legal source:** [BDJ MMSP — Loi n° 53-05](https://bdj.mmsp.gov.ma/Fr/Document/8912-Loi-n-53-05-promulgu%C3%A9e-par-le-dahir-n-1-07-129-d.aspx) (Dahir 1-07-129, BO 5584, 30/11/2007)  
**Incorporated DOC provisions:** Articles 2-1, 417-1, 417-2, 417-3 (via Loi 53-05 Arts. 2–4); verified against WIPO Lex DOC compilation and BO annex text  
**Status:** Technical controls implemented; **legal compliance NOT certified**  
**Prepared by:** Engineering audit (not legal counsel)

---

## 1. Law 53-05 Verified Requirements

### 1.1 Current legal status

| Item | Finding |
|------|---------|
| **Enactment** | Loi n° 53-05 promulgated by Dahir 1-07-129 (30 November 2007), BO n° 5584 |
| **BDJ last modification date** | 06/12/2007 (metadata on official BDJ page) |
| **Mechanism** | Loi 53-05 **amends the Code des obligations et des contrats (DOC)** — operative rules are largely in DOC Arts. 2-1, 417-1 to 417-3, 417, 425, 426, 440, 443 |
| **Supersession** | **Not replaced** by later laws for electronic documents/signatures; consumer/e-commerce rules (e.g. Loi 31-08, Loi 49-16) **supplement** but do not repeal 53-05 |
| **Excluded acts (DOC Art. 2-1)** | Family Code acts; personal/real guarantees under private seal **except** when established by a professional for professional purposes |

### 1.2 Operative provisions (verified text)

**DOC Art. 417-1** (inserted by Loi 53-05 Art. 4):

> *L’écrit sous forme électronique est admis en preuve au même titre que l’écrit sur support papier, **sous réserve** que puisse être **dûment identifiée** la personne dont il émane et qu’il soit **établi et conservé** dans des conditions de nature à **en garantir l’intégrité**.*

**DOC Art. 417-2**:

> *La signature … identifie celui qui l’appose et exprime son consentement … Lorsqu’elle est électronique, il convient d’utiliser un **procédé fiable d’identification** garantissant son lien avec l’acte auquel elle s’attache.*

**DOC Art. 417-3**:

> *La fiabilité d’un procédé de signature électronique est **présumée** … lorsque ce procédé met en œuvre une **signature électronique sécurisée** … créée, l’identité du signataire assurée et l’intégrité de l’acte juridique garantie, conformément à la législation … en vigueur.*

**Loi 53-05 Art. 6–11**: Defines **signature électronique sécurisée** — cryptographic device, conformity certificate, **certificat électronique sécurisé** from an **agréé** certification provider (Arts. 15–21).

**DOC Art. 443** (as amended): Written proof required for obligations **exceeding 10,000 MAD** (may be electronic if DOC 417-1/417-2 conditions met).

### 1.3 What the law does **not** require (verified)

| Requirement | In Loi 53-05 / DOC? |
|-------------|---------------------|
| IP address logging | **No** — not listed as a legal element |
| Timestamp alone | **No** — date certaine for secured signed acts only (417-3 al. 2) |
| Checkbox / “I Accept” = signature électronique sécurisée | **No** — different legal category |
| Qualified/certified signature for all online Terms | **No** — ordinary contracts generally valid without special form (Moroccan non-formalism); secured signature is for **presumption of reliability**, not universal requirement |
| Biometric / ID document for ordinary marketplace signup | **No** under 53-05 alone (certification provider may require ID for **certificat sécurisé**, Art. 21) |

---

## 2. Incorrect or Unsupported Claims

### Claim A — “Electronic documents = paper if person identified”

| Aspect | Verdict |
|--------|---------|
| **Accuracy** | **Partially correct, incomplete** |
| **Source** | DOC **Art. 417-1** |
| **Correction** | Same probative value requires **(1) due identification of the person** AND **(2) establishment/preservation guaranteeing integrity** — identification alone is insufficient |
| **Separate rules for signature?** | **Yes** — Art. 417-1 (document) vs Art. 417-2 (signature/consent) vs Art. 417-3 (secured signature presumption) |

### Claim B — “Log identity, timestamp, and IP to satisfy evidentiary requirements”

| Element | Legally required by 53-05? | Role in Dribex |
|---------|---------------------------|----------------|
| User identity (account link) | **Required** (417-1: person duly identified) | `user_id` + authenticated session |
| Timestamp | **Useful, not expressly mandated** for all acts | `accepted_at` (server UTC) |
| IP address | **Not required** | Supporting security/evidence only (Law 09-08 personal data) |
| Device / session | **Not required** | Optional `user_agent`, `session_reference` |
| Document version | **Integrity best practice** | `policy_version` + manifest |
| Document hash | **Integrity best practice** | SHA-256 of published HTML |
| Email verification | **Not 53-05 requirement** for ordinary ToS | Operational trust layer |
| Qualified e-signature | **Only where secured-signature presumption needed** | **Not implemented** (by design) |

**Conclusion:** IP + timestamp ≠ legally sufficient electronic signature. They are **ancillary technical evidence** when combined with authentication, document versioning, and integrity controls.

### Claim C — “Clickwrap / checkbox = qualified electronic signature”

**Incorrect.** Clickwrap may evidence **consent** under ordinary contract law and support identification when tied to an authenticated account, but it is **not** a *signature électronique sécurisée* under Loi 53-05 Arts. 6–11 unless implemented via an agréé certification mechanism (e.g. Barid eSign class providers — **counsel to confirm current agréés**).

---

## 3. Requirements Applicable to Dribex

| Use case | Likely formality | Identification level | Secured signature required? | Notes |
|----------|------------------|---------------------|----------------------------|-------|
| Account creation | Non-formal | Level 1 (email + password) | No | Pre-contractual processing also under Law 09-08 |
| Terms of Service / Privacy | Non-formal adhesion | Level 1 + affirmative accept | No | Must meet 417-1 integrity + identification |
| Seller agreement | Commercial contract | Level 1 at onboarding + seller terms accept | No* | *Counsel if high-value seller obligations |
| Premium subscription | Commercial + billing | Level 1 + subscription terms + plan/price record | No* | Stripe handles payment authorisation |
| Marketplace product purchase | **Off-platform** today | N/A in-app | N/A | No Order model; buyer contacts seller |
| Acts > 10,000 MAD written proof | DOC Art. 443 | Stronger proof if disputed | Possibly | Not in-app checkout |
| Family Code / excluded guarantees | Excluded Art. 2-1 | N/A | N/A | Not applicable |

**Cross-law (not 53-05 alone):** Loi 31-08 / 49-16 may impose pre-contractual information, confirmation, and withdrawal rules for distance contracts — **counsel review required** for Premium and any future in-app checkout.

---

## 4. Current Implementation Audit

### 4.1 Acceptance flows (before → after this audit)

| Action | Document | Before | After (this PR) |
|--------|----------|--------|-----------------|
| Signup / onboarding | ToS, Privacy | Version + IP + UA | + `document_hash`, `source`, `authentication_method`, proxy-aware IP |
| Seller onboarding | Seller terms | **Not recorded** | Required `seller_terms_acknowledged`; `legal_acceptances` row |
| Premium checkout | Subscription terms | **Not recorded** | Required `subscription_terms_accepted`; `subscription_agreement_records` |
| Purchase / order | — | No in-app orders | Unchanged (discovery marketplace) |
| Account deletion | — | Soft delete + export | Acceptance rows retained per deletion policy |

### 4.2 Database

| Table | Purpose |
|-------|---------|
| `legal_acceptances` | Versioned policy acceptances (unique per user/policy/version) |
| `subscription_agreement_records` | Plan, price, billing period, terms version/hash, provider reference |

Migration: `028_electronic_acceptance_evidence.py`

### 4.3 Legal document versioning

- Published HTML in `souq-local/backend/static/legal/{lang}/{slug}.html`
- Manifest: `static/legal/manifest.json` with `version`, `consent_required`
- Historical versions: **HTML files in repo by version tag** — prior manifest versions should be git-tagged at publish time (operational process)

### 4.4 API security

| Endpoint | Auth | Server-side user | Validation |
|----------|------|------------------|------------|
| `POST /legal/accept` | Bearer | Yes | Policy allow-list |
| `POST /sellers` | Bearer | Yes | `seller_terms_acknowledged` required |
| `POST /subscriptions/checkout/{plan}` | Bearer | Yes | `subscription_terms_accepted` required |
| `POST /subscriptions/subscribe/{plan}` | Bearer | Yes | Same (legacy path updated) |

### 4.5 Gaps remaining

| Gap | Severity | Notes |
|-----|----------|-------|
| Append-only DB enforcement | Medium | Application-level; no DB trigger immutability yet |
| Admin UI edit of acceptances | Low | No admin route found; counsel may want DB privileges review |
| Re-acceptance workflow on minor ToS edits | Process | Version bump triggers gate; legal necessity of re-consent per change = **counsel** |
| In-app orders / receipts | N/A today | Future checkout needs transaction records |
| Secured signature infrastructure | By design omitted | Implement only if counsel requires for specific act types |

---

## 5. Code Changes Made

| Requirement | Source | Change | File/component | Test | Status |
|-------------|--------|--------|----------------|------|--------|
| Document integrity hash | DOC 417-1 | SHA-256 of published HTML | `legal_acceptance.py` | `test_onboarding_acceptance_stores_document_hash` | Done |
| Contextual seller terms | DOC 417-1/417-2 | Record on `POST /sellers` | `sellers.py`, `electronic_acceptance.py` | `test_seller_onboarding_records_seller_terms` | Done |
| Subscription agreement evidence | DOC 417-1/417-2 | `subscription_agreement_records` + checkout hook | `seller_ops.py`, migration 028 | `test_subscription_checkout_requires_terms_acceptance` | Done |
| Proxy-aware IP | Best practice | `get_client_ip()` | `legal_acceptance.py` router | Existing suite | Done |
| Stripe fulfillment link | Evidence chain | Link pending record → subscription | `electronic_acceptance.py`, webhook | Manual / future test | Done |
| Data export | Law 09-08 Art. 7 | Export acceptances + subscription agreements | `data_export.py` | Privacy tests | Done |
| Mobile affirmative accept | UX + evidence | Checkboxes + API fields | `become_seller_screen.dart`, `premium_screen.dart`, models | Flutter manual | Done |

---

## 6. Database Changes Made

**Migration 028** — columns on `legal_acceptances`:

- `document_hash`, `authentication_method`, `source`, `session_reference`

**New table** `subscription_agreement_records`:

- `user_id`, `subscription_id`, `plan_code`, `plan_price_mad`, `billing_period_days`, `policy_id`, `policy_version`, `document_hash`, `accepted_at`, `ip_address`, `user_agent`, `authentication_method`, `provider_reference`

---

## 7. Frontend Changes Made

- `SellerCreatePayload`: `sellerTermsAcknowledged`, `acceptanceLanguage`
- Seller onboarding screens: seller terms checkbox with document link
- `checkoutSubscription`: sends `subscription_terms_accepted`, `acceptance_language`
- Premium screen: subscription terms checkbox before subscribe

---

## 8. Backend Changes Made

See Section 5. Key services: `legal_acceptance.py`, `electronic_acceptance.py`, routers `legal_acceptance.py`, `sellers.py`, `seller_ops.py`.

---

## 9. Security Changes Made

- Acceptance APIs require authenticated user (no client-supplied `userId`)
- Validation rejects missing seller/subscription terms flags (422)
- `legal_acceptances` unique constraint prevents duplicate version rows
- Acceptance metadata minimisation: IP/UA retained with Law 09-08 purpose limitation (see privacy report)

---

## 10. Legal Document Changes Required

| Document | Action | Owner |
|----------|--------|-------|
| Terms / Privacy / Seller / Subscription HTML | Ensure manifest `version` bumped on material changes | Legal + eng |
| Entity placeholders (ICE, address) | Replace before production | Legal |
| Retention schedule for acceptance logs | Document lawful basis + duration | Legal + DPO |
| CNDP declarations for acceptance-log processing | Law 09-08 — separate from 53-05 | Legal / CNDP |

---

## 11. Tests Added

File: `souq-local/backend/tests/test_electronic_acceptance_evidence.py`

- Onboarding stores `document_hash`
- Seller creation records `seller_terms`
- Subscription checkout requires terms acceptance
- Unauthenticated accept blocked

Existing tests updated with `seller_terms_acknowledged` via `tests/seller_helpers.py`.

---

## 12. Remaining Legal Questions

1. For Premium subscriptions, do Loi 31-08 / 49-16 impose mandatory pre-contractual disclosures or withdrawal periods beyond current subscription terms HTML?
2. Must any seller category (e.g. regulated goods) use **signature électronique sécurisée** or written authenticated form?
3. When Terms change cosmetically vs materially, is re-acceptance legally required or merely best practice?
4. For acceptance logs containing IP/UA, what retention period satisfies both evidentiary needs (53-05) and storage limitation (09-08)?
5. If in-app checkout is added later, does Art. 443 (10,000 MAD threshold) require enhanced proof for high-value orders?
6. Current list of **agréé** certification providers for secured signatures (Barid eSign / others)?

---

## 13. Production Blockers

**Only legally supported hard blockers** (not general best practices):

| Blocker | Legal basis | Status |
|---------|-------------|--------|
| Unable to prove which Terms version a user accepted | DOC Art. 417-1 integrity | **Mitigated** — version + hash stored |
| Seller/subscription contractual acceptance not recorded | DOC Art. 417-1/417-2 | **Mitigated** — this implementation |
| Reliance on client-only acceptance without authentication | DOC Art. 417-1 identification | **Mitigated** — server-side bearer auth |
| Formal legal certification of compliance | — | **Not claimed** — requires counsel sign-off |

**Not classified as 53-05 hard blockers:** absence of qualified e-signature, absence of IP logging, absence of in-app order records (no in-app sales contract today).

---

## 14. Lawyer Review Checklist

- [ ] Confirm DOC Arts. 417-1, 417-2, 417-3 analysis against latest BO text
- [ ] Confirm excluded acts (Art. 2-1) do not cover Dribex seller/subscription contracts
- [ ] Confirm ordinary clickwrap + authenticated account sufficient for ToS, Privacy, Seller terms, Subscription terms
- [ ] Confirm whether Premium billing triggers Loi 31-08/49-16 distance-contract rules
- [ ] Confirm retention period for `legal_acceptances` and `subscription_agreement_records`
- [ ] Confirm Law 09-08 processing basis for IP/UA in acceptance logs + CNDP filing
- [ ] Confirm whether any product category requires secured signature or authenticated writing
- [ ] Review historical document archival process (git/manifest) as legal evidence
- [ ] Sign off before stating “53-05 compliant” in marketing or filings

---

## Corrected Claims Table (Section 24)

| Original claim | Actual Law 53-05 / DOC requirement | Article | Correct? | Dribex impact | Implementation required |
|----------------|-----------------------------------|---------|----------|---------------|------------------------|
| Electronic docs = paper if identified | Same force probante if **identified + integrity** preserved | DOC **417-1** | Partial | All acceptance records | **Done** (hash, version, user_id) |
| Art. 2 equivalence rule | Loi 53-05 Art. 2 inserts DOC **2-1** (electronic writing when writing required) | **2-1** | Oversimplified | Formal writing cases | Counsel per contract type |
| Art. 3 | Inserts DOC chapter on electronic transmission | **3** | N/A summary | Messaging/notifications | Partial (message store) |
| Art. 4 | Inserts **417-1, 417-2, 417-3** | **417-1–3** | Core | Acceptance architecture | **Done** |
| Art. 5 | Amends 417, 425, 426, 440, 443 | **417, 425–443** | Partial | Copies & 10k MAD rule | Document for future checkout |
| Electronic signature definition | Identifies signatory + consent; electronic = **reliable identification** linked to act | **417-2** | Correct | Clickwrap ≠ secured | Session + affirmative UI |
| Evidentiary value | Same as paper if conditions met; secured signature **presumed reliable** | **417-1, 417-3** | Correct | No secured infra | Not required for ToS (counsel) |
| Identification | **Dûment identifiée** the person | **417-1** | Correct | Account binding | Auth required |
| Integrity | Establish + conserve guaranteeing integrity | **417-1** | Correct | Hash + immutable version | **Done** |
| Certification | Secured signature via agréé provider + certificat | **Loi 53-05 6–21** | Correct | Not used | Only if counsel mandates |
| Excluded documents | Family code; certain guarantees | **2-1** | Correct | Not applicable | None |
| IP + timestamp sufficient | **Not stated** | — | **Incorrect** | Supporting evidence only | Optional IP logged |
| Checkbox = qualified signature | **No** — secured signature has statutory definition | **6, 417-3** | **Incorrect** | UI checkbox = ordinary consent | Do not overclaim |

---

## Implementation Traceability Matrix

| Requirement | Source | Change | File/component | Test | Status |
|-------------|--------|--------|----------------|------|--------|
| Versioned ToS/Privacy accept | DOC 417-1 | Existing + hash | `legal_acceptance.py` | `test_electronic_acceptance_evidence.py` | Done |
| Seller agreement accept | DOC 417-2 | `record_seller_agreement_acceptance` | `sellers.py` | Same | Done |
| Subscription agreement | DOC 417-2 | `subscription_agreement_records` | `seller_ops.py` | Same | Done |
| Export evidence | 09-08 Art. 7 | Extended export | `data_export.py` | Privacy tests | Done |
| Mobile affirmative accept | 417-2 consent | Checkboxes | mobile onboarding/premium | Manual QA | Done |

---

**Disclaimer:** This report documents technical preparation aligned with verified statutory text. It does **not** constitute legal advice or a compliance certificate. Only qualified Moroccan counsel may opine on production readiness under Loi 53-05 and related consumer/privacy laws.
