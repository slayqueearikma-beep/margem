# Dribex transactional email service

Centralized backend email infrastructure for authentication, security alerts, and future marketplace notifications.

## Architecture

```text
Auth / signup services
        ↓
EmailService (typed methods)
        ↓
Email templates (HTML + plain text)
        ↓
Email provider (SMTP / Resend API / log fallback)
```

Core modules:

| Module | Purpose |
|---|---|
| `app/services/email.py` | Public `EmailService` API |
| `app/services/email_provider.py` | Provider abstraction + retries |
| `app/services/email_templates.py` | Branded HTML/text templates |
| `app/services/email_urls.py` | Trusted HTTPS/deep-link URL builder |
| `app/services/email_redaction.py` | Safe logging helpers |

## Supported email types

### Authentication
- Password reset
- Email verification
- Signup OTP
- Welcome email

### Security alerts
- Password changed
- MFA enabled / disabled
- Account temporarily locked (failed login abuse)
- Email changed (method ready; wired when email change ships)
- Suspicious login (method ready for future IP/device heuristics)

### Future marketplace notifications
Use `EmailService.send_notification()` — do not add new SMTP code in feature modules.

## Environment variables

Preferred names (legacy `SMTP_*` aliases still supported):

```env
EMAIL_PROVIDER=smtp          # smtp | resend | log
EMAIL_HOST=smtp.example.com
EMAIL_PORT=587
EMAIL_USERNAME=
EMAIL_PASSWORD=
EMAIL_FROM_ADDRESS=noreply@dribex.ma
EMAIL_FROM_NAME=Dribex
EMAIL_REPLY_TO=support@dribex.ma
EMAIL_SEND_TIMEOUT_SECONDS=20
EMAIL_MAX_RETRIES=2
EMAIL_RETRY_DELAY_SECONDS=0.75

PUBLIC_APP_URL=https://dribex.ma
ALLOW_INSECURE_EMAIL_FALLBACK=false
```

### Development / home LAN

Set `ALLOW_INSECURE_EMAIL_FALLBACK=true` and leave `EMAIL_HOST` empty to log redacted previews instead of sending mail.

### Staging / production

Configure a transactional provider. Never commit credentials to Git.

## Provider options

### SMTP (default)

Works with any SMTP-compatible transactional provider (Brevo, Mailgun SMTP, Amazon SES SMTP, etc.).

```env
EMAIL_PROVIDER=smtp
EMAIL_HOST=smtp-relay.brevo.com
EMAIL_PORT=587
EMAIL_USERNAME=your-smtp-login
EMAIL_PASSWORD=your-smtp-password
EMAIL_FROM_ADDRESS=noreply@dribex.ma
EMAIL_FROM_NAME=Dribex
```

### Resend (HTTP API)

```env
EMAIL_PROVIDER=resend
EMAIL_PASSWORD=re_xxxxxxxxxxxx   # Resend API key
EMAIL_FROM_ADDRESS=noreply@dribex.ma
EMAIL_FROM_NAME=Dribex
```

Follow Resend dashboard instructions to verify the sending domain before production traffic.

## DNS requirements (production)

Obtain exact DNS records from your chosen provider. Typical setup for `dribex.ma`:

### SPF

Add/update a TXT record on the root domain or mail subdomain, for example:

```text
v=spf1 include:<provider-spf-include> ~all
```

Use the exact `include:` target from your provider (Resend, Brevo, Mailgun, etc.).

### DKIM

Add the CNAME/TXT records published by your provider for selector-based DKIM signing.

### DMARC

After SPF and DKIM validate, add:

```text
_dmarc.dribex.ma TXT "v=DMARC1; p=none; rua=mailto:dmarc@dribex.ma"
```

Move to `p=quarantine` or `p=reject` only after monitoring DMARC reports.

Do not invent record values — copy them from the provider console.

## Security controls

- Reset/verify tokens and OTP codes are redacted from logs
- Email links are built only from configured `PUBLIC_APP_URL` (HTTPS enforced in staging/production)
- Password-reset responses remain enumeration-safe regardless of delivery success
- Rate limits remain on forgot-password, verify-email, and signup OTP endpoints
- Security alerts never include passwords, tokens, or MFA codes
- Credentials/API keys are backend-only (never exposed to Flutter)

## Testing locally

1. Start the API with `ALLOW_INSECURE_EMAIL_FALLBACK=true`
2. Trigger `/auth/forgot-password`, `/auth/signup/otp/send`, or registration
3. Inspect API logs for `email_delivery` / `email_dev_fallback` entries
4. Confirm tokens/codes appear as `[REDACTED]`

Run automated tests:

```bash
cd souq-local/backend
pytest tests/test_email_service.py tests/test_password_reset_security.py tests/test_signup_otp.py -q
```

## Rotating credentials

1. Generate a new SMTP password or Resend API key in the provider console
2. Update `.env.home` / production secrets store
3. Restart the API container
4. Send a test password-reset email
5. Revoke the old credential in the provider console

## Docker / home deployment

`docker-compose.home.yml` passes both legacy `SMTP_*` and new `EMAIL_*` variables. Keep secrets in `.env.home` (never commit).
