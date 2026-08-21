# Dribex Fraud Prevention Policy

**Effective Date:** August 1, 2026  
**Last Updated:** August 5, 2026

---

## 1. Purpose

Dribex implements measures to detect, prevent, and respond to fraud on the Platform.

---

## 2. Types of Fraud Addressed

| Type | Description |
|------|-------------|
| **Fake listings** | Non-existent businesses or products designed to deceive |
| **Account fraud** | Duplicate accounts, stolen credentials, bot accounts |
| **Review fraud** | Fake positive or negative reviews |
| **Payment fraud** | Scams requesting advance payment with no delivery (off-platform) |
| **Impersonation** | Pretending to be a known brand or individual |
| **Verification fraud** | Submitting false information for business verification |
| **Subscription fraud** | Unauthorized payment method use for premium subscriptions |

---

## 3. Prevention Measures

### 3.1 Technical Controls
- Email verification for abuse-prone features
- Rate limiting on API endpoints and authentication
- Encrypted credential storage (bcrypt password hashing)
- Session management with device and IP metadata
- Optional Redis-backed rate limiting for multi-replica deployments

### 3.2 Operational Controls
- Manual business verification review
- User reporting system
- Admin audit logging for staff actions
- Account status management (active, suspended, deleted)

### 3.3 User Education
- Community Guidelines and safety tips
- Clear disclaimers that Dribex does not process buyer-seller payments
- Verification badge explanations

---

## 4. Detection and Response

When fraud is suspected or reported:

1. Account and content are flagged for review
2. Trust & safety staff investigate
3. Enforcement action is taken per [Trust & Safety Policy](trust-safety-policy.md)
4. Affected users are notified where appropriate
5. Law enforcement is contacted for criminal activity

---

## 5. User Responsibilities

Users should:

- Verify seller identity and business legitimacy before transacting
- Avoid sending advance payments to unverified sellers
- Meet in safe, public locations for in-person transactions
- Report suspicious activity immediately
- Never share account credentials or verification codes

---

## 6. Contact

- **Fraud reports:** safety@dribex.ma
- **Security:** security@dribex.ma
