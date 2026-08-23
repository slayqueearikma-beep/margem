# MarGem Data Retention Policy

**Effective Date:** August 1, 2026  
**Last Updated:** August 5, 2026

---

## 1. Purpose

This policy defines how long MarGem retains personal information and the criteria for retention and deletion.

---

## 2. Retention Principles

We retain personal information only as long as necessary for:

- Providing Platform services
- Legal and regulatory compliance
- Security and fraud prevention
- Dispute resolution and enforcement
- Legitimate business interests

---

## 3. Retention Periods

| Data Category | Retention Period | Notes |
|---------------|------------------|-------|
| **Active account data** | Duration of account + 30 days after deletion request | Anonymized on deletion |
| **Deleted account data** | Anonymized immediately; backups purged within 90 days | Email replaced with anonymized identifier |
| **Seller listings** | Deleted with account or upon seller removal | Media files deleted from storage |
| **Reviews** | Deleted with reviewer account; may retain anonymized aggregate scores | |
| **Messages** | Deleted with account deletion | |
| **Session/refresh tokens** | Until revoked or expired | Max 90 days for refresh tokens |
| **Contact event analytics** | 24 months | Aggregated after 12 months |
| **Crash reports (Sentry)** | Per Sentry retention settings (default 90 days) | PII disabled by default |
| **Admin audit logs** | 3 years | Required for security and compliance |
| **Login audit logs** | 2 years | Staff login success/failure records |
| **Reports (moderation)** | 2 years after resolution | |
| **Email verification tokens** | 24 hours after use or 7 days if unused | |
| **Password reset tokens** | 1 hour after issuance | |
| **Subscription records** | 7 years | Tax and billing compliance |
| **Support correspondence** | 3 years after resolution | |
| **Legal hold data** | Until hold is released | Overrides standard retention |

---

## 4. Backup Retention

Database and media backups are retained for up to **90 days** for disaster recovery. Deleted data may persist in backups until backup rotation completes.

---

## 5. Anonymization

When accounts are deleted, personal identifiers are anonymized:

- Email replaced with `deleted_[uuid]@deleted.margem.app`
- Display name set to "Deleted User"
- Password hash cleared
- Account status set to `deleted`

Anonymized data may be retained for aggregate analytics.

---

## 6. Legal Holds

We may retain data beyond standard periods when required by law, litigation, or regulatory investigation.

---

## 7. Contact

privacy@margem.app
