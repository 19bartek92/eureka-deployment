# Azure Entra ID - Setup App Registration dla SharePoint

Ten przewodnik krok po kroku przeprowadzi Cię przez proces utworzenia App Registration w Azure Entra ID (dawniej Azure Active Directory), który jest wymagany do integracji aplikacji Eureka.Crawler z SharePoint przez Microsoft Graph API.

---

## Przegląd

**Co tworzymy:**
- Azure Entra ID App Registration z uprawnieniami do SharePoint
- Client Secret dla uwierzytelniania daemon app
- Application permissions (nie delegated) dla dostępu bez użytkownika

**Czego potrzebujesz:**
- Dostęp do Azure Portal (portal.azure.com)
- Uprawnienia **Global Administrator** lub **Application Administrator** w tenant Azure AD (do nadania admin consent)

**Czas:** ~10 minut

---

## Krok 1: Otwórz Azure Portal i przejdź do Azure Active Directory

1. Otwórz przeglądarkę i przejdź do: [https://portal.azure.com](https://portal.azure.com)
2. Zaloguj się swoim kontem Microsoft
3. W lewym menu kliknij **"Azure Active Directory"**
   - Jeśli nie widzisz w menu, użyj wyszukiwarki na górze (wpisz "Azure Active Directory")

![Azure AD w menu](https://docs.microsoft.com/azure/active-directory/media/...)

---

## Krok 2: Utwórz nową App Registration

1. W lewym menu Azure Active Directory kliknij **"App registrations"**
2. Kliknij przycisk **"+ New registration"** (na górze strony)

![New registration button](https://docs.microsoft.com/azure/active-directory/media/...)

---

## Krok 3: Wypełnij formularz rejestracji

Wypełnij formularz następującymi wartościami:

| Pole | Wartość | Opis |
|------|---------|------|
| **Name** | `Eureka.Crawler.SharePoint` | Nazwa aplikacji (widoczna w Azure AD) |
| **Supported account types** | **Accounts in this organizational directory only (Single tenant)** | Aplikacja działa tylko w Twoim tenant |
| **Redirect URI** | *Zostaw puste* | Daemon app nie wymaga redirect URI |

**Kliknij "Register"** na dole strony.

---

## Krok 4: Zapisz Tenant ID i Client ID

Po utworzeniu App Registration zobaczysz stronę "Overview":

1. **Skopiuj `Application (client) ID`**
   - To jest Twój **SharePoint Client ID**
   - Format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` (GUID)
   - Zapisz w notatniku - będzie potrzebny w deployment

2. **Skopiuj `Directory (tenant) ID`**
   - To jest Twój **SharePoint Tenant ID**
   - Format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` (GUID)
   - Zapisz w notatniku - będzie potrzebny w deployment

![Application IDs](https://docs.microsoft.com/azure/active-directory/media/...)

---

## Krok 5: Utwórz Client Secret

1. W lewym menu App Registration kliknij **"Certificates & secrets"**
2. W sekcji **"Client secrets"** kliknij **"+ New client secret"**
3. Wypełnij formularz:
   - **Description:** `Eureka.Crawler production secret`
   - **Expires:** Wybierz **24 months** (lub według polityki firmy)
4. Kliknij **"Add"**

**WAŻNE:**
- Skopiuj **wartość** Client Secret **NATYCHMIAST** (kolumna "Value", NIE "Secret ID")
- To jest Twój **SharePoint Client Secret**
- **Nigdy więcej nie będziesz mógł zobaczyć tej wartości** (tylko Secret ID)
- Zapisz w bezpiecznym miejscu (np. password manager)
- Format: `~8Q~abc123xyz...` (długi ciąg znaków)

![Client secret created](https://docs.microsoft.com/azure/active-directory/media/...)

---

## Krok 6: Dodaj uprawnienia Microsoft Graph API

1. W lewym menu App Registration kliknij **"API permissions"**
2. Kliknij **"+ Add a permission"**
3. W panelu po prawej wybierz **"Microsoft Graph"**
4. Wybierz **"Application permissions"** (NIE "Delegated permissions")

![Application permissions selection](https://docs.microsoft.com/graph/media/...)

---

## Krok 7: Dodaj uprawnienie Files.ReadWrite.All

1. W wyszukiwarce wpisz: `Files`
2. Rozwiń sekcję **"Files"**
3. Zaznacz checkbox: **`Files.ReadWrite.All`**
   - Opis: "Have full access to all files user can access"
   - Wymagane do: Upload plików RTF do SharePoint

![Files.ReadWrite.All permission](https://docs.microsoft.com/graph/media/...)

---

## Krok 8: Dodaj uprawnienie Sites.ReadWrite.All

1. Kliknij ponownie **"+ Add a permission"** → **"Microsoft Graph"** → **"Application permissions"**
2. W wyszukiwarce wpisz: `Sites`
3. Rozwiń sekcję **"Sites"**
4. Zaznacz checkbox: **`Sites.ReadWrite.All`**
   - Opis: "Edit or delete items in all site collections"
   - Wymagane do: Tworzenie folderów w SharePoint

5. Kliknij **"Add permissions"** na dole panelu

![Sites.ReadWrite.All permission](https://docs.microsoft.com/graph/media/...)

---

## Krok 9: Nadaj Admin Consent

**WAŻNE:** Application permissions wymagają zgody administratora tenant.

1. Na stronie **"API permissions"** kliknij przycisk **"Grant admin consent for [Twoja organizacja]"**
2. Potwierdź w oknie dialogowym klikając **"Yes"**

Po nadaniu consent zobaczysz zielone checkmarki w kolumnie "Status":

```
Permission                  Type         Status
Files.ReadWrite.All         Application  ✅ Granted for [org]
Sites.ReadWrite.All         Application  ✅ Granted for [org]
```

![Admin consent granted](https://docs.microsoft.com/azure/active-directory/media/...)

**Jeśli nie masz uprawnień:**
- Skontaktuj się z administratorem Azure AD w Twojej organizacji
- Poproś o nadanie admin consent dla aplikacji `Eureka.Crawler.SharePoint`
- Administrator może to zrobić przez ten sam przycisk "Grant admin consent"

---

## Weryfikacja - Co powinieneś mieć zapisane

Po ukończeniu tego przewodnika powinieneś mieć zapisane 3 wartości:

| Nazwa | Format | Przykład |
|-------|--------|----------|
| **SharePoint Tenant ID** | GUID | `12345678-1234-1234-1234-123456789abc` |
| **SharePoint Client ID** | GUID | `87654321-4321-4321-4321-cba987654321` |
| **SharePoint Client Secret** | Długi ciąg | `~8Q~abcdefghijklmnopqrstuvwxyz123456` |

**Te wartości będą potrzebne w formularzu "Deploy to Azure".**

---

## Następne kroki

✅ App Registration gotowa!

Teraz przejdź do: **[SETUP_SHAREPOINT.md](SETUP_SHAREPOINT.md)** - Znajdź Site ID i Drive ID

---

## Troubleshooting

### Problem: "You don't have permissions to create App Registration"

**Rozwiązanie:**
- Potrzebujesz roli **Application Developer** w Azure AD
- Poproś administratora o nadanie tej roli lub utworzenie App Registration za Ciebie

### Problem: "Grant admin consent" button is disabled

**Rozwiązanie:**
- Potrzebujesz roli **Global Administrator** lub **Privileged Role Administrator**
- Poproś administratora o nadanie admin consent dla tej aplikacji

### Problem: "Application permissions vs Delegated permissions - która wybrać?"

**Odpowiedź:**
- Eureka.Crawler to **daemon app** (działa w tle bez użytkownika)
- Daemon apps MUSZĄ używać **Application permissions**
- Delegated permissions są dla aplikacji które działają w kontekście zalogowanego użytkownika

### Problem: Zapomniałem skopiować Client Secret

**Rozwiązanie:**
- Nie możesz odzyskać starego Client Secret
- Utwórz nowy: Certificates & secrets → New client secret
- Zaktualizuj wartość w Azure Key Vault po deployment

---

## Dodatkowe zasoby

- 📖 [Microsoft Graph permissions reference](https://learn.microsoft.com/graph/permissions-reference)
- 📖 [Register an application with Azure AD](https://learn.microsoft.com/azure/active-directory/develop/quickstart-register-app)
- 📖 [Application vs Delegated permissions](https://learn.microsoft.com/azure/active-directory/develop/v2-permissions-and-consent#permission-types)

---

**Ostatnia aktualizacja:** 2025-01-21
**Wersja:** 1.0
