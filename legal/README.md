# Dribex Legal & Compliance Package

**Platform:** Dribex — local discovery and marketplace platform for Morocco  
**Package version:** 2.0.0  
**Effective date:** 2026-08-13

This folder is the **single source of truth** for legal content served in the app and on the web API.

---

## Architecture

```
legal/
├── config/entity.yaml          # Configurable entity, contacts, dates (edit here first)
├── manifest.yaml               # Document registry, versions, consent flags, change history
├── content/{slug}/{lang}.md    # Modular markdown source (en, fr, ar)
├── versions/                   # Archived prior publication cycles (never overwrite)
├── reference/                  # Supplementary policies (not served in-app today)
│   ├── terms/ privacy/ marketplace/ trust-safety/ premium/ security/ disclaimers/
└── README.md

souq-local/backend/scripts/generate_legal_html.py  →  static/legal/{lang}/{slug}.html + manifest.json
souq-local/mobile/lib/features/legal/legal_documents.dart  →  stable document ids
```

**Workflow:** Edit markdown or `entity.yaml` → run generator → commit HTML + manifest.json → deploy backend.

```bash
pip install pyyaml
python souq-local/backend/scripts/generate_legal_html.py
```

---

## Served documents (in-app)

| Stable ID | Slug | Purpose |
|-----------|------|---------|
| `privacy_policy` | `privacy` | Privacy Policy |
| `terms_of_service` | `terms` | Terms of Service (buyer rules, IP, liability, termination) |
| `cookie_policy` | `cookies` | Cookie & local storage policy |
| `seller_terms` | `seller-terms` | Seller / marketplace obligations |
| `community_guidelines` | `community-guidelines` | Community conduct |
| `account_deletion` | `account-deletion` | Deletion & data rights |
| `subscription_terms` | `subscription-terms` | Premium billing, refunds, cancellations |
| `legal_notice` | `legal-notice` | Publisher, contacts, amendments |
| `open_source_licenses` | `open-source-licenses` | Mobile OSS notices |

API: `GET /legal/{lang}/{slug}` · `GET /legal/manifest`

---

## Reference policies (not served in-app)

Detailed policies under `terms/`, `privacy/`, `marketplace/`, `trust-safety/`, `premium/`, `security/`, and `disclaimers/` are maintained for counsel review and future publication. Merge into served documents when a feature launches or counsel directs — do not duplicate blindly.

---

## Updating legal content

1. **Configurable facts** — edit `config/entity.yaml` (entity name, address, emails, dates).
2. **Document text** — edit `content/{slug}/{lang}.md`.
3. **Registry** — update `manifest.yaml` (version, effective date, change summary, status).
4. **Archive** — copy prior version metadata under `versions/{version}/`; never delete historical records.
5. **Regenerate** — run `generate_legal_html.py`.
6. **Assess notice/consent** — use manifest `consent_required` and `notify_on_change` flags; obtain counsel guidance for material changes.

Updating files alone does **not** automatically make changes legally binding. Follow applicable notice and consent requirements.

---

## Placeholders requiring business/legal confirmation

- Registered legal entity name and address (`entity.yaml`)
- Registration numbers (RC, ICE, etc.)
- CNDP declaration/authorization status
- DPO appointment (if required)
- Certification claims (ISO, SOC, etc.) — do not publish unless confirmed

See `compliance/lawyer-review-notes.md` and `LEGAL_COMPLIANCE_AUDIT.md` in the repository.

---

## Important notice

These documents are a comprehensive starting point tailored to Dribex's product. **They do not constitute legal advice** and do not guarantee regulatory compliance without review by licensed counsel.
