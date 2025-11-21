# Eureka.Crawler - Wdrożenie w Azure

**Instalacja w jeden klik** dla aplikacji Eureka.Crawler - systemu pobierania dokumentów prawnych z eureka.mf.gov.pl.

> **Uwaga:** To repozytorium zawiera **tylko pliki deployment**. Kod aplikacji jest utrzymywany osobno.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2F19bartek92%2Feureka-deployment%2Fmain%2Fbicep%2Fmain.json)

---

## Co zostanie wdrożone?

Kliknij przycisk "Deploy to Azure" powyżej aby utworzyć:

- ✅ **Resource Group** - kontener dla wszystkich zasobów
- ✅ **Azure Container Registry (ACR)** - Private registry dla obrazów Docker (~$5/miesiąc)
  - UAMI automatic pull access (zero credentials potrzebnych)
- ✅ **Azure Cosmos DB** - Baza danych MongoDB (automatycznie tworzona, Serverless)
  - Connection string automatycznie w Key Vault
- ✅ **Container Apps Environment** - środowisko uruchomieniowe dla jobów
- ✅ **User-Assigned Managed Identity (UAMI)** - uwierzytelnianie bez haseł
- ✅ **Azure Key Vault** - bezpieczne przechowywanie sekretów (RBAC)
- ✅ **2 Container Apps Jobs**:
  - `eureka-backfill` - ręczne uruchamianie (pełna synchronizacja, 24h timeout)
  - `eureka-delta` - codzienne aktualizacje o 4:10 UTC (1h timeout)
- ✅ **Developer Access** - automatyczne nadanie roli **Contributor** dla developera

**Czas wdrożenia:** ~10-15 minut

---

## Wymagania wstępne

Przed kliknięciem "Deploy to Azure" wykonaj poniższe kroki:

### 1. Azure Entra ID (App Registration dla SharePoint)

Setup uwierzytelniania SharePoint:

📖 **Pełna instrukcja:** [docs/SETUP_ENTRA_ID.md](docs/SETUP_ENTRA_ID.md)

**Skrócone kroki:**
1. Azure Portal → Azure Active Directory → App registrations → New registration
2. Nazwa: `Eureka.Crawler.SharePoint`
3. Utwórz client secret
4. Dodaj uprawnienia API: `Files.ReadWrite.All`, `Sites.ReadWrite.All`
5. Nadaj admin consent

**Będziesz potrzebować:** Tenant ID, Client ID, Client Secret

### 2. SharePoint (Site ID i Drive ID)

📖 **Pełna instrukcja:** [docs/SETUP_SHAREPOINT.md](docs/SETUP_SHAREPOINT.md)

**Najszybsza metoda:** [Graph Explorer](https://developer.microsoft.com/graph/graph-explorer)
```
GET https://graph.microsoft.com/v1.0/sites?search=NazwaTwojegoSite
GET https://graph.microsoft.com/v1.0/sites/{siteId}/drives
```

**Będziesz potrzebować:** Site ID, Drive ID

### 3. Developer Object ID

**Otrzymasz od developera:**
- Developer Object ID (format GUID)

Developer wykona:
```bash
az ad user show --id bartoszpalmi@hotmail.com --query id -o tsv
```

**NIE MUSISZ** instalować Azure CLI ani szukać tego samodzielnie - developer dostarczy gotową wartość.

---

## Parametry deployment

Kiedy klikniesz "Deploy to Azure", wypełnij formularz:

| Parametr | Opis | Przykład | Default |
|----------|------|----------|---------|
| **Resource Group** | Nowa lub istniejąca RG | `rg-eureka-crawler` | - |
| **Location** | Region Azure | `West Europe` | - |
| **ACR Name** | Nazwa Azure Container Registry | `acreureka` | `acr${uniqueString(...)}` |
| **Image Name** | Nazwa obrazu Docker | `eureka-crawler` | `eureka-crawler` |
| **Image Tag** | Tag obrazu | `latest` | `latest` |
| **SharePoint Tenant ID** | Z Entra ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` | - |
| **SharePoint Client ID** | Z App Registration | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` | - |
| **SharePoint Client Secret** | Z App Registration | `***` (sekret) | - |
| **SharePoint Site ID** | Z Graph Explorer | `contoso.sharepoint.com,xxx...` | - |
| **SharePoint Drive ID** | Z Graph Explorer | `b!xxx...` | - |
| **Cosmos Account Name** | Nazwa Cosmos DB | `cosmos-eureka-abc123` | `cosmos-eureka-${uniqueString(...)}` |
| **Developer Object ID** | Od developera | `a1b2c3d4-e5f6-7890-abcd-ef1234567890` | - |

**Uwaga:** ACR Name, Image Name, Image Tag mają sensowne defaulty - możesz zostawić puste jeśli nie masz specjalnych wymagań.

---

## Architektura

```
┌────────────────────────────────────────────────────────┐
│           Azure Container Apps Environment              │
│                                                          │
│  ┌─────────────────┐        ┌─────────────────┐        │
│  │ Backfill Job    │        │ Delta Job       │        │
│  │ (Ręczny)        │        │ (CRON: 4:10 UTC)│        │
│  │ Timeout: 24h    │        │ Timeout: 1h     │        │
│  └────────┬────────┘        └────────┬────────┘        │
│           │                          │                  │
│           └──────────┬───────────────┘                  │
│                      │                                   │
│              ┌───────▼─────────┐                        │
│              │ UAMI (Identity) │                        │
│              │ - Key Vault     │                        │
│              │ - Cosmos DB     │                        │
│              │ - ACR Pull      │                        │
│              └───────┬─────────┘                        │
└──────────────────────┼──────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
  ┌─────▼─────┐ ┌──────▼───────┐     │
  │   ACR     │ │  Key Vault   │     │
  │ (Private) │ │  ┌─────────┐ │     │
  │           │ │  │cosmos   │ │     │
  │  Images:  │ │  │sp-*     │ │     │
  │  latest   │ │  └─────────┘ │     │
  └───────────┘ └──────────────┘     │
                                     │
        ┌────────────────────────────┘
        │
  ┌─────▼─────┐  ┌────────┐  ┌──────────┐
  │Cosmos DB  │  │SharePnt│  │Eureka API│
  │(MongoDB)  │  │(Graph) │  │(Public)  │
  │Serverless │  │        │  │          │
  └───────────┘  └────────┘  └──────────┘
```

---

## Po wdrożeniu

✅ **Deployment zakończony!**

Po zakończeniu deployment zobaczysz outputy:

```
ACR Name: acreureka
ACR Login Server: acreureka.azurecr.io
Full Image URL: acreureka.azurecr.io/eureka-crawler:latest
```

**Przekaż te wartości developerowi.**

### Developer może teraz:

**Krok 1: Zalogować się do ACR**

```bash
az acr login --name acreureka
```

**Krok 2: Zbudować i zpushować pierwszy obraz**

```bash
cd ~/Projects/alto/Eureka.Crawler

# Build
docker build -t acreureka.azurecr.io/eureka-crawler:latest .

# Push
docker push acreureka.azurecr.io/eureka-crawler:latest
```

**Krok 3: Uruchomić pierwszy job**

```bash
az containerapp job start \
  --name eureka-backfill \
  --resource-group rg-eureka-crawler
```

**Twoja praca jest skończona.** Developer ma automatyczny dostęp Contributor do Resource Group i może samodzielnie zarządzać aplikacją.

---

## Koszty (szacunkowe, West Europe)

| Serwis | Koszt/miesiąc |
|--------|---------------|
| Container Apps Environment | ~$50 |
| Container Apps Jobs | ~$15 |
| Azure Key Vault | ~$1 |
| Cosmos DB (Serverless) | ~$10-30* |
| **Azure Container Registry (Basic)** | **~$5** |
| **Total** | **~$81-101** |

*Zależnie od volumenu danych i request units

**Free tier:** Pierwsze 180,000 vCPU-seconds/miesiąc FREE, 360,000 GiB-seconds/miesiąc FREE

---

## Bezpieczeństwo

- ✅ **Zero sekretów w repository** - wszystko w Azure Key Vault
- ✅ **Private container registry** - ACR Basic, obrazy nie publiczne
- ✅ **Managed Identity authentication** - zero haseł, Azure-managed tokens
- ✅ **RBAC least privilege** - UAMI ma tylko potrzebne role (AcrPull, Key Vault Secrets User)
- ✅ **Soft delete enabled** - Key Vault recovery protection
- ✅ **Automatic Cosmos DB creation** - zero ręcznego zarządzania connection string

---

## Licencja

**Copyright © 2025. Wszelkie prawa zastrzeżone.**

Ta konfiguracja deployment jest dostarczona "jak jest" wyłącznie do celów referencyjnych i wdrożeniowych.
Kod źródłowy aplikacji jest licencjonowany osobno i nie jest zawarty w tym repozytorium.

---

**Ostatnia aktualizacja:** 2025-01-21
**Kompatybilne z:** Eureka.Crawler v1.x
**Utrzymywane przez:** Developer Team
