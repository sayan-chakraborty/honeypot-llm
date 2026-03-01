// ============================================================================
// AI Honeypot MVP — Main Bicep Orchestrator
// Deploys all Azure resources for the AI Honeypot system
// ============================================================================

targetScope = 'resourceGroup'

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Unique suffix for resource names (keep short, lowercase, no hyphens)')
@minLength(3)
@maxLength(10)
param uniqueSuffix string

@description('Tags applied to all resources')
param tags object = {
  project: 'ai-honeypot'
  environment: 'dev'
}

// ---------------------------------------------------------------------------
// Module: Azure OpenAI (prod + shadow deployments)
// ---------------------------------------------------------------------------
module openai 'modules/openai.bicep' = {
  name: 'openai-deployment'
  params: {
    location: location
    uniqueSuffix: uniqueSuffix
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// Module: Content Safety (F0 free tier)
// ---------------------------------------------------------------------------
module contentSafety 'modules/content-safety.bicep' = {
  name: 'content-safety-deployment'
  params: {
    location: location
    uniqueSuffix: uniqueSuffix
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// Module: Function App + Storage Account
// ---------------------------------------------------------------------------
module functionApp 'modules/function-app.bicep' = {
  name: 'function-app-deployment'
  params: {
    location: location
    uniqueSuffix: uniqueSuffix
    tags: tags
    appInsightsInstrumentationKey: monitoring.outputs.appInsightsInstrumentationKey
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
  }
}

// ---------------------------------------------------------------------------
// Module: App Configuration (Free tier)
// ---------------------------------------------------------------------------
module appConfig 'modules/app-config.bicep' = {
  name: 'app-config-deployment'
  params: {
    location: location
    uniqueSuffix: uniqueSuffix
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// Module: APIM Consumption + API + Routing Policy
// ---------------------------------------------------------------------------
module apim 'modules/apim.bicep' = {
  name: 'apim-deployment'
  params: {
    location: location
    uniqueSuffix: uniqueSuffix
    tags: tags
    openaiEndpoint: openai.outputs.endpoint
    openaiKeySecretUri: openai.outputs.apiKey
    contentSafetyEndpoint: contentSafety.outputs.endpoint
    contentSafetyKey: contentSafety.outputs.apiKey
    functionAppUrl: functionApp.outputs.functionAppUrl
    functionAppKey: functionApp.outputs.functionAppKey
    appInsightsInstrumentationKey: monitoring.outputs.appInsightsInstrumentationKey
  }
}

// ---------------------------------------------------------------------------
// Module: Monitoring (Log Analytics + App Insights)
// ---------------------------------------------------------------------------
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring-deployment'
  params: {
    location: location
    uniqueSuffix: uniqueSuffix
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('APIM Gateway URL for sending requests')
output apimGatewayUrl string = apim.outputs.gatewayUrl

@description('Function App name (needed for func publish)')
output functionAppName string = functionApp.outputs.functionAppName

@description('Storage Account name (for Table Storage access)')
output storageAccountName string = functionApp.outputs.storageAccountName

@description('Azure OpenAI endpoint')
output openaiEndpoint string = openai.outputs.endpoint

@description('App Configuration endpoint')
output appConfigEndpoint string = appConfig.outputs.endpoint
