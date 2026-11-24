// Vehicle Quote API on Azure Container Apps (consumption plan, scale to zero).
// Deployed by .github/workflows/ci-deploy.yml:
//   az deployment group create -g <rg> -f infra/main.bicep -p image=... appVersion=... appKey=...

@description('Azure region. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Base name for all resources.')
@minLength(3)
@maxLength(20)
param appName string = 'vehicle-quote-api'

@description('Full container image reference, e.g. ghcr.io/owner/repo:sha.')
param image string

@description('Build identifier shown by GET /api/info (the git SHA in CI).')
param appVersion string = 'manual'

@secure()
@description('Laravel APP_KEY (base64:...). Stored as a Container Apps secret.')
param appKey string

@minValue(0)
@maxValue(5)
param minReplicas int = 0

@minValue(1)
@maxValue(10)
param maxReplicas int = 2

var tags = {
  app: appName
  managedBy: 'bicep'
}

// Container logs (first 5 GB/month of ingestion are free).
resource logs 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${appName}-logs'
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource env 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: '${appName}-env'
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logs.properties.customerId
        sharedKey: logs.listKeys().primarySharedKey
      }
    }
  }
}

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: appName
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: env.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8080
        transport: 'auto'
        allowInsecure: false
      }
      secrets: [
        { name: 'app-key', value: appKey }
      ]
    }
    template: {
      containers: [
        {
          name: 'api'
          image: image
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            { name: 'APP_KEY', secretRef: 'app-key' }
            { name: 'APP_VERSION', value: appVersion }
            { name: 'AZURE_REGION', value: location }
            { name: 'APP_URL', value: 'https://${appName}.${env.properties.defaultDomain}' }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: { path: '/up', port: 8080 }
              initialDelaySeconds: 5
              periodSeconds: 30
            }
            {
              type: 'Readiness'
              httpGet: { path: '/up', port: 8080 }
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http'
            http: { metadata: { concurrentRequests: '50' } }
          }
        ]
      }
    }
  }
}

output url string = 'https://${app.properties.configuration.ingress.fqdn}'
output latestRevision string = app.properties.latestRevisionName
