# MarGem — cheapest Azure deploy (1 small VM + blob storage)
# Usage: .\start_azure_budget.ps1
#        .\start_azure_budget.ps1 -InfraOnly   # terraform only, skip app deploy

param(
    [switch]$InfraOnly
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$TfDir = Join-Path $Root "infra\terraform-budget"
$TfVars = Join-Path $TfDir "terraform.tfvars"
$TfExample = Join-Path $TfDir "terraform.tfvars.example"
$SshKey = Join-Path $env:USERPROFILE ".ssh\id_rsa"
$SshPub = "$SshKey.pub"

function Get-TfVarValue {
    param([string]$Path, [string]$Name)
    $line = Select-String -Path $Path -Pattern "^\s*$Name\s*=" | Select-Object -First 1
    if ($line -match '=\s*"(.*)"') { return $Matches[1] }
    throw "Missing $Name in $Path"
}

Write-Host ""
Write-Host "=== MarGem Budget Azure Deploy ===" -ForegroundColor Cyan
Write-Host "  ~`$15-25/month (1 VM + storage)" -ForegroundColor DarkGray
Write-Host ""

# Prerequisites
foreach ($cmd in @("az", "terraform", "ssh", "scp")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "Missing '$cmd'. Install Azure CLI, Terraform, and OpenSSH client."
    }
}

az account show 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Logging into Azure..."
    az login | Out-Null
}

if (-not (Test-Path $TfVars)) {
    if (Test-Path $TfExample) {
        Copy-Item $TfExample $TfVars
        Write-Host "Created $TfVars"
        Write-Host ""
        Write-Host "Edit terraform.tfvars:"
        Write-Host "  - subscription_id"
        Write-Host "  - ssh_public_key  (run: Get-Content `$env:USERPROFILE\.ssh\id_rsa.pub)"
        Write-Host "  - postgres_password, jwt_secret_key"
        Write-Host ""
        Write-Host "Generate SSH key if needed:"
        Write-Host "  ssh-keygen -t rsa -b 4096"
        exit 1
    }
    Write-Error "Missing $TfVars"
}

if (-not (Test-Path $SshKey)) {
    Write-Error "SSH private key not found at $SshKey — run: ssh-keygen -t rsa -b 4096"
}

# Ensure ssh_public_key in tfvars matches local key (helpful hint)
$pubContent = (Get-Content $SshPub -Raw).Trim()
$tfPub = Get-TfVarValue -Path $TfVars -Name "ssh_public_key"
if ($tfPub -notmatch [regex]::Escape($pubContent.Substring(0, [Math]::Min(40, $pubContent.Length)))) {
    Write-Warning "ssh_public_key in terraform.tfvars may not match $SshPub"
}

# Terraform
Push-Location $TfDir
try {
    if (-not (Test-Path ".terraform")) { terraform init }
    Write-Host "[1/4] Creating Azure resources (VM + storage)..."
    terraform apply -auto-approve
    if ($LASTEXITCODE -ne 0) { throw "terraform apply failed" }

    $vmIp = terraform output -raw vm_public_ip
    $apiUrl = terraform output -raw api_url
    $storageConn = terraform output -raw storage_connection_string
    $adminUser = Get-TfVarValue -Path $TfVars -Name "admin_username"
    if (-not $adminUser) { $adminUser = "azureuser" }
    $pgPass = Get-TfVarValue -Path $TfVars -Name "postgres_password"
    $jwt = Get-TfVarValue -Path $TfVars -Name "jwt_secret_key"
    try { $adminUser = Get-TfVarValue -Path $TfVars -Name "admin_username" } catch { $adminUser = "azureuser" }
    if ($LASTEXITCODE -eq 0) {
        $sshReady = $true
        break
    }
    Start-Sleep -Seconds 5
}
if (-not $sshReady) {
    Write-Error "SSH/Docker not ready. Try again in a few minutes: ssh ${adminUser}@${vmIp}"
}

# Build .env for compose
$envContent = @"
POSTGRES_PASSWORD=$pgPass
JWT_SECRET_KEY=$jwt
AZURE_STORAGE_CONNECTION_STRING=$storageConn
CORS_ORIGINS=["http://${vmIp}:8000"]
ALLOWED_HOSTS=["${vmIp}","${vmIp}:8000"]
"@
$envFile = Join-Path $Root ".budget-deploy.env"
Set-Content -Path $envFile -Value $envContent -NoNewline

# Upload app
Write-Host "[3/4] Uploading app to VM (may take a few minutes)..."
ssh -i $SshKey -o StrictHostKeyChecking=no "${adminUser}@${vmIp}" "mkdir -p ~/margem/backend"
scp -i $SshKey -o StrictHostKeyChecking=no `
    (Join-Path $Root "docker-compose.budget.yml") `
    "${adminUser}@${vmIp}:~/margem/docker-compose.budget.yml"
scp -i $SshKey -o StrictHostKeyChecking=no `
    $envFile `
    "${adminUser}@${vmIp}:~/margem/.env"

# Copy backend (exclude cache)
$backendSrc = Join-Path $Root "backend"
scp -i $SshKey -o StrictHostKeyChecking=no -r `
    "$backendSrc\app" `
    "$backendSrc\scripts" `
    "$backendSrc\alembic" `
    "$backendSrc\alembic.ini" `
    "$backendSrc\requirements.txt" `
    "$backendSrc\Dockerfile" `
    "${adminUser}@${vmIp}:~/margem/backend/"

Write-Host "[4/4] Building and starting containers on VM..."
ssh -i $SshKey -o StrictHostKeyChecking=no "${adminUser}@${vmIp}" @"
cd ~/margem && docker compose -f docker-compose.budget.yml --env-file .env up -d --build
"@

# Health check
Start-Sleep -Seconds 8
try {
    $health = Invoke-WebRequest -Uri "$apiUrl/health" -UseBasicParsing -TimeoutSec 15
    if ($health.StatusCode -eq 200) {
        Write-Host ""
        Write-Host "=== Budget deploy OK ===" -ForegroundColor Green
    }
}
catch {
    Write-Warning "API not responding yet. Check logs: ssh ${adminUser}@${vmIp} 'cd margem && docker compose -f docker-compose.budget.yml logs api'"
}

Write-Host ""
Write-Host "API URL:  $apiUrl"
Write-Host "Health:   $apiUrl/health"
Write-Host ""
Write-Host "Flutter (beta — HTTP, not Play Store production):"
Write-Host "  flutter run --dart-define=API_BASE_URL=$apiUrl"
Write-Host ""
Write-Host "Stop VM (save money):  .\stop_azure_budget.ps1 -Deallocate"
Write-Host "Delete everything:     .\stop_azure_budget.ps1 -Destroy"
Write-Host ""

Remove-Item $envFile -Force -ErrorAction SilentlyContinue
