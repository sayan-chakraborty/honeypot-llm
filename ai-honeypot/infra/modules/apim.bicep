// ============================================================================
// Azure API Management — Consumption tier
// Honeypot routing: Content Safety → prod or shadow backend
// ============================================================================

@description('Azure region')
param location string

@description('Unique suffix for naming')
param uniqueSuffix string

@description('Resource tags')
param tags object

@description('Azure OpenAI endpoint')
param openaiEndpoint string

@description('Azure OpenAI API key')
param openaiKeySecretUri string

@description('Content Safety endpoint')
param contentSafetyEndpoint string

@description('Content Safety API key')
param contentSafetyKey string

@description('Function App URL for attack logging')
param functionAppUrl string

@description('Function App host key')
param functionAppKey string

@description('App Insights instrumentation key')
param appInsightsInstrumentationKey string

// ---------------------------------------------------------------------------
// APIM Instance — Consumption tier
// ---------------------------------------------------------------------------
resource apim 'Microsoft.ApiManagement/service@2023-09-01-preview' = {
  name: 'apim-honeypot-${uniqueSuffix}'
  location: location
  tags: tags
  sku: {
    name: 'Consumption'
    capacity: 0
  }
  properties: {
    publisherEmail: 'admin@honeypot.dev'
    publisherName: 'AI Honeypot MVP'
  }
}

// ---------------------------------------------------------------------------
// Named Values (used in policies)
// ---------------------------------------------------------------------------
resource nvOpenaiEndpoint 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = {
  parent: apim
  name: 'openai-endpoint'
  properties: {
    displayName: 'openai-endpoint'
    value: openaiEndpoint
    secret: false
  }
}

resource nvOpenaiKey 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = {
  parent: apim
  name: 'openai-key'
  properties: {
    displayName: 'openai-key'
    value: openaiKeySecretUri
    secret: true
  }
}

resource nvContentSafetyEndpoint 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = {
  parent: apim
  name: 'content-safety-endpoint'
  properties: {
    displayName: 'content-safety-endpoint'
    value: contentSafetyEndpoint
    secret: false
  }
}

resource nvContentSafetyKey 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = {
  parent: apim
  name: 'content-safety-key'
  properties: {
    displayName: 'content-safety-key'
    value: contentSafetyKey
    secret: true
  }
}

resource nvFunctionAppUrl 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = {
  parent: apim
  name: 'function-app-url'
  properties: {
    displayName: 'function-app-url'
    value: functionAppUrl
    secret: false
  }
}

resource nvFunctionAppKey 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = {
  parent: apim
  name: 'function-app-key'
  properties: {
    displayName: 'function-app-key'
    value: functionAppKey
    secret: true
  }
}

// ---------------------------------------------------------------------------
// Application Insights Logger
// ---------------------------------------------------------------------------
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2023-09-01-preview' = {
  parent: apim
  name: 'appinsights-logger'
  properties: {
    loggerType: 'applicationInsights'
    credentials: {
      instrumentationKey: appInsightsInstrumentationKey
    }
    isBuffered: true
  }
}

// ---------------------------------------------------------------------------
// API Definition: AI Chat
// ---------------------------------------------------------------------------
resource chatApi 'Microsoft.ApiManagement/service/apis@2023-09-01-preview' = {
  parent: apim
  name: 'ai-chat'
  properties: {
    displayName: 'AI Chat API'
    path: 'ai'
    protocols: [
      'https'
    ]
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'subscription-key'
    }
    serviceUrl: '${openaiEndpoint}openai'
  }
  dependsOn: [
    nvOpenaiEndpoint
    nvOpenaiKey
    nvContentSafetyEndpoint
    nvContentSafetyKey
    nvFunctionAppUrl
    nvFunctionAppKey
  ]
}

// ---------------------------------------------------------------------------
// API Operation: Chat Completions
// ---------------------------------------------------------------------------
resource chatOperation 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: chatApi
  name: 'chat-completions'
  properties: {
    displayName: 'Chat Completions'
    method: 'POST'
    urlTemplate: '/chat/completions'
    request: {
      representations: [
        {
          contentType: 'application/json'
        }
      ]
    }
    responses: [
      {
        statusCode: 200
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// API Policy: Honeypot Routing (loaded from external XML)
// ---------------------------------------------------------------------------
resource chatApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-09-01-preview' = {
  parent: chatApi
  name: 'policy'
  properties: {
    value: loadTextContent('../policies/honeypot-routing.xml')
    format: 'xml'
  }
  dependsOn: [
    chatOperation
  ]
}

// ---------------------------------------------------------------------------
// Product: Unlimited (for demo, no rate limits)
// ---------------------------------------------------------------------------
resource product 'Microsoft.ApiManagement/service/products@2023-09-01-preview' = {
  parent: apim
  name: 'honeypot-demo'
  properties: {
    displayName: 'Honeypot Demo'
    description: 'Demo product for AI Honeypot MVP'
    subscriptionRequired: true
    approvalRequired: false
    state: 'published'
  }
}

resource productApi 'Microsoft.ApiManagement/service/products/apis@2023-09-01-preview' = {
  parent: product
  name: 'ai-chat'
  dependsOn: [
    chatApi
  ]
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('APIM gateway URL')
output gatewayUrl string = apim.properties.gatewayUrl
