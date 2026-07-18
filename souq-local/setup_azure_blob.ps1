# Create Azure Blob Storage only (~$1-3/mo) for home server image uploads
# Usage: .\setup_azure_blob.ps1

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$TfDir = Join-Path $Root "infra\terraform-storage"
$TfVars = Join-Path $TfDir "terraform.tfvars"
$Example = Join-Path $TfDir "terraform.tfvars.example"
$EnvHome = Join-Path $Root ".env.home"
$EnvExample = Join-Path $Root "env.home.example"

Write-Host ""
Write-Host "=== MarGem — Azure Blob only (~`$1-3/mo) ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Install Azure CLI: https://aka.ms/installazurecliwindows"
}

az account show 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { az login | Out-Null }

if (-not (Test-Path $TfVars)) {
    Copy-Item $Example $TfVars
    Write-Host "Created $TfVars — set subscription_id, then re-run."
    exit 1
}

Push-Location $TfDir
try {
    if (-not (Test-Path ".terraform")) { terraform init }
    terraform apply -auto-approve
    $conn = terraform output -raw storage_connection_string
    $rg = terraform output -raw resource_group_name
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "Blob storage created in $rg" -ForegroundColor Green
Write-Host ""

if (-not (Test-Path $EnvHome)) {
    Copy-Item $EnvExample $EnvHome
    Write-Host "Created .env.home — edit ALLOWED_HOSTS with your laptop IP."
}

# Inject connection string into .env.home if placeholder
$content = Get-Content $EnvHome -Raw
if ($content -match 'AZURE_STORAGE_CONNECTION_STRING=DefaultEndpointsProtocol' -and $content -notmatch 'AccountName=\w{3,}') {
    $content = $content -replace 'AZURE_STORAGE_CONNECTION_STRING=.*', "AZURE_STORAGE_CONNECTION_STRING=$conn"
    Set-Content $EnvHome $content -NoNewline
    Write-Host "Updated AZURE_STORAGE_CONNECTION_STRING in .env.home"
}

Write-Host ""
Write-Host "Next:"
Write-Host "  1. Edit .env.home (passwords + ALLOWED_HOSTS = your laptop IP)"
Write-Host "  2. .\start_home_server.ps1"
Write-Host ""
