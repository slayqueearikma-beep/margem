# Dribex Third-Party Services Disclosure

**Effective Date:** August 1, 2026  
**Last Updated:** August 5, 2026

---

## 1. Overview

Dribex uses third-party services to operate the Platform. This document discloses those services and their role in processing your data.

---

## 2. Infrastructure and Hosting

| Service | Provider | Purpose | Data Processed |
|---------|----------|---------|----------------|
| Cloud hosting | Microsoft Azure | Application hosting, container orchestration | Application data, logs |
| Database | PostgreSQL (Azure) | Primary data storage | Account, listing, message data |
| Media storage | Azure Blob Storage or local filesystem (`storage_backend=local`) | Image and video hosting | Uploaded media files |
| Key management | Azure Key Vault | Secrets and credentials | Configuration secrets |
| Optional cache | Redis | Rate limiting, session store | IP addresses, request metadata |

---

## 3. Authentication and Identity

| Service | Provider | Purpose | Data Processed |
|---------|----------|---------|----------------|
| Firebase Admin | Google (optional) | Identity token verification | Firebase UID |
| Email/password auth | Dribex (self-hosted) | Primary authentication | Email, password hash |

---

## 4. Communication

| Service | Provider | Purpose | Data Processed |
|---------|----------|---------|----------------|
| SMTP email | Configurable (e.g., SendGrid, Azure Communication) | Verification, password reset, announcements | Email address, message content |
| WhatsApp | Meta | External contact (user-initiated) | Phone number (not processed by Dribex) |
| Phone/SMS | Device native | External contact (user-initiated) | Phone number (not processed by Dribex) |

---

## 5. Maps and Location

| Service | Provider | Purpose | Data Processed |
|---------|----------|---------|----------------|
| Google Maps Platform | Google (opt-in) | Map display, location pins | Coordinates, map tiles requests |

Maps are disabled unless `ENABLE_MAPS=true` and a valid API key is configured.

---

## 6. Monitoring and Diagnostics

| Service | Provider | Purpose | Data Processed |
|---------|----------|---------|----------------|
| Sentry | Functional Software, Inc. | Crash and error reporting | Device type, app version, stack traces (PII disabled) |
| Application Insights | Microsoft Azure (optional) | APM and telemetry | Request metadata, performance data |

---

## 7. External Contact Tools

When you use call, WhatsApp, email, SMS, or website buttons on Dribex, you are directed to third-party services or your device's native apps. Dribex logs contact events (type and timestamp) for analytics but does not process the content of external communications.

---

## 8. Payment Processing (Future)

When subscription billing is enabled, payments will be processed by a third-party payment provider (to be disclosed at launch). Dribex will not store full payment card numbers.

---

## 9. Data Processing Agreements

Dribex requires third-party service providers to process data only on our instructions and implement appropriate security measures. Data Processing Agreements (DPAs) are maintained where required by GDPR and other applicable law.

---

## 10. Your Choices

- **Sentry:** Crash reporting is enabled only when `SENTRY_DSN` is configured
- **Google Maps:** Requires explicit opt-in via environment configuration
- **Firebase:** Optional; email/password auth is the primary method
- **External contacts:** Always user-initiated

---

## 11. Contact

privacy@dribex.app
