# Phase 7 — Pre-Production Validation

**Goal:** Prove the stack is stable and secure on your home server (Piocco) **before** public HTTPS, store release, or production traffic.

**Branch:** `cursor/search-filter-clear-fix-ee43` (PR #121)

**Phase 8 (next):** Public HTTPS, NAPS live, Play signing, staging soak → production pilot.

---

## Status tracker

| Gate | Owner | Status |
|------|-------|--------|
| Deploy latest branch on Piocco | Ops | ☐ |
| Automated Phase 7 script passes | Ops | ☐ |
| Mobile smoke (login, MFA, search Clear) | Manual | ☐ |
| Admin smoke (Basic Auth + MFA login) | Manual | ☐ |
| Web storefront smoke | Manual | ☐ |
| Backup script tested once | Ops | ☐ |
| Secrets not using CHANGE_ME | Ops | ☐ |

---

## Step 1 — Deploy on Piocco

```bash
cd ~/MarGem/souq-local
git fetch origin
git checkout cursor/search-filter-clear-fix-ee43
git pull origin cursor/search-filter-clear-fix-ee43

docker compose -f docker-compose.home.yml --env-file .env.home up -d --build api admin web
docker compose -f docker-compose.home.yml --env-file .env.home ps
```

Confirm all containers are healthy:

```bash
curl -fsS http://127.0.0.1:8000/ready
curl -fsS http://127.0.0.1:3000/ | head -c 200
```

---

## Step 2 — Run automated validation

From the Piocco host (adjust URLs to your Tailscale/LAN IPs):

```bash
cd ~/MarGem/souq-local
chmod +x scripts/phase7-validate.sh

API_URL=http://100.80.43.124:8000 \
WEB_URL=http://100.80.43.124:3000 \
ADMIN_URL=http://100.80.43.124:8080 \
ADMIN_BASIC_USER=dribex \
ADMIN_BASIC_PASSWORD='YOUR_HTACCESS_PASSWORD' \
./scripts/phase7-validate.sh
```

**Expected:** all checks pass; exit code 0.

Key security checks included:

- `/api-proxy/auth/me` → **403** (proxy allowlist blocks auth namespace)
- `/api-proxy/categories` → **200**
- Web response headers include **CSP** and **X-Frame-Options: DENY**

---

## Step 3 — Manual smoke tests

### Mobile (same LAN / Tailscale API URL)

| Test | Pass |
|------|------|
| Register or login existing account | ☐ |
| MFA enrollment in Settings | ☐ |
| Login with MFA challenge | ☐ |
| Search → Filters → **Clear** (no red screen) | ☐ |
| Browse sellers / products | ☐ |

### Admin dashboard

| Test | Pass |
|------|------|
| Browser Basic Auth gate (dribex / password) | ☐ |
| Dribex login → MFA code field appears | ☐ |
| Valid TOTP → dashboard loads | ☐ |
| Users list loads | ☐ |
| Sign out | ☐ |

### Public web storefront

| Test | Pass |
|------|------|
| Homepage loads | ☐ |
| Search returns results | ☐ |
| Product / seller detail pages load | ☐ |
| Images load via `/api-proxy/media/...` | ☐ |
| Hard refresh (Ctrl+Shift+R) after deploy | ☐ |

---

## Step 4 — Security spot checks

```bash
# Proxy must block auth namespace
curl -s -o /dev/null -w '%{http_code}\n' http://WEB_HOST:3000/api-proxy/auth/me
# Expected: 403

# Proxy must block admin namespace
curl -s -o /dev/null -w '%{http_code}\n' http://WEB_HOST:3000/api-proxy/admin/users
# Expected: 403

# Direct API still requires bearer (bypassing web proxy)
curl -s http://API_HOST:8000/auth/me | jq .detail
# Expected: "Missing bearer token"
```

Review `docs/WEB_SECURITY_HARDENING_REPORT.md` for full control list.

---

## Step 5 — Ops hygiene (before Phase 8)

| Item | Command / action |
|------|------------------|
| Secrets rotated | Replace all `CHANGE_ME` in `.env.home` |
| DB backup | `infra/onprem/scripts/backup.sh` (schedule cron) |
| Container logs | `docker compose ... logs --tail=50 api web admin` |
| Disk space | `df -h` on Piocco |
| Tailscale Serve | Confirm HTTPS URLs match `PUBLIC_API_URL` / CORS |

---

## Phase 7 exit criteria

Phase 7 is **complete** when:

1. `phase7-validate.sh` exits 0 on Piocco
2. All manual smoke tests checked
3. No open Critical/High bugs from this branch
4. Team agrees to proceed to **Phase 8** (public HTTPS + closed beta)

---

## Phase 8 preview (do not start until Phase 7 passes)

1. Cloudflare Tunnel or nginx TLS for `api.dribex.ma` / `dribex.ma`
2. Copy `env.staging.example` → `.env.staging`; deploy staging stack
3. NAPS sandbox end-to-end payment test
4. Android release signing + Play internal testing track
5. 1–2 week staging soak with real devices

See `docs/PRODUCTION_PHASE28_REPORT.md` for full production blockers.
