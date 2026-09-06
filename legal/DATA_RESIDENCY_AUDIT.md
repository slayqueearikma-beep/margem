# Dribex Data Residency Audit

Evidence-based inventory of where personal data can exist or become accessible.
Self-hosting reduces **unnecessary** international transfers; it does not automatically eliminate
Law 09-08 / CNDP obligations (including F118 where applicable).

## Processing locations (summary)

| Provider / component | Country (typical) | Personal data | Purpose | Storage location | Int'l transfer risk | CNDP relevance | Status |
|---------------------|-------------------|---------------|---------|------------------|----------------------|----------------|--------|
| PostgreSQL (on-prem) | Morocco | Accounts, orders, messages, profile metadata | Core app data | Moroccan server | Low when hosted in MA | Law 09-08 registration / declarations | **Target: MA** |
| MinIO (on-prem) | Morocco | Profile photos, product/listing images | Object storage | Moroccan server disk | Low when hosted in MA | Same as above | **Default active** |
| Dribex API image processing (Pillow) | Morocco | Uploaded images (transient) | Sanitize/strip EXIF | API memory | Low | Processing in MA | **Active** |
| Azure Blob Storage | Foreign (Microsoft) | Legacy media blobs | Object storage | Azure region | **High if used** | F118 assessment if personal data transferred | **Inactive by default** |
| Redis (on-prem) | Morocco | Sessions, rate limits (minimal PII) | Cache | Moroccan server | Low | Secondary | On-prem stack |
| SMTP (configurable) | Depends on provider | Email addresses, reset tokens | Transactional email | Provider-dependent | **Assess per provider** | F118 if foreign | Config required in prod |
| Stripe | Foreign | Billing metadata, email | Payments | Stripe | **Likely transfer** | F118 / contract | Optional |
| Firebase Auth (if enabled) | Foreign | Auth identifiers | Authentication | Google | **Assess if enabled** | F118 if enabled | Optional |
| Prometheus/Grafana/Loki (on-prem) | Morocco | Logs (must avoid secrets/images) | Observability | Moroccan server | Low if no PII in logs | Minimize PII in logs | On-prem stack |

## Architectural rules

1. **No new third-party processor** without documenting provider, country, data received, purpose, retention, access, and transfer implications (`legal/config/processing_registry.yaml`).
2. **No foreign CDN** for profile/marketplace images by default — serve via Moroccan API + MinIO.
3. **No foreign backup** of personal media by default without international-transfer assessment.
4. **No foreign image processing APIs** for profile photos — local Pillow pipeline only.
5. **No biometric processing** of profile photographs.

## F118 / transfer decision gate

For each processing activity, ask:

> Does personal data leave Morocco or become accessible to a foreign recipient?

- **Yes** → verify current Law 09-08 / CNDP requirements; treat F118 as a legal requirement where applicable.
- **No** → document why this operation does not involve an international transfer (evidence-based, not assumed).

Self-hosting is an architectural measure to **minimize** transfer exposure, not to evade CNDP obligations.

## Data flow gate (new processors)

Before introducing any new production processor, record:

- Provider name and country
- Categories of personal data
- Purpose and retention
- Access controls
- International-transfer implications
- Applicable CNDP procedures

See also: `legal/SELF_HOSTED_STORAGE_MIGRATION.md`
