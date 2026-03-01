// ============================================================================
// Azure AI Services — prod + shadow (gpt-oss-120b) deployments
// Uses AIServices (multi-service) account for broader model/quota access
// ============================================================================

@description('Azure region')
param location string

@description('Unique suffix for naming')
param uniqueSuffix string

@description('Resource tags')
param tags object

@description('Whether to create model deployments in this environment')
param deployModelDeployments bool = true

// ---------------------------------------------------------------------------
// Azure AI Services Account (multi-service — includes OpenAI models)
// ---------------------------------------------------------------------------
resource aiServicesAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: 'ais-honeypot-${uniqueSuffix}'
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: 'ais-honeypot-${uniqueSuffix}'
    publicNetworkAccess: 'Enabled'
  }
}

// ---------------------------------------------------------------------------
// Custom RAI Policy: Permissive filter for honeypot shadow deployment
// Jailbreak blocking disabled so honeypot can respond to attack prompts
// ---------------------------------------------------------------------------
resource permissivePolicy 'Microsoft.CognitiveServices/accounts/raiPolicies@2024-10-01' = {
  parent: aiServicesAccount
  name: 'honeypot-permissive'
  properties: {
    basePolicyName: 'Microsoft.DefaultV2'
    mode: 'Blocking'
    contentFilters: [
      { name: 'Hate'; severityThreshold: 'High'; blocking: true; enabled: true; source: 'Prompt' }
      { name: 'Hate'; severityThreshold: 'High'; blocking: true; enabled: true; source: 'Completion' }
      { name: 'Sexual'; severityThreshold: 'High'; blocking: true; enabled: true; source: 'Prompt' }
      { name: 'Sexual'; severityThreshold: 'High'; blocking: true; enabled: true; source: 'Completion' }
      { name: 'Violence'; severityThreshold: 'High'; blocking: true; enabled: true; source: 'Prompt' }
      { name: 'Violence'; severityThreshold: 'High'; blocking: true; enabled: true; source: 'Completion' }
      { name: 'Selfharm'; severityThreshold: 'High'; blocking: true; enabled: true; source: 'Prompt' }
      { name: 'Selfharm'; severityThreshold: 'High'; blocking: true; enabled: true; source: 'Completion' }
      { name: 'Jailbreak'; blocking: false; enabled: true; source: 'Prompt' }
      { name: 'Protected Material Text'; blocking: false; enabled: true; source: 'Completion' }
      { name: 'Protected Material Code'; blocking: false; enabled: true; source: 'Completion' }
    ]
  }
}

// ---------------------------------------------------------------------------
// Production Deployment: gpt-oss-120b (OpenAI-compatible OSS model)
// ---------------------------------------------------------------------------
resource prodDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = if (deployModelDeployments) {
  parent: aiServicesAccount
  name: 'prod-gptoss'
  sku: {
    name: 'GlobalStandard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI-OSS'
      name: 'gpt-oss-120b'
      version: '1'
    }
  }
}

// ---------------------------------------------------------------------------
// Shadow/Honeypot Deployment: gpt-oss-120b with permissive content filter
// ---------------------------------------------------------------------------
resource shadowDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = if (deployModelDeployments) {
  parent: aiServicesAccount
  name: 'shadow-gptoss'
  sku: {
    name: 'GlobalStandard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI-OSS'
      name: 'gpt-oss-120b'
      version: '1'
    }
    raiPolicyName: 'honeypot-permissive'
  }
  dependsOn: [
    prodDeployment // Serial deployment to avoid conflicts
    permissivePolicy
  ]
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Azure AI Services endpoint URL')
output endpoint string = aiServicesAccount.properties.endpoint

@description('Azure AI Services API key (primary)')
output apiKey string = aiServicesAccount.listKeys().key1
