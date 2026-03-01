# ============================================================================
# AI Honeypot MVP — Deployment Script (PowerShell)
# Run from the project root: .\scripts\deploy.ps1
# ============================================================================

$ErrorActionPreference = "Stop"

$RESOURCE_GROUP = "rg-ai-honeypot"
$LOCATION = "eastus2"
$DEPLOYMENT_NAME = "ai-honeypot-main"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  AI Honeypot MVP Deployment" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
Write-Host "[0/4] Checking prerequisites..." -ForegroundColor Yellow
try { az version | Out-Null } catch { Write-Error "Azure CLI not found. Install from https://aka.ms/installazurecliwindows"; exit 1 }
try { func --version | Out-Null } catch { Write-Error "Azure Functions Core Tools not found. Run: npm install -g azure-functions-core-tools@4"; exit 1 }

# Verify logged in
try {
    $account = az account show | ConvertFrom-Json
    Write-Host "  Subscription: $($account.name)" -ForegroundColor Green
} catch {
    Write-Error "Not logged in to Azure. Run: az login"
    exit 1
}
Write-Host ""

# Step 1: Create resource group
Write-Host "[1/4] Creating resource group '$RESOURCE_GROUP' in '$LOCATION'..." -ForegroundColor Yellow
az group create --name $RESOURCE_GROUP --location $LOCATION --output none
Write-Host "  Done." -ForegroundColor Green
Write-Host ""

# Step 2: Deploy infrastructure via Bicep
Write-Host "[2/4] Deploying infrastructure via Bicep (this takes 3-5 minutes)..." -ForegroundColor Yellow
az deployment group create `
  --resource-group $RESOURCE_GROUP `
  --name $DEPLOYMENT_NAME `
  --template-file infra/main.bicep `
  --parameters "@infra/parameters.dev.json" `
  --output none
Write-Host "  Done." -ForegroundColor Green
Write-Host ""

# Step 3: Retrieve outputs
Write-Host "[3/4] Retrieving deployment outputs..." -ForegroundColor Yellow
$FUNCTION_APP_NAME = az deployment group show `
  --resource-group $RESOURCE_GROUP `
  --name $DEPLOYMENT_NAME `
  --query "properties.outputs.functionAppName.value" -o tsv

$APIM_GATEWAY_URL = az deployment group show `
  --resource-group $RESOURCE_GROUP `
  --name $DEPLOYMENT_NAME `
  --query "properties.outputs.apimGatewayUrl.value" -o tsv

Write-Host "  Function App: $FUNCTION_APP_NAME" -ForegroundColor Green
Write-Host "  APIM Gateway: $APIM_GATEWAY_URL" -ForegroundColor Green
Write-Host ""

# Step 4: Deploy function code
Write-Host "[4/4] Deploying function code to '$FUNCTION_APP_NAME'..." -ForegroundColor Yellow
Push-Location functions
func azure functionapp publish $FUNCTION_APP_NAME --python
Pop-Location
Write-Host "  Done." -ForegroundColor Green
Write-Host ""

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Deployment Complete!" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  APIM Gateway URL: $APIM_GATEWAY_URL"
Write-Host "  Function App:     $FUNCTION_APP_NAME"
Write-Host ""
Write-Host "  Next steps:"
Write-Host "    1. Create an APIM subscription key in the Azure Portal"
Write-Host "    2. Run: .\scripts\demo-requests.ps1"
Write-Host "    3. Check Table Storage for attack logs"
Write-Host ""
