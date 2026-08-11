# MarGem Security Policy

**Effective Date:** August 1, 2026  
**Last Updated:** August 5, 2026

---

## Table of Contents

1. [Security Commitment](#1-security-commitment)
2. [Authentication](#2-authentication)
3. [Encryption](#3-encryption)
4. [Password Handling](#4-password-handling)
5. [Data Storage](#5-data-storage)
6. [Access Controls](#6-access-controls)
7. [Application Security](#7-application-security)
8. [Infrastructure Security](#8-infrastructure-security)
9. [Monitoring and Logging](#9-monitoring-and-logging)
10. [Incident Response](#10-incident-response)
11. [Security Reporting](#11-security-reporting)
12. [Compliance Alignment](#12-compliance-alignment)
13. [Contact](#13-contact)

---

## 1. Security Commitment

MarGem implements security measures aligned with **ISO/IEC 27001**, **SOC 2**, and **OWASP** best practices to protect user data and Platform integrity.

---

## 2. Authentication

| Control | Implementation |
|---------|---------------|
| Password authentication | bcrypt hashing with appropriate work factor |
| JWT tokens | Short-lived access tokens + refresh token rotation |
| Session management | Device name, IP, user agent metadata on refresh tokens |
| Email verification | Required for abuse-prone features |
| Staff authentication | Role-based access (super_admin, admin, moderator, support) |
| Optional Firebase auth | ID token verification when configured |

---

## 3. Encryption

| Layer | Method |
|-------|--------|
| Data in transit | TLS 1.2+ (HTTPS) for all API and Web traffic |
| Data at rest | Azure-managed encryption for database and blob storage |
| Local device storage | Encrypted secure storage for authentication tokens (flutter_secure_storage) |
| Secrets management | Azure Key Vault for production credentials |

---

## 4. Password Handling

- Passwords are hashed using **bcrypt** before storage
- Plaintext passwords are never stored or logged
- Password reset tokens expire after **1 hour**
- Account deletion clears password hash
- Minimum password requirements enforced at registration

---

## 5. Data Storage

| Data | Location | Protection |
|------|----------|------------|
| User accounts | PostgreSQL (Azure) | Encrypted at rest, access-controlled |
| Media files | Azure Blob Storage | Access-controlled, CDN optional |
| Auth tokens (mobile) | Device secure storage | Encrypted |
| Guest preferences | Device SharedPreferences | Non-sensitive data only |
| Crash reports | Sentry | PII collection disabled by default |

---

## 6. Access Controls

- **Principle of least privilege** for all staff accounts
- **Role-based access control (RBAC)** for admin functions
- **Audit logging** for all administrative actions (IP, user agent, action metadata)
- **Production access** restricted to authorized personnel
- **API authentication** required for all protected endpoints

---

## 7. Application Security

Aligned with OWASP Top 10:

| Risk | Mitigation |
|------|------------|
| Injection | Parameterized queries (SQLAlchemy ORM), input validation |
| Broken authentication | JWT rotation, bcrypt, rate limiting |
| Sensitive data exposure | Encryption, PII stripping from API responses |
| XSS | Flutter (no DOM); Web sanitization |
| Broken access control | RBAC, endpoint-level authorization |
| Security misconfiguration | Environment-based config, secrets in Key Vault |
| Rate limiting | Per-endpoint and per-IP rate limits; optional Redis backend |

---

## 8. Infrastructure Security

- Azure Container Apps with network isolation
- PostgreSQL with firewall rules and SSL connections
- Regular dependency updates and vulnerability scanning
- CI/CD pipeline security checks
- Infrastructure as Code (Terraform/Bicep) for reproducible deployments

---

## 9. Monitoring and Logging

| System | Purpose |
|--------|---------|
| Request logging | Request ID, method, path, status, duration |
| Admin audit logs | Staff actions with metadata |
| Login audit logs | Staff login success/failure |
| Sentry | Crash and error monitoring |
| Application Insights | Optional APM and telemetry |

Logs do not contain passwords, full payment details, or unnecessary PII.

---

## 10. Incident Response

### 10.1 Incident Classification

| Severity | Examples |
|----------|----------|
| Critical | Data breach, active exploitation, service compromise |
| High | Vulnerability with known exploit, authentication bypass |
| Medium | Vulnerability without known exploit, suspicious activity |
| Low | Policy violation, minor misconfiguration |

### 10.2 Response Process

1. **Detection** — Monitoring, reports, or vulnerability disclosure
2. **Triage** — Classify severity and assign incident lead
3. **Containment** — Limit impact (revoke tokens, block IPs, disable features)
4. **Investigation** — Root cause analysis
5. **Remediation** — Fix vulnerability, patch systems
6. **Notification** — Notify affected users and regulators as required by law
7. **Post-incident review** — Document lessons learned

### 10.3 Breach Notification

In the event of a personal data breach, MarGem will notify affected users and relevant authorities (including Morocco's CNDP under Law 09-08) within the timeframes required by applicable law.

---

## 11. Security Reporting

Report security vulnerabilities to **security@margem.ma**. See our [Responsible Disclosure Policy](responsible-disclosure.md).

**Do not** report security issues through public channels, social media, or support tickets.

---

## 12. Compliance Alignment

| Framework | Alignment |
|-----------|-----------|
| ISO/IEC 27001 | Information security management principles |
| SOC 2 | Security, availability, confidentiality trust criteria |
| OWASP | Application security best practices |
| GDPR | Data protection by design and default |
| Morocco Law 09-08 | Personal data protection requirements |

---

## 13. Contact

security@margem.ma
