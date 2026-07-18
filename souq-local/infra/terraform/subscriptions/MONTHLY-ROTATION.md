# Monthly subscription rotation (sub1 → sub2 → sub3 …)

Use **one subscription at a time**. When that subscription’s free credits or budget hits **$0**, tear down that stack and deploy the same app on the next subscription.

You are **not** running multiple stacks in parallel — you rotate month by month.

## One-time setup

```bash
az login
az account list --output table
```

Create a tfvars file for each subscription you might use:

```bash
cd souq-local/infra/terraform

cp subscriptions/sub1.tfvars.example subscriptions/sub1.tfvars
cp subscriptions/sub2.tfvars.example subscriptions/sub2.tfvars
# Add sub3.tfvars, sub4.tfvars, … the same way when needed
```

In each file set:

| Field | Example |
|-------|---------|
| `subscription_id` | GUID from `az account list` |
| `subscription_alias` | `sub1`, `sub2`, `sub3`, … (must be unique per month) |
| `postgres_admin_password` | New strong password each month |
| `jwt_secret_key` | New 32+ char secret each month |

## Month 1 — deploy on sub1

**PowerShell (Windows):**

```powershell
cd souq-local\infra\terraform
.\scripts\switch-subscription.ps1 -Sub 1
```

**Bash:**

```bash
cd souq-local/infra/terraform
./scripts/switch-subscription.sh 1
```

**Manual:**

```bash
terraform init
terraform apply -state=terraform-sub1.tfstate -var-file=subscriptions/sub1.tfvars
terraform output -state=terraform-sub1.tfstate api_url
```

Build/push the API image, then point the mobile app at that `api_url`.

## When sub1 budget hits $0 — move to sub2

### Step 1 (optional): Back up data from sub1

If you need to keep users/sellers/reviews, dump PostgreSQL **before** destroying sub1:

```bash
# While sub1 is still running
PGHOST=$(terraform output -state=terraform-sub1.tfstate -raw postgres_host)
# Use pg_dump with the password from subscriptions/sub1.tfvars
pg_dump "postgresql://margemadmin:PASSWORD@${PGHOST}:5432/margem?sslmode=require" -Fc -f margem-sub1-backup.dump
```

Blob images are in sub1’s storage account — copy them manually if you need them on sub2.

If you skip backup, sub2 starts with an **empty database** (only category taxonomy from migrations).

### Step 2: Destroy sub1 (stops billing)

```powershell
.\scripts\destroy-subscription.ps1 -Sub 1
```

Or:

```bash
terraform destroy -state=terraform-sub1.tfstate -var-file=subscriptions/sub1.tfvars
```

### Step 3: Deploy on sub2

```powershell
.\scripts\switch-subscription.ps1 -Sub 2
```

Push the API image to the **new** ACR (`margemregsub2`), update `api_image` in `subscriptions/sub2.tfvars`, and run `terraform apply` again if needed.

### Step 4: Rebuild the mobile app

The API URL **changes** every rotation (new Container App FQDN):

```powershell
cd ..\..\mobile
$api = terraform -chdir=..\infra\terraform output -state=terraform-sub2.tfstate -raw api_url
flutter build apk --dart-define=PRODUCTION=true --dart-define=API_BASE_URL=$api
```

### Step 5 (optional): Restore backup on sub2

```bash
PGHOST=$(terraform output -state=terraform-sub2.tfstate -raw postgres_host)
pg_restore -d "postgresql://margemadmin:PASSWORD@${PGHOST}:5432/margem?sslmode=require" margem-sub1-backup.dump
```

## Month 3, 4, …

Repeat: destroy `subN`, deploy `sub(N+1)`:

```powershell
.\scripts\destroy-subscription.ps1 -Sub 2
.\scripts\switch-subscription.ps1 -Sub 3
```

Copy `subscriptions/sub2.tfvars.example` → `sub3.tfvars` and set the new `subscription_id`.

## Important notes

- **Destroy the old subscription** when credits run out, or leftover resources (PostgreSQL, Container Apps) can still incur charges.
- **API URL changes** each rotation unless you add a custom domain in front of Container Apps.
- **JWT secret changes** each month if you use new tfvars — existing app tokens from the old month will not work on the new stack (users re-login).
- Terraform **always** uses `subscription_id` from your tfvars file, not whatever `az account` shows.
