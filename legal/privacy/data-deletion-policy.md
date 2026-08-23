# MarGem Data Deletion Policy

**Effective Date:** August 1, 2026  
**Last Updated:** August 5, 2026

---

## 1. Purpose

This policy explains how MarGem handles requests to delete personal data, separate from full account deletion.

---

## 2. Types of Deletion Requests

| Request Type | Description |
|--------------|-------------|
| **Account deletion** | Complete removal of your MarGem account and associated data |
| **Partial data deletion** | Removal of specific data while retaining your account |
| **Data subject request (GDPR/Law 09-08)** | Formal request under privacy law |

---

## 3. Account Deletion

For full account deletion, see [Account Deletion Policy](account-deletion-policy.md). Account deletion is the primary method for removing your personal data from MarGem.

**Methods:**
- In-app: Settings → Delete Account (requires password confirmation)
- API: `DELETE /auth/me` with password and confirmation
- Email: privacy@margem.app

---

## 4. Partial Data Deletion

You may request deletion of specific data without deleting your account:

| Data | How to Delete |
|------|---------------|
| Profile information | Update in account settings |
| Listings | Delete via seller dashboard |
| Reviews you wrote | Contact privacy@margem.app |
| Messages | Delete conversations in-app (where supported) or contact privacy@margem.app |
| Saved searches / favorites | Remove in-app |

---

## 5. Data We May Retain After Deletion

Even after deletion, we may retain:

- Anonymized or aggregated data that cannot identify you
- Data required by law (tax records, billing history)
- Admin audit logs referencing your former account ID
- Backup copies until backup rotation (up to 90 days)
- Data subject to legal hold

---

## 6. Processing Timeline

| Request Type | Timeline |
|--------------|----------|
| In-app account deletion | Immediate (soft-delete); backups within 90 days |
| Email deletion request | 30 days (GDPR/Law 09-08 compliance) |
| Partial data deletion | 14 business days |

---

## 7. Verification

We may verify your identity before processing deletion requests to prevent unauthorized data removal.

---

## 8. Contact

privacy@margem.app
