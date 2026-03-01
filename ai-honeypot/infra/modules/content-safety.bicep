// ============================================================================
// Azure AI Content Safety — F0 (Free tier, 5K transactions/month)
// ============================================================================

@description('Azure region')
param location string

@description('Unique suffix for naming')
param uniqueSuffix string

@description('Resource tags')
param tags object

// ---------------------------------------------------------------------------
// Content Safety Resource
// ---------------------------------------------------------------------------
resource contentSafety 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: 'cs-honeypot-${uniqueSuffix}'
  location: location
  tags: tags
  kind: 'ContentSafety'
  sku: {
    name: 'F0' // Free tier: 5,000 transactions/month
  }
  properties: {
    customSubDomainName: 'cs-honeypot-${uniqueSuffix}'
    publicNetworkAccess: 'Enabled'
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Content Safety endpoint URL')
output endpoint string = contentSafety.properties.endpoint

@description('Content Safety API key (primary)')
output apiKey string = contentSafety.listKeys().key1
