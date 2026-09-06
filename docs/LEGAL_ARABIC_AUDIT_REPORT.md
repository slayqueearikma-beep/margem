# Legal & Arabic Audit Report

**Date:** August 10, 2026  
**Branch:** `cursor/legal-arabic-audit-ee43`

## Legal documents upgraded

| Document | Action |
|----------|--------|
| `legal/privacy/privacy-policy.md` | Updated dates; removed unverified ISO/SOC 2 claims; added Law 09-08 / CNDP verification note; documented `GET /auth/me/export` |
| `legal/privacy/account-deletion-policy.md` | Aligned with actual deletion email format (`deleted+{uuid}@invalid.local`); community message anonymization; in-app flow |
| `legal/privacy/third-party-services.md` | Added local media storage option |
| `legal/compliance/lawyer-review-notes.md` | Updated pre-launch checklist |
| `backend/static/legal/{en,fr,ar}/*.html` | Production HTML for privacy, terms, cookies, account-deletion (RTL for Arabic) |
| `backend/app/routers/legal_pages.py` | Served at `/legal/{lang}/{doc}` with `/privacy`, `/terms`, `/cookies` redirects |

## Legal/compliance issues found

| Issue | Resolution |
|-------|------------|
| Legal pages not wired in API | Router registered in `main.py` |
| Policy claimed ISO/SOC 2 alignment | Removed; honest security language only |
| Account deletion policy email format mismatch | Policy updated to match code |
| Community/MFA data not cleaned on delete | Backend deletion extended |
| No in-app legal links | `LegalLinksSection` in buyer profile & seller settings |
| No signup terms notice | Compact acknowledgment on registration |
| CNDP registration unverified | Explicit disclaimer in policies (not claimed) |
| Entity registration / RC / ICE missing | Still requires counsel (marked in `contact.md`) |

## Arabic translation issues fixed

| Issue | Fix |
|-------|-----|
| Missing `growTitle` | Added Arabic: «نمِّ نشاطك التجاري» |
| Broken `dayLabel` abbreviations | Corrected Mon–Sun short forms |
| `navBookings` vs inquiry terminology | Changed to «الاستفسارات» |
| `premium` transliteration | Changed to «الاشتراك المميز» |
| English API errors in Arabic mode | `AsyncErrorView` maps common errors to localized strings |
| Legal strings missing | Added full legal/privacy string set (EN/FR/AR) |

## RTL bugs fixed

| Location | Fix |
|----------|-----|
| `messages_inbox_screen.dart` | Message bubbles use `AlignmentDirectional` |
| `community_channel_screen.dart` | Typing indicator uses `AlignmentDirectional.centerStart` |
| Legal HTML (`ar/*.html`) | `dir="rtl"` on Arabic pages |
| Typography | Noto Sans Arabic for `ar` locale |

## Functional bugs fixed

| Bug | Fix |
|-----|-----|
| `/legal/...` returned 404 | Router + static HTML |
| Account deletion left community/MFA data | Extended `DELETE /auth/me` cleanup |
| `privacyPolicyUrl` pointed to external default only | Locale-aware `AppConfig.legalDocumentUrl` |

## Remaining issues (external / legal verification)

- Registered legal entity name, RC, ICE, postal address (`legal/contact.md`)
- CNDP declaration/authorization under Law 09-08 (counsel to confirm requirement)
- DPO formal appointment
- Cookie consent banner on Web (not yet implemented)
- Full French/Arabic translation of all 48 markdown legal files (hosted HTML summaries only)
- WCAG 2.1 AA accessibility audit before publishing accessibility statement
- Payment provider integration when billing goes live
- In-app data export UI (API exists; no mobile screen yet)

## Files modified

**Backend:** `app/main.py`, `app/routers/auth.py`, `app/routers/legal_pages.py`, `scripts/generate_legal_html.py`, `static/legal/**`, `tests/test_legal_pages.py`

**Mobile:** `app.dart`, `app_config.dart`, `app_theme.dart`, `app_typography.dart`, `async_error_view.dart`, `legal_links_section.dart`, `buyer_home_screen.dart`, `seller_settings_screen.dart`, `buyer_registration_screen.dart`, `seller_registration_screen.dart`, `messages_inbox_screen.dart`, `community_channel_screen.dart`, `app_strings*.dart`

**Legal:** `legal/privacy/*.md`, `legal/compliance/lawyer-review-notes.md`

## Tests performed

- `pytest souq-local/backend/tests/test_legal_pages.py`
- `pytest souq-local/backend/tests/test_auth_lifecycle.py` (account deletion)
- `flutter analyze` (mobile)
- Backend test suite (full)

## Build/test result

See CI output on PR. Regenerate legal HTML after content changes:

```bash
python3 souq-local/backend/scripts/generate_legal_html.py
```

---

## Stability / security / Arabic follow-up (Aug 11, 2026)

### Stability / ops (~8/10)
- `validate_home_env.py` — preflight `.env.home` before Docker start
- `start_home_server.sh` — runs validator, correct storage backend messaging, `/ready` URL
- `/ready` — DB + local media writability + schema probe
- `entrypoint.sh` — media directory writable check before uvicorn
- `env.home.example` — bootable LAN defaults (`ALLOW_INSECURE_EMAIL_FALLBACK=true`, `MFA_ENCRYPTION_KEY`, `ADMIN_IP_ALLOWLIST`)

### Security (~8.5/10)
- `AdminIpGuardMiddleware` — optional `ADMIN_IP_ALLOWLIST` for `/admin/*` paths
- Production rejects placeholder secrets (`CHANGE_ME`, etc.)
- Separate `MFA_ENCRYPTION_KEY` required in production (distinct from JWT)
- Dev Postgres bound to `127.0.0.1` only

### Arabic / RTL (~7.5–8/10)
- `paymentMethodLabel` / `deliveryMethodLabel` (EN/FR/AR) on storefront screens
- Localized city names in seller registration review
- RTL: city picker, promo banner, message send icon, registration remove button
- `appStorageNotReady`, `communityYou`, premium terminology fixes in Arabic
- Noto Sans Arabic wordmark for `ar` locale
