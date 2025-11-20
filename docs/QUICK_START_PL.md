# Instrukcja przygotowania do wdrożenia Eureka.Crawler

## Wymagania wstępne
- Konto Azure z uprawnieniami Administrator lub Contributor
- Dostęp do SharePoint (Office 365)
- Docker zainstalowany lokalnie (do budowy obrazu kontenera)
- Azure CLI zainstalowane (opcjonalnie, zalecane)
- Około 30-45 minut czasu

---

## Krok 1: Azure Entra ID (App Registration dla SharePoint)

### 1.1 Utworzenie App Registration

1. Zaloguj się na: **https://portal.azure.com**
2. W polu wyszukiwania wpisz `Microsoft Entra Id` → kliknij pierwszy wynik
3. Z górnego menu wybierz **Add**, a następnie wybierz **App registrations
5. Wypełnij formularz:
   - **Name**: `Eureka.Crawler.SharePoint`
   - **Supported account types**: `Accounts in this organizational directory only (Single tenant)`
   - **Redirect URI**: zostaw puste
6. Kliknij **Register**

### 1.2 Zapisanie identyfikatorów

Po utworzeniu zobaczysz stronę "Overview" aplikacji.

**ZAPISZ następujące wartości** (będą potrzebne później):

| Pole | Gdzie znaleźć | Zapisz jako |
|------|---------------|-------------|
| **Application (client) ID** | Overview → Application (client) ID | `SharePoint Client ID` |
| **Directory (tenant) ID** | Overview → Directory (tenant) ID | `SharePoint Tenant ID` |

### 1.3 Utworzenie Client Secret 

1. Z menu po lewej wybierz **Certificates & secrets**
2. Kliknij zakładkę **Client secrets**
3. Kliknij przycisk **New client secret**
4. Wypełnij:
   - **Description**: `Eureka.Crawler.Prod`
   - **Expires**: `730 days (24 months)` lub `180 days (6 months)`
5. Kliknij **Add**
6. **NATYCHMIAST SKOPIUJ wartość sekretu** (kolumna **Value**, NIE "Secret ID")
   - ⚠️ **WAŻNE:** Ta wartość NIE będzie już nigdy widoczna po opuszczeniu tej strony!
   - **ZAPISZ jako**: `SharePoint Client Secret`

### 1.4 Przypisanie uprawnień

1. Z menu po lewej wybierz **API permissions**
2. Kliknij **Add a permission**
3. Wybierz **Microsoft Graph**
4. Wybierz **Application permissions** (NIE "Delegated permissions")
5. W polu wyszukiwania wpisz `Files.ReadWrite.All`, zaznacz checkbox
6. W polu wyszukiwania wpisz `Sites.ReadWrite.All`, zaznacz checkbox
7. Kliknij **Add permissions**
8. **WAŻNE:** Kliknij przycisk **Grant admin consent for Default Directory/[Nazwa Organizacji]**
9. Potwierdź klikając **Yes**

Po tym kroku zobaczysz zielone znaczniki ✓ w kolumnie "Status".

---

## Krok 2: SharePoint (Site ID i Drive ID)

### Opcja A: Graph Explorer (zalecana - najłatwiejsza)

1. Zaloguj się na: **https://developer.microsoft.com/en-us/graph/graph-explorer**
2. Kliknij **Sign in to Graph Explorer** (zaloguj się kontem Office 365)
3. Zatwierdź uprawnienia jeśli pojawi się prompt

#### 2.1 Znajdź Site ID

1. W polu **Request URL** wpisz:
   ```
   https://graph.microsoft.com/v1.0/sites?search=Eureka
   ```
   (zamień `Eureka` na nazwę Twojego SharePoint site, np. `Documents` lub `Intranet`)
2. Kliknij **Run query**
3. Z odpowiedzi (response) skopiuj wartość pola `"id"` z pierwszego wyniku
   - Przykład: `contoso.sharepoint.com,a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6,x1y2z3w4-v5u6-t7s8-r9q0-p1o2n3m4l5k6`
4. **ZAPISZ jako**: `SharePoint Site ID`

#### 2.2 Znajdź Drive ID

1. W polu **Request URL** wpisz:
   ```
   https://graph.microsoft.com/v1.0/sites/{SITE_ID}/drives
   ```
   ⚠️ **Zamień** `{SITE_ID}` na wartość skopiowaną w poprzednim kroku (pełny string z przecinkami)
2. Kliknij **Run query**
3. Z odpowiedzi znajdź Document Library którą chcesz użyć (sprawdź pole `"name"`)
4. Skopiuj wartość `"id"` dla wybranej biblioteki
   - Przykład: `b!a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6x1y2z3w4v5u6t7s8r9q0p1o2n3m4l5k6`
5. **ZAPISZ jako**: `SharePoint Drive ID`

### Opcja B: PowerShell (dla zaawansowanych użytkowników)

Jeśli wolisz PowerShell:

```powershell
# Zainstaluj moduł Microsoft Graph (jednorazowo)
Install-Module -Name Microsoft.Graph -Scope CurrentUser

# Połącz się z Microsoft Graph
Connect-MgGraph -Scopes "Sites.Read.All"

# Znajdź Site ID (zamień "Eureka" na nazwę swojego site)
Get-MgSite -Search "Eureka"
# Skopiuj wartość pola "Id"

# Znajdź Drive ID (podaj SiteId z poprzedniego kroku)
Get-MgSiteDrive -SiteId "contoso.sharepoint.com,a1b2c3d4-..."
# Skopiuj wartość pola "Id" dla wybranej biblioteki
```

---

## ~~Krok 3: Azure Cosmos DB~~ (automatyczne)

✅ **Cosmos DB zostanie utworzony automatycznie podczas deployment.**

Bicep template utworzy:
- Cosmos DB Account (MongoDB API, Serverless)
- Database `eureka`
- Connection string automatycznie w Key Vault

Nie musisz nic robić ręcznie.

---

## Krok 3: Azure Container Registry (obraz Docker)

### Opcja A: Masz już registry (ACR, Docker Hub, GitHub Container Registry)

Jeśli masz własny registry:
- **ZAPISZ**: URL registry (np. `myregistry.azurecr.io`)
- **ZAPISZ**: Nazwa użytkownika (username)
- **ZAPISZ**: Hasło lub Personal Access Token

### Opcja B: Utwórz nowe Azure Container Registry

1. Zaloguj się na: **https://portal.azure.com**
2. Kliknij **Create a resource**
3. Wyszukaj `Container Registry`
4. Kliknij **Create**
5. Wypełnij formularz:
   - **Registry name**: `eurekacrawler` (musi być globalnie unikalna, tylko małe litery i cyfry)
   - **Resource group**: `rg-eureka-crawler`
   - **Location**: `West Europe`
   - **SKU**: `Basic` (najtańsza opcja)
6. Kliknij **Review + create** → **Create**
7. Po utworzeniu kliknij **Go to resource**
8. Z menu po lewej wybierz **Access keys**
9. Włącz przełącznik **Admin user**
10. **ZAPISZ następujące wartości**:
    - **Login server**: `eurekacrawler.azurecr.io` → `Registry URL`
    - **Username**: `eurekacrawler` → `Registry Username`
    - **password**: (pierwsza wartość) → `Registry Password`

---

## Krok 4: Zbuduj i wyślij obraz Docker

### 4.1 Przygotowanie środowiska

Upewnij się, że masz zainstalowane:
- Docker Desktop (Windows/Mac) lub Docker Engine (Linux)
- Git

### 4.2 Pobranie kodu

```bash
# Sklonuj repozytorium (jeśli jeszcze nie masz)
git clone https://github.com/your-username/Eureka.Crawler.git
cd Eureka.Crawler
```

### 4.3 Budowa obrazu

```bash
# Zbuduj obraz Docker
# Zamień <registry-url> na swoją wartość z Kroku 3
docker build -t <registry-url>/eureka-crawler:latest .

# Przykład dla ACR:
docker build -t eurekacrawler.azurecr.io/eureka-crawler:latest .

# Przykład dla Docker Hub:
docker build -t yourname/eureka-crawler:latest .
```

Budowa zajmie ~2-5 minut.

### 4.4 Logowanie do registry

**Dla Azure Container Registry:**
```bash
# Zaloguj się przez Azure CLI (jeśli masz zainstalowane)
az acr login --name eurekacrawler

# LUB zaloguj się przez Docker
docker login eurekacrawler.azurecr.io
# Username: eurekacrawler
# Password: (wartość z Kroku 3)
```

**Dla Docker Hub:**
```bash
docker login
# Username: yourname
# Password: twoje hasło
```

### 4.5 Wysłanie obrazu

```bash
# Wyślij obraz do registry
docker push <registry-url>/eureka-crawler:latest

# Przykład dla ACR:
docker push eurekacrawler.azurecr.io/eureka-crawler:latest

# Przykład dla Docker Hub:
docker push yourname/eureka-crawler:latest
```

Upload zajmie ~2-10 minut w zależności od prędkości internetu.

### 4.6 Zapisanie pełnej ścieżki obrazu

**ZAPISZ pełną ścieżkę obrazu:**
- Przykład ACR: `eurekacrawler.azurecr.io/eureka-crawler:latest`
- Przykład Docker Hub: `yourname/eureka-crawler:latest`

---

## Podsumowanie - Lista kontrolna

**Przed przejściem do "Deploy to Azure" upewnij się, że masz zapisane wszystkie poniższe wartości:**

### ✅ Entra ID (App Registration)
- [ ] **SharePoint Tenant ID** (Directory tenant ID)
- [ ] **SharePoint Client ID** (Application client ID)
- [ ] **SharePoint Client Secret** (wartość sekretu, NIE Secret ID)

### ✅ SharePoint
- [ ] **SharePoint Site ID** (długi string z przecinkami)
- [ ] **SharePoint Drive ID** (długi string bez przecinków)

### ✅ Azure AD (dla developer access)
- [ ] **Developer Object ID** (`az ad user show --id bartoszpalmi@hotmail.com --query id -o tsv`)

### ✅ Container Registry
- [ ] **Registry URL** (np. `eurekacrawler.azurecr.io`)
- [ ] **Registry Username** (np. `eurekacrawler`)
- [ ] **Registry Password** (hasło lub PAT)

### ✅ Docker Image
- [ ] **Obraz został zbudowany** (`docker build` zakończony sukcesem)
- [ ] **Obraz został wysłany** (`docker push` zakończony sukcesem)
- [ ] **Pełna ścieżka obrazu** (np. `eurekacrawler.azurecr.io/eureka-crawler:latest`)

---

## Krok 5: Developer Object ID (dla automatycznego dostępu)

Aby developer (`bartoszpalmi@hotmail.com`) automatycznie otrzymał dostęp Contributor do Resource Group, potrzebujesz jego Azure AD Object ID:

```bash
# Zaloguj się do Azure CLI
az login

# Pobierz Object ID dewelopera
az ad user show --id bartoszpalmi@hotmail.com --query id -o tsv
```

**Przykładowy output:** `a1b2c3d4-e5f6-7890-abcd-ef1234567890`

**ZAPISZ** tę wartość - będzie potrzebna podczas deployment w polu "Developer Object ID".

---

## Gotowe do wdrożenia! 🚀

Teraz możesz przejść do głównej instrukcji deployment i kliknąć przycisk **"Deploy to Azure"**.

### Następne kroki:

1. Otwórz plik: **`docs/DEPLOY.md`**
2. Kliknij przycisk **"Deploy to Azure"**
3. Zaloguj się do Azure Portal
4. Wypełnij formularz wartościami zapisanymi powyżej
5. Kliknij **Review + create** → **Create**
6. Poczekaj ~5-10 minut na wdrożenie
7. Uruchom pierwszy job backfill

---

## Dodatkowe zasoby

### Dokumentacja szczegółowa:
- **Pełna instrukcja deployment**: `docs/DEPLOY.md`
- **Konfiguracja Entra ID**: `docs/ENTRA_SETUP.md` (wersja angielska)
- **Ręczny deployment (Azure CLI)**: `docs/deploy-aca.md`
- **Referencja zmiennych środowiskowych**: `docs/deploy-env.md`

### Pomoc techniczna:
- **Eureka API**: https://eureka.mf.gov.pl
- **Microsoft Graph API**: https://learn.microsoft.com/en-us/graph/
- **Azure Container Apps**: https://learn.microsoft.com/en-us/azure/container-apps/

### Rozwiązywanie problemów:

**Problem: "Nie mogę znaleźć Site ID lub Drive ID"**
- Upewnij się, że zalogowałeś się do Graph Explorer kontem, które ma dostęp do SharePoint
- Sprawdź czy nazwa site w zapytaniu jest poprawna
- Spróbuj wyszukać bez polskich znaków

**Problem: "Admin consent nie działa"**
- Upewnij się, że jesteś administratorem w Azure AD
- Spróbuj zalogować się w trybie incognito
- Skontaktuj się z administratorem organizacji

**Problem: "Docker build kończy się błędem"**
- Upewnij się, że masz zainstalowane Docker Desktop i jest uruchomione
- Sprawdź czy jesteś w katalogu `Eureka.Crawler` (tam gdzie jest `Dockerfile`)
- Sprawdź czy masz połączenie z internetem (pobiera obrazy bazowe)

**Problem: "Docker push nie działa"**
- Upewnij się, że jesteś zalogowany (`docker login`)
- Sprawdź czy nazwa obrazu zgadza się z nazwą registry
- Dla ACR: sprawdź czy Admin user jest włączony

---

**Powodzenia z wdrożeniem! 🎉**
