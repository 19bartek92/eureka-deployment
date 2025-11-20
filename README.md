# Eureka.Crawler - Azure Deployment

**One-click deployment** for Eureka.Crawler - a .NET 9.0 Worker Service that integrates with the public Eureka API (eureka.mf.gov.pl) to fetch and process Polish government legal documents.

> **Note:** This repository contains **deployment artifacts only**. Application source code is maintained separately.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fyour-username%2Feureka-deployment%2Fmain%2Fbicep%2Fmain.json)

---

## What Gets Deployed?

Click the "Deploy to Azure" button above to create:

- ✅ **Resource Group** - container for all resources
- ✅ **Azure Cosmos DB for MongoDB** - Serverless database (auto-created)
  - Database: `eureka`
  - Connection string automatically stored in Key Vault
- ✅ **Container Apps Environment** - managed runtime for jobs
- ✅ **User-Assigned Managed Identity (UAMI)** - passwordless authentication
- ✅ **Azure Key Vault** - secure secrets storage (RBAC-based)
- ✅ **2 Container Apps Jobs**:
  - `eureka-backfill` - manual trigger for full sync (24h timeout)
  - `eureka-delta` - scheduled daily updates at 4:10 AM UTC (1h timeout)
- ✅ **Developer Access** - `bartoszpalmi@hotmail.com` automatically granted **Contributor** role

**Deployment time:** ~10-15 minutes

---

## Prerequisites

Before clicking "Deploy to Azure", complete these steps:

### 1. Azure Entra ID (App Registration)

Setup SharePoint authentication:

📖 **Full guide:** [docs/ENTRA_SETUP.md](docs/ENTRA_SETUP.md)

**Quick steps:**
1. Azure Portal → Azure Active Directory → App registrations → New registration
2. Name: `Eureka.Crawler.SharePoint`
3. Create client secret
4. Add API permissions: `Files.ReadWrite.All`, `Sites.ReadWrite.All`
5. Grant admin consent

**You'll need:** Tenant ID, Client ID, Client Secret

### 2. SharePoint (Site ID and Drive ID)

📖 **Full guide:** [docs/ENTRA_SETUP.md#finding-site-and-drive-ids](docs/ENTRA_SETUP.md#finding-site-and-drive-ids)

**Quick method:** [Graph Explorer](https://developer.microsoft.com/graph/graph-explorer)
```
GET https://graph.microsoft.com/v1.0/sites?search=YourSiteName
GET https://graph.microsoft.com/v1.0/sites/{siteId}/drives
```

**You'll need:** Site ID, Drive ID

### 3. Developer Object ID (for automatic access)

```bash
az login
az ad user show --id bartoszpalmi@hotmail.com --query id -o tsv
```

**You'll need:** Developer Object ID (GUID format)

### 4. Container Image

Your pre-built Docker image URL (e.g., `yourregistry.azurecr.io/eureka-crawler:latest`)

**You'll need:** Image URL, Registry credentials (username + password/PAT)

---

## Deployment Parameters

When you click "Deploy to Azure", fill in these parameters:

| Parameter | Description | Example |
|-----------|-------------|---------|
| **Resource Group** | New or existing RG | `rg-eureka-crawler` |
| **Location** | Azure region | `West Europe` |
| **Container Image** | Full image URL | `myregistry.azurecr.io/eureka-crawler:latest` |
| **Registry Server** | Container registry URL | `myregistry.azurecr.io` |
| **Registry Username** | Registry login | `myregistry` |
| **Registry Password** | Registry PAT/password | `***` (secret) |
| **SharePoint Tenant ID** | From Entra ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| **SharePoint Client ID** | From App Registration | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| **SharePoint Client Secret** | From App Registration | `***` (secret) |
| **SharePoint Site ID** | From Graph Explorer | `contoso.sharepoint.com,xxx...` |
| **SharePoint Drive ID** | From Graph Explorer | `b!xxx...` |
| **Cosmos Account Name** | Globally unique name | `cosmos-eureka-abc123` |
| **Developer Object ID** | Azure AD Object ID | `a1b2c3d4-e5f6-7890-abcd-ef1234567890` |

---

## After Deployment

📖 **Full guide:** [docs/POST_DEPLOYMENT.md](docs/POST_DEPLOYMENT.md)

### Quick verification:

```bash
# List created resources
az resource list --resource-group rg-eureka-crawler --output table

# Verify developer access
az role assignment list \
  --resource-group rg-eureka-crawler \
  --query "[?principalType=='User']" --output table

# Start first job
az containerapp job start \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler

# Monitor logs
az containerapp job logs show \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler \
  --follow
```

---

## Architecture

```
┌────────────────────────────────────────────────────────┐
│           Azure Container Apps Environment              │
│                                                          │
│  ┌─────────────────┐        ┌─────────────────┐        │
│  │ Backfill Job    │        │ Delta Job       │        │
│  │ (Manual)        │        │ (CRON: 4:10 UTC)│        │
│  │ Timeout: 24h    │        │ Timeout: 1h     │        │
│  └────────┬────────┘        └────────┬────────┘        │
│           │                          │                  │
│           └──────────┬───────────────┘                  │
│                      │                                   │
│              ┌───────▼─────────┐                        │
│              │ UAMI (Identity) │                        │
│              │ - Key Vault     │                        │
│              │ - Cosmos DB     │                        │
│              └───────┬─────────┘                        │
└──────────────────────┼──────────────────────────────────┘
                       │
            ┌──────────▼───────────┐
            │   Azure Key Vault    │
            │  ┌─────────────────┐ │
            │  │ cosmos-conn     │ │ ← Auto-generated
            │  │ sp-tenant       │ │
            │  │ sp-client-id    │ │
            │  │ sp-client-secret│ │
            │  │ sp-site         │ │
            │  │ sp-drive        │ │
            │  └─────────────────┘ │
            └──────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
   ┌────▼─────┐  ┌────▼────┐  ┌──────▼────────┐
   │Cosmos DB │  │SharePoint│  │Eureka API     │
   │(MongoDB) │  │(Graph)   │  │(Public)       │
   │Serverless│  │          │  │               │
   └──────────┘  └─────────┘  └───────────────┘
```

---

## Documentation

- 🇵🇱 **[Polski - Quick Start](docs/QUICK_START_PL.md)** - Instrukcja krok po kroku
- 🇬🇧 **[Full Deployment Guide](docs/DEPLOY.md)** - Detailed instructions
- 🔐 **[Entra ID Setup](docs/ENTRA_SETUP.md)** - Authentication configuration
- ✅ **[Post-Deployment Guide](docs/POST_DEPLOYMENT.md)** - Verification & developer workflow
- ❓ **[FAQ](docs/FAQ.md)** - Common questions

---

## Developer Workflow

After deployment, developer (`bartoszpalmi@hotmail.com`) can:

### Build and deploy updates:

```bash
# 1. Build new version
docker build -t registry/eureka-crawler:v1.1.0 .
docker push registry/eureka-crawler:v1.1.0

# 2. Update Container Apps Jobs
az containerapp job update \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler \
  --image registry/eureka-crawler:v1.1.0

az containerapp job update \
  --name eureka-delta \
  --resource-group rg-eureka-crawler \
  --image registry/eureka-crawler:v1.1.0
```

### Monitor and troubleshoot:

```bash
# View job execution history
az containerapp job execution list \
  --name eureka-delta \
  --resource-group rg-eureka-crawler \
  --output table

# View logs
az containerapp job logs show \
  --name eureka-delta \
  --resource-group rg-eureka-crawler \
  --follow
```

---

## Cost Estimate

**Approximate monthly costs (West Europe, 2025):**

| Service | Cost/month |
|---------|------------|
| Container Apps Environment | ~$50 |
| Container Apps Jobs execution | ~$15 |
| Azure Key Vault | ~$1 |
| Cosmos DB (Serverless) | ~$10-30* |
| **Total** | **~$76-96** |

*Depends on data volume and request units consumed

**Free tier:** First 180,000 vCPU-seconds/month free, first 360,000 GiB-seconds/month free

---

## Security

- ✅ **Zero secrets in repository** - all in Azure Key Vault
- ✅ **Managed Identity authentication** - passwordless, Azure-managed
- ✅ **RBAC-based access** - least privilege principle
- ✅ **Soft delete enabled** - Key Vault recovery protection
- ✅ **Automatic Cosmos DB creation** - no manual connection string management

---

## Support

- **Deployment issues:** Check [docs/POST_DEPLOYMENT.md](docs/POST_DEPLOYMENT.md) troubleshooting section
- **Application support:** Contact developer (bartoszpalmi@hotmail.com)
- **Documentation:** See [docs/](docs/) folder

---

## License

**Copyright © 2025. All rights reserved.**

This deployment configuration is provided as-is for reference and deployment purposes only.
Application source code is separately licensed and not included in this repository.

---

**Last Updated:** 2025-01-19
**Compatible with:** Eureka.Crawler v1.x
**Maintained by:** Developer Team
