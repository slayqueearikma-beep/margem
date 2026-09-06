# Dribex Legal Package — Lawyer Review Notes

**Effective Date:** August 1, 2026  
**Last Updated:** August 5, 2026

---

## Important Notice

The legal documents in this `/legal` folder were drafted as a **comprehensive starting point** tailored to Dribex's current product architecture, data practices, and business model. **They do not constitute legal advice.** A licensed attorney qualified in Moroccan law (and, where applicable, EU/GDPR and California/CCPA law) must review and approve all documents before public release.

---

## Clauses Requiring Legal Review Before Publication

### 1. Entity and Registration (Critical)

| Item | Status | Action Required |
|------|--------|-----------------|
| Registered legal entity name | **Missing** | Insert actual company name (e.g., SARL, SA) |
| Registered office address | **Missing** | Insert physical address in Morocco |
| Commercial registration (RC) number | **Missing** | Insert once registered |
| ICE / IF / tax identifiers | **Missing** | Insert as applicable |
| EU representative (GDPR Art. 27) | **Not appointed** | Required if offering services to EEA users |
| DPO appointment | **Referenced but not formalized** | Confirm DPO designation under Law 09-08 |

**Affected documents:** All documents; especially [contact.md](../contact.md), [Privacy Policy](../privacy/privacy-policy.md), [Governing Law](../terms/governing-law.md)

---

### 2. Governing Law and Dispute Resolution (Critical)

| Clause | Concern |
|--------|---------|
| Arbitration (CMAC) | Enforceability under Moroccan consumer protection law (Law 31-08) for B2C subscriptions |
| Class action waiver | May not be enforceable for EU/California consumers |
| Exclusive jurisdiction (Casablanca courts) | Confirm for international users |
| English as prevailing language | Confirm for trilingual platform (EN/FR/AR) |

**Affected documents:** [Dispute Resolution](../terms/dispute-resolution.md), [Governing Law](../terms/governing-law.md), [Terms of Service](../terms/terms-of-service.md)

---

### 3. Privacy and Data Protection (High Priority)

| Item | Concern |
|------|---------|
| CNDP declaration (Morocco) | Law 09-08 may require registration with Morocco's data protection authority |
| GDPR legal bases | Confirm legitimate interest assessments for analytics and contact event tracking |
| International data transfers | Confirm Azure region and adequacy/SCCs for EEA data |
| Data export/portability | Feature not yet implemented — policy promises email-based export |
| Consent mechanisms | Cookie banner and marketing consent UI not yet implemented on Web |
| Children's age threshold | 16 chosen — confirm against Morocco and target market requirements |

**Affected documents:** [Privacy Policy](../privacy/privacy-policy.md), [Cookie Policy](../privacy/cookie-policy.md), [Data Retention](../privacy/data-retention-policy.md), [Children's Privacy](../privacy/children-privacy-policy.md)

---

### 4. Subscription and Consumer Law (High Priority)

| Item | Concern |
|------|---------|
| Billing not yet live | Terms reference future payment provider — update when integrated |
| Auto-renewal disclosures | May require specific consumer notices under Moroccan and EU law |
| 48-hour refund window | Confirm compliance with applicable cooling-off periods |
| Price change notice period | Confirm minimum notice requirements |
| MAD pricing for international users | Currency and tax implications |

**Affected documents:** [Subscription Terms](../premium/subscription-terms.md), [Refund Policy](../premium/refund-policy.md), [Payment Terms](../marketplace/payment-terms.md)

---

### 5. Marketplace Liability (High Priority)

| Item | Concern |
|------|---------|
| Platform intermediary status | Confirm Dribex's legal classification under Moroccan e-commerce law |
| Off-platform transaction disclaimer | Strengthen if required by consumer protection authorities |
| Verification badge liability | Ensure disclaimers are prominent in UI, not just legal docs |
| Category-specific disclaimers | Medical, legal, automotive — confirm regulatory requirements |

**Affected documents:** [Marketplace Rules](../marketplace/marketplace-rules.md), [Seller Terms](../marketplace/seller-terms.md), all [disclaimers](../disclaimers/)

---

### 6. Intellectual Property (Medium Priority)

| Item | Concern |
|------|---------|
| DMCA-style process | Morocco has different IP enforcement framework — adapt for local law |
| User content license scope | Confirm scope is sufficient for Platform operation without overreach |
| Trademark registration | Confirm "Dribex" trademark status |

**Affected documents:** [DMCA Takedown](../trust-safety/dmca-takedown-policy.md), [Copyright Policy](../trust-safety/copyright-ip-policy.md), [UGC Policy](../marketplace/user-generated-content-policy.md)

---

### 7. Employment and Staff (Medium Priority)

| Item | Concern |
|------|---------|
| Admin staff access to user data | Confirm employment agreements and data access policies |
| Admin audit log retention (3 years) | Confirm against retention minimization principles |

**Affected documents:** [Security Policy](../security/security-policy.md), [Data Retention](../privacy/data-retention-policy.md)

---

### 8. Accessibility (Medium Priority)

| Item | Concern |
|------|---------|
| WCAG 2.1 AA claim | Verify through formal audit before publishing statement |
| Moroccan accessibility law | Confirm applicable requirements |

**Affected documents:** [Accessibility Statement](../compliance/accessibility-statement.md)

---

### 9. AI Disclosure (Low Priority — Current)

| Item | Status |
|------|--------|
| No AI currently used | Disclosure is accurate as of August 2026 |
| "Personalized recommendations" marketing | Ensure UI/marketing aligns with non-AI implementation |

**Affected documents:** [AI Usage Disclosure](../privacy/ai-usage-disclosure.md), [Dribex Plus Membership Terms](../premium/buyer-plus-membership-terms.md)

---

## Recommended Pre-Launch Checklist

- [ ] Engage Moroccan-licensed counsel for full review
- [ ] Register legal entity and insert details in all documents
- [ ] File CNDP declaration if required under Law 09-08
- [ ] Appoint DPO and update contact information
- [ ] Implement cookie consent banner on Web
- [x] Implement in-app links to Privacy Policy and Terms of Service
- [x] Publish policies at API `/legal/{lang}/{doc}` with `/privacy`, `/terms`, `/cookies` redirects
- [x] Configure locale-aware legal URLs via `AppConfig.legalDocumentUrl`
- [ ] Conduct accessibility audit before publishing Accessibility Statement
- [ ] Update subscription terms when payment provider is integrated
- [x] Implement data export endpoint or confirm email-only process with counsel (`GET /auth/me/export` implemented)
- [ ] Translate key documents to French and Arabic (hosted HTML summaries at `/legal/fr` and `/legal/ar`; full markdown counsel review pending)
- [x] Add legal acceptance notice at registration
- [ ] Review Google Play and Apple App Store policy compliance

---

## Document Inventory

**Total documents:** 46 (including this review notes file and README index)

All documents are in Markdown format, organized under `/legal/` with subdirectories for privacy, terms, marketplace, trust-safety, premium, security, disclaimers, and compliance.

---

## Contact for Legal Review

legal@dribex.ma
