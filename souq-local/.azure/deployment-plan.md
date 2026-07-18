# MarGem Production Deployment

Deploy the API to Azure with PostgreSQL, Key Vault, Blob Storage, and Container Apps. **No demo users or businesses are seeded** — you create real accounts through the app.

## Prerequisites

- One or more Azure subscriptions
- [Terraform](https://www.terraform.io/downloads) >= 1.5
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) logged in (`az login`)
- Docker (to build the API image)

List your subscriptions:

```bash
az account list --output table
```

## 1. Configure secrets

```bash
cd souq-local/infra/terraform
cp terraform.tfvars.example terraform.tfvars
```

**Multiple subscriptions:** copy `subscriptions/sub1.tfvars.example` → `subscriptions/sub1.tfvars` (and `sub2` for a second subscription). Use `-var-file=subscriptions/sub1.tfvars` instead of a single `terraform.tfvars` when applying.

Edit your tfvars file(s):

- `subscription_id` — Azure subscription GUID to deploy into
- `subscription_alias` — short label (`sub1`, `sub2`, …) used in resource names
- `postgres_admin_password` — strong password (8+ chars)
- `jwt_secret_key` — random string, **32+ characters**
- `cors_origins` — your real origins, e.g. `["https://margem.app"]` (no `*`)
- `api_image` — set after pushing to ACR (step 3)

## 2. Provision Azure infrastructure

```bash
# Single subscription (terraform.tfvars)
terraform init
terraform plan
terraform apply

# Or per-subscription with isolated state
terraform apply -state=terraform-sub1.tfstate -var-file=subscriptions/sub1.tfvars
```

When the first subscription's credits are used up, deploy to a second subscription without touching the first stack:

```bash
terraform apply -state=terraform-sub2.tfstate -var-file=subscriptions/sub2.tfvars
```

See `infra/terraform/README.md` for workspaces and remote state options.

This creates:

| Resource | Purpose |
|----------|---------|
| PostgreSQL Flexible Server | Production database |
| Key Vault | Stores DB URL, JWT secret, storage connection string |
| Blob Storage | Seller/product images |
| Container Apps | Hosts the FastAPI API |
| Application Insights | Monitoring and logs |
| Container Registry | API Docker images |

Note the outputs:

```bash
terraform output api_url
terraform output key_vault_name
```

## 3. Build and deploy the API image

```bash
cd ../../backend
ACR=$(terraform -chdir=../infra/terraform output -raw container_registry_login_server)

az acr login --name ${ACR%%.azurecr.io}
docker build -t $ACR/margem-api:1.0.0 .
docker push $ACR/margem-api:1.0.0
```

Update your tfvars (match the ACR name for your subscription alias, e.g. `margemregsub1`):

```hcl
api_image = "margemregsub1.azurecr.io/margem-api:1.0.0"
```

```bash
cd ../infra/terraform
terraform apply
```

Migrations run automatically on container start (`alembic upgrade head`). Category taxonomy is seeded by migration `002` only — no demo businesses.

## 4. Verify the API

```bash
curl https://YOUR-API-URL/health
```

Expected:

```json
{"status":"ok","database":"ok","environment":"prod",...}
```

## 5. Build the mobile app for production

```bash
cd ../../mobile
flutter pub get

flutter build apk \
  --dart-define=PRODUCTION=true \
  --dart-define=API_BASE_URL=https://YOUR-API-URL
```

Optional (Google Maps):

```bash
flutter build apk \
  --dart-define=PRODUCTION=true \
  --dart-define=API_BASE_URL=https://YOUR-API-URL \
  --dart-define=ENABLE_MAPS=true \
  --dart-define=GOOGLE_MAPS_API_KEY=your_key
```

Add the Maps key to `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_KEY"/>
```

## 6. Local development (optional)

```bash
cd souq-local
docker compose up --build
```

- Runs Postgres + API with migrations (no demo users)
- Register accounts through the app
- For a physical phone: `flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:8000`

## Security checklist

- [ ] `JWT_SECRET_KEY` is 32+ random characters (stored in Key Vault)
- [ ] `CORS_ORIGINS` does not include `*`
- [ ] `ALLOWED_HOSTS` set to your API FQDN only
- [ ] `AUTH_DEV_BYPASS=false` in production
- [ ] Key Vault purge protection enabled
- [ ] PostgreSQL firewall reviewed for your environment
- [ ] Release APK signed with a production keystore (not debug)
- [ ] Privacy policy published before Play Store submission
- [ ] Passwords require upper, lower, and number (enforced by API)
- [ ] Short-lived access tokens (60 min) + refresh token rotation

## Estimated Azure cost

~$50–90/month (PostgreSQL B1ms, Container Apps, Storage, Log Analytics).
