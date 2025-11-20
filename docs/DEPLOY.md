# Deploy Eureka.Crawler to Azure Container Apps

This guide provides a quick one-click deployment option for Eureka.Crawler using Azure Container Apps Jobs with Azure Key Vault integration.

---

## Przed rozpoczęciem (Pre-deployment Checklist)

⚠️ **WAŻNE:** Przed kliknięciem "Deploy to Azure" wykonaj kroki przygotowawcze opisane w:

- 🇵🇱 **[Instrukcja przygotowania (Polski)](QUICK_START_PL.md)** - Krok po kroku w języku polskim
- 🇬🇧 **[Entra ID Setup (English)](ENTRA_SETUP.md)** - Detailed authentication configuration

**Te instrukcje przeprowadzą Cię przez:**
- Utworzenie App Registration w Azure Entra ID
- Konfigurację uprawnień SharePoint
- Uzyskanie Site ID i Drive ID
- Przygotowanie Cosmos DB
- Zbudowanie i wysłanie obrazu Docker

**Bez tych kroków deployment się nie powiedzie!**

---

## Quick Start - Deploy to Azure

The fastest way to deploy Eureka.Crawler is using the "Deploy to Azure" button below. This will launch the Azure Portal with a pre-configured template.

### Prerequisites

Before clicking the button, ensure you have:

1. **Azure Subscription** with appropriate permissions
2. **Container Image** published to a registry (ACR or public registry like Docker Hub/GHCR)
3. **SharePoint App Registration** with required credentials (see [SharePoint Setup](#sharepoint-setup))
4. **Developer Object ID** - Required for automatic access grant
   ```bash
   az ad user show --id bartoszpalmi@hotmail.com --query id -o tsv
   ```

### Deploy Now

Click the button below to start deployment:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fyour-username%2FEureka.Crawler%2Fmain%2Fops%2Fbicep%2Faca-jobs-kv.json)

**Note:** Replace the URL in the button above with your actual repository URL once you publish the template to GitHub.

### Alternative: Deploy via Azure CLI

If you prefer using Azure CLI or need more control over the deployment:

```bash
# Clone the repository
git clone https://github.com/your-username/Eureka.Crawler.git
cd Eureka.Crawler

# Deploy using the Bicep template
az deployment group create \
  --resource-group rg-eureka-crawler \
  --template-file ops/bicep/aca-jobs-kv.bicep \
  --parameters @ops/bicep/aca-jobs-kv.parameters.json
```

Or use the automated provisioning script:

```bash
# Set required environment variables
export IMAGE="myregistry.azurecr.io/eureka-crawler:latest"
export REGISTRY_SERVER="myregistry.azurecr.io"
export REGISTRY_USER="myregistry"
export REGISTRY_PAT="your-password-or-pat"

# Run provisioning script
./ops/scripts/aca-provision-kv.sh
```

For detailed manual deployment steps, see [deploy-aca.md](deploy-aca.md).

## What Gets Deployed

When you deploy using the template, the following Azure resources are automatically created:

### Infrastructure Resources

1. **Azure Cosmos DB for MongoDB** - Serverless database (auto-created)
   - Database: `eureka`
   - Connection string automatically stored in Key Vault
   - Serverless capacity mode (cost-effective)

2. **Container Apps Environment** (`env-eureka-crawler`)
   - Managed environment for running Container Apps Jobs
   - Includes log analytics workspace integration

3. **User-Assigned Managed Identity** (`uami-eureka-crawler`)
   - Used by both jobs to securely access Key Vault and Cosmos DB
   - No passwords or keys to manage

4. **Azure Key Vault** (`kv-eureka-XXXXXXXX`)
   - Stores all sensitive configuration (connection strings, secrets)
   - RBAC-enabled for secure access control
   - Soft delete enabled for recovery

5. **RBAC Role Assignments**
   - Grants "Key Vault Secrets User" role to the managed identity
   - Grants "Contributor" role to developer (`bartoszpalmi@hotmail.com`)
   - Allows jobs to read secrets without storing credentials

### Application Jobs

1. **Backfill Job** (`eureka-backfill`)
   - **Trigger:** Manual (on-demand)
   - **Purpose:** Full catalog sync - fetches all documents from Eureka API
   - **Timeout:** 24 hours
   - **Retries:** Up to 3 attempts
   - **Mode:** `MODE=backfill`

2. **Delta Job** (`eureka-delta`)
   - **Trigger:** Scheduled (CRON: daily at 4:10 AM UTC)
   - **Purpose:** Incremental updates - fetches only new documents
   - **Timeout:** 1 hour
   - **Retries:** Up to 2 attempts
   - **Mode:** `MODE=delta`

### Secrets in Key Vault

The following secrets are created and used by the jobs:

| Secret Name | Description |
|------------|-------------|
| `cosmos-connection-string` | MongoDB connection string for Cosmos DB |
| `sharepoint-tenant-id` | Azure AD Tenant ID |
| `sharepoint-client-id` | App Registration Client ID |
| `sharepoint-client-secret` | App Registration Client Secret |
| `sharepoint-site-id` | SharePoint Site identifier |
| `sharepoint-drive-id` | SharePoint Drive/Library identifier |

## Deployment Process

### Step-by-Step Portal Flow

After clicking "Deploy to Azure":

1. **Sign In**
   - You'll be redirected to Azure Portal
   - Sign in with your Azure credentials

2. **Configure Deployment**
   - Select **Subscription** and **Resource Group** (create new or use existing)
   - Choose **Region** (e.g., West Europe)
   - Fill in **Parameters**:

#### Basic Settings

| Parameter | Description | Example |
|-----------|-------------|---------|
| `Location` | Azure region for resources | `westeurope` |
| `Environment Name` | Container Apps Environment name | `env-eureka-crawler` |
| `UAMI Name` | User-Assigned Managed Identity name | `uami-eureka-crawler` |
| `Key Vault Name` | Key Vault name (globally unique) | `kv-eureka-xyz123` |

#### Job Configuration

| Parameter | Description | Example |
|-----------|-------------|---------|
| `Job Backfill Name` | Name for backfill job | `eureka-backfill` |
| `Job Delta Name` | Name for scheduled job | `eureka-delta` |
| `CRON Expression` | Schedule for delta job (UTC) | `10 4 * * *` |
| `CPU` | CPU cores per job | `0.5` |
| `Memory` | Memory per job | `1Gi` |

#### Container Settings

| Parameter | Description | Example |
|-----------|-------------|---------|
| `Container Image` | Full image path with tag | `myacr.azurecr.io/eureka-crawler:latest` |
| `Registry Server` | Container registry server | `myacr.azurecr.io` |
| `Registry Username` | Registry username | `myacr` |
| `Registry Password` | Registry password or PAT | `***********` |

#### Cosmos DB Settings

| Parameter | Description | Example |
|-----------|-------------|---------|
| `Cosmos Account Name` | Globally unique name for Cosmos DB | `cosmos-eureka-abc123` |

#### Developer Access

| Parameter | Description | Where to Get |
|-----------|-------------|--------------|
| `Developer Object ID` | Azure AD Object ID of developer | `az ad user show --id bartoszpalmi@hotmail.com --query id -o tsv` |

#### Secrets (Secure Parameters)

| Parameter | Description | Where to Get |
|-----------|-------------|--------------|
| `SharePoint Tenant ID` | Azure AD Tenant ID | Azure AD → Properties |
| `SharePoint Client ID` | App Registration Client ID | App Registrations → Your App |
| `SharePoint Client Secret` | App Registration Secret | App Registrations → Certificates & Secrets |
| `SharePoint Site ID` | SharePoint Site ID | See [SharePoint Setup](#sharepoint-setup) |
| `SharePoint Drive ID` | SharePoint Drive/Library ID | See [SharePoint Setup](#sharepoint-setup) |

3. **Review and Create**
   - Review all parameters
   - Accept terms and conditions
   - Click **Create** to start deployment

4. **Wait for Deployment**
   - Deployment typically takes 5-10 minutes
   - You can monitor progress in the Azure Portal
   - Once complete, you'll see "Your deployment is complete"

## Post-Deployment Steps

See [Post-Deployment Guide](POST_DEPLOYMENT.md) for:
- Comprehensive verification steps
- First job execution
- Developer workflow (updates, monitoring)
- Troubleshooting

### Quick Verification

After deployment completes:

```bash
# List all resources in the resource group
az resource list \
  --resource-group rg-eureka-crawler \
  --output table

# Verify jobs are created
az containerapp job list \
  --resource-group rg-eureka-crawler \
  --output table
```

Expected resources:
- Cosmos DB Account (MongoDB API)
- Container Apps Environment
- User-Assigned Managed Identity
- Key Vault with 6 secrets
- 2 Container Apps Jobs

### 2. Run the Backfill Job

Start the initial full catalog sync:

```bash
# Start backfill job manually
az containerapp job start \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler
```

Or via Azure Portal:
1. Navigate to Resource Group → `rg-eureka-crawler`
2. Click on job `eureka-backfill`
3. Click **Start execution**
4. Monitor progress in "Execution history"

### 3. Monitor Job Execution

```bash
# List all executions
az containerapp job execution list \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler \
  --output table

# Stream logs
az containerapp job logs show \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler \
  --follow
```

### 4. Verify Delta Job Schedule

The delta job runs automatically on the configured schedule. To verify:

```bash
# Check schedule configuration
az containerapp job show \
  --name eureka-delta \
  --resource-group rg-eureka-crawler \
  --query "properties.configuration.scheduleTriggerConfig"
```

## Configuration Details

### Environment Variables

All application configuration is passed via environment variables. See [deploy-env.md](deploy-env.md) for complete mapping.

Key variables:
- `MODE`: Job operation mode (`backfill` or `delta`)
- `Eureka__BaseUrl`: Eureka API endpoint
- `Eureka__Limits__*`: Rate limiting configuration
- `Cosmos__*`: Cosmos DB configuration
- `SharePoint__*`: SharePoint integration settings

### Rate Limiting

The application respects Eureka API rate limits:
- **Search endpoint:** 10 requests/minute
- **Info endpoint:** 25 requests/minute
- **Global:** 40 requests/minute
- **Hourly:** 300 requests/hour

Expected processing time for backfill: ~300 documents/hour (due to rate limits).

### Resource Allocation

Default resource allocation per job:
- **CPU:** 0.5 cores
- **Memory:** 1Gi

Adjust in template parameters if needed for better performance.

## Authentication Modes

Eureka.Crawler supports **two authentication modes** for accessing SharePoint and Azure services:

### Mode 1: Client Secret (Development)
- Traditional Azure AD App Registration with client secret
- Best for: Local development, testing, non-Azure environments
- Setup: Create App Registration, generate client secret
- Security: Moderate - requires secret rotation every 1-2 years

### Mode 2: Managed Identity (Production - Recommended)
- Uses User-Assigned Managed Identity (UAMI) for passwordless authentication
- Best for: Production workloads in Azure (Container Apps, VMs, App Service)
- Setup: Assign Graph API permissions to UAMI via PowerShell/CLI
- Security: High - no secrets, automatic token rotation

**Auto-detection:** The application automatically selects the authentication mode based on configuration:
- If `AZURE_CLIENT_ID` is set → Managed Identity
- If `SharePoint__ClientSecret` is provided → Client Secret

For complete setup instructions, see [ENTRA_SETUP.md](ENTRA_SETUP.md).

## SharePoint Setup

### For Client Secret Mode (Development)

Before deploying, you need to set up SharePoint integration:

### 1. Create App Registration

In Azure Portal:

1. Go to **Azure Active Directory** → **App registrations**
2. Click **New registration**
3. Name: `Eureka.Crawler.SharePoint`
4. Supported account types: **Single tenant**
5. Click **Register**

### 2. Configure Permissions

After creating the app:

1. Go to **API permissions**
2. Click **Add a permission** → **Microsoft Graph** → **Application permissions**
3. Add these permissions:
   - `Files.ReadWrite.All`
   - `Sites.ReadWrite.All`
4. Click **Grant admin consent** (requires admin rights)

### 3. Create Client Secret

1. Go to **Certificates & secrets**
2. Click **New client secret**
3. Description: `Eureka Crawler`
4. Expires: Choose duration (e.g., 24 months)
5. Click **Add**
6. **Copy the secret value immediately** (you won't see it again)

### 4. Get Required IDs

#### Tenant ID and Client ID

From the app registration overview page:
- **Application (client) ID** → Use as `SharePoint__ClientId`
- **Directory (tenant) ID** → Use as `SharePoint__TenantId`

#### Site ID and Drive ID

**Option 1: Graph Explorer** (easiest)

1. Go to [Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer)
2. Sign in with your account
3. Find Site ID:
   ```
   GET https://graph.microsoft.com/v1.0/sites?search={your-site-name}
   ```
   Copy the `id` field

4. Find Drive ID (using Site ID from above):
   ```
   GET https://graph.microsoft.com/v1.0/sites/{site-id}/drives
   ```
   Copy the `id` field of your target document library

**Option 2: PowerShell**

```powershell
# Install Microsoft Graph module
Install-Module -Name Microsoft.Graph -Scope CurrentUser

# Connect
Connect-MgGraph -Scopes "Sites.Read.All"

# Find Site ID
Get-MgSite -Search "Your Site Name"

# Find Drive ID (replace {site-id} with actual value)
Get-MgSiteDrive -SiteId "{site-id}"
```

**Option 3: From URL**

If your SharePoint URL is `https://contoso.sharepoint.com/sites/YourSite`:

```bash
# Get Site ID via Graph API
curl "https://graph.microsoft.com/v1.0/sites/contoso.sharepoint.com:/sites/YourSite" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

For complete SharePoint Client Secret setup, see [ENTRA_SETUP.md - Section A](ENTRA_SETUP.md#section-a-client-secret-authentication-traditional).

### For Managed Identity Mode (Production - Recommended)

To use Managed Identity authentication in production:

1. **After deployment**, assign Graph API permissions to the UAMI `id-eureka`
2. Use PowerShell or Azure CLI to grant `Files.ReadWrite.All` and `Sites.ReadWrite.All`
3. Add `AZURE_CLIENT_ID` environment variable to jobs (UAMI Client ID)
4. No App Registration or client secret needed

**Complete instructions:** [ENTRA_SETUP.md - Section B](ENTRA_SETUP.md#section-b-managed-identity-authentication-recommended-for-production)

**Automated setup:** The provisioning script `ops/scripts/aca-provision-kv.sh` can configure Managed Identity RBAC automatically during deployment.

## Monitoring and Logs

### Azure Portal

1. Navigate to **Resource Group** → `rg-eureka-crawler`
2. Click on a job (e.g., `eureka-backfill`)
3. View:
   - **Execution history:** All past runs
   - **Logs:** Real-time and historical logs
   - **Metrics:** Performance metrics

### Azure CLI

```bash
# View execution history
az containerapp job execution list \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler \
  --output table

# Stream logs
az containerapp job logs show \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler \
  --follow

# Show specific execution logs
az containerapp job logs show \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler \
  --execution {execution-name}
```

### Log Analysis

Logs will show:
- API requests and rate limiting status
- Document processing progress
- Cosmos DB upsert operations
- SharePoint upload status
- Error details (if any)

## Troubleshooting

### Deployment Fails

**Issue:** Template deployment fails in Azure Portal

**Common Causes:**
- Key Vault name not globally unique
- Insufficient permissions in subscription
- Invalid parameter values

**Solution:**
1. Check deployment error details in Azure Portal
2. Ensure Key Vault name is unique (try adding more random characters)
3. Verify you have Contributor role on the subscription/resource group

### Job Fails to Start

**Issue:** Job execution fails immediately after starting

**Common Causes:**
- Container image not accessible
- Registry credentials incorrect
- RBAC not propagated

**Solution:**
```bash
# Verify image is accessible
docker pull {your-image}

# Check job identity configuration
az containerapp job show \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler \
  --query identity

# Wait for RBAC to propagate (can take up to 10 minutes)
sleep 600
```

### Cannot Access Secrets

**Issue:** Job starts but fails with secret-related errors

**Common Causes:**
- RBAC role not assigned correctly
- Secret names mismatch
- UAMI not configured on job

**Solution:**
```bash
# Verify RBAC assignment
UAMI_ID=$(az identity show \
  --name uami-eureka-crawler \
  --resource-group rg-eureka-crawler \
  --query principalId --output tsv)

az role assignment list \
  --assignee $UAMI_ID \
  --all \
  --output table

# List secrets in Key Vault
KV_NAME=$(az keyvault list \
  --resource-group rg-eureka-crawler \
  --query "[0].name" --output tsv)

az keyvault secret list \
  --vault-name $KV_NAME \
  --query "[].name" --output table
```

### SharePoint Upload Fails

**Issue:** Documents saved to Cosmos DB but not uploaded to SharePoint

**Common Causes:**
- Incorrect SharePoint credentials
- Missing admin consent for app permissions
- Wrong Site ID or Drive ID

**Solution:**
1. Verify SharePoint secrets in Key Vault are correct
2. Check App Registration has admin consent granted
3. Test SharePoint access manually using Graph Explorer
4. Review job logs for specific SharePoint errors:
   ```bash
   az containerapp job logs show \
     --name eureka-backfill \
     --resource-group rg-eureka-crawler \
     | grep -i sharepoint
   ```

For more troubleshooting, see [deploy-aca.md](deploy-aca.md#troubleshooting).

## Updating Configuration

### Update Secrets in Key Vault

```bash
# Update a secret
az keyvault secret set \
  --vault-name {kv-name} \
  --name cosmos-connection-string \
  --value "new-connection-string"

# Restart job to pick up new values
az containerapp job stop \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler \
  --execution {execution-name}
```

### Update Job Configuration

```bash
# Update environment variables
az containerapp job update \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler \
  --set-env-vars "Eureka__PageSize=200"

# Update resource allocation
az containerapp job update \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler \
  --cpu 1.0 \
  --memory 2Gi

# Update schedule (delta job)
az containerapp job update \
  --name eureka-delta \
  --resource-group rg-eureka-crawler \
  --cron-expression "0 */6 * * *"  # Every 6 hours
```

### Update Container Image

```bash
# Update to new image version
az containerapp job update \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler \
  --image myregistry.azurecr.io/eureka-crawler:v2.0
```

## Cost Optimization

### Estimated Costs

Monthly cost estimate (West Europe region):

| Resource | Configuration | Estimated Cost |
|----------|--------------|----------------|
| Container Apps Environment | Standard tier | ~$50/month |
| Container Apps Jobs | 0.5 vCPU, 1Gi memory, ~2h/day runtime | ~$15/month |
| Key Vault | Standard SKU, 6 secrets | ~$1/month |
| User-Assigned Identity | - | Free |
| **Total** | | **~$66/month** |

**Note:** Actual costs depend on:
- Job execution frequency and duration
- Cosmos DB usage (not included in estimate)
- Log Analytics retention (not included in estimate)

### Cost Reduction Tips

1. **Optimize job schedule:** Run delta job less frequently if data freshness allows
2. **Right-size resources:** Monitor actual CPU/memory usage and adjust
3. **Use consumption tier:** Consider Container Apps consumption plan for lower costs
4. **Log retention:** Reduce log retention period in Log Analytics

## Cleanup

To remove all deployed resources:

```bash
# Delete entire resource group
az group delete \
  --name rg-eureka-crawler \
  --yes --no-wait
```

**Warning:** This will permanently delete all resources including:
- All job execution history
- Key Vault (with soft delete, recoverable for 90 days)
- All configuration and logs

To soft-delete only (allows recovery):
```bash
# Delete jobs only
az containerapp job delete --name eureka-backfill --resource-group rg-eureka-crawler --yes
az containerapp job delete --name eureka-delta --resource-group rg-eureka-crawler --yes

# Key Vault will be soft-deleted automatically when deleted
```

## Additional Resources

### Documentation

- [Entra ID / Managed Identity Setup](ENTRA_SETUP.md) - Complete authentication configuration guide
- [Environment Variables Reference](deploy-env.md) - Complete configuration mapping
- [Manual Deployment Guide](deploy-aca.md) - Step-by-step CLI deployment
- [Application Documentation](../CLAUDE.md) - Eureka.Crawler features and architecture

### Azure Documentation

- [Azure Container Apps Jobs](https://learn.microsoft.com/en-us/azure/container-apps/jobs)
- [Azure Key Vault Best Practices](https://learn.microsoft.com/en-us/azure/key-vault/general/best-practices)
- [Managed Identities](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview)
- [CRON Expressions in Azure](https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-timer?tabs=python-v2%2Cisolated-process%2Cnodejs-v4&pivots=programming-language-csharp#ncrontab-expressions)

### Support

- Report issues: [GitHub Issues](https://github.com/your-username/Eureka.Crawler/issues)
- Eureka API documentation: [eureka.mf.gov.pl](https://eureka.mf.gov.pl)
- Microsoft Graph API: [Microsoft Graph Documentation](https://learn.microsoft.com/en-us/graph/)

## Next Steps

After successful deployment:

1. **Start backfill job** to populate initial dataset
2. **Monitor execution** in Azure Portal or via CLI
3. **Verify data** in Cosmos DB
4. **Check SharePoint** for uploaded RTF documents
5. **Set up alerts** for job failures (optional)
6. **Review logs** to optimize configuration
7. **Adjust schedule** based on your requirements

---

**Ready to deploy?** Click the "Deploy to Azure" button at the top of this page to get started!
