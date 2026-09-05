# Dribex Production Readiness — Phase 28 Report

**Date:** 2026-08-22  
**Branch:** `cursor/production-readiness-ee43`  
**Base:** `cursor/security-audit-hardening-ee43` (includes video upload + security hardening)

---

## Current status

```text
Development  ████████████░░  Complete (feature-rich, tested locally)
Staging      ████████░░░░░░  Ready to deploy (templates + scripts added)
Production   ██████░░░░░░░░  NOT READY — ops + monetization gaps remain
```

### Final release status: **READY FOR STAGING**

Not **READY FOR PRODUCTION** until: NAPS live credentials, Cloudflare tunnel live, FCM push, credits/auctions (if required for launch), signed store builds validated, and rollback tested.

---

## Phase 1 — Audit summary

| Area | Stack | Status |
|------|-------|--------|
| Flutter | 3.47+ / Dart 3.13, SDK `>=3.35` | ✅ |
| Backend | FastAPI 0.135, Python 3.12, async Postgres | ✅ |
| Database | PostgreSQL 16, Alembic head `034` | ✅ |
| Storage | local / Azure / MinIO (selfhosted) | ✅ |
| Auth | JWT + refresh rotation, bcrypt, MFA, lockout | ✅ |
| Payments | NAPS (prod) + manual (dev) | ⚠️ Sandbox only |
| Video | 59s server + client, free tier 5 videos | ✅ This branch |
| QR | `/p/{token}` + share-link API | ✅ This branch |
| Maps | Android manifest key; iOS `GMSApiKey` via `Secrets.xcconfig` | ⚠️ Keys required at build |
| Push (FCM) | Not implemented | ❌ |
| Credits | Not implemented | ❌ |
| Auctions | Not implemented | ❌ |
| Boosts | Backend packages 10/25/49/99 DH | ✅ Migration 034 |
| Cloudflare | Config templates only | ⚠️ Ops |
| CI | Tests + security scans | ✅ No CD deploy |
| Monitoring | Mobile Sentry; backend Sentry + `/metrics` | ⚠️ Partial |

### Dev-only values found (expected in dev files)

- `localhost`, `127.0.0.1`, `10.0.2.2`, `192.168.x.x` in `app_config.dart`, compose, `.env.example` — **blocked in release** via HTTPS guard
- No production secrets committed to Git

---

## Completed in this pass

- [x] **Environment separation** — `env.development.example`, `env.staging.example`, `env.production.example`
- [x] **QR public URLs** — `ShareLink` model, `GET /p/{token}`, seller/product share-link endpoints
- [x] **Cloudflare tunnel** — `infra/cloudflare/README.md` + `config.yml.example`
- [x] **Free tier videos** — 5 active videos for free sellers; unlimited for Dribex Pro (server-enforced)
- [x] **Boost packages** — 10/25/49/99 DH migration (`034`)
- [x] **Dribex Pro pricing** — 99 MAD/month in seed data
- [x] **Backend Sentry** — `SENTRY_DSN` + `sentry-sdk` in `requirements-telemetry.txt`
- [x] **Prometheus metrics** — `GET /metrics` (restrict via firewall)
- [x] **iOS production prep** — Dribex display name, location permission, `margem://` URL scheme, `GMSApiKey` via `Secrets.xcconfig`
- [x] **Flutter** — Casablanca default coords, `QR_PUBLIC_BASE_URL`, free video UX (no client-only premium gate)
- [x] **Deploy scripts** — `scripts/production-deploy.sh`, `scripts/build-production-android.sh`

---

## Remaining blockers

### 1. NAPS production payment credentials

| | |
|---|---|
| **Impact** | No real subscription/boost revenue |
| **Component** | `env.production`, NAPS merchant portal |
| **Action** | Complete sandbox E2E → obtain production merchant ID → set `NAPS_*` env vars → verify webhooks on `https://api.dribex.ma/billing/webhooks/naps` |

### 2. Cloudflare Tunnel + DNS not live

| | |
|---|---|
| **Impact** | No public HTTPS API for mobile production builds |
| **Component** | `infra/cloudflare/`, DNS at registrar |
| **Action** | Create tunnel, point `api.dribex.ma`, `qr.dribex.ma`, `dribex.ma` per README |

### 3. Push notifications (FCM)

| | |
|---|---|
| **Impact** | No message/payment/auction push alerts |
| **Component** | `mobile/pubspec.yaml`, backend FCM sender |
| **Action** | Add `firebase_messaging`, `google-services.json`, backend token registration + send service |

### 4. Dribex Credits + Monthly Seller Auction

| | |
|---|---|
| **Impact** | Phase 14 monetization incomplete |
| **Component** | Not in codebase |
| **Action** | Design ledger (`credit_transactions` table), auction engine with server-side winner selection — separate epic |

### 5. Android release signing + Play Console

| | |
|---|---|
| **Impact** | Cannot ship to Play Store |
| **Component** | `android/key.properties` (gitignored) |
| **Action** | Generate keystore, run `scripts/build-production-android.sh`, internal testing track |

### 6. iOS App Store signing + Maps key

| | |
|---|---|
| **Impact** | No App Store build until Apple signing is configured; maps need a restricted API key in `Secrets.xcconfig` |
| **Component** | `ios/Flutter/Secrets.xcconfig.example`, Apple Developer account |
| **Action** | Copy `Secrets.xcconfig.example` → `Secrets.xcconfig`, set `GOOGLE_MAPS_API_KEY`, configure provisioning profile, archive in Xcode |

### 7. CI/CD production deploy pipeline

| | |
|---|---|
| **Impact** | Manual deploy only |
| **Component** | `.github/workflows/` |
| **Action** | Add staging deploy workflow with approval gate before production |

### 8. Database backup restore test

| | |
|---|---|
| **Impact** | Backups unverified |
| **Component** | `infra/onprem/scripts/backup.sh` |
| **Action** | Schedule cron + quarterly restore drill |

---

## Production URLs (target)

| Service | URL |
|---------|-----|
| App / marketing | `https://dribex.ma` |
| API | `https://api.dribex.ma` |
| QR / public shares | `https://qr.dribex.ma/p/{token}` |
| Media (MinIO proxy) | `https://media.dribex.ma` |
| Privacy (FR) | `https://api.dribex.ma/legal/fr/privacy` |
| Monitoring | Internal VPN / Grafana (not public) |
| Sentry | Project DSN in env (mobile + backend) |

---

## Deployment commands

### Staging

```bash
cp env.staging.example .env.staging
# Edit secrets
docker compose --env-file .env.staging -f infra/onprem/docker-compose.prod.yml up -d
curl -fsS https://api-staging.dribex.ma/ready
```

### Production

```bash
cp env.production.example .env.production
# Edit secrets — rotate all CHANGE_ME values
chmod +x scripts/production-deploy.sh
./scripts/production-deploy.sh
```

### Migrate only

```bash
docker compose --env-file .env.production -f infra/onprem/docker-compose.prod.yml \
  run --rm api alembic upgrade head
```

### Android release build

```bash
chmod +x scripts/build-production-android.sh
export API_BASE_URL=https://api.dribex.ma
export SENTRY_DSN=https://...
export GOOGLE_MAPS_API_KEY=AIza...
./scripts/build-production-android.sh
```

### Rollback

```bash
docker compose --env-file .env.production -f infra/onprem/docker-compose.prod.yml \
  pull api:previous-tag
docker compose --env-file .env.production -f infra/onprem/docker-compose.prod.yml \
  up -d api
# DB rollback only if migration is reversible:
docker compose run --rm api alembic downgrade -1
```

### Verify

```bash
curl -fsS https://api.dribex.ma/health
curl -fsS https://api.dribex.ma/ready
curl -fsS https://qr.dribex.ma/qr/health
```

---

## Phase 27 checklist (honest)

| Item | Status |
|------|--------|
| Production backend | ⚠️ Template ready, not deployed |
| Production database | ⚠️ Ops |
| Database backups | ⚠️ Script exists, not scheduled |
| Storage working | ✅ Code ready |
| HTTPS | ⚠️ Needs Cloudflare |
| Cloudflare | ⚠️ Template only |
| API domain | ⚠️ DNS pending |
| QR domain | ⚠️ DNS pending |
| No localhost in release app | ✅ Enforced |
| Authentication | ✅ |
| Authorization | ✅ Security audit |
| Google Maps Android | ⚠️ Key in local.properties |
| Google Maps iOS | ⚠️ `GMSApiKey` wired; needs `Secrets.xcconfig` |
| QR external network | ⚠️ After DNS |
| Product/Service/Video | ✅ |
| 59-second limit | ✅ |
| Payments | ⚠️ NAPS sandbox |
| Premium | ✅ |
| Boosts | ✅ Backend packages |
| Credits | ❌ |
| Auctions | ❌ |
| Notifications push | ❌ In-app only |
| Privacy/Terms | ✅ API `/legal/fr/*` |
| Monitoring | ⚠️ Partial |
| Android signed | ⚠️ Requires keystore |
| iOS signed | ❌ |
| Store listings | ❌ Ops |

---

## Security status (from prior audit)

```text
Critical: 0
High:     0
Medium:   2 (mitigated)
```

---

## Recommended release path

```text
Internal testing (home server + LAN)
      ↓
Staging (api-staging.dribex.ma) — deploy this branch
      ↓
Closed Play Test / TestFlight
      ↓
Limited production (Casablanca pilot)
      ↓
Monitor 2 weeks → full rollout
```
