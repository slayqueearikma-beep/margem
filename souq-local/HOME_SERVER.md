# Dribex Home Server — Laptop API + local (or Azure) images

Run the API and database on **your laptop**. Images default to **local disk** on the
laptop (no Azure required). Optionally point `STORAGE_BACKEND=azure` at Blob (~$1–3/month).

## Architecture

```
Your laptop (Linux)
┌─────────────────────────────┐
│ Docker                      │
│  ├── Postgres               │
│  ├── FastAPI :8000          │
│  └── /data/media (images)   │
└─────────────────────────────┘
         ▲
    Phone / users
```

Optional Azure mode:

```
Your laptop                    Azure (~$1-3/mo)
┌─────────────────────┐      ┌──────────────────┐
│ Docker API+Postgres │─────▶│ Blob margem-media│
└─────────────────────┘      └──────────────────┘
```

## Setup (one time)

### On your laptop (Linux)

```bash
# Install Docker
sudo apt update && sudo apt install -y docker.io docker-compose-plugin
sudo usermod -aG docker $USER
# log out and back in

git clone <your-repo>
cd souq-local
```

### Configure `.env.home`

```bash
cp env.home.example .env.home
```

Edit `.env.home`:

| Variable | Example |
|----------|---------|
| `POSTGRES_PASSWORD` | Strong password |
| `JWT_SECRET_KEY` | 32+ random chars |
| `UPLOAD_TOKEN_SECRET` | Different 32+ random chars; required for secure local image uploads |
| `STORAGE_BACKEND` | `local` (default) or `azure` |
| `PUBLIC_API_URL` | `http://192.168.1.50:8000` — **must** be the LAN IP your phone uses |
| `ALLOWED_HOSTS` | `localhost,127.0.0.1,192.168.1.50` |
| `CORS_ORIGINS` | `http://192.168.1.50:8000` |
| `AZURE_STORAGE_CONNECTION_STRING` | Only if `STORAGE_BACKEND=azure` |
| `SMTP_HOST` / credentials | Required in production for verification and password-reset email |

Find laptop IP:

```bash
hostname -I | awk '{print $1}'    # Linux
```

```powershell
ipconfig   # Windows — look for IPv4
```

## Start / stop

**Linux laptop — one command starts everything:**

```bash
chmod +x start_home_server.sh stop_home_server.sh

# Docker (API + Postgres) + Flutter on USB phone
./start_home_server.sh

# Rebuild API image after code changes
./start_home_server.sh --build

# API only (no Flutter)
./start_home_server.sh --api-only

./stop_home_server.sh
```

Manual compose (same as the script):

```bash
docker compose -f docker-compose.home.yml --env-file .env.home up -d --build
docker compose -f docker-compose.home.yml --env-file .env.home down
```

**Windows (if laptop runs Windows):**


```powershell
.\start_home_server.ps1
.\stop_home_server.ps1
```

## Admin dashboard (web)

Staff admin is **not** in the mobile app. It runs as a **separate web dashboard** on its own port:

`http://<laptop-lan-ip>:8080` (e.g. `http://192.168.11.101:8080`)

The mobile app talks to the API on port **8000** only. Admin uses port **8080** and calls the API in the background.

1. Register an account in the mobile app (role cannot be set at signup).
2. Promote that email to admin:

```bash
DRIBEXM_PROFILE=home ./scripts/docker-admin.sh promote-admin you@example.com
```

3. Open the admin URL in a browser (phone or laptop on the same Wi‑Fi) and log in.

Ensure `.env.home` allows cross-origin requests from the admin port:

```env
CORS_ORIGINS=http://192.168.11.101:8000,http://192.168.11.101:8080
ADMIN_PORT=8080
```

**If the admin page does not load**, rebuild and start both services:

```bash
git pull
docker compose -f docker-compose.home.yml --env-file .env.home up -d --build
MARGEM_API_URL=http://192.168.11.101:8000 MARGEM_ADMIN_URL=http://192.168.11.101:8080 \
  DRIBEXM_PROFILE=home ./scripts/docker-admin.sh check-admin
```

Legacy note: home compose disables embedded `/admin` on the API — **use port 8080 only**.

### Admin security (maximum hardening)

The admin container applies several layers by default:

| Layer | What it does |
|-------|----------------|
| **Private IP only** | Blocks access from the public internet (`ADMIN_ALLOW_PUBLIC=false`) |
| **HTTP Basic Auth** | Second password gate before Dribex login (`ADMIN_BASIC_AUTH_*`) |
| **Security headers + CSP** | Reduces XSS / clickjacking risk |
| **Rate limiting** | nginx limits requests to the admin UI |
| **No embedded admin on API** | `/admin` is not served on port 8000 |
| **Origin guard** | Admin API rejects browser calls from unknown origins |
| **Session token** | JWT stored in `sessionStorage` (cleared when browser tab closes) |
| **MFA for staff** | `ADMIN_REQUIRE_STAFF_MFA=true` requires MFA for admin/support |

Add to `.env.home`:

```env
ADMIN_BASIC_AUTH_USER=margem
ADMIN_BASIC_AUTH_PASSWORD=your-strong-gate-password
ADMIN_REQUIRE_STAFF_MFA=true
ADMIN_ALLOW_PUBLIC=false
CORS_ORIGINS=http://192.168.11.101:8000,http://192.168.11.111:8080
```

On your phone you will enter **two passwords**: Basic Auth gate, then Dribex admin login.

**Never** expose port 8080 through Cloudflare or port-forwarding. Keep admin on LAN only.

## Backups (home server)

```bash
chmod +x scripts/backup_home_db.sh
./scripts/backup_home_db.sh
# writes matching database and local-media archives — copy both off-site

# Restore a matching backup pair (asks for confirmation)
chmod +x scripts/restore_home_backup.sh
./scripts/restore_home_backup.sh backups/margem-YYYYMMDD….sql.gz

# Install a daily 02:17 backup job (keeps 14 days locally)
chmod +x scripts/install_home_backup_cron.sh
./scripts/install_home_backup_cron.sh

# Optional: encrypted/off-site rclone remote (configure rclone first)
RCLONE_REMOTE="b2:margem-backups" ./scripts/install_home_backup_cron.sh
```

For an isolated LAN-only test without SMTP, set
`ALLOW_INSECURE_EMAIL_FALLBACK=true` explicitly in `.env.home`. Do not use
that mode for public access: reset and verification links are not delivered.

## Connect from phone

### Wireless debugging (no USB cable)

Phone and Ubuntu server must be on the **same Wi-Fi**.

**On phone:** Settings → Developer options → **Wireless debugging** → ON

**Step 1 — Pair (first time only)**

Tap **“Pair device with pairing code”** on the phone. You’ll see:
- IP address & port (pairing port, e.g. `192.168.11.107:37123`)
- 6-digit pairing code

On the server:

```bash
chmod +x setup_wireless_adb.sh
./setup_wireless_adb.sh pair 192.168.11.107:37123 123456
```

**Step 2 — Connect**

On the Wireless debugging screen, note **“IP address & port”** (debug port — different from pairing port):

```bash
./setup_wireless_adb.sh connect 192.168.11.107:41293
./setup_wireless_adb.sh status
```

**Step 3 — Start everything**

```bash
./start_home_server.sh
```

If connection drops after reboot, run `connect` again (pairing is usually once per Wi-Fi).

### Same Wi-Fi (manual flutter run)

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000
```

### From anywhere (recommended): Tailscale

1. Install [Tailscale](https://tailscale.com/) on laptop + phone (free)
2. Note laptop Tailscale IP (e.g. `100.x.x.x`)
3. Add to `.env.home`:

```env
ALLOWED_HOSTS=["100.x.x.x","100.x.x.x:8000","192.168.1.50","192.168.1.50:8000"]
CORS_ORIGINS=["http://100.x.x.x:8000","http://192.168.1.50:8000"]
```

4. Restart: `docker compose -f docker-compose.home.yml --env-file .env.home up -d`

```bash
flutter run --dart-define=API_BASE_URL=http://100.x.x.x:8000
```

## Costs

| Item | Cost |
|------|------|
| Laptop electricity | ~$2-5/mo if 24/7 |
| Azure Blob | ~$1-3/mo |
| **Total** | **~$3-8/mo** |

## vs other options

| Setup | Cost | 24/7 | Public access |
|-------|------|------|---------------|
| **Home + Blob** | ~$3-8 | If laptop stays on | Tailscale |
| `start_lab.ps1` | $0 | No (dev only) | LAN only |
| `start_azure_budget.ps1` | ~$15-25 | Yes | Public IP |

## Troubleshooting home API (`margem-home-api` Error)

Docker Compose marks the API as **Error** when the container exits or never passes the
`/ready` healthcheck (~5 minutes). The database can be healthy while the API still fails.

**Step 1 — get the real error:**

```bash
cd ~/MarGem/souq-local
docker logs margem-home-api --tail 100
```

Or use the diagnostic script:

```bash
chmod +x scripts/diagnose_home_api.sh
MARGEM_PROFILE=home ./scripts/docker-admin.sh diagnose
```

**Step 2 — match the log message:**

| Log message | Fix |
|-------------|-----|
| `Settings validation failed` / `MFA_ENCRYPTION_KEY must differ` | Generate three **different** secrets with `openssl rand -hex 32`. Set `APP_ENV=development` for LAN home. |
| `Alembic migration failed` / `Can't locate revision` | `git pull origin cursor/final-integration-ee43` then rebuild: `docker compose -f docker-compose.home.yml --env-file .env.home up -d --build api` |
| `Media directory not writable` | `docker run --rm --user root -v souq-local_margem_home_media:/data alpine sh -c "chown -R 999:999 /data && chmod -R u+rwX /data"` |
| `MINIO_ENDPOINT is not configured` | Set `STORAGE_PROVIDER=local` and `STORAGE_BACKEND=local` in `.env.home` |
| `PAYMENT_PROVIDER=manual is not allowed in production` | Set `APP_ENV=development` in `.env.home` (home LAN default) |

**Step 3 — verify endpoints:**

```bash
curl http://127.0.0.1:8000/health    # database only
curl http://127.0.0.1:8000/ready     # must be 200 for Docker healthcheck
```

If `/health` works but `/ready` returns 503, check the JSON body for `"schema": "missing"` or `"media": "error"`.

**Start API only (skip admin dependency):**

```bash
docker compose -f docker-compose.home.yml --env-file .env.home up -d --no-deps api
```

## Keep laptop awake (Linux)

```bash
sudo systemctl mask sleep.target suspend.target hibernate.target
```

Or disable sleep in power settings.

## Troubleshooting Azure blob setup

### `404 ResourceNotFound` on storage account keys

Azure sometimes needs a minute after creating a storage account before keys/blob APIs work. This is usually a timing issue, not a wrong subscription.

**Step 1 — check Azure (PowerShell on Windows):**

```powershell
az account show
az provider show --namespace Microsoft.Storage --query registrationState
az group show -n rg-margem-home-sub1
az storage account show -n margemhomesub1stpbqc13 -g rg-margem-home-sub1
```

If `Microsoft.Storage` is not `Registered`, run:

```powershell
az provider register --namespace Microsoft.Storage
# wait 1-2 minutes, then retry
```

**Step 2 — retry Terraform:**

```powershell
cd souq-local\infra\terraform-storage
terraform init -upgrade
terraform apply
```

**Step 3 — if it still fails, clean up and start fresh:**

```powershell
terraform destroy
terraform apply
```

If `destroy` complains about missing resources:

```powershell
terraform state list
terraform state rm azurerm_storage_container.media
terraform state rm azurerm_storage_account.media
terraform apply
```

Or delete the resource group in the [Azure Portal](https://portal.azure.com), then run `terraform apply` again.

**Step 4 — pull latest repo** (includes a 60s wait fix between storage account and container):

```powershell
git pull origin cursor/production-ready-f384
.\setup_azure_blob.ps1
```

## Delete Azure blob only

```bash
cd infra/terraform-storage
terraform destroy
```
