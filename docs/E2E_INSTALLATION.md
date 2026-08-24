# Propfocus AI — Complete E2E Installation (New Salesforce Org)

**Audience:** Salesforce admin + Propfocus backend  
**Goal:** Brand-new org → package installed → configured → inbound/outbound working → features verified  
**Time:** Demo / Developer org with click-path: ~1–2 hours. Enterprise (change control, External Client App + JWT, backend registration, pipeline deploy of subscriber config): plan **several days**, not a single sitting.  
**Package:** Propfocus AI **v0.12.0-3 (Released)** (`PropfocusAI` namespace) — Opportunity support, External Credential outbound auth, optional Site/Post Visit buttons, history card status sync, auto-open modals by status + auto-create, configurable SV-scheduled status (see [Upgrade from 0.5.x](#upgrade-from-05x) and [FAQ.txt](./FAQ.txt)).

This is the exact workflow. Follow phases in order. Do not skip prerequisites.

**Enterprise:** Prefer [Subscriber config via SFDX / change set](#subscriber-config-via-sfdx--change-set) for permission sets, Lightning page, and CMDT values — do not rely on clicks in production.

---

## Authentication overview

Propfocus uses **two separate OAuth systems**. Do not mix them up.

| Direction                             | Where credentials live                                                                             | Token endpoint                                       | Used for                                                 |
| ------------------------------------- | -------------------------------------------------------------------------------------------------- | ---------------------------------------------------- | -------------------------------------------------------- |
| **Salesforce → Propfocus** (outbound) | **External Credential** → Propfocus Principal (Client Id + Secret, encrypted)                      | `https://propfocus.in/api/oauth2/token`              | Generate Microsite, Test Connection, site visit callouts |
| **Propfocus → Salesforce** (inbound)  | **External Client App** + JWT (`server.key` held by Propfocus; customer uploads `server.crt` only) | `https://login.salesforce.com/services/oauth2/token` | Inbound REST POST                                        |

**Why not Custom Metadata for the client secret?** CMDT is visible to admins with Customize Application, appears in metadata exports/change sets, and is not encrypted. Enterprise customers expect outbound secrets in **Setup → External Credentials**, linked to the packaged Named Credential — Salesforce handles token exchange; Apex never reads the secret.

**What stays in Propfocus Config (CMDT):** Organization Id, embed URL, field mappings, Named Credential developer name — not OAuth credentials.

---

## What you will end up with

| Direction                     | Mechanism                                                           | Purpose                                                            |
| ----------------------------- | ------------------------------------------------------------------- | ------------------------------------------------------------------ |
| Salesforce → Propfocus        | External Credential + Named Credential (OAuth `client_credentials`) | Generate microsite / site visit / post-visit links; Buyer Insights |
| Propfocus → Salesforce        | JWT Bearer → inbound REST                                           | Notifications + write-back                                         |
| Salesforce → Propfocus (sync) | Platform Event `Propfocus_Lead_Event__e`                            | Lead field-change sync                                             |

---

## Collect these before you start

| Item                                                         | Who provides it | Notes                                                                                                                                                     |
| ------------------------------------------------------------ | --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Salesforce **admin** login                                   | Customer IT     | Org must support Apex (Enterprise / Unlimited / Developer / sandbox of those)                                                                             |
| Propfocus **Organization Id**                                | Propfocus team  | UUID; must match backend registration                                                                                                                     |
| Outbound OAuth **Client Id** + **Client Secret**             | Propfocus team  | Enter in **External Credential → Propfocus Principal** (Phase 4.1) — **not** in Propfocus Config                                                          |
| API / embed base URL                                         | Propfocus team  | Production: `https://propfocus.in` (API), `https://propfocus.in/embed/salesforce` (embed). Sandboxes: see [Sandbox override](#sandbox--uat--point-at-dev) |
| List of **Lead field API names** to map                      | Customer admin  | Buyer Id, Name, Project, Status, owners — see [FIELDS.md](./FIELDS.md)                                                                                    |
| List of **Opportunity field API names** (if using Opp panel) | Customer admin  | Buyer Id, Name, Stage/Status, Project — see [FIELDS.md](./FIELDS.md)                                                                                      |
| **Site Visit** object API name + fields (if used)            | Customer admin  | Package does **not** create `Site_Visit__c`; it must already exist (Lead + Opportunity lookups)                                                           |
| Sales test user                                              | Customer admin  | For LWC / Generate Microsite tests                                                                                                                        |
| Dedicated **integration user** email                         | Customer admin  | e.g. `propfocus.integration@yourcompany.com`                                                                                                              |
| JWT **`server.crt`** (public cert only)                      | Propfocus team  | Propfocus generates the key pair and keeps `server.key`; customer uploads only `server.crt` (valid 365 days)                                              |

---

## Phase 0 — Org prerequisites (before install)

Do these **before** opening the install link. Lead Field History Tracking is **not** required.

| #    | Where                                 | Action                                                              | Pass when                                                   |
| ---- | ------------------------------------- | ------------------------------------------------------------------- | ----------------------------------------------------------- |
| 0.1  | Object Manager → Lead → Fields        | Confirm custom fields you will map exist (or create them)           | Buyer Id / Name / Project fields exist                      |
| 0.1b | Object Manager → Opportunity → Fields | If using Opportunity panel: confirm buyer id / project fields exist | Opportunity mappings possible                               |
| 0.2  | Object Manager                        | If using site visit features: confirm **Site Visit** object exists  | Object + Lead lookup (and Opportunity lookup if used) exist |
| 0.3  | —                                     | Confirm org edition supports Apex                                   | Not Starter / Essentials / Group                            |

---

## Phase 1 — Install the managed package

**Install URL (v0.12.0-3, Released):**

```
https://login.salesforce.com/packaging/installPackage.apexp?p0=04tdL000000nuSTQAY
```

Sandboxes: use `https://test.salesforce.com/packaging/installPackage.apexp?p0=04tdL000000nuSTQAY`.

| #    | Action                                                                                                    | Pass when                                                           |
| ---- | --------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| 1.1  | Log into the **target org** first (sandbox: use `https://test.salesforce.com`, then open the install URL) | You are in the correct org                                          |
| 1.1b | **Sandbox only:** after install, complete [Sandbox override](#sandbox--uat--point-at-dev) before Phase 4  | All URLs point to `dev.propfocus.in`                                |
| 1.2  | Open install URL → **Install for Admins Only** → Install                                                  | Install completes with no errors                                    |
| 1.3  | Setup → **Installed Packages**                                                                            | **Propfocus AI** version **0.16.0.1** (or later Released) is listed |

**Installed for you (no action):** Apex, Lead trigger, inbound REST, Platform Event, custom objects, permission sets, External Credential + Named Credential (skeleton), Remote Site, CSP Trusted Site (`https://propfocus.in` only — sandboxes add `dev.propfocus.in` manually, see Sandbox override), LWCs, Admin Setup tab, Propfocus AI app, default `Propfocus_Config` CMDT record.

**Not installed (you configure next):** External Credential Client Id/Secret, External Client App (inbound JWT), field mappings, permission set assignments, Lead/Opportunity page LWC placement, integration user.

---

## Phase 2 — Users and permission sets

| #    | Who                               | Permission set                       | Action                                                                                                                   |
| ---- | --------------------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| 2.1  | Sales reps / test user            | **Propfocus User**                   | Setup → Permission Sets → Manage Assignments                                                                             |
| 2.1b | Sales reps / test user            | **Propfocus Callout Access** (local) | Required — [SETUP_GUIDE.md](./SETUP_GUIDE.md) §2.1e. Managed Propfocus User cannot grant User External Credentials Read. |
| 2.2  | Salesforce admin(s)               | **Propfocus AI Admin**               | Same                                                                                                                     |
| 2.3  | New user (Minimum Access profile) | **Propfocus Integration**            | Create user → assign this set                                                                                            |

**Integration user (recommended):**

1. Setup → Users → **New User**
2. Username: `propfocus.integration@yourcompany.com` (unique globally)
3. Profile: **Minimum Access** (not System Administrator)
4. Active → Save
5. Assign **Propfocus Integration**

Write down: `integration_username`

---

## Phase 3 — Configure Propfocus Config (Custom Metadata)

### 3.1 Make all fields editable

If Edit only shows Label / Name:

1. Setup → Custom Metadata Types → **Propfocus Config** → **Page Layouts**
2. Edit layout → drag **all** fields onto the layout → Save

### 3.2 Edit the Default record

**Where:** Setup → Custom Metadata Types → **Propfocus Config** → Manage Records → **Default** → **Edit**

#### A. API settings (Salesforce → Propfocus)

| Config field                         | Value                                                                                                                                |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| API Named Credential                 | `Propfocus_API`                                                                                                                      |
| Organization Id                      | _(from Propfocus team)_                                                                                                              |
| Embed Base Url                       | `https://propfocus.in/embed/salesforce` (subscriber-editable in this record; sandboxes: `https://dev.propfocus.in/embed/salesforce`) |
| Embed Uses Salesforce Lead Id        | Checked                                                                                                                              |
| Embed Uses Salesforce Opportunity Id | Checked                                                                                                                              |
| Show Copy Modal                      | Checked (optional UX)                                                                                                                |
| Show Site Visit Button               | Checked (default) — uncheck to hide **Confirm Site Visit** on the panel                                                              |
| Show Post Visit Button               | Checked (default) — uncheck to hide **Generate Post Visit** on the panel                                                             |

Outbound OAuth Client Id/Secret are **not** stored in Config — see Phase 4.1.

#### B. Lead field mappings (required for Lead panel)

Enter **API names** only (custom fields end in `__c`). Discover them via [FIELDS.md](./FIELDS.md).

| Config field                | Maps to                            | Example                      |
| --------------------------- | ---------------------------------- | ---------------------------- |
| Buyer Id Field              | Unique buyer / enquiry ref on Lead | `Enquiry_Ref_No__c`          |
| Buyer Name Field            | Display name                       | `Full_Name__c` or `LastName` |
| Lead Status Field           | Status                             | `Status`                     |
| Project Field               | Project interested                 | `Project_Interested__c`      |
| Lead Source Field           | Source                             | `LeadSource`                 |
| Pre Sales Rep Source Field  | Presales owner (outbound)          | org-specific                 |
| Pre-Sales Owner Name Field  | Write-back                         | org-specific                 |
| Pre-Sales Owner Phone Field | Write-back                         | org-specific                 |
| Sales Owner Name Field      | Write-back                         | org-specific                 |
| Sales Owner Phone Field     | Write-back                         | org-specific                 |

**Critical:** Buyer Id Field must be populated on Leads you test. Inbound REST matches `buyer_id` to this field (or to Opportunity buyer id after Lead miss).

#### C. Opportunity field mappings (required for Opportunity panel)

| Config field                           | Maps to                                   | Example      |
| -------------------------------------- | ----------------------------------------- | ------------ |
| Opportunity Buyer Id Field             | Unique buyer / enquiry ref on Opportunity | org-specific |
| Opportunity Buyer Name Field           | Display name                              | `Name`       |
| Opportunity Status Field               | Stage / status                            | `StageName`  |
| Opportunity Project Field              | Project                                   | org-specific |
| Opportunity Lead Source Field          | Source                                    | `LeadSource` |
| Opportunity Pre Sales Rep Source Field | Broker / presales (outbound)              | org-specific |
| Opportunity owner name/phone fields    | Write-back                                | org-specific |

#### D. Site Visit mappings (if using Confirm Site Visit)

| Config field                                  | Example                        |
| --------------------------------------------- | ------------------------------ |
| Site Visit Object                             | `Site_Visit__c`                |
| Lead Lookup Field                             | `Lead__c`                      |
| Opportunity Lookup Field                      | `Opportunity__c`               |
| Site Visit Status Field                       | `Status__c`                    |
| Site Visit Project Field                      | org-specific                   |
| Site Visit Type Field                         | org-specific                   |
| Site Visit Datetime Field                     | org-specific                   |
| Site Visit Team Field                         | org-specific                   |
| Site Visit Manager Name / Phone / Email Field | optional — org field API names |

Save the record.

### 3.3 Grant integration user FLS on mapped fields

**Propfocus Integration** does not include customer Lead/Opportunity/Site Visit field access.

1. Setup → Permission Sets → **Propfocus Integration** (or a companion set)
2. Object Settings → **Lead** → grant **Read + Edit** on every mapped field
3. Object Settings → **Opportunity** → grant **Read + Edit** on every mapped Opportunity field (if using Opp panel)
4. Repeat for **Site Visit** object fields if used

---

## Phase 4 — Outbound auth, CSP, notifications, UI placement

### 4.1 External Credential (OAuth client credentials)

Client Id and Client Secret are stored encrypted in the External Credential — not in Custom Metadata.

| #    | Where                                                                    | Action                                                                                                                                                                      | Pass when                           |
| ---- | ------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- |
| 4.1a | Setup → Named Credentials → **External Credentials** → **Propfocus API** | Confirm **Authentication Protocol** = OAuth 2.0, **Flow Type** = Client Credentials with Client Secret, **Identity Provider URL** = `https://propfocus.in/api/oauth2/token` | Token endpoint matches environment  |
| 4.1b | Same record → **Propfocus Principal** (Named Principal)                  | Enter **Client Id** and **Client Secret** from Propfocus team → Save                                                                                                        | Principal shows configured          |
| 4.1c | Setup → Named Credentials → **Propfocus API**                            | Confirm URL = `https://propfocus.in`, linked External Credential, **Generate Authorization Header** enabled                                                                 | Named Credential ready for callouts |
| 4.1d | Permission sets **Propfocus User** and **Propfocus AI Admin**            | Confirm **External Credential Principal Access** includes `Propfocus API — Propfocus Principal` (packaged; re-check after upgrade)                                          | Sales users and admins can call out |

### 4.2 CSP, notifications, UI

| #   | Where                                                     | Action                                                                                                                                                                           | Pass when                                   |
| --- | --------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| 4.2 | Setup → CSP Trusted Sites                                 | Confirm `https://propfocus.in` exists, Active, **frame-src** (and connect-src) enabled. Create if missing.                                                                       | Site active                                 |
| 4.3 | Browser                                                   | Hard-refresh (Ctrl/Cmd+Shift+R) after CSP changes                                                                                                                                | —                                           |
| 4.4 | Setup → Custom Notifications → **PropFocus Notification** | Ensure delivery to users who should get bell alerts                                                                                                                              | Recipients configured                       |
| 4.5 | Setup → App Manager → your sales app → Edit               | Add **propfocusAI Admin Setup** to Navigation Items → Save                                                                                                                       | Tab visible in app                          |
| 4.6 | Open any Lead → gear → **Edit Page**                      | Drag **propfocusLeadLinkGen** onto the page → **Save** → **Activate** (org default or relevant apps)                                                                             | Component visible on Lead                   |
| 4.7 | Open any Opportunity → gear → **Edit Page**               | Drag **propfocusLeadLinkGen** onto the page → **Save** → **Activate**                                                                                                            | Component visible on Opportunity            |
| 4.8 | (Optional) Auto site visit link                           | Setup → **Flows** → Record-Triggered Flow on Site Visit object → Apex **Generate Propfocus Site Visit Link From Record** → **Site Visit Record Id** = `{!$Record.Id}` → Activate | See [SETUP_GUIDE.md](./SETUP_GUIDE.md) §2.8 |

Optional: open the packaged **Propfocus AI** app (includes Lead + Admin Setup) instead of adding the tab to an existing app.

---

## Phase 5 — Admin verification (outbound)

1. Open **propfocusAI Admin Setup**
2. Confirm page loads and shows:
   - Organization Id
   - Config summary
   - **Inbound REST URL** (copy this for Phase 6 / backend)
3. Click **Test Connection**

| Result  | Meaning                                                                         |
| ------- | ------------------------------------------------------------------------------- |
| Success | External Credential + Named Credential + Organization Id are good               |
| Fail    | Fix Phase 4.1 (Client Id/Secret, token URL) and Phase 3 Organization Id; retest |

Inbound REST URL shape:

```
https://<your-instance>/services/apexrest/PropfocusAI/propfocus/events/
```

---

## Phase 6 — Inbound auth (Propfocus → Salesforce)

Outbound auth (Phase 4.1) is **not** used for inbound. Inbound needs a Salesforce **External Client App** + JWT.

Full detail: [JWT_SETUP.txt](./JWT_SETUP.txt). Condensed workflow:

**Key ownership:** Propfocus generates the RSA pair and stores `server.key` in secrets manager. Propfocus sends the customer **only `server.crt`**. Never transmit `server.key`. If the customer keeps the only private key, Propfocus has no inbound access. Cert validity is **365 days** — rotate before expiry or inbound fails with `invalid_grant` (see [JWT_SETUP.txt](./JWT_SETUP.txt) Step 10).

| #   | Who            | Action                                                                                                                                                   | Output                                                |
| --- | -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| 6.1 | **Propfocus**  | Generate RSA key pair; store `server.key` in secrets manager; send customer **only `server.crt`**                                                        | Customer has public cert; Propfocus holds private key |
| 6.2 | Customer admin | Setup → App Manager → **New External Client App**                                                                                                        | Name e.g. `Propfocus Integration JWT`                 |
| 6.3 | Customer admin | Enable OAuth; scope: **api** only (JWT Bearer does not use refresh tokens)                                                                               | Callback can be placeholder                           |
| 6.4 | Customer admin | **Enable JWT Bearer Flow** → upload `server.crt` from Propfocus                                                                                          | Save; wait 2–10 minutes                               |
| 6.5 | Customer admin | Copy **Consumer Key** (`3MVG9...`)                                                                                                                       | This is JWT `iss`                                     |
| 6.6 | Customer admin | App Policies → **Admin approved users are pre-authorized** → assign integration user via **Propfocus Integration** permission set                        | User can obtain tokens                                |
| 6.7 | **Propfocus**  | Sign JWT with `server.key`; exchange for `access_token` at `https://login.salesforce.com/services/oauth2/token` (sandbox: `https://test.salesforce.com`) | Token + `instance_url` returned                       |
| 6.8 | **Propfocus**  | POST to inbound URL with `Authorization: Bearer <token>`                                                                                                 | See [INBOUND.md](./INBOUND.md)                        |

Local token helper (optional **sandbox-only** testing with a separate local key pair): `propfocus-sf-jwt/` in this repo — not a substitute for the Propfocus-held production key.

---

## Phase 7 — Hand off to Propfocus backend

**Customer → Propfocus** (never send `server.key`):

| Item                               | Value                                                                        |
| ---------------------------------- | ---------------------------------------------------------------------------- |
| Salesforce org host / instance URL | From Admin Setup or login                                                    |
| Organization Id                    | From Config                                                                  |
| Inbound REST URL                   | From Admin Setup                                                             |
| Connected App Consumer Key         | From Phase 6.5                                                               |
| Integration username               | From Phase 2.3                                                               |
| Confirm `server.crt` uploaded      | Cert Propfocus already sent; customer does **not** hold or send `server.key` |
| Environment                        | Sandbox vs production (login vs test.salesforce.com)                         |

**Propfocus → Customer** (before Phase 6): `server.crt` only.

Propfocus must also:

1. Register this Salesforce org against the Organization Id
2. Subscribe to Platform Event **`PropfocusAI__Propfocus_Lead_Event__e`** (CometD / EMP)
3. Confirm outbound Client Id/Secret match the External Credential principal
4. Record JWT cert expiry (+365 days from generation) and set a 30-day rotation reminder

---

## Phase 8 — End-to-end feature tests

Use a Lead with **Buyer Id Field** populated. For Opportunity tests, use an Opportunity with **Opportunity Buyer Id Field** populated.

| #    | Test                      | Do                                                                         | Pass when                                                                                |
| ---- | ------------------------- | -------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| 8.1  | Generate Microsite        | Lead → Generate Microsite → pick project                                   | `Propfocus_Link__c` populated; no error toast                                            |
| 8.2  | Buyer Insights            | After microsite                                                            | Iframe loads (not blank)                                                                 |
| 8.3  | Confirm Site Visit (Lead) | Lead → Confirm Site Visit (button visible if Show Site Visit Button is on) | Lead site visit URL field populated                                                      |
| 8.3b | Confirm Site Visit (Opp)  | Opportunity → Confirm Site Visit                                           | Opportunity site visit URL populated; outbound body includes `salesforce_opportunity_id` |
| 8.3c | Generate Post Visit       | Lead/Opp → Generate Post Visit (if Show Post Visit Button is on)           | `Propfocus_Post_Visit__c` populated                                                      |
| 8.3d | History status            | Open panel History after Propfocus engagement / site visit update          | Card status shows Engaged / Confirmed / Rescheduled (not only Salesforce picklists)      |
| 8.4  | Outbound sync             | Change Lead Status → Save                                                  | Propfocus receives Platform Event                                                        |
| 8.5  | Inbound notification      | Propfocus POSTs notification event                                         | Lead or Opportunity owner gets bell notification                                         |
| 8.6  | Write-back                | Propfocus POSTs write-back payload                                         | Parent + child records update (Lead or Opportunity)                                      |

Payload formats: outbound [OUTBOUND.md](./OUTBOUND.md) · inbound [INBOUND.md](./INBOUND.md)

**Optional Apex sanity check** (Developer Console → Execute Anonymous), from `scripts/verify-sandbox.apex`:

```apex
PropfocusConfigService.Config cfg = PropfocusConfigService.getUiConfiguration();
System.debug('ORG_ID=' + cfg.organizationId);
System.debug('BUYER_ID_FIELD=' + cfg.buyerIdField);
System.debug('API_NAMED_CREDENTIAL=' + cfg.apiNamedCredential);
System.debug('INBOUND=' + PropfocusConfigService.getInboundEndpoint());
```

---

## Sandbox / UAT — point at dev

If installing in a **Salesforce sandbox**, override these packaged production defaults after install:

| Setting                | Where                                                          | Sandbox value                                                                                                        |
| ---------------------- | -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Named Credential URL   | Setup → Named Credentials → **Propfocus API**                  | `https://dev.propfocus.in`                                                                                           |
| OAuth token URL        | Setup → External Credentials → **Propfocus API**               | `https://dev.propfocus.in/api/oauth2/token`                                                                          |
| Embed Base URL         | Setup → Custom Metadata Types → **Propfocus Config → Default** | `https://dev.propfocus.in/embed/salesforce`                                                                          |
| CSP Trusted Site       | Setup → CSP Trusted Sites                                      | **Create new** site `https://dev.propfocus.in` (not packaged — Active, context All, frame-src + connect-src enabled) |
| Connected App callback | Setup → External Client Apps → **Propfocus AI**                | `https://dev.propfocus.in/oauth/callback`                                                                            |

Use the **dev** Organization Id and OAuth Client Id/Secret from Propfocus for that environment. Re-run Phase 8 after changing URLs.

### Platform side (Propfocus team): issue the OAuth client

The Client Id/Secret the org's External Credential principal needs is a row in the
platform's `oauth_clients` table. Create it on the target environment's host
(dev shown; the script prints the id and the secret **once**):

```bash
ssh -i ~/.ssh/prop-focus-dev.pem ec2-user@3.6.136.192 \
  'docker exec -e DB_SSL=require backend node scripts/manage-oauth-clients.js add "<Customer> Salesforce Sandbox" "<purpose>"'
```

(`DB_SSL=require` is mandatory — RDS refuses unencrypted connections.) Also confirm the
customer **organization exists** on that environment (`organizations` table) with at least
one active **broker** and **project** — link generation resolves both, and the org's UUID is
what goes into `Propfocus Config → Organization Id`. The admin then pastes the Client
Id/Secret into **Setup → Named Credentials → External Credentials → Propfocus API →
Principals → `Propfocus_Principal` → Edit**.

---

## Phase 9 — Production install checklist

**Preferred playbook for production go-live (Released 0.16.0.1):** [PROD_INSTALLATION.md](./PROD_INSTALLATION.md).

Production orgs use the packaged defaults (`https://propfocus.in`). Complete Phases 0–8 with production credentials:

| #   | Action                                                                                                                                                    |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 9.1 | Install package in production (use `login.salesforce.com`; complete Phases 0–8)                                                                           |
| 9.2 | Confirm Named Credential URL, External Credential token URL, and Embed Base Url point to `https://propfocus.in` (no change needed if defaults are intact) |
| 9.3 | Put **production** Organization Id in Config and **production** Client Id/Secret in External Credential principal                                         |
| 9.4 | Create a **new** External Client App + JWT keys in production (do not reuse sandbox Consumer Key)                                                         |
| 9.5 | Use `aud` / token URL `https://login.salesforce.com` (not test.salesforce.com)                                                                            |
| 9.6 | Re-run Phase 8 in production with a real Lead                                                                                                             |

---

## Subscriber config via SFDX / change set

The **managed package** installs Apex, LWCs, permission set _definitions_, External/Named Credential skeletons, and default CMDT. These subscriber-owned items should go through your deployment pipeline (not ad-hoc clicks in production):

| Item                                                   | Metadata type (typical)                                           | Notes                                                              |
| ------------------------------------------------------ | ----------------------------------------------------------------- | ------------------------------------------------------------------ |
| Propfocus Config → Default values                      | `CustomMetadata` (`PropfocusAI__Propfocus_Config.Default`)        | Organization Id, field API names, Embed Base Url                   |
| Permission set assignments                             | `PermissionSetAssignment` or Manual / group assignment automation | Propfocus User / AI Admin / Integration                            |
| Lead Lightning page with `propfocusLeadLinkGen`        | `FlexiPage`                                                       | Activate as org/app default via deploy or App Builder + change set |
| Opportunity Lightning page with `propfocusLeadLinkGen` | `FlexiPage`                                                       | Same shared LWC; activate for Opportunity record page              |
| Integration user FLS on mapped customer fields         | Permission set (customer-owned)                                   | Companion set recommended; not fully packaged                      |
| Sandbox URL overrides                                  | Named Credential / External Credential / CSP                      | Environment-specific; often manual or unlocked package             |

**SFDX (example shape):** retrieve or author the CMDT record + FlexiPage in a scratch/sandbox, then:

```bash
sf project deploy start --source-dir force-app-subscriber --target-org <prod-or-uat-alias>
```

**Change set:** Sandbox → outbound change set with Custom Metadata Type records + Lightning page → deploy to production → Activate page if needed.

Secrets (External Credential Client Id/Secret, JWT cert upload) stay in Setup; do not put them in git or change sets.

---

## Upgrade from 0.5.x

Use this when moving from **0.5.0-1** (or any 0.5.x build that stored outbound OAuth on Propfocus Config) to a release that uses **External Credential** only.

| #   | Action                                                                                                                                                                                    |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| U.1 | In sandbox first: note current package version (Setup → Installed Packages)                                                                                                               |
| U.2 | **Before upgrade:** copy OAuth **Client Id** + **Client Secret** from Propfocus Config (if still present) into Setup → External Credentials → **Propfocus API** → **Propfocus Principal** |
| U.3 | Confirm Named Credential **Propfocus API** URL and External Credential token URL for the environment                                                                                      |
| U.4 | Install the new package version → choose **Upgrade** (do not uninstall)                                                                                                                   |
| U.5 | Confirm OAuth fields are gone from Config (or ignored); secrets live only on the External Credential principal                                                                            |
| U.6 | Re-check permission sets for **External Credential Principal Access** (`Propfocus API — Propfocus Principal`)                                                                             |
| U.7 | Smoke test: Admin Setup → Test Connection; Generate Microsite; one inbound POST                                                                                                           |
| U.8 | Repeat U.2–U.7 in production in a change window; keep JWT External Client App / Consumer Key unless the release notes say otherwise                                                       |

What is kept on upgrade: Propfocus Config mappings, Lead/package data, permission set assignments, Named/External Credential principal values (post-install), CSP, Lightning page customizations.  
What changes: packaged Apex/LWC/REST; OAuth-in-Config fields removed after the External Credential release.

If Upgrade is not offered (e.g. Beta → Released): note Client Id/Secret and JWT Consumer Key, uninstall, install Released, restore secrets and re-run Phase 8. See also [Uninstall / rollback](#uninstall--rollback).

---

## Uninstall / rollback

**Rollback without uninstall:** Prefer upgrading to a prior Released version only if Propfocus publishes one; otherwise leave the package installed and disable usage (remove LWC from Lead/Opportunity pages, unassign permission sets, revoke External Client App / integration user).

**Before uninstall** (Setup → Installed Packages → Uninstall), record:

- External Credential Client Id/Secret
- Organization Id and field mappings (export CMDT or screenshot)
- External Client App Consumer Key + whether `server.crt` must be re-uploaded later
- Inbound REST URL / org host shared with Propfocus backend

**After uninstall (typical Salesforce managed-package behavior):**

| Removed                                                                         | Usually retained / orphaned                                                                                              |
| ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Packaged Apex, LWCs, permission set _definitions_, Platform Event, inbound REST | Lead/Opportunity field **values** already written (e.g. packaged URL fields) may remain as data until fields are deleted |
| Packaged custom objects / fields (if uninstall deletes them — confirm prompt)   | Customer Site Visit object and customer-owned fields                                                                     |
| Packaged External/Named Credential skeletons                                    | Secrets you typed (gone with credential)                                                                                 |

Uninstall does **not** automatically unregister the org in Propfocus backend — ask Propfocus to disable the Organization Id and revoke outbound Client credentials. Delete or deactivate the customer-created External Client App used for JWT.

---

## Master checklist

```
Prerequisites
[ ] Lead (and Opportunity / Site Visit) fields exist for mapping
[ ] Credentials / Org Id received from Propfocus
[ ] Enterprise: change window + pipeline path for CMDT / FlexiPage / perm sets

Install
[ ] Package 0.16.0.1 installed (or upgraded — see Upgrade from 0.5.x)

Users
[ ] Propfocus User assigned to sales users
[ ] Local Propfocus Callout Access assigned to sales users (SETUP_GUIDE §2.1e); users logged out/in
[ ] Propfocus AI Admin assigned to admins
[ ] Integration user created + Propfocus Integration assigned
[ ] Integration user FLS on all mapped fields

Config
[ ] Propfocus Config → Default filled (Org Id + field maps + optional Show Site/Post Visit Button)
[ ] External Credential principal: Client Id + Secret configured
[ ] Named Credential URL + token endpoint correct (prod: propfocus.in; sandbox: dev.propfocus.in)
[ ] Sandbox override completed if applicable
[ ] CSP Trusted Site active (frame-src)
[ ] Admin Setup tab in app nav
[ ] propfocusLeadLinkGen on Lead record page (activated)
[ ] propfocusLeadLinkGen on Opportunity record page (activated, if using Opp panel)
[ ] Optional: Site Visit Record-Triggered Flow active (SETUP_GUIDE §2.8)
[ ] Custom notification delivery configured

Inbound
[ ] Propfocus generated key pair; customer uploaded server.crt only
[ ] External Client App + JWT Bearer; Admin approved + permission set
[ ] Consumer Key + integration username shared with Propfocus
[ ] Backend can obtain access_token and POST inbound REST
[ ] Cert expiry date recorded (365 days); rotation reminder set

Verify
[ ] Test Connection succeeds
[ ] Microsite / iframe / site visit work
[ ] Platform Event sync confirmed by Propfocus
[ ] Notification + write-back confirmed
```

---

## Troubleshooting (quick)

| Symptom                                                              | Fix                                                                                                                                                                                          |
| -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Buttons missing on Lead / Opportunity                                | Phase 4.6 / 4.7 — add LWC + Activate; for Site/Post Visit only, confirm Phase 3 Show Site Visit / Show Post Visit Button                                                                     |
| Site Visit or Post Visit button hidden                               | Phase 3 — enable **Show Site Visit Button** / **Show Post Visit Button** on Propfocus Config → Default                                                                                       |
| Insufficient privileges                                              | Phase 2 permission sets                                                                                                                                                                      |
| Test Connection fails                                                | Phase 4.1 Client Id/Secret + token URL; Phase 3 Organization Id                                                                                                                              |
| Unauthorized / insufficient access on callout                        | Phase 4.1d — user needs **Propfocus User** or **Propfocus AI Admin** (External Credential principal access) **and** local **Propfocus Callout Access** for sales (§2.1b / SETUP_GUIDE §2.1e) |
| Microsite works for admin but not sales user                         | Assign **Propfocus User** + **Propfocus Callout Access**; confirm principal access; user must log out/in                                                                                     |
| "don't have read permissions on the User External Credential object" | Local Callout Access PS with UEC Read — SETUP_GUIDE §2.1e                                                                                                                                    |
| Site Visit Save creates SV but no Propfocus link                     | Phase 4.8 / SETUP_GUIDE §2.8 — Flow active, `{!$Record.Id}`, project name in Propfocus, Callout Access                                                                                       |
| Iframe blank                                                         | Phase 4.2 CSP + Embed Base Url; hard-refresh                                                                                                                                                 |
| No Lead/Opportunity found for `buyer_id`                             | Buyer Id Field mapping + value on Lead or Opportunity                                                                                                                                        |
| 403 Organization ID mismatch                                         | Organization Id in Config ≠ backend                                                                                                                                                          |
| Write-back fails / field errors                                      | Phase 3.3 integration user FLS                                                                                                                                                               |
| `invalid_grant` on JWT                                               | Phase 6.6 pre-authorize integration user; or cert expired / wrong key (rotate per JWT_SETUP Step 10)                                                                                         |
| Wrong org on install                                                 | Log into target org (sandbox vs prod) before install URL                                                                                                                                     |

More: [SETUP_GUIDE.md](./SETUP_GUIDE.md) troubleshooting · [FAQ.txt](./FAQ.txt)

---

## Related documents

| Document                                                            | Use when                                                 |
| ------------------------------------------------------------------- | -------------------------------------------------------- |
| [SETUP_GUIDE.md](./SETUP_GUIDE.md)                                  | Same setup with Hosachiguru example values + test matrix |
| [propfocus-admin-setup-guide.md](../propfocus-admin-setup-guide.md) | Short checklist card                                     |
| [FIELDS.md](./FIELDS.md)                                            | Field API names + outbound auth reference                |
| [OUTBOUND.md](./OUTBOUND.md)                                        | Salesforce → Propfocus payloads, PII, residency / DPA    |
| [INBOUND.md](./INBOUND.md)                                          | REST payloads, auth options                              |
| [JWT_SETUP.txt](./JWT_SETUP.txt)                                    | Full JWT External Client App steps                       |
| [FAQ.txt](./FAQ.txt)                                                | Upgrades, uninstall, common Q&A                          |

---

## Appendix — Configuring a subscriber org from the CLI (lessons from real installs)

All of Phase 3–6 can be done with `sf` against the customer org instead of clicking Setup.
The traps below cost real time; respect them.

| What                            | How                                                                                                    | Trap                                                                                                                                                                                                                                                                                              |
| ------------------------------- | ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Propfocus Config` record       | Deploy `CustomMetadata` member **`PropfocusAI__Propfocus_Config.PropfocusAI__Default`**                | Deploying member `…Propfocus_Config.Default` silently **creates a second, local-namespace record** that shadows nothing and confuses everyone — the managed code reads its own namespace's record. Delete the stray via destructive changes if you make one.                                      |
| Blanking a config field         | Include the field with `<value xsi:nil="true"/>`                                                       | **Omitting** a field keeps the record's existing value — deploys merge, they don't replace. Notably `Site Visit Scheduled Status` ships as `SV Scheduled`; if that isn't a real Lead Status picklist value in this org, nil it (or map it) or site-visit generation will stamp an invalid status. |
| External Credential (token URL) | Deployable from the subscriber org (`ExternalCredential` type)                                         | —                                                                                                                                                                                                                                                                                                 |
| Named Credential (base URL)     | **Setup UI only**                                                                                      | A subscriber deploy fails with _"the namespace of the named credential and external credential don't match"_. Edit in Setup → Named Credentials instead.                                                                                                                                          |
| Local dev CSP Trusted Site      | Deploy a `CspTrustedSite` (see Sandbox override)                                                       | Not packaged since 0.16.0 — must be created per sandbox.                                                                                                                                                                                                                                          |
| Panel placement                 | Add `PropfocusAI:propfocusLeadLinkGen` to the Lead FlexiPage                                           | On heavily customized pages where the whole layout is **one full-page custom LWC**, place the Propfocus panel **first** in the region — placed after, the custom component's floating card renders on top of it and the panel is invisible.                                                       |
| Permission sets                 | `sf org assign permset --name PropfocusAI__Propfocus_User …` plus the local `Propfocus_Callout_Access` | The local callout set is still required (see §2.1b).                                                                                                                                                                                                                                              |
