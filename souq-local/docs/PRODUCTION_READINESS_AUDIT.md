# MarGem Production Readiness Audit

**Date:** 2026-07-22  
**Branch:** `cursor/production-grade-audit-f384`  
**Scope:** Entire `souq-local/` discovery platform (FastAPI + Flutter + Postgres + Azure Blob + Compose/Terraform)

This report is based on reading the implemented codebase (routers, models, migrations, mobile screens, Docker, CI, infra). Findings cite concrete files. Automatic fixes from this audit are included on this branch.

---

## 1. Executive summary

MarGem is a **local discovery / connection platform** (not e-commerce). The repository already implements sellers, listings, search, favorites, follows, messaging, contact events, reviews, uploads, premium *visibility* memberships, and admin user ops.

**Deployment Readiness: 72%**

The app is suitable for a **controlled beta / home-server or budget-VM soft launch** after completing the remaining manual checklist (rotated secrets, SMTP, TLS reverse proxy, billing provider or admin-only premium, Play signing, monitoring). It is **not** yet ready for unattended public production at internet scale: CD/deploy automation, crash reporting, DB backup automation, and paid premium billing are still manual or missing.

This audit closed several production blockers automatically (free premium self-grant in prod, default JWT rejection, health→503, ProxyHeaders trust, invalid-token→503, email token logging, SAS TTL, media URL validation, report/recently-viewed FK 404s, favorite uniqueness indexes, Docker non-root, session-expiry binding, contact→conversation wiring).

---

## 2. Deployment readiness percentage

### Deployment Readiness: **72%**

| Category | Score | Evidence |
|---|---:|---|
| Architecture | 78 | FastAPI modular routers (`auth`, `catalog`, `sellers`, `discovery`, `seller_ops`, `uploads`); Flutter feature folders; discovery pivot migration `007` |
| Backend | 82 | Async SQLAlchemy, Alembic through `008`, rate limits, JWT refresh rotation, security headers; prod subscribe gated |
| Frontend (web) | N/A | No separate web app — Flutter is the client |
| Mobile | 75 | Buyer/seller flows, messaging, favorites; production HTTPS assert; session bind at app root |
| Database | 80 | Postgres + Alembic; indexes/uniques in `008`; FK validation on reports/views |
| Security | 78 | Prod settings validators; non-root Docker; shortened SAS; URL validation; ProxyHeaders scoped |
| Performance | 70 | Seller/product pagination; conversation/message limits; remaining N+1 in inbox |
| UX/UI | 72 | Home/Messages redesign present; leftover ecommerce-named l10n keys; seller inquiries routed to messages |
| Code quality | 76 | Clear layering; some dead `SellerOrdersScreen` retained as redirect; ecommerce wording leftovers |
| Testing | 62 | **29** backend tests passing; mobile unit/smoke only; no E2E |
| Documentation | 74 | README + `MARKETPLACE_PRODUCTION.md` + this audit |
| Deployment | 70 | Compose (dev/home/budget), Dockerfile, CI image build; no MarGem CD to Azure |
| Monitoring | 45 | Structured access logs + `/live` `/ready` `/health`; no APM/Sentry/alerts |
| Scalability | 58 | Single-VM budget compose; no Redis/queue/horizontal API story |
| Reliability | 68 | Healthchecks fail on DB down; mobile upload/API timeouts; backups not automated in-repo |

**Scoring method:** each category weighted equally among applicable rows (Frontend N/A excluded). 72% ≈ soft-launch capable with manual ops; 90%+ would require CD, monitoring, billing provider, backup/restore drills, and broader test coverage.

---

## 3. Production readiness checklist

| Item | Status |
|---|---|
| Discovery APIs (no cart/checkout) | Done |
| Auth register/login/refresh/logout | Done |
| Seller storefront + listings | Done |
| Favorites / follows / contact events | Done |
| In-app messaging | Done |
| Uploads via Azure SAS | Done (requires Azure conn string in prod) |
| Alembic migrations | Done through `008` |
| Prod config validators | Done (JWT default, DEBUG, CORS, hosts, storage) |
| Free premium self-subscribe in prod | **Blocked** (returns 503) — needs provider/admin |
| SMTP for password reset | Manual — warn if empty in prod |
| TLS / HTTPS reverse proxy | Manual |
| Rotated `JWT_SECRET_KEY` | Manual |
| DB backups / restore runbook | Manual |
| Crash reporting (mobile) | Missing |
| APM / metrics / alerts | Missing |
| Play Store signing + release pipeline | Manual |
| CI: backend tests + Flutter + image build | Done (`margem-ci.yml`) |
| CD deploy | Missing for MarGem |

---

## 4. Issues by severity

### Critical (would block safe public launch)

| Issue | Path | Impact | Status |
|---|---|---|---|
| Free `POST /subscriptions/subscribe/{plan}` granted premium with `provider=manual` | `backend/app/routers/seller_ops.py` | Anyone could self-activate paid visibility | **Fixed** — 503 in production |
| Default JWT secret accepted if length ≥32 | `backend/app/config.py` | Predictable token forging | **Fixed** — rejects `change-this-secret*` |
| `/health` returned 200 when DB down | `backend/app/main.py` | Orchestrators marked unhealthy API healthy | **Fixed** — 503 + `/ready` |
| Invalid JWT fell through to Firebase → 503 | `backend/app/auth.py` | Broken clients / confused ops when Firebase unset | **Fixed** — 401 when Firebase unset |

### High

| Issue | Path | Impact | Status |
|---|---|---|---|
| `ProxyHeadersMiddleware(trusted_hosts="*")` | `backend/app/main.py` | Client IP / scheme spoofing | **Fixed** — uses `ALLOWED_HOSTS` |
| Email fallback logged full bodies (tokens) | `backend/app/services/email.py` | Secret leakage via logs | **Fixed** — redaction + SMTP try/except |
| Read SAS ~10 years | `backend/app/routers/uploads.py` | Long-lived signed URLs if leaked | **Fixed** — 90 days |
| `media_urls` / `video_url` unvalidated | `backend/app/schemas/__init__.py` | XSS/phishing via `javascript:` etc. | **Fixed** — http(s) only |
| Reports / recently-viewed no target check | `backend/app/routers/discovery.py` | FK integrity errors → 500 | **Fixed** — 404 |
| Session expiry callback on disposed Splash | `mobile/lib/features/splash/splash_screen.dart` | Stale logout / missed redirect | **Fixed** — bind in `MarGemApp` |
| Contact seller did not open conversation | `product_detail_screen.dart`, `seller_detail_screen.dart` | Core discovery CTA incomplete | **Fixed** — starts conversation |
| Dockerfile ran as root | `backend/Dockerfile` | Container escape blast radius | **Fixed** — non-root `margem` |

### Medium

| Issue | Path | Impact | Status |
|---|---|---|---|
| Favorites lacked DB uniqueness | migration `008` | Duplicate favorites race | **Fixed** |
| Message lists unpaginated | `seller_ops.py` | Large inbox memory/CPU | **Fixed** — limit/offset |
| Budget compose no API healthcheck | `docker-compose.budget.yml` | Silent API death | **Fixed** |
| Nested `souq-local/.github/workflows` unused | CI at repo root | Confusion | Root `margem-ci.yml` updated + image job |
| DEBUG openable in prod | `config.py` | OpenAPI exposure | **Fixed** — rejected |
| Upload no timeout (mobile) | `upload_service.dart` | Hung UI | **Fixed** — 60s + 8MB cap |
| Search ignored city changes | `search_screen.dart` | Stale results | **Fixed** |
| Seller inquiries opened analytics only | `seller_dashboard_screen.dart` | Dead-end UX | **Fixed** → `/seller/messages` |

### Low

| Issue | Path | Impact | Status |
|---|---|---|---|
| Ecommerce-named l10n leftovers (`checkout`, `addToCart`) | `app_strings_*.dart` | Confusing for translators | Partially remapped to contact wording; rename later |
| `SellerOrdersScreen` placeholder | `seller_orders_screen.dart` | Dead route risk | Redirect CTA to messages |
| Premium expiry not continuously enforced | models/auth | `is_premium` may linger after period | Remaining manual / follow-up job |
| Conversation list N+1 queries | `seller_ops.py` | Latency at scale | Remaining |
| No mobile crash reporting | mobile | Blind production crashes | Remaining |
| Docs drift (token TTL / ecommerce) | various docs | Operator confusion | This audit + discovery docs |

---

## 5. File-by-file findings (high-signal)

### Backend
- `app/config.py` — prod validators for DEBUG, default JWT, CORS, hosts, storage; SMTP warning
- `app/main.py` — `/live`, `/ready`, `/health` (503 on DB fail), global handlers, scoped ProxyHeaders
- `app/auth.py` — Firebase-optional 401 path
- `app/services/email.py` — redacted logs, SMTP errors caught
- `app/routers/seller_ops.py` — prod subscribe disabled; conversation/message pagination
- `app/routers/discovery.py` — target validation; rate limits on reports/contact
- `app/routers/uploads.py` — 90-day read SAS
- `app/schemas/__init__.py` — media URL validation
- `app/models/__init__.py` — favorite/follow index hints
- `alembic/versions/008_production_hardening.py` — unique favorites + indexes
- `Dockerfile` + `.dockerignore` — non-root, lean context

### Mobile
- `lib/app.dart` — session bind; `/messages` + `/seller/messages` routes
- `lib/core/config/app_config.dart` — production HTTPS assert
- `lib/core/services/upload_service.dart` — timeout + size limit
- `lib/features/seller/product_detail_screen.dart` — contact → conversation
- `lib/features/seller/seller_detail_screen.dart` — message CTA
- `lib/features/search/search_screen.dart` — city listen
- `lib/features/seller/seller_dashboard_screen.dart` — inquiries → messages

### DevOps
- `.github/workflows/margem-ci.yml` — migrations, pytest, Flutter, Docker image build
- `docker-compose*.yml` — `/ready` healthchecks

---

## 6. Recommended improvements (next)

1. Integrate a membership billing provider (or admin-only grant UI) and webhook to replace gated subscribe.
2. Add Sentry/Firebase Crashlytics + server metrics (Prometheus or Azure Monitor).
3. Automate Postgres backups and a restore drill; document RPO/RTO.
4. Put API behind HTTPS reverse proxy; set `PUBLIC_API_URL` to https.
5. Reduce conversation inbox N+1 (join/subquery for last message + unread).
6. Expand mobile widget/integration tests for auth, messaging, favorites.
7. Rename leftover ecommerce l10n keys.
8. Enforce `premium_until` on request (middleware or dependency) and expire flags via scheduled job.
9. Prefer public-read blob container or CDN for media instead of long-lived SAS in listing URLs.

---

## 7. Automatic fixes applied on this branch

See sections 4–5. Backend tests: **29 passed** (`PYTHONPATH=. pytest`).

---

## 8. Final deployment checklist

1. Set `APP_ENV=production`, `DEBUG=false`, `AUTH_DEV_BYPASS=false`
2. Set unique `JWT_SECRET_KEY` (≥32, not the default)
3. Set `AZURE_STORAGE_CONNECTION_STRING`, `CORS_ORIGINS`, `ALLOWED_HOSTS` (no `*`)
4. Configure SMTP (`SMTP_HOST` …) for reset/verify mail
5. Terminate TLS at reverse proxy; point app `PUBLIC_API_URL` to HTTPS
6. `alembic upgrade head` (includes `008`)
7. Deploy via `docker-compose.budget.yml` or home compose; confirm `/ready` = 200
8. Build mobile with `--dart-define=PRODUCTION=true --dart-define=API_BASE_URL=https://…`
9. Verify subscribe returns 503 until billing/admin grant exists
10. Smoke: register buyer/seller, listing, favorite, message, upload, report

---

## 9. Remaining manual work before production

- Rotate and store secrets in Key Vault / host env (never commit)
- SMTP provider + SPF/DKIM
- Billing provider or admin premium grant process
- TLS certificates + domain DNS
- Database backup schedule + restore test
- Mobile crash reporting + store listing assets / signing
- Azure (or home-server) CD pipeline with rollback
- Load test messaging and search for expected city traffic
- Legal: privacy policy URL live; Play Data Safety form
