# MarGem — Terraform (Azure)

Deploys the full MarGem backend stack on Azure:

| Resource | Purpose |
|----------|---------|
| Resource Group | All MarGem resources |
| PostgreSQL Flexible Server | Users, sellers, reviews |
| Blob Storage | Product/seller images |
| Key Vault | Secrets (RBAC-enabled) |
| Container Apps Environment + App | FastAPI API |
| Container Registry (optional) | API Docker images |

Estimated cost: **~$50–90 USD/month** at launch.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- One or more Azure subscriptions

## Quick deploy (single subscription)

```bash
az login

# List subscriptions and copy the ID you want to use
az account list --output table

cd souq-local/infra/terraform

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set subscription_id, postgres_admin_password, jwt_secret_key

terraform init
terraform plan
terraform apply
```

Note the `api_url` output after apply.

## Switching between subscriptions

Each Azure subscription gets its **own isolated stack** with unique names (resource group, ACR, Key Vault, etc.). Use a different `subscription_id` and `subscription_alias` per subscription.

### 1. Create per-subscription variable files

```bash
cp subscriptions/sub1.tfvars.example subscriptions/sub1.tfvars
cp subscriptions/sub2.tfvars.example subscriptions/sub2.tfvars
```

Edit each file:

| Field | sub1 | sub2 |
|-------|------|------|
| `subscription_id` | Your first subscription GUID | Your second subscription GUID |
| `subscription_alias` | `sub1` | `sub2` |
| Secrets | Unique passwords per environment | Unique passwords per environment |

Resource names are derived automatically, e.g. `rg-margem-prod-sub1` vs `rg-margem-prod-sub2`, and ACR `margemregsub1` vs `margemregsub2`.

### 2. Keep separate Terraform state per subscription

**Option A — separate state files (simplest, local)**

```bash
# Deploy to subscription 1
terraform apply -state=terraform-sub1.tfstate -var-file=subscriptions/sub1.tfvars

# When credits run out, deploy to subscription 2
terraform apply -state=terraform-sub2.tfstate -var-file=subscriptions/sub2.tfvars
```

**Option B — Terraform workspaces**

```bash
terraform workspace new sub1
terraform apply -var-file=subscriptions/sub1.tfvars

terraform workspace new sub2
terraform apply -var-file=subscriptions/sub2.tfvars

# Switch back to manage sub1
terraform workspace select sub1
```

**Option C — remote state in Azure Storage (teams)**

```bash
cp backends/remote-sub1.backend.hcl.example backends/remote-sub1.backend.hcl
cp backends/remote-sub2.backend.hcl.example backends/remote-sub2.backend.hcl
# Edit both files — use a different `key` per subscription

terraform init -reconfigure -backend-config=backends/remote-sub1.backend.hcl
terraform apply -var-file=subscriptions/sub1.tfvars

terraform init -reconfigure -backend-config=backends/remote-sub2.backend.hcl
terraform apply -var-file=subscriptions/sub2.tfvars
```

### 3. Verify the active Azure CLI account (optional)

Terraform always targets `subscription_id` from your tfvars file. You can still align the CLI for `az` commands:

```bash
az account set --subscription "00000000-0000-0000-0000-000000000001"
az account show --output table
```

### 4. Point the mobile app at the new API

After switching subscriptions, rebuild the app with the new API URL:

```bash
flutter build apk \
  --dart-define=PRODUCTION=true \
  --dart-define=API_BASE_URL=$(terraform output -raw api_url)
```

Run `terraform output` in the same state/workspace you used for that subscription.

## Build and deploy API image

```bash
# If ACR was created (default)
ACR=$(terraform output -raw container_registry_login_server)
ACR_NAME=$(terraform output -raw acr_name)
RG=$(terraform output -raw resource_group_name)
API_APP=$(terraform output -raw api_url | sed 's|https://||')

az acr login --name "$ACR_NAME"
cd ../../backend
az acr build --registry "$ACR_NAME" --image margem-api:1.0.0 .

# Update Container App to use ACR image
az containerapp update \
  --name "$(echo $API_APP | cut -d. -f1)" \
  --resource-group "$RG" \
  --image "${ACR}/margem-api:1.0.0"
```

Or set `api_image` in your tfvars before `terraform apply`.

## Database migrations

Migrations run automatically on container start. For manual runs:

```bash
export DATABASE_URL="postgresql+asyncpg://margemadmin:YOUR_PASSWORD@$(terraform output -raw postgres_host):5432/margem?ssl=require"

cd ../../backend
pip install -r requirements.txt
alembic upgrade head
```

## Mobile app

```bash
flutter run \
  --dart-define=PRODUCTION=true \
  --dart-define=API_BASE_URL=$(cd infra/terraform && terraform output -raw api_url)
```

## Destroy (careful)

Destroy only the stack for the subscription you are managing (match `-state` or workspace):

```bash
terraform destroy -state=terraform-sub1.tfstate -var-file=subscriptions/sub1.tfvars
```

## Bicep alternative

Bicep templates are still available in `infra/main.bicep` if you prefer ARM/Bicep over Terraform.
