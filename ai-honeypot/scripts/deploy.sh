#!/bin/bash
# ============================================================================
# AI Honeypot MVP — One-Command Deployment
# ============================================================================
set -euo pipefail

RESOURCE_GROUP="rg-ai-honeypot"
LOCATION="eastus2"
DEPLOYMENT_NAME="ai-honeypot-main"

echo "========================================="
echo "  AI Honeypot MVP Deployment"
echo "========================================="
echo ""

# Check prerequisites
echo "[0/4] Checking prerequisites..."
command -v az >/dev/null 2>&1 || { echo "ERROR: Azure CLI not found. Install from https://aka.ms/installazurecliwindows"; exit 1; }
command -v func >/dev/null 2>&1 || { echo "ERROR: Azure Functions Core Tools not found. Run: npm install -g azure-functions-core-tools@4"; exit 1; }

# Verify logged in
az account show >/dev/null 2>&1 || { echo "ERROR: Not logged in to Azure. Run: az login"; exit 1; }

SUBSCRIPTION=$(az account show --query name -o tsv)
echo "  Subscription: $SUBSCRIPTION"
echo ""

# Step 1: Create resource group
echo "[1/4] Creating resource group '$RESOURCE_GROUP' in '$LOCATION'..."
az group create --name $RESOURCE_GROUP --location $LOCATION --output none
echo "  Done."
echo ""

# Step 2: Deploy infrastructure via Bicep
echo "[2/4] Deploying infrastructure via Bicep (this takes 3-5 minutes)..."
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --name $DEPLOYMENT_NAME \
  --template-file infra/main.bicep \
  --parameters @infra/parameters.dev.json \
  --output none
echo "  Done."
echo ""

# Step 3: Retrieve outputs
echo "[3/4] Retrieving deployment outputs..."
FUNCTION_APP_NAME=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name $DEPLOYMENT_NAME \
  --query properties.outputs.functionAppName.value -o tsv)

APIM_GATEWAY_URL=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name $DEPLOYMENT_NAME \
  --query properties.outputs.apimGatewayUrl.value -o tsv)

echo "  Function App: $FUNCTION_APP_NAME"
echo "  APIM Gateway: $APIM_GATEWAY_URL"
echo ""

# Step 4: Deploy function code
echo "[4/4] Deploying function code to '$FUNCTION_APP_NAME'..."
pushd functions > /dev/null
func azure functionapp publish $FUNCTION_APP_NAME --python
popd > /dev/null
echo "  Done."
echo ""

echo "========================================="
echo "  Deployment Complete!"
echo "========================================="
echo ""
echo "  APIM Gateway URL: $APIM_GATEWAY_URL"
echo "  Function App:     $FUNCTION_APP_NAME"
echo ""
echo "  Next steps:"
echo "    1. Create an APIM subscription key in the Azure Portal"
echo "    2. Run: ./scripts/demo-requests.sh"
echo "    3. Check Table Storage for attack logs"
echo ""
