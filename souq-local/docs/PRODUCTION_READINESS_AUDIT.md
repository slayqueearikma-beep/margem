# MarGem Production Readiness Audit (Full Engineering Review)

**Date:** 2026-07-22  
**Branch:** `cursor/production-grade-audit-f384`  
**Scope:** Entire `souq-local/` tree (FastAPI, Flutter, Postgres, Azure Blob, Compose, Terraform/Bicep, CI)  
**Method:** Recursive source review of all application behavior files; backend + Flutter tests executed; critical findings fixed on this branch.

---

## 1. Executive summary

MarGem is a **local discovery / connection platform** (not checkout e-commerce). The codebase implements sellers, listings, search/map, favorites, follows, messaging, contact events, reviews, Azure uploads, premium *visibility* memberships (billing gated in prod), and admin ops.

**Deployment Readiness: 78%**

Suitable for a **controlled soft launch / home-server or budget-VM beta** after completing the remaining manual ops checklist (rotated secrets, SMTP, TLS, billing/admin premium grants, backups, crash reporting, Play signing). Not yet unattended internet-scale production (no MarGem CD, no APM wiring, no iOS project, limited automated test depth).

This pass closed additional production-critical gaps beyond the earlier audit: durable public blob URLs, paused-product visibility, media/social URL allowlisting, premium expiry, message rate limits, DB wait on boot, Android intent queries, HTTPS release enforcement, favorites routing, WhatsApp consistency, messaging UX, SMTP env wiring, and Bicep CORS/`ALLOWED_HOSTS`.

**Verification this revision:** backend **32 passed**; Flutter analyze clean; Flutter tests **5 passed**.

---

## 2. Deployment readiness score

### Deployment Readiness: **78%**

| Category | Score | Evidence |
|---|---:|---|
| Architecture | 82 | Clear FastAPI routers + Flutter feature modules; discovery pivot complete (`007`) |
| Backend | 84 | Auth, Alembic→`008`, rate limits, upload hardening, visibility filters, premium expiry |
| Mobile | 78 | Buyer/seller/messaging flows; Android release HTTPS gate; no iOS tree |
| UI/UX | 76 | Dashboard overflow fixed; contact CTAs aligned; some ecommerce l10n identifier debt |
| Security | 82 | Prod validators, URL allowlists, scoped ProxyHeaders, message limits; SUPPORT==ADMIN remains |
| Performance | 72 | Pagination + indexes; conversation N+1 and unpaged threads remain |
| Database | 80 | Migrations + uniqueness indexes; Float money; counters improved for views |
| Testing | 64 | 32 backend tests; thin mobile suite; no E2E; create_all in conftest |
| Documentation | 76 | This audit + marketplace docs; architecture.md still partially drifted |
| DevOps | 70 | Compose healthchecks, CI image build; no MarGem CD; App Insights env unused by app |
| Reliability | 72 | `/live` `/ready`, entrypoint DB wait, upload retry; backups manual |
| Maintainability | 78 | Layering OK; dead `SellerOrdersScreen`; leftover cart/order string keys |

---

## 3. Production readiness checklist

| Item | Status |
|---|---|
| Discovery APIs (no cart/checkout) | Done |
| Auth register/login/refresh/logout | Done |
| Seller storefront + listings | Done |
| Favorites / follows / contact / messaging | Done |
| Uploads (Azure, durable public blob URLs) | Done (requires Azure + container) |
| Public listing hides paused/unavailable | Done |
| Media + social URL validation | Done |
| Premium self-subscribe in production | Blocked (503) until billing/admin |
| Premium expiry on authenticated requests | Done |
| SMTP wired in home/budget compose | Done (env passthrough) |
| TLS reverse proxy | Manual |
| Rotated JWT + Azure secrets | Manual |
| DB backups automation | Manual |
| Crash reporting | Missing |
| APM (App Insights SDK) | Missing (env only on ACA TF) |
| Play signing / iOS | Manual / missing iOS |
| CI tests + image build | Done (`margem-ci.yml`) |
| CD deploy | Missing for MarGem |

---

## 4. Issues by severity (post-fix state)

### Critical — fixed this audit cycle

| Issue | Path | Fix |
|---|---|---|
| Azure `account_key` AttributeError → “Storage unavailable” | `uploads.py`, `azure_storage.py` | Use `named_key.key`; auto-create container |
| Expiring SAS stored as permanent `image_url` | `uploads.py` | Public-blob container + durable URL without SAS |
| Paused products visible publicly | `sellers.py` | Filter `is_hidden` / `!is_available` / `is_paused` |
| Gallery/video URLs bypassed Azure allowlist | `sellers.py` | Validate `media_urls` / `video_url` like `image_url` |

### High — fixed

| Issue | Path | Fix |
|---|---|---|
| Seller website/social unvalidated | `sellers.py` | https-only URL validation |
| Guest favorite migrate skipped counters | `discovery.py` | Increment `favorite_count` |
| Messaging under-limited | `seller_ops.py` | 30/min start, 60/min reply |
| Map only returned 50 pins | `sellers.py` | Map uses max page size |
| Premium never expired | `auth.py` | Clear flags when `premium_until` past |
| Entrypoint raced Postgres | `entrypoint.sh` | Wait-for-DB before migrate |
| `PRODUCTION` HTTPS only via assert | `main.dart` | Throw in release/PRODUCTION |
| Android could not resolve tel/https | `AndroidManifest.xml` | Package visibility queries |
| Favorites seller-only routes broken | `wishlist_screen.dart` | Route/remove by seller |
| Product WhatsApp inconsistent | `product_detail_screen.dart` | Contact + Call only |
| Bicep CORS `*` | `infra/main.bicep` | Explicit CORS + ALLOWED_HOSTS |
| SMTP not in compose | `docker-compose.home.yml` / `.budget.yml` | Pass SMTP + PUBLIC_* |

### Medium — remaining / partial

| Issue | Path | Notes |
|---|---|---|
| SUPPORT has full admin | `auth.py` `require_admin` | Split roles before hiring support staff |
| Body size limit Content-Length only | `request_limits.py` | Chunked bypass risk |
| Conversation list N+1 | `seller_ops.py` | Scale issue |
| Money as Float | models | Prefer Numeric |
| MFA tables unused | models | Future |
| Email verify unused for gating | auth | Optional today |
| Nested unused CI workflow | `souq-local/.github/workflows/ci.yml` | Prefer root `margem-ci.yml` |
| `docs/architecture.md` drift | docs | Discovery rewrite still needed |
| No iOS project | mobile | Android-only |
| Ecommerce l10n key names | `app_strings_*.dart` | Remapped text; rename later |
| Unrouted `SellerOrdersScreen` | mobile | Dead screen |

### Low

Theme not persisted; search autofocus in IndexedStack; category UI uses `nameEn` only; `python-jose` maintenance risk; Dockerfile includes pytest.

---

## 5. File-by-file high-signal findings

### Backend
- `app/config.py` — prod gates; strip Azure connection quotes  
- `app/main.py` — `/live` `/ready` `/health` 503; exception handlers  
- `app/auth.py` — Firebase-optional 401; premium expiry  
- `app/routers/uploads.py` — durable public URLs; clearer errors  
- `app/routers/sellers.py` — visibility, media allowlist, featured gate, city escape, map limit, atomic views  
- `app/routers/discovery.py` — report/view targets; guest migrate counters  
- `app/routers/seller_ops.py` — prod subscribe 503; message rate limits  
- `scripts/entrypoint.sh` — DB wait + migrate  
- `alembic/versions/008_production_hardening.py` — favorite uniqueness + indexes  

### Mobile
- `lib/main.dart` — release HTTPS enforcement  
- `lib/app.dart` — session bind; messages routes  
- Dashboard / StatCard — overflow-safe  
- `product_detail_screen.dart` / `seller_detail_screen.dart` — discovery contact CTAs  
- `wishlist_screen.dart` — seller favorite navigation  
- `messages_inbox_screen.dart` — send errors + bubble alignment  
- `splash_screen.dart` — restore `authSession` via `/auth/me`  
- AndroidManifest — intent queries  

### DevOps
- Compose home/budget — SMTP + PUBLIC_* + `/ready`  
- `infra/main.bicep` — CORS/hosts  
- `.github/workflows/margem-ci.yml` — tests + image build  

---

## 6. Recommended next improvements

1. Membership billing webhook or admin-only grant UI  
2. Wire OpenTelemetry/App Insights **or** remove unused ACA env  
3. Automate Postgres backups + restore drill  
4. Split SUPPORT vs ADMIN permissions  
5. Message inbox SQL join for last/unread (kill N+1)  
6. Expand Flutter widget/integration tests; Alembic upgrade test in CI  
7. Rewrite `docs/architecture.md` to discovery reality  
8. Add iOS project or formally document Android-only  
9. Purge unused cart/order l10n identifiers  
10. Numeric money columns migration  

---

## 7. Automatic fixes applied (this branch)

All Critical/High items in §4 tables marked **Done**, plus earlier audit hardening (JWT default rejection, health 503, ProxyHeaders trust, upload key extraction, dashboard overflow, welcome greeting, etc.).

---

## 8. Final deployment checklist

1. `APP_ENV=production`, `DEBUG=false`, `AUTH_DEV_BYPASS=false`  
2. Unique `JWT_SECRET_KEY` (not default), Azure storage, CORS, ALLOWED_HOSTS (no `*`)  
3. SMTP + `PUBLIC_APP_URL` https  
4. TLS reverse proxy; mobile `--dart-define=PRODUCTION=true --dart-define=API_BASE_URL=https://…`  
5. `alembic upgrade head` (via entrypoint)  
6. Confirm blob container `margem-media` is public-blob (API attempts this)  
7. Smoke: register → listing + image → favorite → message → public storefront hides paused  
8. Subscribe returns 503 until billing/admin grant  

---

## 9. Remaining manual work

- Secret rotation / Key Vault  
- SMTP DNS (SPF/DKIM)  
- Billing or admin premium process  
- Certificates + DNS  
- Backup cron + offsite copy  
- Crashlytics/Sentry + store listing  
- CD pipeline with rollback  
- Load test messaging/search for city traffic  
- Legal privacy URL live  

---

## 10. Test evidence

```text
backend: 32 passed (PYTHONPATH=. pytest)
mobile:  flutter analyze — No issues found
mobile:  flutter test — All tests passed (5)
```
