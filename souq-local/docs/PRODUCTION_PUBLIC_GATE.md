# Dribex Public Production Gate Report

Generated from repository audit and code changes on branch `cursor/public-production-ready-ee43`.

```text
PRODUCTION STATUS

NOT READY
```

Public launch requires **server-side operations** (DNS, trusted TLS, firewall, Tailscale port conflict resolution) that cannot be completed from the repository alone. Code and configuration templates are aligned for public production; the live Pi must be operated per the runbooks below.

---

## BLOCKERS

Only issues that genuinely prevent public launch:

1. **Public DNS** — `api.dribex.ma` / `dribex.ma` must resolve to the **public IP** (or Cloudflare proxy), not Tailscale `100.x.x.x`. *Server-only verification.*
2. **Trusted TLS** — nginx must serve a **publicly trusted** certificate (Cloudflare Origin behind proxy, or Let's Encrypt). Bootstrap self-signed certs reject mobile HTTPS. *Server-only verification.*
3. **Tailscale Serve on :443** — if `tailscaled` owns port 443, nginx cannot serve public HTTPS. Reset Serve/Funnel without disabling Tailscale SSH. *Server-only verification.*
4. **`.env.prod` secrets** — production file must exist on server with real values (not `CHANGE_ME`). Run `validate-production-env.sh`. *Server-only.*
5. **Legal/CNDP placeholders** — privacy/legal HTML still contains `[CNDP DECLARATION OR AUTHORIZATION STATUS — TO BE CONFIRMED BY COUNSEL]` and entity placeholders in `/workspace/legal/`. *Requires counsel, not code.*
6. **Backup restore test** — MinIO backup script fixed in repo; **restore drill not executed** on production. *Server-only.*
7. **Physical mobile test on 4G** — release APK on Moroccan mobile data without Tailscale not verified in this environment. *Manual QA.*

---

## FIXED

Issues resolved in this work:

| Area | Fix |
|------|-----|
| Env templates | Canonical `infra/onprem/env.prod.example`; reconciled root `env.production.example` |
| Deploy path | `scripts/production-deploy.sh` uses on-prem `.env.prod`, validates env, deploys full stack + migrations |
| Env validator | Requires `APP_ENV=production`, `REWARDED_AD_SIGNING_SECRET`, `GRAFANA_ADMIN_PASSWORD`; rejects `MINIO_PUBLIC_URL` |
| Nginx | Removed `/storage/` MinIO bypass; media only via API `/media/` |
| Nginx health | `/health` on port 80 for container healthchecks |
| Backups | All 5 MinIO buckets via `minio/mc` sidecar; retention for postgres + minio |
| Mobile release | `kReleaseMode` always uses `https://api.dribex.ma` — no silent dev URL in release builds |
| Mobile hosts | Tailscale `100.64.0.0/10` blocked in `isDevelopmentApiHost` |
| CI | Release APK + AAB with `PRODUCTION=true`; optional `SENTRY_DSN` from GitHub secret |
| Safety script | Asserts nginx does **not** expose `/storage/` |
| Sentry backend | `SENTRY_DSN` wired into production compose for API |
| Prometheus | Scrapes API `/metrics` internally |
| Azure Bicep | `ALLOWED_HOSTS` no longer includes localhost |
| Docs | `PUBLIC_TLS_SETUP.md`, `TAILSCALE_PUBLIC_COEXISTENCE.md`, `production-gate-check.sh` |

---

## VERIFIED

Verified from repository / CI (not live production server):

- Production compose publishes **only** nginx `80:443`
- Internal services on `internal: true` network
- Mobile `AppConfig` pins release builds to `https://api.dribex.ma`
- Web production build locks API to `https://api.dribex.ma`
- `PAYMENTS_ENABLED=false`, `SUBSCRIPTIONS_ENABLED=false`, `ADS_ENABLED=true`, `LISTING_VIDEO_UPLOADS_ENABLED=false` in templates
- `.env.prod` / `.env.production` in `.gitignore`
- API media authorization model (`media_access.py`, `/media/` router)
- Upload security (magic bytes, size limits, owner binding)
- Rate limiting via Redis when `REDIS_URL` set
- Brevo required in production config validation
- Alembic migration chain through `043_remove_listing_video`

---

## SERVER-ONLY VERIFICATIONS

Must be run on the production host:

```bash
cd infra/onprem
./scripts/validate-production-env.sh .env.prod
./scripts/production-gate-check.sh
./scripts/verify-public-api.sh
sudo ufw status verbose
sudo ss -lntp | grep -E ':22|:80|:443'
curl -v https://api.dribex.ma/ready
curl -I https://dribex.ma
```

TLS install: `docs/PUBLIC_TLS_SETUP.md`  
Tailscale conflict: `docs/TAILSCALE_PUBLIC_COEXISTENCE.md`

---

## DEFERRED

Non-blocking after public beta:

- Vault Agent secret injection (bootstrap file mode OK initially)
- Certificate pinning (`CERTIFICATE_PINS`) for extra TLS hardening
- Full Prometheus/Grafana dashboards beyond API scrape
- Stripe/NAPS payments (intentionally disabled)
- Listing video uploads (`LISTING_VIDEO_UPLOADS_ENABLED=false`)
- Legal language default mismatch (web `ar` vs API legal redirect `en`)

---

## SECURITY STATUS

**No open P0 code vulnerabilities identified in this pass.**

Remaining **P1 operational** items:

- Live TLS trust chain
- Public DNS not pointing at Tailscale
- MinIO no longer directly proxied (fixed in nginx)
- Admin endpoints require `ADMIN_IP_ALLOWLIST` (configured in `.env.prod`)

---

## PUBLIC INTERNET STATUS

| Host | Repository expectation | Live status |
|------|------------------------|-------------|
| `dribex.ma` | Public HTTPS → nginx → web | **Not verified here** |
| `www.dribex.ma` | Public HTTPS → nginx → web | **Not verified here** |
| `api.dribex.ma` | Public HTTPS → nginx → API | **Not verified here** |

---

## MOBILE STATUS

Release APK/AAB **guaranteed** to use `https://api.dribex.ma`:

- `kReleaseMode` hardcodes canonical URL in `app_config.dart`
- CI builds with `--dart-define=PRODUCTION=true`
- `scripts/build-production-android.sh` uses same flags

`ALLOW_INSECURE_TLS` is for private beta only and ignored when `PRODUCTION=true`.

---

## BACKUP STATUS

| Component | Status |
|-----------|--------|
| PostgreSQL | Script dumps to `/var/backups/margem/postgres-*.sql.gz` |
| MinIO (all buckets) | Fixed — `minio/mc` mirrors all 5 buckets |
| Off-server copy | Documented; operator must schedule rsync/rclone |
| Restore tested | **Not verified** — run restore drill on staging copy |

---

## TLS STATUS

| Item | Status |
|------|--------|
| Repository default | Bootstrap self-signed if certs missing (`deploy.sh`) |
| Public production requirement | Cloudflare Origin or Let's Encrypt |
| Mobile trust | Requires publicly trusted cert — see `PUBLIC_TLS_SETUP.md` |

---

## TAILSCALE STATUS

| Use | Status |
|-----|--------|
| SSH / admin | **Keep enabled** |
| End-user API/website | **Must not be required** |
| Port 443 conflict | Documented reset procedure — does not remove Tailscale SSH |

---

## FINAL LAUNCH DECISION

```text
NOT READY FOR PUBLIC BETA
```

**Reason:** Live server must complete DNS → trusted TLS → firewall → Tailscale port resolution → `.env.prod` validation → mobile 4G test. Repository changes remove code/config blockers; operator runbooks are in `infra/onprem/docs/` and `scripts/production-gate-check.sh`.

**Decisive test:** A Moroccan user on mobile data installs the production app and completes signup over `https://api.dribex.ma` without Tailscale. Run after server steps above.
