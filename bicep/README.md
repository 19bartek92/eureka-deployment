# Bicep Templates

This folder contains Infrastructure as Code (IaC) templates for deploying Eureka.Crawler to Azure Container Apps.

## Files

- **`main.bicep`** - Main Bicep template (creates all Azure resources)
- **`main.json`** - Compiled ARM template (for "Deploy to Azure" button)
- **`parameters.example.json`** - Example parameters file (replace placeholders)

## What Gets Deployed

- Azure Cosmos DB for MongoDB (Serverless)
- Container Apps Environment
- User-Assigned Managed Identity
- Azure Key Vault (with secrets)
- 2 Container Apps Jobs (backfill + delta)
- RBAC assignment (developer Contributor access)

## Usage

### Option 1: Deploy to Azure Button (Easiest)

Click the button in main [README.md](../README.md)

### Option 2: Azure CLI

```bash
# Compile Bicep to JSON (if modified)
az bicep build --file main.bicep

# Create Resource Group
az group create --name rg-eureka-crawler --location westeurope

# Deploy
az deployment group create \
  --resource-group rg-eureka-crawler \
  --template-file main.bicep \
  --parameters @parameters.json
```

### Option 3: What-If (Dry Run)

```bash
# Preview changes without deploying
az deployment group what-if \
  --resource-group rg-eureka-crawler \
  --template-file main.bicep \
  --parameters @parameters.json
```

## Parameters

See `parameters.example.json` for all parameters.

**Required parameters:**
- Container image URL + registry credentials
- SharePoint configuration (Tenant ID, Client ID, Secret, Site ID, Drive ID)
- Developer Object ID (for automatic RBAC)

**Optional parameters:**
- Cosmos Account Name (defaults to `cosmos-eureka-{uniqueString}`)
- Key Vault Name (defaults to `kv-eureka-{uniqueString}`)
- Location (defaults to Resource Group location)

## Outputs

After deployment, these values are returned:

- `cosmosAccountName` - Name of created Cosmos DB account
- `cosmosEndpoint` - Cosmos DB endpoint URL
- `cosmosDatabaseName` - Database name (`eureka`)
- `devUserAccessGranted` - Confirmation of developer RBAC assignment
- `keyVaultName` - Name of created Key Vault
- `containerAppsEnvironmentName` - Environment name

## Validation

```bash
# Validate Bicep syntax
az bicep build --file main.bicep

# Lint
az bicep lint --file main.bicep
```

## Customization

To modify the template:
1. Edit `main.bicep`
2. Validate: `az bicep build --file main.bicep`
3. Test: `az deployment group what-if ...`
4. Deploy: `az deployment group create ...`

## Documentation

- [Full Deployment Guide](../docs/DEPLOY.md)
- [Post-Deployment Verification](../docs/POST_DEPLOYMENT.md)
- [Entra ID Setup](../docs/ENTRA_SETUP.md)
