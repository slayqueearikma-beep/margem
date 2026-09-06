# Dribex transactional email service

Centralized backend email infrastructure for authentication, security alerts, and marketplace notifications.

## Architecture

```text
Auth / signup services
        ↓
EmailService (typed methods)
        ↓
Email templates (HTML + plain text)
        ↓
Brevo REST API (production) / log fallback (development)
```

Core modules:

| Module | Purpose |
|---|---|
| `app/services/email.py` | Public `EmailService` API |
| `app/services/email_provider.py` | Brevo provider + dev log fallback |
| `app/services/email_templates.py` | Branded HTML/text templates |
| `app/services/email_urls.py` | Trusted HTTPS/deep-link URL builder |
| `app/services/email_redaction.py` | Safe logging helpers |

## Official provider: Brevo

Dribex uses the **Brevo Transactional Email API** (`POST /v3/smtp/email`) as the sole production mail provider.

Development and home LAN servers may set `ALLOW_INSECURE_EMAIL_FALLBACK=true` to log redacted previews instead of sending mail. This is not used in staging or production.

## Environment variables

```env
EMAIL_PROVIDER=brevo          # brevo | log
BREVO_API_KEY=                # never commit — store in secrets manager / .env.home
BREVO_SENDER_EMAIL=noreply@dribex.ma
BREVO_SENDER_NAME=Dribex
EMAIL_REPLY_TO=support@dribex.ma
EMAIL_SEND_TIMEOUT_SECONDS=20
EMAIL_MAX_RETRIES=2
EMAIL_RETRY_DELAY_SECONDS=0.75
ALLOW_INSECURE_EMAIL_FALLBACK=false
PUBLIC_APP_URL=https://dribex.ma
```

### Development / home LAN

```env
ALLOW_INSECURE_EMAIL_FALLBACK=true
EMAIL_PROVIDER=log
# Leave BREVO_API_KEY empty — OTP/reset tokens are logged server-side only
```

### Staging / production

Configure a Brevo API key with permission to send transactional email. Verify `BREVO_SENDER_EMAIL` in the Brevo dashboard before sending live traffic.

Never commit `BREVO_API_KEY` to Git.

## Supported email flows (all via Brevo in production)

| Flow | EmailService method |
|---|---|
| Signup OTP | `send_otp_email` / `send_signup_otp` |
| Password reset | `send_password_reset_email` / `send_password_reset` |
| Email verification | `send_verification_email` / `send_email_verification` |
| Welcome email | `send_welcome_email` |
| Security alerts (password changed, MFA, lockout) | `send_security_alert` |
| Generic transactional | `send_transactional_email` / `send_notification` |

Authentication tokens and OTP codes are generated and validated by the Dribex backend only. Brevo is delivery-only.

## DNS requirements (production)

Configure SPF, DKIM, and DMARC for `dribex.ma` using the exact records published in the Brevo sender/domain settings.

## Security controls

- `BREVO_API_KEY` is never logged, returned in API responses, or committed to source control
- Reset/verify tokens and OTP codes are redacted from logs
- Email links are built only from configured `PUBLIC_APP_URL` (HTTPS enforced in staging/production)
- Password-reset responses remain enumeration-safe regardless of delivery success

## Testing locally

```bash
cd souq-local/backend
pytest tests/test_email_service.py tests/test_password_reset_security.py tests/test_signup_otp.py -q
```

With `ALLOW_INSECURE_EMAIL_FALLBACK=true`, trigger `/auth/forgot-password` or signup OTP and inspect logs for `email_delivery` / `email_dev_fallback` entries.

## Rotating credentials

1. Generate a new Brevo API key in the Brevo dashboard
2. Update `.env.home` / production secrets store
3. Restart the API container
4. Send a test password-reset email
5. Revoke the old API key in Brevo

## Docker / deployment

`docker-compose.home.yml`, `infra/onprem/docker-compose.prod.yml`, Azure Terraform, and Bicep templates pass `BREVO_*` variables to the API container. Keep secrets in private env files only.
