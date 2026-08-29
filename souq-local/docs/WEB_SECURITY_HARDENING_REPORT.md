# Public Web Application Security Hardening Report

**Application:** Dribex public storefront (`souq-local/web`)  
**Scope:** Next.js web app + web-facing backend read APIs (no mobile, no admin UI changes)  
**Date:** August 27, 2026  
**Branch:** `cursor/web-security-hardening-ee43`

---

## Executive summary

The public web storefront is a **read-only** Next.js application that renders marketplace catalog data server-side and exposes a same-origin BFF proxy (`/api-proxy`) for browser media requests. This pass adds defense-in-depth controls focused on the web attack surface without changing business logic, user flows, UI/UX, or visual design.

Existing backend controls (rate limiting, CORS validation, upload allowlisting, admin guards, JWT/session hardening, production-safe errors) were preserved and extended with web-specific regression tests.

---

## Attack surface mapped

| Surface | Component | Notes |
|---------|-----------|-------|
| HTML pages | `souq-local/web/src/app/**` | SSR catalog/search/detail pages |
| BFF proxy | `/api-proxy/[...path]` | Browser GET/HEAD to API |
| Server-side API calls | `src/lib/api.ts` | Direct to `API_BASE_URL` in SSR |
| External links | Seller `website_url` | User-controlled, rendered as outbound links |
| JSON-LD | Product/service/seller pages | Structured data in `<script type="application/ld+json">` |
| Media URLs | `resolveMediaUrl()` | Rewritten to same-origin proxy |
| Shared backend | FastAPI public GET routes | Categories, search, catalog, media, legal redirects |

**Out of scope (unchanged):** Flutter mobile app, admin dashboard UI, authenticated write APIs (auth, uploads, billing, community WebSockets).

---

## Vulnerabilities discovered and remediated

| ID | Severity | Component | Issue | Remediation |
|----|----------|-----------|-------|-------------|
| WEB-01 | **High** | `/api-proxy` | Unrestricted read proxy could forward any public GET path (health, docs, auth metadata, admin-readable routes) | Strict path allowlist + traversal rejection in `security-core.js` / route handler |
| WEB-02 | **Medium** | Next.js HTML responses | No CSP/HSTS/X-Frame-Options on storefront pages (relied entirely on edge proxy) | Added `middleware.ts` + `next.config.ts` security headers |
| WEB-03 | **Medium** | `next.config.ts` rewrite | Duplicate rewrite to API could bypass route-handler controls in edge cases | Removed rewrite; proxy handled only by hardened route handler |
| WEB-04 | **Medium** | JSON-LD (`jsonLd`) | `JSON.stringify` without encoding enables `</script>` breakout if API data is hostile | `safeJsonLd()` Unicode-escapes `<`, `>`, `&`, line separators |
| WEB-05 | **Medium** | `externalHref()` | Accepted scheme-relative input; no block for `javascript:`, `data:`, etc. | `safeExternalHref()` allows http/https only, rejects credentials in URL |
| WEB-06 | **Low** | `resolveMediaUrl()` | No explicit block for dangerous URL schemes in absolute media URLs | `sanitizeMediaSource()` rejects non-http(s) schemes |
| WEB-07 | **Low** | Proxy responses | Upstream headers (e.g. `Set-Cookie`) forwarded to browser | Forward only safe response headers allowlist |
| WEB-08 | **Low** | Error messages | SSR/network errors exposed internal `API_BASE_URL` in production | Generic production messages in `api.ts` and `marketplace-fetch.ts` |
| WEB-09 | **Info** | BFF proxy | No CSRF exposure (GET-only, no cookies/session on web) | Verified; no change required |

---

## Security controls added

### Web frontend

1. **`src/lib/security-core.js`** — shared pure-JS security primitives (testable without transpilation)
2. **`src/middleware.ts`** — CSP, HSTS (HTTPS), X-Frame-Options DENY, nosniff, COOP/CORP, Permissions-Policy
3. **`src/app/api-proxy/[...path]/route.ts`** — allowlist enforcement, traversal block, GET/HEAD only, safe header forwarding
4. **`next.config.ts`** — defense-in-depth response headers; removed permissive API rewrite
5. **Output encoding** — safe JSON-LD, external links, media URL sanitization
6. **Production-safe errors** — no internal hostnames in user-visible failures

### Backend (web-related verification)

1. **`tests/test_web_storefront_security.py`** — public catalog auth boundaries, PII minimization, search input limits

### Existing controls retained (not modified)

- Global and per-route API rate limiting (slowapi + Redis)
- CORS / allowed hosts production validation
- Security headers on API JSON responses
- Upload content-type / magic-byte validation (mobile-only path)
- Media path traversal protection
- Admin IP + origin guards
- JWT token version binding, MFA, account lockout
- CI: Bandit, Gitleaks, pip-audit, Trivy

---

## Tests performed

| Test | Result |
|------|--------|
| `cd souq-local/web && npm run test:security` | 5/5 passed (proxy allowlist, traversal, URL schemes, JSON-LD) |
| `pytest tests/test_web_storefront_security.py` | 5/5 passed |
| `npm run build` (Next.js standalone) | Success; middleware compiled |
| Manual review: no mobile/admin files changed | Confirmed |

---

## OWASP Top 10 / API mapping (web scope)

| Risk | Status |
|------|--------|
| A01 Broken access control | Proxy allowlist blocks auth/admin/upload paths from browser BFF |
| A02 Cryptographic failures | HSTS on HTTPS; no secrets in frontend code |
| A03 Injection | Search query length capped server-side; JSON-LD encoded; React SSR escaping |
| A04 Insecure design | Read-only storefront; write paths not exposed via web |
| A05 Security misconfiguration | CSP + headers on HTML; removed permissive rewrite |
| A06 Vulnerable components | Dependencies unchanged; recommend ongoing `npm audit` / CI |
| A07 Auth failures | Web has no session; `/auth/me` requires bearer (tested) |
| A08 Data integrity failures | GET-only proxy; no CSRF state on web |
| A09 Logging/monitoring failures | Server logs retain detail; user-facing errors sanitized in prod |
| A10 SSRF | Proxy upstream host fixed; path allowlisted; no user-controlled host |

---

## Remaining risks

| Risk | Severity | Mitigation owner |
|------|----------|------------------|
| Edge WAF / DDoS at scale | High (operational) | Cloudflare / nginx (see `infra/cloudflare/`) |
| CSP uses `'unsafe-inline'` for Next.js/JSON-LD | Low | Nonce-based CSP would require larger refactor |
| Seller `website_url` phishing links | Low | Links open off-site with `rel="noopener noreferrer"`; backend rejects private IPs |
| Direct API access (`api.dribex.ma`) bypasses web proxy allowlist | Medium | Expected; API has its own auth/rate limits; keep admin IP allowlist enforced |
| Dependency CVEs | Ongoing | CI pip-audit/Trivy; run `npm audit` on web regularly |
| Source maps in production builds | Low | Ensure `productionBrowserSourceMaps: false` at deploy (Next default) |

---

## Infrastructure / edge controls (not implemented in app code)

These should remain configured at deployment:

- TLS termination and HSTS preload at Cloudflare/nginx
- Rate limiting and bot management at edge
- `CORS_ORIGINS` / `ALLOWED_HOSTS` explicit in production `.env`
- `ADMIN_IP_ALLOWLIST` for staff routes
- Web Application Firewall rules
- Log aggregation and alerting

---

## Files changed

| Path | Change |
|------|--------|
| `web/src/lib/security-core.js` | New — core security helpers |
| `web/src/lib/security.ts` | New — TS re-exports |
| `web/src/middleware.ts` | New — security headers |
| `web/src/app/api-proxy/[...path]/route.ts` | Hardened proxy |
| `web/next.config.ts` | Headers; removed rewrite |
| `web/src/lib/format.ts` | Safe external URLs |
| `web/src/lib/seo.ts` | Safe JSON-LD |
| `web/src/lib/media.ts` | Media URL sanitization |
| `web/src/lib/api.ts` | Production-safe errors |
| `web/src/lib/marketplace-fetch.ts` | Production-safe errors |
| `web/scripts/test-security.mjs` | New — regression tests |
| `web/package.json` | `test:security` script |
| `backend/tests/test_web_storefront_security.py` | New — API boundary tests |
| `docs/WEB_SECURITY_HARDENING_REPORT.md` | This report |

---

## Disclaimer

This hardening **reduces** risk against common web attack classes tested above. It does **not** guarantee immunity from all attacks. Effectiveness depends on correct production configuration, timely dependency updates, and edge/infrastructure controls listed above.
