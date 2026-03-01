// ============================================================================
// Azure OpenAI — prod (gpt-4o) + shadow (gpt-4o-mini) deployments
// ============================================================================

@description('Azure region')
param location string

@description('Unique suffix for naming')
param uniqueSuffix string

@description('Resource tags')
param tags object

// ---------------------------------------------------------------------------
// Azure OpenAI Cognitive Services Account
// ---------------------------------------------------------------------------
resource openaiAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: 'oai-honeypot-${uniqueSuffix}'
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: 'oai-honeypot-${uniqueSuffix}'
    publicNetworkAccess: 'Enabled'
  }
}

// ---------------------------------------------------------------------------
// Production Deployment: GPT-4o
// ---------------------------------------------------------------------------
resource prodDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: openaiAccount
  name: 'prod-gpt4o'
  sku: {
    name: 'Standard'
    capacity: 10 // 10K tokens per minute — minimal for MVP
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-11-20'
    }
  }
}

// ---------------------------------------------------------------------------
// Shadow/Honeypot Deployment: GPT-4o-mini (33x cheaper)
// ---------------------------------------------------------------------------
resource shadowDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: openaiAccount
  name: 'shadow-gpt4o-mini'
  sku: {
    name: 'Standard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini'
      version: '2024-07-18'
    }
  }
  dependsOn: [
    prodDeployment // Serial deployment to avoid conflicts
  ]
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Azure OpenAI endpoint URL')
output endpoint string = openaiAccount.properties.endpoint

@description('Azure OpenAI API key (primary)')
output apiKey string = openaiAccount.listKeys().key1
