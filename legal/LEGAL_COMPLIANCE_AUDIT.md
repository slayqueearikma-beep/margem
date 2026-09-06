# Legal & Compliance Audit Report

**Date:** 2026-08-13  
**Scope:** All legal documentation, configuration, served HTML, mobile legal module, and related l10n  
**Package version:** 2.0.0

> **Disclaimer:** This audit describes product and documentation alignment. It does **not** constitute legal advice or a compliance certification. Licensed counsel must review before publication.

---

## Executive summary

Legal content was fragmented across 48 reference markdown files, embedded Python HTML strings, stale root HTML placeholders, and scattered hard-coded emails in the mobile app. Served documents contained implementation-specific language (API paths, database names, internal env vars) and contradictions (Stripe payments vs manual billing).

This overhaul introduces a **modular, versioned legal system** with centralized configuration, markdown sources, generated HTML, a public manifest API, and stable document identifiers in the mobile app.

---

## What was changed

| Area | Change |
|------|--------|
| **Source of truth** | New `legal/content/{slug}/{lang}.md` for all 9 served documents |
| **Configuration** | `legal/config/entity.yaml` for entity, contacts, dates, placeholders |
| **Registry** | `legal/manifest.yaml` with stable ids, versions, consent flags, change history |
| **Generator** | `generate_legal_html.py` reads markdown + config; outputs HTML + `manifest.json` |
| **Served content** | Regenerated 27 HTML files (9 docs × 3 languages), version 2.0.0 |
| **API** | `GET /legal/manifest` for document registry |
| **Mobile** | `LegalDocumentId` stable ids; `LegalConfig` for contact emails; hub links for subscription & account deletion docs |
| **Presentation** | Improved mobile parser for tables; clearer document structure |
| **CI** | Legal generation step; workflow watches `legal/**` |
| **Documentation** | Updated `legal/README.md` |

---

## What was removed

| Item | Reason |
|------|--------|
| Embedded HTML strings in `generate_legal_html.py` | Replaced by markdown pipeline |
| `static/legal/privacy.html` and `static/legal/terms.html` (root orphans) | Stale placeholders mentioning Stripe and wrong privacy email |
| API paths from user-facing legal text (`DELETE /auth/me`, `GET /auth/me/export`, etc.) | Implementation detail; replaced with in-app paths |
| Internal service names in privacy policy (PostgreSQL, Redis, env var names) | Replaced with functional descriptions |
| False precision on certifications | README no longer implies ISO/SOC certification without confirmation |

---

## What was added

| Item | Purpose |
|------|---------|
| **Subscription & Billing Terms** (`subscription-terms`) | Covers premium plans, future payment providers, refunds |
| **`legal/config/entity.yaml`** | Single place for entity/contact/date configuration |
| **`legal/manifest.yaml`** | Document registry, versioning, consent/notification metadata |
| **`legal/versions/1.1.0/`** | Archive pointer for prior publication cycle |
| **`static/legal/manifest.json`** | Runtime manifest for API (Docker-safe) |
| **`LegalConfig` (mobile)** | Centralized contact emails |
| **Stable document ids** | e.g. `privacy_policy`, `terms_of_service` |
| **FR/AR translations** | Full parallel markdown for all served documents |
| **Expanded Terms** | Buyer rules, IP, indemnification, termination, amendments |
| **Expanded Privacy** | Future-proof processing, third-party, rights sections |

---

## What remains uncertain (requires business/legal owner)

| Item | Status |
|------|--------|
| Registered legal entity name | Placeholder in `entity.yaml` |
| Physical address | Placeholder |
| RC / ICE / registration numbers | Placeholder |
| CNDP declaration or authorization | Placeholder — **must not claim compliance until confirmed** |
| DPO appointment | Contact email exists; appointment unconfirmed |
| ISO / SOC / GDPR certification claims | Explicitly disclaimed in legal notice |
| Cookie consent banner (web) | Policy exists; UI banner not implemented |
| Privacy preference sync to backend | Marketing/recommendation toggles remain device-local |
| Translation legal equivalence | FR/AR are professional translations; counsel should confirm for Morocco |

---

## Product ↔ legal alignment notes

| Product behavior | Legal coverage | Gap |
|------------------|----------------|-----|
| In-app data export | Account Deletion doc + Privacy | Covered |
| In-app account deletion | Account Deletion doc | Covered |
| Manual premium billing | Subscription Terms | Covered; notes current manual stage |
| Off-platform buyer–seller payments | Terms, Seller Terms | Covered |
| Community chat & moderation | Community Guidelines, Terms | Covered |
| MFA / phone OTP | Privacy (verification) | Covered at high level |
| Maps / location | Privacy, Cookie policy | Covered |
| No in-app Stripe checkout | Subscription Terms, Terms | Aligned (no false Stripe claims) |
| Reference trust-safety policies (40 files) | Not served in-app | Available for counsel; publish when features launch |
| Play Store privacy URL in manifest | Not found | **Action:** set before store submission |

---

## Future product changes → legal update map

| Product change | Document(s) to update | Likely notice/consent |
|----------------|----------------------|------------------------|
| New payment provider / in-app checkout | `subscription-terms`, `terms`, `privacy` | Yes |
| New data collection (analytics, ads) | `privacy`, `cookies` | Often yes |
| New subscription tier | `subscription-terms`, manifest | Notice |
| New community feature | `community-guidelines`, `terms` | Notice if rules change |
| New seller verification | `seller-terms`, `privacy` | Notice |
| Entity registration finalized | `legal-notice`, `entity.yaml`, all docs via regen | Publication |
| CNDP registration completed | `privacy`, `legal-notice`, `entity.yaml` | Publication |
| AI features | `privacy` (+ reference `ai-usage-disclosure.md`) | Often yes |
| International expansion | `terms`, `privacy`, `legal-notice` | Counsel review |

Use `manifest.yaml` fields `consent_required`, `notify_on_change`, and `change_history` when planning updates.

---

## Consistency checks performed

- Contact emails aligned: privacy/DPO → `@dribex.app`; support/legal/sellers → `@dribex.ma`
- User roles consistent: buyer, seller, user defined in Terms
- Payment story consistent: no Stripe in served docs; manual billing noted
- Deletion/export described via in-app paths, not API endpoints
- Dates unified at package version 2.0.0 / 2026-08-13
- Historical version 1.1.0 archived, not overwritten

---

## Recommended next steps (non-legal advice)

1. Counsel review of all served documents and placeholders  
2. Fill `entity.yaml` with confirmed registration details  
3. Confirm CNDP status before any compliance claim  
4. Implement web cookie consent banner if web analytics cookies are enabled  
5. Sync privacy marketing preferences to backend when email campaigns launch  
6. Set Play Store / App Store privacy policy URLs to `https://dribex.app/privacy`  
7. Publish reference trust-safety policies when moderating new content types  

---

*Generated as part of the legal documentation overhaul on `cursor/arabic-localization-audit-ee43`.*
