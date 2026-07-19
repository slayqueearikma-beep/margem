# MarGem Home Server — Laptop + Azure Blob

Run the API and database on **your laptop**, store images in **Azure Blob** (~$1–3/month).

## Architecture

```
Your laptop (Linux)          Azure (~$1-3/mo)
┌─────────────────────┐      ┌──────────────────┐
│ Docker              │      │ Blob Storage     │
│  ├── Postgres       │      │  margem-media/   │
│  └── FastAPI :8000  │─────▶│  (images only)   │
└─────────────────────┘      └──────────────────┘
         ▲
    Phone / users
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

### On Windows (setup Azure blob from your dev PC)

```powershell
cd souq-local
.\setup_azure_blob.ps1
```

Or on the laptop with Terraform:

```bash
cd infra/terraform-storage
cp terraform.tfvars.example terraform.tfvars
# edit subscription_id
terraform init && terraform apply
```

### Configure `.env.home`

```powershell
copy env.home.example .env.home
```

Edit `.env.home`:

| Variable | Example |
|----------|---------|
| `POSTGRES_PASSWORD` | Strong password |
| `JWT_SECRET_KEY` | 32+ random chars |
| `AZURE_STORAGE_CONNECTION_STRING` | From `setup_azure_blob.ps1` |
| `ALLOWED_HOSTS` | `["192.168.1.50","192.168.1.50:8000"]` — your laptop LAN IP |
| `CORS_ORIGINS` | `["http://192.168.1.50:8000"]` |

Find laptop IP:

```bash
hostname -I | awk '{print $1}'    # Linux
```

```powershell
ipconfig   # Windows — look for IPv4
```

## Start / stop

**Linux laptop:**

```bash
docker compose -f docker-compose.home.yml --env-file .env.home up -d --build
docker compose -f docker-compose.home.yml --env-file .env.home down
```

**Windows (if laptop runs Windows):**

```powershell
.\start_home_server.ps1
.\stop_home_server.ps1
```

## Connect from phone

### Same Wi-Fi

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

## Keep laptop awake (Linux)

```bash
sudo systemctl mask sleep.target suspend.target hibernate.target
```

Or disable sleep in power settings.

## Delete Azure blob only

```bash
cd infra/terraform-storage
terraform destroy
```
