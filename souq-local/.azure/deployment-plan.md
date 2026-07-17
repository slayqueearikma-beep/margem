# MarGem — Azure deployment plan

## Architecture

| Component | Azure service | Purpose |
|-----------|---------------|---------|
| API | Container Apps | FastAPI backend |
| Database | PostgreSQL Flexible Server | Users, sellers, reviews |
| Images | Blob Storage | Product/seller photos |
| Secrets | Key Vault | JWT, DB password, storage keys |

Estimated cost: **~$50–90 USD/month** at launch (Burstable DB + scale-to-zero API).

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- Docker (to build API image)
- Azure subscription

## 1. Create resource group

```bash
az login
az group create --name rg-margem-prod --location westeurope
```

## 2. Deploy infrastructure

```bash
export MARGEM_PG_PASSWORD='your-strong-postgres-password'
export MARGEM_JWT_SECRET='your-32-char-minimum-jwt-secret'

az deployment group create \
  --resource-group rg-margem-prod \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam \
  --parameters postgresAdminPassword="$MARGEM_PG_PASSWORD" \
               jwtSecretKey="$MARGEM_JWT_SECRET"
```

Note the `apiUrl` output — this is your production API base URL.

## 3. Build and push API container

```bash
# Create Azure Container Registry (one time)
az acr create --resource-group rg-margem-prod --name margemregistry --sku Basic

cd backend
az acr build --registry margemregistry --image margem-api:1.0.0 .

# Update Container App image
az containerapp update \
  --name margem-prod-api \
  --resource-group rg-margem-prod \
  --image margemregistry.azurecr.io/margem-api:1.0.0
```

## 4. Run database migrations

```bash
# From your machine with DATABASE_URL pointing to Azure PostgreSQL
cd backend
pip install -r requirements.txt
alembic upgrade head
python scripts/seed.py
```

## 5. Configure mobile app

```bash
flutter run --dart-define=API_BASE_URL=https://YOUR-API-URL \
           --dart-define=DEMO_FALLBACK=false
```

## 6. Security checklist (production)

- [ ] `AUTH_DEV_BYPASS=false`
- [ ] Strong `JWT_SECRET_KEY` in Key Vault
- [ ] PostgreSQL firewall: restrict to Container Apps outbound IPs
- [ ] CORS: set exact app origins (not `*`)
- [ ] Google Maps API key restricted by package name
- [ ] Enable Azure Monitor / Application Insights
- [ ] TLS only on Container Apps ingress (default)

## Local development (full stack)

```bash
cd souq-local
docker compose up
```

API: http://localhost:8000  
Demo accounts after seed:
- buyer@demo.local / demo1234
- seller@demo.local / demo1234
