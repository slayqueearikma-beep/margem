# Security & Production-Readiness Audit Report

**Application:** Dribex marketplace (`souq-local`)  
**Audit date:** August 2026  
**Branch:** `cursor/arabic-localization-audit-ee43` (integration branch)  
**Scope:** Backend API, mobile client, community/marketplace features, Docker deployment, CI/CD

---

## Executive summary

This audit covers the full integration branch: Dribex rebrand, privacy/legal hub, Arabic localization, marketplace/community features, seller flows, and prior security hardening passes. It confirms baseline controls (bcrypt passwords, refresh-token rotation with reuse detection, upload allowlisting, production config validation, rate limiting, security headers, seller ownership checks) and closes remaining gaps around **admin network exposure for community moderation routes**, **production validation error leakage**, **CI security scanning**, and **budget deployment configuration**.

**Production-readiness status:** Suitable for controlled production deployment when operators configure `ADMIN_IP_ALLOWLIST`, HTTPS URLs, SMTP (or documented break-glass email fallback), separate upload/JWT/MFA secrets, and TLS at the edge. Remaining operational risks are documented below.

---

## Critical vulnerabilities fixed

| Vulnerability | Component | Root cause | Fix |
|---------------|-----------|------------|-----|
| Admin APIs reachable from any IP in production | `/admin/*` and `/community/admin/*` | Network guard only matched `/admin/*` | Shared `is_admin_protected_path()` + `AdminIpGuardMiddleware` |
| Cross-origin browser abuse of admin APIs | Admin + community moderation paths | Admin paths accepted requests from arbitrary `Origin` headers | `AdminOriginGuardMiddleware` uses shared path matcher |
| Stolen access tokens remain valid after credential change | JWT access tokens | Access tokens had no session/version binding | `token_version` on users, embedded as `tv` claim; bumped on password change/reset, account deletion, admin suspend |

---

## High-risk vulnerabilities fixed

| Vulnerability | Component | Root cause | Fix |
|---------------|-----------|------------|-----|
| No account-level brute-force slowdown | `/auth/login` | Only IP rate limits; unlimited per-account attempts | Escalating lockout after 5 failures (`login_lockout.py`) |
| Production validation errors expose schema internals | FastAPI 422 handler | Full Pydantic error structures returned to clients | Generic `"Validation error"` in production |
| Sensitive API errors shown raw in mobile UI | Buyer home, login | Raw exception strings in UI | `friendlyErrorMessage()` helper with production-safe mapping |
| Budget production missing admin IP / MFA config | `docker-compose.budget.yml` | Required env not passed to API container | `ADMIN_IP_ALLOWLIST`, `TRUSTED_PROXY_HOPS`, `MFA_ENCRYPTION_KEY` added |
| Community WebSocket / reaction IDOR | Community chat | Membership not enforced on all paths | Regression tests in `test_security_audit_fixes.py` |

---

## Medium-risk vulnerabilities fixed

| Issue | Fix |
|-------|-----|
| Client IP for audit logs ignored reverse-proxy chain | `get_client_ip()` with configurable `TRUSTED_PROXY_HOPS` |
| Admin suspend did not invalidate outstanding JWTs | `bump_token_version()` on suspend/delete admin action |
| MFA secrets stored without dedicated encryption key | `MFA_ENCRYPTION_KEY` required in production settings |
| Manual billing abuse in staging | Blocked when `allow_manual_billing=false` and Stripe unset |
| CI lacked SAST/secret scanning | Bandit + Gitleaks in `margem-ci.yml` |
| Community moderation outside `/admin/*` unguarded at network layer | Extended admin path matcher |

---

## Low-risk improvements

- Documented `ADMIN_IP_ALLOWLIST` and `TRUSTED_PROXY_HOPS` in `.env.example`
- Login/audit events log resolved client IP via `get_client_ip`
- Production settings smoke test in CI requires `ADMIN_IP_ALLOWLIST` and `MFA_ENCRYPTION_KEY`
- Arabic legal copy centralized in privacy/legal hub (reduces scattered hard-coded strings)

---

## Remaining risks (operational follow-through)

| Risk | Severity | Notes |
|------|----------|-------|
| Budget Azure stack exposes API on `:8000` without TLS edge | High (operational) | Terminate TLS at nginx/Caddy or restrict bind address |
| Local `/media` URLs are public if leaked | Medium | Use Azure storage for internet-facing prod |
| Mobile certificate pinning is opt-in | Medium | Set `CERTIFICATE_PINS` for release builds |
| Stripe webhook flow | Medium when enabled | Requires signature verification, idempotency, redirect URL allowlist |
| Gitleaks/bandit in CI may need tuning | Low | Review first CI run for false positives |
| Large integration branch (108+ commits) | Process | Prefer incremental merges to `main` to reduce review blast radius |

---

## Security architecture

1. **Defense in depth for admin:** JWT role check → origin guard → IP allowlist (covers `/admin/*` and `/community/admin/*`)
2. **Session invalidation:** Refresh-token rotation + access-token version (`tv`) + revoke-all on password events
3. **Account lockout:** Per-user escalating lockout independent of IP rate limits
4. **Production-safe errors:** Generic 422/500 bodies; detailed errors only in development
5. **Community boundaries:** Membership checks on reactions, WebSocket tickets, and moderation routes

---

## Tests

Key security regression suites:

- `tests/test_admin_paths.py` — shared admin path matcher
- `tests/test_ops_security.py` — admin IP/origin guards, production 422 sanitization
- `tests/test_security_hardening.py` — MFA, lockout, JWT revocation
- `tests/test_security_audit_fixes.py` — community WebSocket/reaction boundaries, billing blocks
- `tests/test_production_hardening.py` — production settings validation
- `tests/test_security_helpers.py` — client IP, upload URL validation, text sanitization

All backend tests pass on this branch after the audit changes.

---

## CI/CD additions

- **Bandit** static analysis on `app/`
- **Gitleaks** filesystem scan on `souq-local/`
- Production settings smoke includes `ADMIN_IP_ALLOWLIST` and `MFA_ENCRYPTION_KEY`

---

## Operator checklist before production

1. Set strong `JWT_SECRET_KEY`, `UPLOAD_TOKEN_SECRET`, and `MFA_ENCRYPTION_KEY` (≥32 chars each, all distinct)
2. Set `ADMIN_IP_ALLOWLIST` to office/VPN/home CIDRs
3. Set `CORS_ORIGINS` and `ALLOWED_HOSTS` explicitly (no `*`)
4. Configure SMTP or consciously enable `ALLOW_INSECURE_EMAIL_FALLBACK` (break-glass only)
5. Use HTTPS for `PUBLIC_APP_URL` and `PUBLIC_API_URL`
6. Set `TRUSTED_PROXY_HOPS=1` when behind nginx/Azure front door
7. Run `alembic upgrade head`
8. Terminate TLS at edge for budget VM deployments

---

*This report reflects code verified on `cursor/arabic-localization-audit-ee43`. Security work previously opened on `cursor/security-production-audit-ee43` has been consolidated here.*
