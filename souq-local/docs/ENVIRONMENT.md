# MarGem Environment Variables

## Backend (`souq-local/backend/.env`)

| Variable | Dev | Production | Description |
|----------|-----|------------|-------------|
| `DATABASE_URL` | Required | Required | PostgreSQL async connection string |
| `JWT_SECRET_KEY` | Required | Required (≥32 chars, non-default) | Access/refresh token signing |
| `UPLOAD_TOKEN_SECRET` | Optional | Required if `STORAGE_BACKEND=local` | Media upload token signing |
| `APP_ENV` | `development` | `production` | Environment gate for validation |
| `DEBUG` | `false` | `false` | Must be false in production |
| `AUTH_DEV_BYPASS` | `false` | `false` | Dev-only auth bypass |
| `CORS_ORIGINS` | `http://localhost:3000` | HTTPS origins only | Comma-separated |
| `ALLOWED_HOSTS` | `*` | Explicit hostnames | TrustedHost middleware |
| `REDIS_URL` | Optional | Recommended multi-replica | Distributed rate limiting |
| `SMTP_HOST` | Optional | Required (or break-glass flag) | Transactional email |
| `AZURE_STORAGE_CONNECTION_STRING` | Optional | Required if azure backend | Blob storage |
| `STORAGE_BACKEND` | `azure` / `local` | `azure` typical | Media storage driver |
| `PUBLIC_APP_URL` | `https://margem.ma` | HTTPS | Email deep links |
| `PUBLIC_API_URL` | `http://localhost:8000` | HTTPS | API base for media URLs |
| `SENTRY_DSN` | Optional | Recommended | Error tracking |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Optional | Recommended | Azure APM |
| `FIREBASE_CREDENTIALS_PATH` | Optional | Optional | Firebase ID token auth |

## Mobile (`--dart-define`)

| Variable | Default | Description |
|----------|---------|-------------|
| `API_BASE_URL` | `http://10.0.2.2:8000` | Backend API (HTTPS in production) |
| `PRODUCTION` | `false` | Enforces HTTPS API URL |
| `SENTRY_DSN` | empty | Crash reporting (required for release) |
| `GOOGLE_MAPS_API_KEY` | empty | Maps when `ENABLE_MAPS=true` |
| `ENABLE_MAPS` | `false` | Opt-in map feature |
| `PRIVACY_POLICY_URL` | `https://margem.app/privacy` | In-app legal link |
| `TERMS_OF_SERVICE_URL` | `https://margem.app/terms` | Registration consent |
| `LEGAL_INDEX_URL` | `https://margem.app/legal` | Legal index |

## Example commands

```bash
# Local backend
cd souq-local/backend && uvicorn app.main:app --reload

# Android emulator
cd souq-local/mobile && flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000

# Production release build
flutter build appbundle \
  --dart-define=PRODUCTION=true \
  --dart-define=API_BASE_URL=https://api.margem.ma \
  --dart-define=SENTRY_DSN=https://...@sentry.io/...
```

## Staff bootstrap

```bash
cd souq-local/backend
PYTHONPATH=. python scripts/promote_admin.py --email admin@example.com --role super_admin
```
