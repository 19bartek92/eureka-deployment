# Post-Deployment Guide

Po zakończeniu deployment (około 10-15 minut), wykonaj następujące kroki aby zweryfikować poprawność wdrożenia i rozpocząć pracę.

---

## 1. Weryfikacja utworzonych zasobów

### 1.1. Lista zasobów

```bash
# Zaloguj się do Azure CLI (jeśli jeszcze nie jesteś zalogowany)
az login

# Lista wszystkich zasobów w Resource Group
az resource list \
  --resource-group rg-eureka-crawler \
  --output table
```

**Oczekiwany output (powinny być wszystkie zasoby):**

| Name | Resource Type | Location |
|------|--------------|----------|
| `env-eureka` | Microsoft.App/managedEnvironments | westeurope |
| `eureka-backfill` | Microsoft.App/jobs | westeurope |
| `eureka-delta` | Microsoft.App/jobs | westeurope |
| `id-eureka` | Microsoft.ManagedIdentity/userAssignedIdentities | westeurope |
| `kv-eureka-xxxxx` | Microsoft.KeyVault/vaults | westeurope |
| `cosmos-eureka-xxxxx` | Microsoft.DocumentDB/databaseAccounts | westeurope |

✅ **Jeśli wszystkie 6 zasobów są na liście - deployment OK!**

---

## 2. Weryfikacja Cosmos DB

### 2.1. Sprawdź Cosmos DB account

```bash
# Pobierz nazwę Cosmos DB account
COSMOS_NAME=$(az cosmosdb list \
  --resource-group rg-eureka-crawler \
  --query "[0].name" -o tsv)

echo "Cosmos DB Account: $COSMOS_NAME"

# Sprawdź właściwości
az cosmosdb show \
  --name $COSMOS_NAME \
  --resource-group rg-eureka-crawler \
  --query "{Name:name, Kind:kind, ServerVersion:apiProperties.serverVersion, Endpoint:documentEndpoint}" \
  --output table
```

**Oczekiwany output:**
```
Name                    Kind      ServerVersion  Endpoint
----------------------  --------  -------------  ------------------------------------------------
cosmos-eureka-abc123    MongoDB   4.2            https://cosmos-eureka-abc123.documents.azure.com:443/
```

### 2.2. Sprawdź database

```bash
# Lista databases
az cosmosdb mongodb database list \
  --account-name $COSMOS_NAME \
  --resource-group rg-eureka-crawler \
  --query "[].name" -o table
```

**Oczekiwany output:**
```
Result
--------
eureka
```

### 2.3. Weryfikuj connection string w Key Vault

```bash
# Pobierz nazwę Key Vault
KV_NAME=$(az keyvault list \
  --resource-group rg-eureka-crawler \
  --query "[0].name" -o tsv)

echo "Key Vault: $KV_NAME"

# Sprawdź czy secret 'cosmos-conn' istnieje
az keyvault secret show \
  --vault-name $KV_NAME \
  --name cosmos-conn \
  --query "value" -o tsv
```

**Oczekiwany format:**
```
mongodb://cosmos-eureka-xxxxx:PRIMARY_KEY@cosmos-eureka-xxxxx.mongo.cosmos.azure.com:10255/?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000
```

✅ **Jeśli connection string zaczyna się od `mongodb://` - OK!**

---

## 3. Weryfikacja developer access

### 3.1. Sprawdź RBAC assignment

```bash
# Sprawdź role assignments dla Resource Group
az role assignment list \
  --resource-group rg-eureka-crawler \
  --query "[?principalType=='User'].{Principal:principalName, Role:roleDefinitionName, Scope:scope}" \
  --output table
```

**Oczekiwany output (developer powinien mieć Contributor):**
```
Principal                    Role         Scope
---------------------------  -----------  ----------------------------------------------
bartoszpalmi@hotmail.com     Contributor  /subscriptions/.../resourceGroups/rg-eureka-crawler
```

### 3.2. Test developer access

**Jako developer (`bartoszpalmi@hotmail.com`):**

```bash
# Zaloguj się jako developer
az login --username bartoszpalmi@hotmail.com

# Sprawdź access do Resource Group
az group show --name rg-eureka-crawler

# Sprawdź access do Container Apps Jobs
az containerapp job list \
  --resource-group rg-eureka-crawler \
  --output table
```

**Jeśli komendy działają bez błędów 403 - access OK!** ✅

---

## 4. Pierwsze uruchomienie job

### 4.1. Uruchom backfill job (pełna synchronizacja)

```bash
# Start backfill job (manual trigger)
az containerapp job start \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler
```

**Oczekiwany output:**
```json
{
  "id": "/subscriptions/.../executions/eureka-backfill-xxxxx",
  "name": "eureka-backfill-xxxxx",
  "properties": {
    "status": "Running",
    ...
  }
}
```

### 4.2. Monitor logs (real-time)

```bash
# Obserwuj logi w czasie rzeczywistym
az containerapp job logs show \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler \
  --follow
```

**Przykładowe logi (co powinieneś zobaczyć):**
```
info: Eureka.Crawler.Worker[0]
      Worker running in MODE: backfill

info: Eureka.Crawler.Services.ManagedIdentityDetector[0]
      Managed Identity not available - will use Client Secret authentication

info: Eureka.Crawler.Services.GraphClientFactory[0]
      Using Client Secret for Microsoft Graph API (Tenant: 886b2a43-...)

info: Eureka.Crawler.Worker[0]
      Page 1/3: fetched 100 documents

info: Eureka.Crawler.Infrastructure.Db.InfoRepository[0]
      Upserted 100 documents (inserted: 100, updated: 0)
```

### 4.3. Sprawdź execution history

```bash
# Lista wykonań job
az containerapp job execution list \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler \
  --output table
```

**Przykładowy output:**
```
Name                      Status     StartTime                  EndTime
------------------------  ---------  -------------------------  -------------------------
eureka-backfill-20250119  Succeeded  2025-01-19T10:15:30+00:00  2025-01-19T10:45:12+00:00
```

---

## 5. Developer Workflow

### 5.1. Build i deploy nowej wersji aplikacji

**Krok 1: Build nowego obrazu**

```bash
cd /Users/bartoszpalmi/Projects/alto/Eureka.Crawler

# Build nowej wersji
docker build -t yourregistry.azurecr.io/eureka-crawler:v1.1.0 .

# Push do registry
az acr login --name yourregistry
docker push yourregistry.azurecr.io/eureka-crawler:v1.1.0
```

**Krok 2: Update Container Apps Jobs**

```bash
# Update backfill job
az containerapp job update \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler \
  --image yourregistry.azurecr.io/eureka-crawler:v1.1.0

# Update delta job
az containerapp job update \
  --name eureka-delta \
  --resource-group rg-eureka-crawler \
  --image yourregistry.azurecr.io/eureka-crawler:v1.1.0
```

**Krok 3: Weryfikacja update**

```bash
# Sprawdź czy image został zaktualizowany
az containerapp job show \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler \
  --query "properties.template.containers[0].image" -o tsv
```

**Oczekiwany output:**
```
yourregistry.azurecr.io/eureka-crawler:v1.1.0
```

### 5.2. Monitoring i troubleshooting

**View job execution history:**
```bash
az containerapp job execution list \
  --name eureka-delta \
  --resource-group rg-eureka-crawler \
  --output table
```

**View logs dla konkretnego execution:**
```bash
# Pobierz execution name z poprzedniej komendy
az containerapp job logs show \
  --name eureka-delta \
  --resource-group rg-eureka-crawler \
  --execution eureka-delta-20250119-abc123
```

**Check job configuration:**
```bash
# Sprawdź schedule (CRON)
az containerapp job show \
  --name eureka-delta \
  --resource-group rg-eureka-crawler \
  --query "properties.configuration.scheduleTriggerConfig" -o json
```

**Expected output:**
```json
{
  "cronExpression": "10 4 * * *",
  "parallelism": 1,
  "replicaCompletionCount": 1
}
```

### 5.3. Update environment variables (jeśli potrzeba)

```bash
# Przykład: zmiana MODE dla delta job (normally nie potrzebne)
az containerapp job update \
  --name eureka-delta \
  --resource-group rg-eureka-crawler \
  --set-env-vars "MODE=delta" "Eureka__PageSize=200"
```

### 5.4. Update secrets (przez Key Vault)

```bash
# Update SharePoint Client Secret
az keyvault secret set \
  --vault-name $KV_NAME \
  --name sp-client-secret \
  --value "NEW-SECRET-VALUE"

# Restart job aby użyć nowego secretu
az containerapp job stop \
  --name eureka-delta \
  --resource-group rg-eureka-crawler \
  --execution <running-execution-name>

az containerapp job start \
  --name eureka-delta \
  --resource-group rg-eureka-crawler
```

---

## 6. Scheduled Delta Job

Delta job (`eureka-delta`) uruchamia się automatycznie **codziennie o 4:10 AM UTC**.

**Manual trigger (jeśli potrzebujesz uruchomić wcześniej):**

```bash
az containerapp job start \
  --name eureka-delta \
  --resource-group rg-eureka-crawler
```

**Disable schedule (jeśli chcesz wyłączyć automatyczne uruchamianie):**

```bash
# Usuń schedule trigger (zmienia na manual-only)
az containerapp job update \
  --name eureka-delta \
  --resource-group rg-eureka-crawler \
  --yaml-file /path/to/manual-trigger-config.yaml
```

---

## 7. Cost Monitoring

### 7.1. Miesięczny koszt estimate

```bash
# UWAGA: Wymaga Azure Cost Management API access

# Koszty Resource Group (ostatnie 30 dni)
az consumption usage list \
  --start-date $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-date $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --query "[?contains(instanceId, 'rg-eureka-crawler')].{Service:meterCategory, Cost:pretaxCost}" \
  --output table
```

**Szacunkowe koszty (West Europe):**
- Container Apps Environment: ~$50/miesiąc
- Jobs execution: ~$15/miesiąc
- Key Vault: ~$1/miesiąc
- Cosmos DB (Serverless): $0.25/GB stored + $0.25/1M RU consumed (~$10-30/miesiąc zależnie od użycia)

**Total estimate:** ~$76-96/miesiąc

---

## 8. Troubleshooting

### Problem: Container Apps Job fails to start

**Diagnoza:**
```bash
az containerapp job show \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler \
  --query "properties.{ProvisioningState:provisioningState, LatestRevision:latestRevisionName}" -o json
```

**Common causes:**
- Image pull failure (registry credentials)
- Key Vault access denied (UAMI permissions)
- Invalid environment variables

**Solution:**
```bash
# Check logs dla failed execution
az containerapp job logs show \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler \
  --execution <failed-execution-name>
```

### Problem: Developer nie ma access

**Diagnoza:**
```bash
# Sprawdź RBAC propagation (może trwać do 5 minut)
az role assignment list \
  --resource-group rg-eureka-crawler \
  --assignee bartoszpalmi@hotmail.com
```

**Solution:**
Jeśli RBAC nie pojawia się po 10 minutach, dodaj manualnie:
```bash
az role assignment create \
  --role Contributor \
  --assignee bartoszpalmi@hotmail.com \
  --resource-group rg-eureka-crawler
```

### Problem: Cosmos DB connection fails

**Diagnoza:**
```bash
# Test connection string
CONN_STRING=$(az keyvault secret show \
  --vault-name $KV_NAME \
  --name cosmos-conn \
  --query "value" -o tsv)

echo $CONN_STRING | grep -o "mongodb://.*mongo.cosmos.azure.com:10255"
```

**Solution:**
Sprawdź Cosmos DB firewall settings:
```bash
az cosmosdb show \
  --name $COSMOS_NAME \
  --resource-group rg-eureka-crawler \
  --query "ipRules"
```

Jeśli firewall jest włączony, dodaj Container Apps subnet lub włącz "Allow access from Azure services".

### Problem: SharePoint upload fails (403 Forbidden)

**Common causes:**
- Brak admin consent dla App Registration
- Nieprawidłowe permissions (Files.ReadWrite.All, Sites.ReadWrite.All)

**Solution:**
```bash
# Sprawdź logi aplikacji
az containerapp job logs show \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler \
  --follow | grep "SharePoint\|Graph"
```

Verify admin consent w Azure Portal:
1. Azure AD → App registrations → Eureka.Crawler.SharePoint
2. API permissions → Status should show "Granted for [tenant]"

---

## 9. Next Steps

✅ **Deployment verified and working!**

**Regular operations:**
- Delta job runs automatically daily
- Developer can deploy updates via `az containerapp job update`
- Monitor costs via Azure Cost Management
- Check execution logs for errors

**Optional enhancements:**
- Setup Log Analytics workspace for advanced monitoring
- Configure alerts dla failed job executions
- Enable Application Insights dla performance monitoring
- Setup backup strategy dla Cosmos DB

**Documentation:**
- [Configuration Reference](CONFIGURATION.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [FAQ](FAQ.md)

---

**Questions or issues?**
Contact: bartoszpalmi@hotmail.com (Developer)
