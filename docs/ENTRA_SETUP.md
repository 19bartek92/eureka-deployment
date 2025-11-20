# Microsoft Entra ID Setup Guide

This guide covers authentication setup for Eureka.Crawler using Microsoft Entra ID (formerly Azure Active Directory). The application supports **two authentication modes** for accessing Azure services (SharePoint Graph API and Cosmos DB).

---

**🇵🇱 Szukasz prostej instrukcji krok po kroku w języku polskim?**
Zobacz: **[Instrukcja przygotowania (Polski)](QUICK_START_PL.md)** - uproszczona wersja tego dokumentu.

---

## Table of Contents

1. [Authentication Modes Overview](#authentication-modes-overview)
2. [Section A: Client Secret Authentication (Traditional)](#section-a-client-secret-authentication-traditional)
3. [Section B: Managed Identity Authentication (Recommended for Production)](#section-b-managed-identity-authentication-recommended-for-production)
4. [Section C: Comparison - Secret vs Managed Identity](#section-c-comparison---secret-vs-managed-identity)
5. [Section D: Troubleshooting](#section-d-troubleshooting)

---

## Authentication Modes Overview

Eureka.Crawler automatically detects which authentication mode to use based on available configuration:

### Auto-Detection Logic

```
IF AZURE_CLIENT_ID environment variable is set:
    → Use Managed Identity (production mode)
ELSE IF SharePoint__ClientSecret is provided:
    → Use Client Secret (development/local mode)
ELSE:
    → Fail with configuration error
```

### When to Use Each Mode

| Mode | Use Case | Environment | Security |
|------|----------|-------------|----------|
| **Client Secret** | Local development, testing | Local machine, dev containers | 🟡 Moderate - requires secret rotation |
| **Managed Identity** | Production workloads | Azure Container Apps, VMs, App Service | 🟢 High - no secrets to manage |

---

## Section A: Client Secret Authentication (Traditional)

This method uses an Azure AD App Registration with a client secret. Suitable for local development and environments where Managed Identity is not available.

### Step 1: Create App Registration

1. Navigate to [Azure Portal](https://portal.azure.com)
2. Go to **Microsoft Entra ID** → **App registrations**
3. Click **New registration**
4. Configure:
   - **Name:** `Eureka.Crawler.SharePoint`
   - **Supported account types:** Accounts in this organizational directory only (Single tenant)
   - **Redirect URI:** Leave empty (daemon/console app)
5. Click **Register**

### Step 2: Configure API Permissions

After creating the app registration:

1. Go to **API permissions** in the left menu
2. Click **Add a permission**

#### For SharePoint Access (Microsoft Graph)

1. Select **Microsoft Graph**
2. Select **Application permissions** (NOT Delegated permissions)
3. Add these permissions:
   - `Files.ReadWrite.All` - Read and write files in all site collections
   - `Sites.ReadWrite.All` - Read and write items in all site collections
4. Click **Add permissions**

#### Grant Admin Consent

⚠️ **IMPORTANT:** Application permissions require admin consent.

1. Click **Grant admin consent for [Your Organization]**
2. Confirm by clicking **Yes**
3. Wait for status to show green checkmarks

### Step 3: Create Client Secret

1. Go to **Certificates & secrets**
2. Click **New client secret**
3. Configure:
   - **Description:** `Eureka Crawler Production Secret`
   - **Expires:** 24 months (or per your org policy)
4. Click **Add**
5. **IMMEDIATELY copy the secret Value** - you won't see it again!

### Step 4: Collect Required Values

From the App Registration overview page, collect:

| Value | Where to Find | Configuration Key |
|-------|--------------|-------------------|
| Application (client) ID | Overview page | `SharePoint__ClientId` |
| Directory (tenant) ID | Overview page | `SharePoint__TenantId` |
| Client secret value | Certificates & secrets (from Step 3) | `SharePoint__ClientSecret` |

### Step 5: Configure Application (Client Secret Mode)

#### For Local Development

Create `appsettings.Development.json` (excluded from git):

```json
{
  "SharePoint": {
    "TenantId": "886b2a43-292d-44f9-b46b-1645d550b7c3",
    "ClientId": "b369a886-5cef-443a-9621-4dedacf854cc",
    "ClientSecret": "EUc8Q~qf1234567890abcdefg",
    "SiteId": "your-site-id",
    "DriveId": "your-drive-id",
    "FolderFormat": "yyyyMM"
  },
  "Cosmos": {
    "ConnectionString": "mongodb://localhost:27017"
  }
}
```

#### For Azure (using Key Vault)

DO NOT set `AZURE_CLIENT_ID` environment variable. Secrets will be loaded from Key Vault, and the application will use Client Secret authentication.

---

## Section B: Managed Identity Authentication (Recommended for Production)

This method uses Azure User-Assigned Managed Identity (UAMI) to access SharePoint and Cosmos DB without storing any secrets. The existing UAMI `id-eureka` (created during deployment) is used.

### Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│         Azure Container Apps Job                          │
│                                                            │
│  ┌─────────────────────────────────────────────────┐     │
│  │  Eureka.Crawler Application                      │     │
│  │                                                   │     │
│  │  ENV: AZURE_CLIENT_ID = <UAMI-client-id>        │     │
│  │       SharePoint__TenantId = <tenant-id>         │     │
│  │       SharePoint__SiteId = <site-id>            │     │
│  │       SharePoint__DriveId = <drive-id>          │     │
│  │                                                   │     │
│  │  Authentication:                                  │     │
│  │  ✅ Uses Managed Identity (no secrets!)          │     │
│  └─────────────────────────────────────────────────┘     │
│                         │                                  │
│                         │ Assigned identity                │
│                         ▼                                  │
│  ┌─────────────────────────────────────────────────┐     │
│  │  User-Assigned Managed Identity                  │     │
│  │  Name: id-eureka                                 │     │
│  │  Client ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx │     │
│  │  Principal ID: yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyy  │     │
│  └─────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────┘
                         │
           ┌─────────────┴──────────────┐
           │                            │
           ▼                            ▼
┌──────────────────────┐    ┌──────────────────────┐
│  Microsoft Graph API  │    │   Cosmos DB          │
│  (SharePoint)         │    │   (MongoDB API)      │
│                       │    │                      │
│  RBAC Assigned:       │    │  RBAC Assigned:      │
│  • Files.ReadWrite.All│    │  • Data Contributor  │
│  • Sites.ReadWrite.All│    │                      │
└──────────────────────┘    └──────────────────────┘
```

### Prerequisites

- User-Assigned Managed Identity `id-eureka` already created (from deployment)
- Azure Container Apps Job or other Azure service with UAMI assigned
- Permissions to assign RBAC roles in Entra ID and Cosmos DB

### Step 1: Assign Graph API Permissions to UAMI

Managed Identities cannot use the Portal UI for Graph API permissions. You must use Microsoft Graph API or PowerShell.

#### Option 1: Using Azure CLI and REST API (Recommended)

```bash
# Variables
UAMI_NAME="id-eureka"
RESOURCE_GROUP="rg-eureka-crawler"

# Get UAMI details
UAMI_PRINCIPAL_ID=$(az identity show \
  --name $UAMI_NAME \
  --resource-group $RESOURCE_GROUP \
  --query principalId \
  --output tsv)

UAMI_CLIENT_ID=$(az identity show \
  --name $UAMI_NAME \
  --resource-group $RESOURCE_GROUP \
  --query clientId \
  --output tsv)

echo "UAMI Principal ID: $UAMI_PRINCIPAL_ID"
echo "UAMI Client ID: $UAMI_CLIENT_ID"

# Get Microsoft Graph Service Principal ID
GRAPH_SP_ID=$(az ad sp list \
  --query "[?appId=='00000003-0000-0000-c000-000000000000'].id" \
  --output tsv)

echo "Microsoft Graph SP ID: $GRAPH_SP_ID"

# Get App Role IDs for required permissions
# Files.ReadWrite.All = 75359482-378d-4052-8f01-80520e7db3cd
# Sites.ReadWrite.All = 9492366f-7969-46a4-8d15-ed1a20078fff

FILES_ROLE_ID="75359482-378d-4052-8f01-80520e7db3cd"
SITES_ROLE_ID="9492366f-7969-46a4-8d15-ed1a20078fff"

# Get access token
TOKEN=$(az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv)

# Assign Files.ReadWrite.All
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"principalId\": \"$UAMI_PRINCIPAL_ID\",
    \"resourceId\": \"$GRAPH_SP_ID\",
    \"appRoleId\": \"$FILES_ROLE_ID\"
  }" \
  "https://graph.microsoft.com/v1.0/servicePrincipals/$UAMI_PRINCIPAL_ID/appRoleAssignments"

# Assign Sites.ReadWrite.All
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"principalId\": \"$UAMI_PRINCIPAL_ID\",
    \"resourceId\": \"$GRAPH_SP_ID\",
    \"appRoleId\": \"$SITES_ROLE_ID\"
  }" \
  "https://graph.microsoft.com/v1.0/servicePrincipals/$UAMI_PRINCIPAL_ID/appRoleAssignments"
```

#### Option 2: Using PowerShell (Alternative)

```powershell
# Install required module
Install-Module -Name Microsoft.Graph -Scope CurrentUser

# Connect with admin account
Connect-MgGraph -Scopes "AppRoleAssignment.ReadWrite.All", "Application.Read.All"

# Get UAMI details
$uamiName = "id-eureka"
$resourceGroup = "rg-eureka-crawler"

$uami = az identity show --name $uamiName --resource-group $resourceGroup | ConvertFrom-Json
$principalId = $uami.principalId
$clientId = $uami.clientId

Write-Host "UAMI Principal ID: $principalId"
Write-Host "UAMI Client ID: $clientId"

# Get Microsoft Graph service principal
$graphSp = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"

# Get app roles
$filesRole = $graphSp.AppRoles | Where-Object { $_.Value -eq "Files.ReadWrite.All" }
$sitesRole = $graphSp.AppRoles | Where-Object { $_.Value -eq "Sites.ReadWrite.All" }

# Get UAMI service principal
$uamiSp = Get-MgServicePrincipal -Filter "servicePrincipalType eq 'ManagedIdentity' and displayName eq '$uamiName'"

# Assign Files.ReadWrite.All
New-MgServicePrincipalAppRoleAssignment `
  -ServicePrincipalId $uamiSp.Id `
  -PrincipalId $uamiSp.Id `
  -ResourceId $graphSp.Id `
  -AppRoleId $filesRole.Id

# Assign Sites.ReadWrite.All
New-MgServicePrincipalAppRoleAssignment `
  -ServicePrincipalId $uamiSp.Id `
  -PrincipalId $uamiSp.Id `
  -ResourceId $graphSp.Id `
  -AppRoleId $sitesRole.Id

Write-Host "Graph API permissions assigned successfully"
```

### Step 2: Assign Cosmos DB Permissions to UAMI

```bash
# Variables
COSMOS_ACCOUNT_NAME="your-cosmos-account"
COSMOS_RESOURCE_GROUP="your-cosmos-rg"
UAMI_PRINCIPAL_ID="<principal-id-from-step-1>"

# Get Cosmos DB account resource ID
COSMOS_ID=$(az cosmosdb show \
  --name $COSMOS_ACCOUNT_NAME \
  --resource-group $COSMOS_RESOURCE_GROUP \
  --query id \
  --output tsv)

# Assign "Cosmos DB Built-in Data Contributor" role
# Role definition ID: 00000000-0000-0000-0000-000000000002
az cosmosdb sql role assignment create \
  --account-name $COSMOS_ACCOUNT_NAME \
  --resource-group $COSMOS_RESOURCE_GROUP \
  --role-definition-id "00000000-0000-0000-0000-000000000002" \
  --principal-id $UAMI_PRINCIPAL_ID \
  --scope "/"

echo "Cosmos DB Data Contributor role assigned to UAMI"
```

### Step 3: Configure Application (Managed Identity Mode)

#### Update Container Apps Job YAML

Add the UAMI Client ID as an environment variable:

```yaml
env:
# Enable Managed Identity mode by setting AZURE_CLIENT_ID
- name: AZURE_CLIENT_ID
  value: "<UAMI-client-id>"  # From Step 1

# SharePoint configuration (non-secret values)
- name: SharePoint__TenantId
  value: "<your-tenant-id>"
- name: SharePoint__SiteId
  secretRef: sharepoint-site-id  # Or direct value
- name: SharePoint__DriveId
  secretRef: sharepoint-drive-id  # Or direct value
- name: SharePoint__FolderFormat
  value: "yyyyMM"

# NOTE: SharePoint__ClientId and SharePoint__ClientSecret are NOT needed in MI mode
# NOTE: Cosmos__ConnectionString should NOT include credentials (MI will authenticate)
```

#### Cosmos DB Connection String for Managed Identity

When using Managed Identity with Cosmos DB, use a connection string **without credentials**:

```bash
# Standard connection string (with secret):
mongodb://account:KEY@account.mongo.cosmos.azure.com:10255/?ssl=true...

# Managed Identity connection string (no secret):
mongodb://account.mongo.cosmos.azure.com:10255/?ssl=true&authSource=$external&authMechanism=MONGODB-X509
```

**Note:** Cosmos DB Managed Identity support for MongoDB API may require additional configuration. Verify support in [Cosmos DB documentation](https://learn.microsoft.com/en-us/azure/cosmos-db/how-to-setup-managed-identity).

### Step 4: Verify RBAC Assignments

```bash
# Verify Graph API permissions
TOKEN=$(az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv)

curl -H "Authorization: Bearer $TOKEN" \
  "https://graph.microsoft.com/v1.0/servicePrincipals/$UAMI_PRINCIPAL_ID/appRoleAssignments" \
  | jq '.value[] | {appRoleId, resourceDisplayName}'

# Expected output should include:
# - Files.ReadWrite.All on Microsoft Graph
# - Sites.ReadWrite.All on Microsoft Graph

# Verify Cosmos DB role assignment
az cosmosdb sql role assignment list \
  --account-name $COSMOS_ACCOUNT_NAME \
  --resource-group $COSMOS_RESOURCE_GROUP \
  --query "[?principalId=='$UAMI_PRINCIPAL_ID']"
```

### Step 5: Test Managed Identity Authentication

Deploy the updated job configuration and monitor logs:

```bash
# Start job
az containerapp job start \
  --name eureka-delta \
  --resource-group rg-eureka-crawler

# Watch logs for authentication method
az containerapp job logs show \
  --name eureka-delta \
  --resource-group rg-eureka-crawler \
  --follow | grep -i "identity\|auth"

# Look for log messages indicating:
# - "Using Managed Identity authentication" (success)
# - "Using Client Secret authentication" (fallback)
```

---

## Section C: Comparison - Secret vs Managed Identity

### Security Posture

| Aspect | Client Secret | Managed Identity |
|--------|---------------|------------------|
| **Secret Storage** | Key Vault or config files | No secrets - Azure manages tokens |
| **Secret Rotation** | Manual (every 24 months) | Automatic (hourly) |
| **Secret Exposure Risk** | 🟡 Moderate (can be leaked in logs, config) | 🟢 None (tokens never exposed) |
| **Audit Trail** | App Registration audit logs | Managed Identity audit logs |
| **Credential Theft Risk** | 🟡 High (secret can be stolen) | 🟢 Low (tokens are short-lived, scoped) |

### Management Overhead

| Task | Client Secret | Managed Identity |
|------|---------------|------------------|
| **Initial Setup** | 🟢 Simple (Portal UI) | 🟡 Moderate (requires scripting) |
| **Secret Rotation** | 🔴 Manual every 1-2 years | 🟢 Automatic |
| **Multi-Environment** | 🔴 Different secrets per env | 🟢 Same identity, different RBAC |
| **Monitoring** | 🟡 Key Vault logs | 🟢 Managed Identity logs |
| **Disaster Recovery** | 🔴 Regenerate secrets, update KV | 🟢 Recreate identity, reassign RBAC |

### Cost Implications

| Resource | Client Secret | Managed Identity |
|----------|---------------|------------------|
| **Key Vault** | ~$1/month (secret storage) | Not required for auth |
| **UAMI** | Not used | Free |
| **Operations** | Key Vault access charges (~$0.03/10k ops) | Free token acquisition |
| **Total** | ~$1-2/month | ~$0/month |

### Use Cases

#### ✅ Use Client Secret When:

- Running locally on developer machine
- Testing in non-Azure environments (e.g., on-premises)
- Quick prototyping without Azure infrastructure
- CI/CD pipelines in GitHub Actions (with secrets)

#### ✅ Use Managed Identity When:

- Production workloads in Azure (Container Apps, VMs, App Service)
- Compliance requirements mandate no static secrets
- Zero-trust security model required
- Multi-region deployments (same identity, regional RBAC)

---

## Section D: Troubleshooting

### Problem: "Authentication failed" in Managed Identity mode

**Symptoms:**
- Logs show: `Azure.Identity.AuthenticationFailedException`
- SharePoint upload fails with 401/403 errors

**Possible Causes:**
1. UAMI not assigned to Container Apps Job
2. Graph API permissions not granted to UAMI
3. RBAC propagation delay (can take up to 30 minutes)

**Solutions:**

```bash
# Verify UAMI is assigned to job
az containerapp job show \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler \
  --query "identity.userAssignedIdentities"

# Should show: { "/subscriptions/.../id-eureka": {} }

# Verify Graph API permissions (PowerShell)
$uamiSp = Get-MgServicePrincipal -Filter "displayName eq 'id-eureka'"
Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $uamiSp.Id |
  Select-Object AppRoleId, ResourceDisplayName

# Wait for RBAC propagation
sleep 1800  # 30 minutes
```

### Problem: Application still uses Client Secret despite AZURE_CLIENT_ID being set

**Symptoms:**
- Logs show: "Using Client Secret authentication"
- `AZURE_CLIENT_ID` environment variable is set

**Possible Causes:**
1. `SharePoint__ClientSecret` is still provided (app prefers secrets)
2. Application code prioritizes secret over MI

**Solutions:**

```bash
# Remove SharePoint__ClientSecret from environment variables
az containerapp job update \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler \
  --remove-env-vars "SharePoint__ClientSecret"

# Verify environment variables
az containerapp job show \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler \
  --query "properties.template.containers[0].env" \
  | jq '.[] | select(.name | contains("SharePoint") or contains("AZURE"))'
```

### Problem: Cosmos DB connection fails with Managed Identity

**Symptoms:**
- Connection string authentication works, but MI fails
- Error: `MongoAuthenticationException`

**Possible Causes:**
1. Cosmos DB MongoDB API may not fully support Managed Identity (as of 2025)
2. Connection string includes credentials (incompatible with MI)

**Solutions:**

```bash
# Option 1: Continue using connection string with Key Vault secret
# MI is used ONLY for SharePoint, Cosmos uses traditional connection string

# Option 2: Use Cosmos DB SQL API with full MI support
# Requires application code changes

# Option 3: Verify Cosmos DB MI support in latest docs
# https://learn.microsoft.com/en-us/azure/cosmos-db/how-to-setup-managed-identity
```

**Current Recommendation:** Use Managed Identity for SharePoint only. Keep Cosmos DB connection string in Key Vault until MongoDB API supports MI.

### Problem: "Invalid client" error in Graph API calls

**Symptoms:**
- Error: `AADSTS700016: Application with identifier 'xxxxx' was not found`
- UAMI Client ID is correct

**Possible Causes:**
1. Using UAMI Client ID where App Registration Client ID is expected
2. Multi-tenant configuration mismatch

**Solutions:**

```bash
# Verify you're using UAMI Client ID (not App Registration Client ID)
UAMI_CLIENT_ID=$(az identity show \
  --name id-eureka \
  --resource-group rg-eureka-crawler \
  --query clientId \
  --output tsv)

echo "Correct UAMI Client ID: $UAMI_CLIENT_ID"

# Update AZURE_CLIENT_ID environment variable with this value
```

### Problem: RBAC assignment succeeds but permissions not working

**Symptoms:**
- `az cosmosdb sql role assignment create` succeeds
- Application still gets 403 errors

**Possible Causes:**
1. RBAC propagation delay (Azure global replication)
2. Wrong scope assigned (should be `/` for database account)
3. Using wrong role definition ID

**Solutions:**

```bash
# Wait for propagation (up to 30 minutes in some regions)
sleep 1800

# Verify role assignment scope
az cosmosdb sql role assignment list \
  --account-name $COSMOS_ACCOUNT_NAME \
  --resource-group $COSMOS_RESOURCE_GROUP \
  --query "[?principalId=='$UAMI_PRINCIPAL_ID'].{Scope:scope, RoleDefinitionId:roleDefinitionId}"

# Expected: scope should be "/" (entire account)

# Verify correct role definition ID
# Built-in Data Contributor: 00000000-0000-0000-0000-000000000002
# Built-in Data Reader:      00000000-0000-0000-0000-000000000001
```

### Problem: Graph API permissions assignment fails with "Insufficient privileges"

**Symptoms:**
- PowerShell: `Insufficient privileges to complete the operation`
- REST API: `Authorization_RequestDenied`

**Possible Causes:**
1. Logged-in user lacks required Entra ID roles
2. Missing `AppRoleAssignment.ReadWrite.All` consent

**Solutions:**

```powershell
# Ensure you're logged in as Global Administrator or Application Administrator
Connect-MgGraph -Scopes "AppRoleAssignment.ReadWrite.All", "Application.Read.All"

# Check current permissions
Get-MgContext | Select-Object -ExpandProperty Scopes

# If missing, re-authenticate
Disconnect-MgGraph
Connect-MgGraph -Scopes "AppRoleAssignment.ReadWrite.All", "Application.Read.All"
```

### Diagnostic Commands

```bash
# Check UAMI details
az identity show --name id-eureka --resource-group rg-eureka-crawler

# List all role assignments for UAMI
UAMI_PRINCIPAL_ID="<principal-id>"
az role assignment list --assignee $UAMI_PRINCIPAL_ID --all --output table

# Test Graph API access with managed identity (from Container Apps)
# This requires running inside the container with AZURE_CLIENT_ID set
curl -H "Metadata: true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://graph.microsoft.com" \
  | jq .access_token

# Decode token to verify claims (use https://jwt.ms/)
```

---

## Additional Resources

### Microsoft Documentation

- [Managed Identities Overview](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview)
- [Assign Graph API Permissions to Managed Identity](https://learn.microsoft.com/en-us/graph/api/serviceprincipal-post-approleassignments)
- [Cosmos DB Managed Identity Setup](https://learn.microsoft.com/en-us/azure/cosmos-db/how-to-setup-managed-identity)
- [Azure Identity SDK for .NET](https://learn.microsoft.com/en-us/dotnet/api/overview/azure/identity-readme)

### Related Documentation

- [Main Deployment Guide](DEPLOY.md)
- [Environment Variables Reference](deploy-env.md)
- [Manual Deployment Guide](deploy-aca.md)

---

**Last Updated:** 2025-11-17

**Status:** Production-ready for both authentication modes
