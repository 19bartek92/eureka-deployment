@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Name of the Container Apps Environment')
param environmentName string = 'env-eureka-crawler'

@description('Name of the User-Assigned Managed Identity')
param uamiName string = 'uami-eureka-crawler'

@description('Name of the Azure Key Vault (must be globally unique)')
param keyVaultName string = 'kv-eureka-${uniqueString(resourceGroup().id)}'

@description('Name of the backfill job')
param jobBackfillName string = 'eureka-backfill'

@description('Name of the delta job')
param jobDeltaName string = 'eureka-delta'

@description('Name of the Azure Container Registry (must be globally unique, 5-50 alphanumeric characters)')
@minLength(5)
@maxLength(50)
param acrName string = 'acr${uniqueString(resourceGroup().id)}'

@description('Container image name in ACR')
param imageName string = 'eureka-crawler'

@description('Container image tag')
param imageTag string = 'latest'

@description('Name of the Cosmos DB account (must be globally unique)')
@minLength(3)
@maxLength(44)
param cosmosAccountName string = 'cosmos-eureka-${uniqueString(resourceGroup().id)}'

@description('Microsoft Entra ID Object ID of developer user for Contributor access (optional - leave empty to skip)')
@metadata({
  hint: 'Admin must first add developer as Guest User in Microsoft Entra ID, then get Object ID via: az ad user show --id <email> --query id -o tsv'
})
param devUserObjectId string = ''

@description('SharePoint Tenant ID')
@secure()
param sharePointTenantId string

@description('SharePoint Client ID')
@secure()
param sharePointClientId string

@description('SharePoint Client Secret')
@secure()
param sharePointClientSecret string

@description('SharePoint Site ID')
@secure()
param sharePointSiteId string

@description('SharePoint Drive ID')
@secure()
param sharePointDriveId string

@description('CPU cores for job containers')
param cpu string = '0.5'

@description('Memory for job containers')
param memory string = '1Gi'

@description('CRON expression for delta job schedule (UTC timezone)')
param cronExpression string = '10 4 * * *'

// User-Assigned Managed Identity
resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: uamiName
  location: location
}

// Azure Key Vault with RBAC authorization
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    publicNetworkAccess: 'Enabled'
  }
}

// RBAC: Grant UAMI 'Key Vault Secrets User' role on Key Vault
resource keyVaultSecretUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, uami.id, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Cosmos DB Account (MongoDB API, Serverless)
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-11-15' = {
  name: cosmosAccountName
  location: location
  kind: 'MongoDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    enableFreeTier: false
    capabilities: [
      {
        name: 'EnableServerless'
      }
      {
        name: 'EnableMongo'
      }
    ]
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    apiProperties: {
      serverVersion: '4.2'
    }
  }
}

// Cosmos DB Database
resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2023-11-15' = {
  parent: cosmosAccount
  name: 'eureka'
  properties: {
    resource: {
      id: 'eureka'
    }
  }
}

// Key Vault Secrets
resource secretCosmosConnection 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'cosmos-connection-string'
  properties: {
    value: 'mongodb://${cosmosAccount.name}:${cosmosAccount.listKeys().primaryMasterKey}@${cosmosAccount.name}.mongo.cosmos.azure.com:10255/?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000'
  }
  dependsOn: [
    cosmosDatabase
  ]
}

resource secretSharePointTenantId 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'sharepoint-tenant-id'
  properties: {
    value: sharePointTenantId
  }
}

resource secretSharePointClientId 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'sharepoint-client-id'
  properties: {
    value: sharePointClientId
  }
}

resource secretSharePointClientSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'sharepoint-client-secret'
  properties: {
    value: sharePointClientSecret
  }
}

resource secretSharePointSiteId 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'sharepoint-site-id'
  properties: {
    value: sharePointSiteId
  }
}

resource secretSharePointDriveId 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'sharepoint-drive-id'
  properties: {
    value: sharePointDriveId
  }
}

// Azure Container Registry (Basic tier, ~$5/month)
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false  // Use UAMI instead of admin credentials
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'  // Basic tier doesn't support zone redundancy
  }
}

// RBAC: UAMI gets AcrPull role on the ACR
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, uami.id, 'AcrPull')
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Container Apps Environment
resource environment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: environmentName
  location: location
  properties: {}
}

// Container Apps Job - Backfill (Manual Trigger)
resource jobBackfill 'Microsoft.App/jobs@2023-05-01' = {
  name: jobBackfillName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uami.id}': {}
    }
  }
  properties: {
    environmentId: environment.id
    configuration: {
      triggerType: 'Manual'
      replicaTimeout: 86400 // 24 hours
      replicaRetryLimit: 3
      manualTriggerConfig: {
        parallelism: 1
        replicaCompletionCount: 1
      }
      secrets: [
        {
          name: 'cosmos-connection-string'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/cosmos-connection-string'
          identity: uami.id
        }
        {
          name: 'sharepoint-tenant-id'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/sharepoint-tenant-id'
          identity: uami.id
        }
        {
          name: 'sharepoint-client-id'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/sharepoint-client-id'
          identity: uami.id
        }
        {
          name: 'sharepoint-client-secret'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/sharepoint-client-secret'
          identity: uami.id
        }
        {
          name: 'sharepoint-site-id'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/sharepoint-site-id'
          identity: uami.id
        }
        {
          name: 'sharepoint-drive-id'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/sharepoint-drive-id'
          identity: uami.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'eureka-crawler-backfill'
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'  // Placeholder - developer will update after pushing real image
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          env: [
            { name: 'MODE', value: 'backfill' }
            { name: 'Eureka__BaseUrl', value: 'https://eureka.mf.gov.pl/api/public/v1/' }
            { name: 'Eureka__PageSize', value: '100' }
            { name: 'Eureka__Category', value: '1' }
            { name: 'Eureka__Limits__SearchRpm', value: '10' }
            { name: 'Eureka__Limits__InfoRpm', value: '25' }
            { name: 'Eureka__Limits__AllRpm', value: '40' }
            { name: 'Eureka__Limits__ReqPerHour', value: '300' }
            { name: 'Cosmos__Database', value: 'eureka' }
            { name: 'Cosmos__Collection', value: 'informations' }
            { name: 'Cosmos__CreateIndexesOnStart', value: 'true' }
            { name: 'Cosmos__ConnectionString', secretRef: 'cosmos-connection-string' }
            { name: 'SharePoint__FolderFormat', value: 'yyyyMM' }
            { name: 'SharePoint__TenantId', secretRef: 'sharepoint-tenant-id' }
            { name: 'SharePoint__ClientId', secretRef: 'sharepoint-client-id' }
            { name: 'SharePoint__ClientSecret', secretRef: 'sharepoint-client-secret' }
            { name: 'SharePoint__SiteId', secretRef: 'sharepoint-site-id' }
            { name: 'SharePoint__DriveId', secretRef: 'sharepoint-drive-id' }
            { name: 'Logging__LogLevel__Default', value: 'Information' }
            { name: 'Logging__LogLevel__Microsoft.Hosting.Lifetime', value: 'Information' }
          ]
        }
      ]
    }
  }
  dependsOn: [
    keyVaultSecretUserRole
    secretCosmosConnection
    secretSharePointTenantId
    secretSharePointClientId
    secretSharePointClientSecret
    secretSharePointSiteId
    secretSharePointDriveId
    acrPullRoleAssignment
  ]
}

// Container Apps Job - Delta (Scheduled Trigger)
resource jobDelta 'Microsoft.App/jobs@2023-05-01' = {
  name: jobDeltaName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uami.id}': {}
    }
  }
  properties: {
    environmentId: environment.id
    configuration: {
      triggerType: 'Schedule'
      replicaTimeout: 3600 // 1 hour
      replicaRetryLimit: 2
      scheduleTriggerConfig: {
        cronExpression: cronExpression
        parallelism: 1
        replicaCompletionCount: 1
      }
      secrets: [
        {
          name: 'cosmos-connection-string'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/cosmos-connection-string'
          identity: uami.id
        }
        {
          name: 'sharepoint-tenant-id'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/sharepoint-tenant-id'
          identity: uami.id
        }
        {
          name: 'sharepoint-client-id'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/sharepoint-client-id'
          identity: uami.id
        }
        {
          name: 'sharepoint-client-secret'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/sharepoint-client-secret'
          identity: uami.id
        }
        {
          name: 'sharepoint-site-id'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/sharepoint-site-id'
          identity: uami.id
        }
        {
          name: 'sharepoint-drive-id'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/sharepoint-drive-id'
          identity: uami.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'eureka-crawler-delta'
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'  // Placeholder - developer will update after pushing real image
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          env: [
            { name: 'MODE', value: 'delta' }
            { name: 'Eureka__BaseUrl', value: 'https://eureka.mf.gov.pl/api/public/v1/' }
            { name: 'Eureka__PageSize', value: '100' }
            { name: 'Eureka__Category', value: '1' }
            { name: 'Eureka__Limits__SearchRpm', value: '10' }
            { name: 'Eureka__Limits__InfoRpm', value: '25' }
            { name: 'Eureka__Limits__AllRpm', value: '40' }
            { name: 'Eureka__Limits__ReqPerHour', value: '300' }
            { name: 'Cosmos__Database', value: 'eureka' }
            { name: 'Cosmos__Collection', value: 'informations' }
            { name: 'Cosmos__CreateIndexesOnStart', value: 'true' }
            { name: 'Cosmos__ConnectionString', secretRef: 'cosmos-connection-string' }
            { name: 'SharePoint__FolderFormat', value: 'yyyyMM' }
            { name: 'SharePoint__TenantId', secretRef: 'sharepoint-tenant-id' }
            { name: 'SharePoint__ClientId', secretRef: 'sharepoint-client-id' }
            { name: 'SharePoint__ClientSecret', secretRef: 'sharepoint-client-secret' }
            { name: 'SharePoint__SiteId', secretRef: 'sharepoint-site-id' }
            { name: 'SharePoint__DriveId', secretRef: 'sharepoint-drive-id' }
            { name: 'Logging__LogLevel__Default', value: 'Information' }
            { name: 'Logging__LogLevel__Microsoft.Hosting.Lifetime', value: 'Information' }
          ]
        }
      ]
    }
  }
  dependsOn: [
    keyVaultSecretUserRole
    secretCosmosConnection
    secretSharePointTenantId
    secretSharePointClientId
    secretSharePointClientSecret
    secretSharePointSiteId
    secretSharePointDriveId
    acrPullRoleAssignment
  ]
}

// RBAC: Grant developer user Contributor access to Resource Group (conditional)
resource devContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (devUserObjectId != '') {
  name: guid(resourceGroup().id, devUserObjectId, 'Contributor')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor
    principalId: devUserObjectId
    principalType: 'User'
  }
}

// Outputs
output environmentId string = environment.id
output uamiId string = uami.id
output uamiPrincipalId string = uami.properties.principalId
output uamiClientId string = uami.properties.clientId
output keyVaultId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri
output jobBackfillName string = jobBackfill.name
output jobDeltaName string = jobDelta.name
output cosmosAccountName string = cosmosAccount.name
output cosmosEndpoint string = cosmosAccount.properties.documentEndpoint
output cosmosDatabaseName string = cosmosDatabase.name
output devUserAccessGranted string = devUserObjectId != '' ? 'Contributor role assigned to ${devUserObjectId}' : 'Developer access not configured (devUserObjectId was empty)'
output acrName string = containerRegistry.name
output acrLoginServer string = containerRegistry.properties.loginServer
output fullImageUrl string = '${containerRegistry.properties.loginServer}/${imageName}:${imageTag}'
output updateJobBackfillCommand string = 'az containerapp job update -n ${jobBackfillName} -g ${resourceGroup().name} --image ${containerRegistry.properties.loginServer}/${imageName}:${imageTag} --registry-server ${containerRegistry.properties.loginServer} --registry-identity ${uami.id}'
output updateJobDeltaCommand string = 'az containerapp job update -n ${jobDeltaName} -g ${resourceGroup().name} --image ${containerRegistry.properties.loginServer}/${imageName}:${imageTag} --registry-server ${containerRegistry.properties.loginServer} --registry-identity ${uami.id}'
