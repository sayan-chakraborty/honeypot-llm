// ============================================================================
// Azure App Configuration — Free tier (1K requests/day)
// Stores hardening rules generated from attack analysis
// ============================================================================

@description('Azure region')
param location string

@description('Unique suffix for naming')
param uniqueSuffix string

@description('Resource tags')
param tags object

// ---------------------------------------------------------------------------
// App Configuration Store
// ---------------------------------------------------------------------------
resource appConfig 'Microsoft.AppConfiguration/configurationStores@2023-03-01' = {
  name: 'appcs-honeypot-${uniqueSuffix}'
  location: location
  tags: tags
  sku: {
    name: 'free'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('App Configuration endpoint')
output endpoint string = appConfig.properties.endpoint

@description('App Configuration connection string')
output connectionString string = appConfig.listKeys().value[0].connectionString
