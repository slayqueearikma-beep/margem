# MarGem Account Deletion Policy

**Effective Date:** August 1, 2026  
**Last Updated:** August 1, 2026

---

## 1. Your Right to Delete

You may delete your MarGem account at any time. Account deletion is permanent and cannot be undone.

---

## 2. How to Delete Your Account

### 2.1 In-App (Recommended)

1. Open MarGem → Settings
2. Select **Delete Account**
3. Enter your password
4. Confirm by typing "DELETE"
5. Your account will be immediately deactivated

### 2.2 Email Request

Email **privacy@margem.app** from your registered email address with the subject "Account Deletion Request."

### 2.3 API

Authenticated users may call `DELETE /auth/me` with:
- Current password
- Confirmation string: `"DELETE"`

---

## 3. What Happens When You Delete

| Action | Detail |
|--------|--------|
| Account status | Set to `deleted` |
| Email | Anonymized to `deleted_[uuid]@deleted.margem.app` |
| Password | Cleared |
| Display name | Set to "Deleted User" |
| Storefront & listings | Removed |
| Products & services | Deleted |
| Reviews you wrote | Deleted |
| Reviews about your business | Deleted (if seller) |
| Messages | Deleted |
| Favorites & follows | Deleted |
| Subscriptions | Cancelled |
| Refresh tokens | Revoked |
| Guest favorites (if migrated) | Already on device; clear app data separately |

---

## 4. What Is Retained

- Anonymized analytics aggregates
- Admin audit logs (referencing anonymized account ID)
- Subscription billing records (7 years, tax compliance)
- Backup copies (up to 90 days)
- Data under legal hold

---

## 5. Before You Delete

Consider:

- **Downloading your data:** Request a data export at privacy@margem.app before deletion
- **Active subscriptions:** Cancellation takes effect immediately; no refund for remaining period unless eligible under [Refund Policy](../premium/refund-policy.md)
- **Seller obligations:** Complete pending buyer communications before deletion
- **Irreversibility:** You cannot recover your account, reviews, or listings after deletion

---

## 6. Deletion by MarGem

MarGem may delete accounts that violate our policies. In such cases, the same data removal process applies, but refunds may not be available.

---

## 7. Guest Users

Guest users have no account to delete. Clear app data on your device to remove local guest favorites and preferences.

---

## 8. Contact

privacy@margem.app
