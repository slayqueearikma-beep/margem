# Security & Production-Readiness Audit Report

**Application:** MarGem / Dribex marketplace (`souq-local`)  
**Audit date:** August 2026  
**Scope:** Backend API, mobile client, Docker deployment, CI/CD

---

## Executive summary

This audit reviewed authentication, authorization, API input handling, uploads, configuration, deployment, and client-side error handling. Several **high-impact hardening controls** were implemented, regression tests were added, and CI security scanning was expanded.

The application already had meaningful baseline controls (bcrypt passwords, refresh-token rotation with reuse detection, upload allowlisting, production config validation, rate limiting, security headers, seller ownership checks). This pass closes gaps around **admin network exposure**, **account lockout**, **access-token invalidation on credential change**, **production error leakage**, and **automated security testing**.

**Production-readiness status:** Suitable for controlled production deployment when operators configure `ADMIN_IP_ALLOWLIST`, HTTPS URLs, SMTP (or documented break-glass email fallback), and separate upload/JWT secrets. Remaining risks are documented below and require operational follow-through (TLS edge on budget VM stack, certificate pinning on mobile, future payment webhook integration).

---

## Critical vulnerabilities fixed

| Vulnerability | Component | Root cause | Fix |
|---------------|-----------|------------|-----|
| Admin APIs reachable from any IP in production | `/admin/*` routes | No network-layer guard on staff/admin endpoints | `AdminIpGuardMiddleware` + required `ADMIN_IP_ALLOWLIST` in production config |
| Cross-origin browser abuse of admin APIs | `/admin/*` + CORS | Admin paths accepted requests from arbitrary `Origin` headers | `AdminOriginGuardMiddleware` restricts admin calls to configured CORS origins |
| Stolen access tokens remain valid after password reset | JWT access tokens | Access tokens had no session/version binding | `token_version` on users, embedded as `tv` claim; bumped on password change/reset, account deletion, admin suspend |

---

## High-risk vulnerabilities fixed

| Vulnerability | Component | Root cause | Fix |
|---------------|-----------|------------|-----|
| No account-level brute-force slowdown | `/auth/login` | Only IP rate limits; unlimited per-account attempts | Escalating lockout after 5 failures (`login_lockout.py`) |
| Production validation errors expose schema internals | FastAPI 422 handler | Full Pydantic error structures returned to clients | Generic `"Validation error"` in production |
| Premium self-serve abuse in non-prod | `/subscriptions/subscribe` | Dev-only endpoint without tight throttle | Explicit `10/minute` rate limit; production still returns 503 |
| Sensitive API errors shown raw in mobile UI | Buyer home, login | `e.toString()` / raw `ApiException.message` | `friendlyErrorMessage()` helper with production-safe mapping |
| Flaky/incomplete security tests | pytest `conftest` | Leftover DB tables blocked schema reset | `DROP SCHEMA public CASCADE` before each test run |
| Budget production missing admin IP config | `docker-compose.budget.yml` | Required env not passed to API container | `ADMIN_IP_ALLOWLIST` + `TRUSTED_PROXY_HOPS` added |

---

## Medium-risk vulnerabilities fixed

| Issue | Fix |
|-------|-----|
| Client IP for audit logs ignored reverse-proxy chain | `get_client_ip()` with configurable `TRUSTED_PROXY_HOPS` |
| Admin suspend did not invalidate outstanding JWTs | `bump_token_version()` on suspend/delete admin action |
| No automated IDOR/premium/admin regression tests | New `tests/test_security_audit.py` |
| CI lacked SAST/secret scanning for souq-local path | Bandit + Gitleaks (filesystem scan) in `margem-ci.yml` |

---

## Low-risk improvements

- Documented `ADMIN_IP_ALLOWLIST` and `TRUSTED_PROXY_HOPS` in `.env.example`
- Login/audit events now log resolved client IP via `get_client_ip`
- Production settings smoke test in CI requires `ADMIN_IP_ALLOWLIST`

---

## Remaining risks (genuine, not yet fully verified)

| Risk | Severity | Notes |
|------|----------|-------|
| Budget Azure stack exposes API on `:8000` without TLS edge | High (operational) | Compose binds API publicly; place nginx/Caddy or restrict bind address |
| Local `/media` URLs are public if leaked | Medium | By design for local storage; use Azure in internet-facing prod |
| Mobile certificate pinning is opt-in | Medium | Set `CERTIFICATE_PINS` for release builds |
| No Stripe/webhook payment flow on `main` yet | N/A today | When added: signature verification, idempotency, redirect URL allowlist required |
| WebSocket/community features not on current `main` branch | N/A | Re-audit when merged |
| Admin dashboard static assets CSP | Low | Global CSP `default-src 'none'` may affect future embedded admin UI |
| Gitleaks/bandit in CI may need tuning | Low | False positives possible; review first CI run |

---

## Security architecture improvements

1. **Defense in depth for admin:** JWT role check → origin guard → IP allowlist
2. **Session invalidation model:** Refresh-token rotation + access-token version (`tv`) + revoke-all on password events
3. **Account lockout:** Per-user escalating lockout independent of IP rate limits
4. **Production-safe errors:** Generic 422/500 bodies; detailed errors only in development
5. **Test isolation:** Full schema reset prevents cross-branch migration contamination

---

## Stability improvements

- Test database setup uses schema cascade drop (reliable CI/local runs)
- Subscribe endpoint rate-limited to reduce accidental load in dev/staging
- `TRUSTED_PROXY_HOPS` documented for reverse-proxy deployments

---

## Tests added

`tests/test_security_audit.py`:

- Cross-user notification read (IDOR) → 404
- Cross-seller product mutation → 403/404
- Self-serve premium in production → 503
- Admin routes without IP allowlist in production → 403
- Access token invalid after password change → 401
- Login lockout after repeated failures → 429

All **78** backend tests pass after changes.

---

## CI/CD additions

- **Bandit** static analysis on `app/`
- **Gitleaks** filesystem scan on `souq-local/`
- Production settings smoke includes `ADMIN_IP_ALLOWLIST`

---

## Operator checklist before production

1. Set strong `JWT_SECRET_KEY` and separate `UPLOAD_TOKEN_SECRET` (≥32 chars each)
2. Set `ADMIN_IP_ALLOWLIST` to office/VPN/home CIDRs
3. Set `CORS_ORIGINS` and `ALLOWED_HOSTS` explicitly (no `*`)
4. Configure SMTP or consciously enable `ALLOW_INSECURE_EMAIL_FALLBACK` (break-glass only)
5. Use HTTPS for `PUBLIC_APP_URL` and `PUBLIC_API_URL`
6. Set `TRUSTED_PROXY_HOPS=1` when behind nginx/Azure front door
7. Run `alembic upgrade head` (includes migration `014` security fields)
8. Terminate TLS at edge for budget VM deployments

---

*This report reflects code verified in this audit branch. It does not certify the entire repository history or infrastructure outside `souq-local`.*
