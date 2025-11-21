# SharePoint - Znajdź Site ID i Drive ID

Ten przewodnik pomoże Ci znaleźć **Site ID** i **Drive ID** dla Twojej biblioteki dokumentów SharePoint, które są wymagane do wdrożenia aplikacji Eureka.Crawler.

---

## Przegląd

**Co znajdujemy:**
- **Site ID** - unikalny identyfikator Twojego SharePoint Site
- **Drive ID** - unikalny identyfikator biblioteki dokumentów (Document Library)

**Czego potrzebujesz:**
- Dostęp do SharePoint Site (read access wystarczy)
- Przeglądarka internetowa

**Czas:** ~5 minut

---

## Metoda 1: Microsoft Graph Explorer (ZALECANA - najszybsza)

### Krok 1: Otwórz Graph Explorer

Otwórz przeglądarkę i przejdź do: [https://developer.microsoft.com/graph/graph-explorer](https://developer.microsoft.com/graph/graph-explorer)

### Krok 2: Zaloguj się

1. Kliknij **"Sign in to Graph Explorer"** (prawy górny róg)
2. Zaloguj się tym samym kontem Microsoft, którego używasz do SharePoint
3. Po zalogowaniu zobaczysz swoje zdjęcie profilowe w prawym górnym rogu

### Krok 3: Znajdź Site ID

1. W polu "Request URL" wpisz:
   ```
   https://graph.microsoft.com/v1.0/sites?search=NazwaTwojegoSite
   ```

   **Zastąp `NazwaTwojegoSite`** nazwą Twojego SharePoint Site:
   - Jeśli URL SharePoint to: `https://contoso.sharepoint.com/sites/Marketing`
   - Użyj: `search=Marketing`

2. Kliknij **"Run query"** (niebieski przycisk)

3. W odpowiedzi (Response Preview) znajdź:
   ```json
   {
     "value": [
       {
         "id": "contoso.sharepoint.com,12345678-1234-1234-1234-123456789abc,87654321-4321-4321-4321-cba987654321",
         "displayName": "Marketing",
         "webUrl": "https://contoso.sharepoint.com/sites/Marketing"
       }
     ]
   }
   ```

4. **Skopiuj całą wartość `id`**
   - To jest Twój **Site ID**
   - Format: `hostname,guid,guid` (np. `contoso.sharepoint.com,12345678-...`)
   - Zapisz w notatniku

### Krok 4: Znajdź Drive ID

1. W polu "Request URL" wpisz (zastąp `{siteId}` wartością z poprzedniego kroku):
   ```
   https://graph.microsoft.com/v1.0/sites/{siteId}/drives
   ```

   **Przykład:**
   ```
   https://graph.microsoft.com/v1.0/sites/contoso.sharepoint.com,12345678-1234-1234-1234-123456789abc,87654321-4321-4321-4321-cba987654321/drives
   ```

2. Kliknij **"Run query"**

3. W odpowiedzi zobaczysz listę wszystkich bibliotek dokumentów (drives) w tym Site:
   ```json
   {
     "value": [
       {
         "id": "b!abc123...",
         "name": "Documents",
         "driveType": "documentLibrary",
         "webUrl": "https://contoso.sharepoint.com/sites/Marketing/Shared Documents"
       },
       {
         "id": "b!xyz789...",
         "name": "Another Library",
         "driveType": "documentLibrary"
       }
     ]
   }
   ```

4. **Znajdź odpowiednią bibliotekę dokumentów** (sprawdź `name` lub `webUrl`)
   - Zazwyczaj główna biblioteka nazywa się "Documents" lub "Shared Documents"

5. **Skopiuj wartość `id`** dla wybranej biblioteki
   - To jest Twój **Drive ID**
   - Format: `b!...` (długi ciąg znaków)
   - Zapisz w notatniku

---

## Metoda 2: PowerShell (dla zaawansowanych)

Jeśli preferujesz PowerShell:

### Krok 1: Zainstaluj moduł Microsoft Graph (jednorazowo)

```powershell
Install-Module -Name Microsoft.Graph -Scope CurrentUser
```

### Krok 2: Połącz się z Microsoft Graph

```powershell
Connect-MgGraph -Scopes "Sites.Read.All"
```

Zaloguj się w oknie przeglądarki.

### Krok 3: Znajdź Site ID

```powershell
# Zastąp "Marketing" nazwą Twojego Site
Get-MgSite -Search "Marketing" | Select-Object Id, DisplayName, WebUrl | Format-List
```

Output:
```
Id          : contoso.sharepoint.com,12345678-1234-1234-1234-123456789abc,87654321-4321-4321-4321-cba987654321
DisplayName : Marketing
WebUrl      : https://contoso.sharepoint.com/sites/Marketing
```

**Skopiuj wartość `Id`** - to jest Twój **Site ID**.

### Krok 4: Znajdź Drive ID

```powershell
# Zastąp {siteId} wartością z poprzedniego kroku
Get-MgSiteDrive -SiteId "{siteId}" | Select-Object Id, Name, WebUrl | Format-List
```

**Przykład:**
```powershell
Get-MgSiteDrive -SiteId "contoso.sharepoint.com,12345678-1234-1234-1234-123456789abc,87654321-4321-4321-4321-cba987654321"
```

Output:
```
Id     : b!abc123xyz789...
Name   : Documents
WebUrl : https://contoso.sharepoint.com/sites/Marketing/Shared Documents

Id     : b!def456uvw012...
Name   : Another Library
WebUrl : https://contoso.sharepoint.com/sites/Marketing/AnotherLibrary
```

**Skopiuj wartość `Id`** dla wybranej biblioteki - to jest Twój **Drive ID**.

---

## Metoda 3: Z URL SharePoint (wymaga dodatkowego API call)

Jeśli masz URL SharePoint: `https://contoso.sharepoint.com/sites/Marketing`

### Znajdź Site ID przez Graph API:

```
GET https://graph.microsoft.com/v1.0/sites/contoso.sharepoint.com:/sites/Marketing
```

W odpowiedzi znajdziesz `id` - to jest Site ID.

Następnie użyj tego Site ID żeby znaleźć Drive ID (jak w Metodzie 1, Krok 4).

---

## Weryfikacja - Co powinieneś mieć zapisane

Po ukończeniu tego przewodnika powinieneś mieć zapisane 2 wartości:

| Nazwa | Format | Przykład |
|-------|--------|----------|
| **Site ID** | `hostname,guid,guid` | `contoso.sharepoint.com,12345678-1234-1234-1234-123456789abc,87654321-4321-4321-4321-cba987654321` |
| **Drive ID** | `b!...` | `b!abc123xyz789def456uvw012ghi345jkl678mno901pqr234stu567vwx890` |

**Te wartości będą potrzebne w formularzu "Deploy to Azure".**

---

## Następne kroki

✅ Site ID i Drive ID znalezione!

Teraz masz wszystkie wymagane wartości:
1. ✅ SharePoint Tenant ID (z [SETUP_ENTRA_ID.md](SETUP_ENTRA_ID.md))
2. ✅ SharePoint Client ID (z [SETUP_ENTRA_ID.md](SETUP_ENTRA_ID.md))
3. ✅ SharePoint Client Secret (z [SETUP_ENTRA_ID.md](SETUP_ENTRA_ID.md))
4. ✅ SharePoint Site ID (z tego przewodnika)
5. ✅ SharePoint Drive ID (z tego przewodnika)

**Możesz teraz wrócić do [README.md](../README.md) i kliknąć "Deploy to Azure"!**

---

## Troubleshooting

### Problem: Graph Explorer zwraca błąd 403 Forbidden

**Rozwiązanie:**
- Zaloguj się ponownie do Graph Explorer
- Upewnij się że Twoje konto ma dostęp do SharePoint Site
- Jeśli problem persystuje, poproś administratora SharePoint o nadanie Ci uprawnień "Read" do Site

### Problem: W odpowiedzi `/drives` nie ma biblioteki "Documents"

**Możliwe przyczyny:**
- Biblioteka ma inną nazwę (sprawdź `name` i `webUrl` wszystkich wyników)
- Nie masz uprawnień do tej biblioteki
- Biblioteka została usunięta

**Rozwiązanie:**
- Wybierz inną bibliotekę z listy (skopiuj jej `id`)
- Lub poproś administratora SharePoint o weryfikację

### Problem: Site ID ma inny format niż oczekiwany

**To normalne:**
- Site ID zawsze składa się z 3 części oddzielonych przecinkami: `hostname,guid,guid`
- Długość może się różnić w zależności od hostname SharePoint
- Skopiuj całą wartość włącznie z przecinkami

### Problem: PowerShell "Connect-MgGraph: command not found"

**Rozwiązanie:**
- Zainstaluj moduł: `Install-Module -Name Microsoft.Graph -Scope CurrentUser`
- Lub użyj Metody 1 (Graph Explorer) - nie wymaga instalacji

---

## Dodatkowe zasoby

- 📖 [Microsoft Graph - Sites API](https://learn.microsoft.com/graph/api/resources/site)
- 📖 [Microsoft Graph - Drives API](https://learn.microsoft.com/graph/api/resources/drive)
- 📖 [Graph Explorer](https://developer.microsoft.com/graph/graph-explorer)

---

**Ostatnia aktualizacja:** 2025-01-21
**Wersja:** 1.0
