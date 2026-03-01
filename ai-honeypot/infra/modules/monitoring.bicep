// ============================================================================
// Monitoring — Log Analytics Workspace + Application Insights
// ============================================================================

@description('Azure region')
param location string

@description('Unique suffix for naming')
param uniqueSuffix string

@description('Resource tags')
param tags object

// ---------------------------------------------------------------------------
// Log Analytics Workspace
// ---------------------------------------------------------------------------
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-honeypot-${uniqueSuffix}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// ---------------------------------------------------------------------------
// Application Insights
// ---------------------------------------------------------------------------
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-honeypot-${uniqueSuffix}'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('App Insights instrumentation key')
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey

@description('App Insights connection string')
output appInsightsConnectionString string = appInsights.properties.ConnectionString

@description('Log Analytics workspace ID')
output logAnalyticsWorkspaceId string = logAnalytics.id
