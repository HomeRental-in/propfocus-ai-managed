# Propfocus AI — Production Installation Guide (v0.16.0.1)

**Audience:** Customer Salesforce admin + Propfocus backend  
**Goal:** Install Released **Propfocus AI `0.16.0.1`** in a **production** org, configure it, and prove inbound + outbound work.  
**Time:** First production org typically a few hours of Salesforce setup plus backend registration. Enterprise change control can stretch this across days.  
**Namespace:** `PropfocusAI`

This is the production go-live playbook. Follow the phases in order. Do not skip prerequisites.

For how versions are built and promoted, see [RELEASE_PROCESS.md](./RELEASE_PROCESS.md). JWT deep-dive: [JWT_SETUP.txt](./JWT_SETUP.txt). Field API names: [FIELDS.md](./FIELDS.md).

---

## Package to install

|                                   |                          |
| --------------------------------- | ------------------------ |
| **Package**                       | Propfocus AI             |
| **Version**                       | **0.16.0.1** (Released)  |
| **Subscriber package version Id** | `04tdL000000nuSTQAY`     |
| **Ancestor**                      | Released `0.11.0.1`      |
| **Coverage**                      | 79% (promotion gate met) |

**Production install URL** — log in at `https://login.salesforce.com` first:

```
https://login.salesforce.com/packaging/installPackage.apexp?p0=04tdL000000nuSTQAY
```

CLI (if the production org is authorized):

```bash
sf org login web --instance-url https://login.salesforce.com --alias amberstone-prod
sf package install --package 04tdL000000nuSTQAY --target-org amberstone-prod --wait 30 \
  --security-type AdminsOnly --upgrade-type Mixed --no-prompt
```

Do **not** install `0.12.0.1` or `0.12.0.2`. Those are betas. Production only accepts this Released build.

---

## Hard rules (read before clicking Install)

1. **Use `login.salesforce.com`.** Sandbox install URLs (`test.salesforce.com`) will put the package in UAT, not production.
2. **Never install a beta in production.** A beta cannot be upgraded in place; uninstall deletes package data.
3. **Do not reuse UAT secrets.** Production needs its own Propfocus Organization Id, outbound Client Id/Secret, External Client App, and JWT certificate. Do not copy the UAT Consumer Key.
4. **Production URLs only.** Named Credential, token endpoint, embed URL, and CSP must be `https://propfocus.in` — not `dev.propfocus.in`.
5. **JWT `aud` is production.** `https://login.salesforce.com` — not `https://test.salesforce.com`.
6. **Uninstall is destructive.** Prefer Upgrade if a Released version is already installed. Snapshot Config before any uninstall.

Amberstone UAT (`amberstoneproperties--uat2026`) is on **beta `0.12.0.2`**. That does **not** block production. Production is a different org and can take Released `0.16.0.1` as a first install or as an upgrade from any earlier **Released** version (`0.11.0.1`, `0.10.0.1`, …).

---

## What 0.16.0.1 adds (vs 0.12)

- **0.13/0.14** — RNR microsite lead type from CMDT (`RNR Microsite Statuses`); site-visit
  date/time-of-day stamps on the Lead; Confirm Site Visit modal prefill from Lead dates; full
  Config layout.
- **0.15** — Existing-link guard: repeat generate calls return the record's stored link with **no
  callout** (ends the duplicate WhatsApp flood to agents); explicit Regenerate opts back in.
  Duplicate re-check bypasses the Lightning client cache. Admin Setup shows the inbound endpoint.
- **0.16** — The install screen no longer shows `dev.propfocus.in`: the package ships only
  production CSP Trusted Sites (`propfocus.in`, `www.propfocus.in`). Sandboxes create a local dev
  CSP site (see the sandbox override in E2E_INSTALLATION.md).

## What 0.12.0.3 added (vs 0.11)

- Auto-open Generate Microsite / Confirm Site Visit / Generate Post Visit when Lead status matches Config lists.
- **Site Visit Scheduled Status** — optional Lead/Opportunity status stamp when a site-visit link is created.
- Optional **Show Site Visit Button** / **Show Post Visit Button**.
- Unused OAuth fields hidden on the Config layout. Outbound Client Id/Secret stay on **External Credential → Propfocus Principal**.

---

## Collect these before you start

| Item                                                    | Who            | Production notes                                                                                      |
| ------------------------------------------------------- | -------------- | ----------------------------------------------------------------------------------------------------- |
| Salesforce **admin** login to **production**            | Customer IT    | Org must support Apex (Enterprise / Unlimited). Log in at `login.salesforce.com`.                     |
| Propfocus **production Organization Id**                | Propfocus      | UUID. **Not** the UAT/dev org id.                                                                     |
| Outbound OAuth **Client Id** + **Client Secret** (prod) | Propfocus      | Enter in External Credential principal — **not** in Propfocus Config.                                 |
| **Lead / Opportunity / Site Visit field API names**     | Customer admin | Copy from UAT if already validated. See [Amberstone mappings](#appendix-a--amberstone-copy-from-uat). |
| Site Visit object API name                              | Customer admin | Package does **not** create this object. Amberstone UAT uses `Visit__c`.                              |
| Dedicated **integration user** email                    | Customer admin | e.g. `propfocus.integration@amberstoneproperties.com` (globally unique).                              |
| JWT **`server.crt`** only                               | Propfocus      | Propfocus generates the key pair and keeps `server.key`. Customer uploads the cert. Valid 365 days.   |
| Change window / who activates Lightning pages           | Customer IT    | Panel is invisible until the FlexiPage is saved **and activated**.                                    |

---

## Decide: first install vs upgrade

In production: **Setup → Installed Packages → Propfocus AI**.

| What’s there                                                    | What to do                                                                                                                                             |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Package **not listed**                                          | First-time install. Use the URL above → **Install**.                                                                                                   |
| Any **Released** version (`0.11.0.1`, `0.10.0.1`, `0.7.0.2`, …) | Same URL → Salesforce offers **Upgrade**. Config and data are kept. Then fill any new 0.12 Config fields (auto statuses, Site Visit Scheduled Status). |
| A **Beta**                                                      | Stop. Do **not** Upgrade. Snapshot Config, uninstall (destructive), then install Released `0.16.0.1`, then restore Config.                             |

If you cannot see the org, ask the admin to screenshot Installed Packages before the change window.

---

## Phase 0 — Org prerequisites (before Install)

Do these in **production** before opening the install URL.

| #   | Where                                 | Action                                                                                              | Pass when                     |
| --- | ------------------------------------- | --------------------------------------------------------------------------------------------------- | ----------------------------- |
| 0.1 | Object Manager → Lead → Fields        | Mapped buyer / name / project / status fields exist                                                 | API names known               |
| 0.2 | Object Manager → Opportunity → Fields | Same if using the Opportunity panel                                                                 | Opportunity mappings possible |
| 0.3 | Object Manager                        | Site Visit object exists (Amberstone: `Visit__c`) with Lead lookup (and Opportunity lookup if used) | Object + lookups exist        |
| 0.4 | Login                                 | You are in **production** (`*.my.salesforce.com` with **no** `--sandbox` / `--uat` in the host)     | Correct org                   |

Lead Field History Tracking is **not** required.

---

## Phase 1 — Install the package

| #   | Action                                                                                 | Pass when                                            |
| --- | -------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| 1.1 | Log into **production** as a System Administrator at `https://login.salesforce.com`    | Host is production                                   |
| 1.2 | Open the install URL above                                                             | Install wizard for **Propfocus AI 0.16.0.1**         |
| 1.3 | Choose **Install for Admins Only** → Install                                           | Completes with no errors                             |
| 1.4 | On **Approve Third-Party Access**, approve CSP / remote site access for `propfocus.in` | Approved                                             |
| 1.5 | Setup → **Installed Packages**                                                         | **Propfocus AI** version **0.12.0.3** / **ver 0.12** |

**Installed for you (no action):** Apex, Lead trigger, inbound REST, Platform Event, custom objects, permission set _definitions_, External + Named Credential skeletons, Remote Site, CSP Trusted Site for `https://propfocus.in`, LWCs, Admin Setup tab, Propfocus AI app, default `Propfocus_Config` CMDT.

**Not installed (you configure next):** External Credential Client Id/Secret, External Client App (inbound JWT), field mappings, permission set _assignments_, Lead/Opportunity page LWC, integration user, local **Propfocus Callout Access** permission set.

---

## Phase 2 — Users and permission sets

### 2.1 Create the integration user

Setup → Users → **New User**:

| Field        | Value                                                                                                                                       |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| User License | **Salesforce Integration** (free; ~5 per prod org) if available, otherwise a standard license                                               |
| Profile      | **Salesforce API Only System Integrations** (or **Minimum Access – API Only Integrations** / Minimum Access). **Not** System Administrator. |
| Username     | e.g. `propfocus.integration@amberstoneproperties.com` (globally unique)                                                                     |
| Email        | a monitored inbox                                                                                                                           |
| Active       | checked                                                                                                                                     |

Complete the activation email. Write down the **username** — this is JWT `sub`.

### 2.2 Assign packaged permission sets

| Who                    | Permission set            | Where                                        |
| ---------------------- | ------------------------- | -------------------------------------------- |
| Sales / pre-sales reps | **Propfocus User**        | Setup → Permission Sets → Manage Assignments |
| Salesforce admins      | **Propfocus AI Admin**    | Same                                         |
| Integration user       | **Propfocus Integration** | Same                                         |

### 2.3 Local permission set — Propfocus Callout Access (required for sales)

Salesforce strips **User External Credentials** Read from managed permission sets. Packaged **Propfocus User** alone is not enough for most sales profiles. Create this **once per org** (it is not in the package):

1. Setup → Permission Sets → **New** → Label: `Propfocus Callout Access` → Save.
2. Object Settings → **User External Credentials** → enable **Read** → Save.
3. **External Credential Principal Access** → enable **Propfocus API — Propfocus Principal** → Save.
4. **Manage Assignments** → every sales user who generates links (they also need **Propfocus User**).
5. Those users must **log out and log back in**.

Without this, sales users see empty Projects or: _You don't have read permissions on the User External Credential object._

---

## Phase 3 — Propfocus Config (Custom Metadata)

**Where:** Setup → Custom Metadata Types → **Propfocus Config** → Manage Records → **Default** → **Edit**.

If Edit only shows Label / Name, or 0.12 fields are missing: Setup → Custom Metadata Types → **Propfocus Config** → **Page Layouts** → **Propfocus Config Layout** → drag the missing fields onto the layout → Save → re-open Default.

OAuth Client Id / Secret / Token URL are **not** on this layout. They belong in Phase 4.

### 3.1 API / UI (production values)

| Config field                         | Production value                                                                                                                                                     |
| ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| API Named Credential                 | `Propfocus_API`                                                                                                                                                      |
| Organization Id                      | **production** Propfocus org UUID (from Propfocus — not UAT)                                                                                                         |
| Embed Base Url                       | `https://propfocus.in/embed/salesforce`                                                                                                                              |
| Embed Uses Salesforce Lead Id        | Checked                                                                                                                                                              |
| Embed Uses Salesforce Opportunity Id | Checked (if using Opp panel)                                                                                                                                         |
| Show Copy Modal                      | As agreed (UAT: checked)                                                                                                                                             |
| Show Site Visit Button               | Checked unless Confirm Site Visit is not used                                                                                                                        |
| Show Post Visit Button               | Checked unless Generate Post Visit is not used                                                                                                                       |
| Auto Microsite Statuses              | Comma-separated Lead statuses that auto-open Generate Microsite (leave blank to disable)                                                                             |
| Auto Site Visit Statuses             | Comma-separated statuses that auto-open Confirm Site Visit                                                                                                           |
| Auto Post Visit Statuses             | Comma-separated statuses that auto-open Generate Post Visit                                                                                                          |
| Site Visit Scheduled Status          | Exact Lead/Opportunity **status picklist value** to stamp when a site-visit link is created. Leave blank to never change status. Must already exist on the picklist. |

Auto-open only fires when the Lead **moves into** a listed status and the corresponding link does not already exist.

### 3.2 Lead / Opportunity / Site Visit mappings

Enter **API names** only (custom fields end in `__c`). Relationship paths such as `Project__r.Name` are allowed.

Copy the values already proven in UAT where possible. Amberstone’s UAT mappings are in [Appendix A](#appendix-a--amberstone-copy-from-uat).

**Critical:** Buyer Id Field must be populated on records you test. Inbound REST matches `buyer_id` to this field (Lead first, then Opportunity).

### 3.3 Integration user FLS on mapped fields

**Propfocus Integration** does not include customer Lead/Opportunity/Visit field access.

1. Setup → Permission Sets → **Propfocus Integration** (or a companion local set).
2. Object Settings → **Lead** → **Read + Edit** on every mapped field.
3. Repeat for **Opportunity** and the Site Visit object (`Visit__c` for Amberstone).

Save the Default Config record.

---

## Phase 4 — Outbound auth, CSP, UI

Outbound (Salesforce → Propfocus) is **External Credential**, not Config.

### 4.1 External Credential + Named Credential

| #    | Where                                                                    | Action                                                                                                                                             | Pass when                                     |
| ---- | ------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| 4.1a | Setup → Named Credentials → **External Credentials** → **Propfocus API** | Authentication Protocol = OAuth 2.0, Flow = Client Credentials with Client Secret, Identity Provider URL = `https://propfocus.in/api/oauth2/token` | Token URL is **prod**, not `dev.propfocus.in` |
| 4.1b | Same → **Propfocus Principal**                                           | Enter **production** Client Id and Client Secret → Save                                                                                            | Principal configured                          |
| 4.1c | Setup → Named Credentials → **Propfocus API**                            | URL = `https://propfocus.in`, External Credential linked, **Generate Authorization Header** enabled                                                | Ready for callouts                            |
| 4.1d | Permission sets **Propfocus User** and **Propfocus AI Admin**            | **External Credential Principal Access** includes `Propfocus API — Propfocus Principal`                                                            | Sales + admins can call out                   |

### 4.2 CSP, notifications, pages

| #   | Where                                                     | Action                                                                                                                                                     | Pass when                                                 |
| --- | --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| 4.2 | Setup → CSP Trusted Sites                                 | `https://propfocus.in` exists, **Active**, **frame-src** (and connect-src) enabled                                                                         | Site active. Do **not** point this at `dev.propfocus.in`. |
| 4.3 | Browser                                                   | Hard-refresh (Ctrl/Cmd+Shift+R) after CSP changes                                                                                                          | —                                                         |
| 4.4 | Setup → Custom Notifications → **PropFocus Notification** | Delivery enabled for users who should get bell alerts                                                                                                      | Recipients configured                                     |
| 4.5 | Setup → App Manager → sales app → Edit                    | Add **propfocusAI Admin Setup** to Navigation Items → Save                                                                                                 | Tab visible                                               |
| 4.6 | Any **Lead** → gear → **Edit Page**                       | Drag **`propfocusLeadLinkGen`** (managed `PropfocusAI:propfocusLeadLinkGen`) onto the page → **Save** → **Activate** (org default or the apps that matter) | Component visible on Lead                                 |
| 4.7 | Any **Opportunity** → gear → **Edit Page**                | Same component → **Save** → **Activate**                                                                                                                   | Component visible on Opportunity                          |

Do not add an unmanaged copy of the LWC.

### 4.3 Optional — auto site-visit link on Visit save

The package does not own `Visit__c`. To generate a Propfocus site-visit link when a Visit is saved:

1. Setup → **Flows** → **New** → Record-Triggered Flow.
2. Object = the Config **Site Visit Object** (Amberstone: `Visit__c`).
3. Trigger = **A record is created**. Optimize for **Actions and Related Records**.
4. Action → Apex **Generate Propfocus Site Visit Link From Record**.
5. **Site Visit Record Id** = `{!$Record.Id}`.
6. Save → **Activate**.

Saving user needs **Propfocus User** + **Propfocus Callout Access**. Project name on the Visit must exist in Propfocus.

---

## Phase 5 — Admin verification (outbound)

1. Open the **propfocusAI Admin Setup** tab.
2. Confirm Organization Id, Config summary, and **Inbound REST URL**.
3. Click **Test Connection**.

| Result  | Meaning                                                                         |
| ------- | ------------------------------------------------------------------------------- |
| Success | External Credential + Named Credential + Organization Id are good               |
| Fail    | Fix Phase 4.1 (Client Id/Secret, token URL) and Phase 3 Organization Id; retest |

Copy the inbound URL for Phase 6 / backend. Shape:

```
https://<your-instance>.my.salesforce.com/services/apexrest/PropfocusAI/propfocus/events/
```

---

## Phase 6 — Inbound auth (Propfocus → Salesforce)

Outbound credentials from Phase 4 are **not** used for inbound. Production inbound is a **new** External Client App + JWT. Full detail: [JWT_SETUP.txt](./JWT_SETUP.txt).

**Do not reuse the UAT External Client App or Consumer Key.**

| #   | Who            | Action                                                                                                                                                                                    | Output                          |
| --- | -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------- |
| 6.1 | **Propfocus**  | Generate RSA key pair **for this production org**. Store `server.key` in secrets manager. Send the customer **only `server.crt`**.                                                        | Customer has public cert        |
| 6.2 | Customer admin | Setup → App Manager → **New External Client App**. Name: `Propfocus Integration JWT`. Distribution: Local.                                                                                | App created                     |
| 6.3 | Customer admin | Enable OAuth. Callback (placeholder): `https://login.salesforce.com/services/oauth2/callback`. Scope: **api** only (no refresh_token).                                                    | OAuth enabled                   |
| 6.4 | Customer admin | **Flow Enablement** → **Enable JWT Bearer Flow** → upload `server.crt` → Save. Wait 2–10 minutes.                                                                                         | Cert attached                   |
| 6.5 | Customer admin | Copy **Consumer Key** (`3MVG9…`). This is JWT `iss`. Consumer Secret is unused for JWT.                                                                                                   | Key written down                |
| 6.6 | Customer admin | App Policies → **Permitted Users = Admin approved users are pre-authorized**. Assign the app to the **Propfocus Integration** permission set (the integration user already has that set). | User can obtain tokens          |
| 6.7 | **Propfocus**  | Sign JWT with `server.key`; `iss` = Consumer Key, `sub` = integration username, `aud` = `https://login.salesforce.com`. POST to `https://login.salesforce.com/services/oauth2/token`.     | `access_token` + `instance_url` |
| 6.8 | **Propfocus**  | POST inbound events with `Authorization: Bearer <token>`. See [INBOUND.md](./INBOUND.md).                                                                                                 | 2xx                             |

Never email or Slack `server.key`. If the customer keeps the only private key, Propfocus cannot call inbound. Cert validity is **365 days** — record expiry and set a 30-day rotation reminder.

---

## Phase 7 — Hand off to Propfocus backend

**Customer → Propfocus** (never send `server.key`):

| Item                             | Value                                               |
| -------------------------------- | --------------------------------------------------- |
| Environment                      | **Production**                                      |
| Salesforce org host              | Production instance URL (from Admin Setup or login) |
| Organization Id                  | From Config (production UUID)                       |
| Inbound REST URL                 | From Admin Setup                                    |
| External Client App Consumer Key | From Phase 6.5                                      |
| Integration username             | From Phase 2.1                                      |
| Confirm `server.crt` uploaded    | Cert Propfocus already sent                         |

**Propfocus must also:**

1. Register this Salesforce org against the **production** Organization Id.
2. Subscribe to Platform Event `PropfocusAI__Propfocus_Lead_Event__e` (CometD / EMP).
3. Confirm outbound Client Id/Secret match the External Credential principal.
4. Record JWT cert expiry and a rotation reminder.
5. Point the customer’s Propfocus org at **production** APIs (`https://propfocus.in`), not `dev.propfocus.in`.

---

## Phase 8 — End-to-end tests (production)

Use a real Lead with **Buyer Id Field** populated. Repeat site-visit tests on an Opportunity if the Opp panel is in use.

| #   | Test                 | Do                                                                      | Pass when                                                                                |
| --- | -------------------- | ----------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| 8.1 | Generate Microsite   | Lead → Generate Microsite → pick project                                | `Propfocus_Link__c` populated; no error toast                                            |
| 8.2 | Buyer Insights       | After microsite                                                         | Iframe loads (not blank)                                                                 |
| 8.3 | Confirm Site Visit   | Lead → Confirm Site Visit                                               | Site visit URL field populated; status stamped if Config has Site Visit Scheduled Status |
| 8.4 | Generate Post Visit  | Lead → Generate Post Visit                                              | `Propfocus_Post_Visit__c` populated                                                      |
| 8.5 | Auto-open            | Move Lead into an Auto Microsite status (no existing microsite)         | Generate Microsite modal opens                                                           |
| 8.6 | Outbound sync        | Change Lead Status → Save                                               | Propfocus receives Platform Event                                                        |
| 8.7 | Inbound notification | Propfocus POSTs a notification event                                    | Owner gets a bell                                                                        |
| 8.8 | Write-back           | Propfocus POSTs write-back                                              | Mapped fields update                                                                     |
| 8.9 | Sales user           | Log in as a sales user (not admin) with Propfocus User + Callout Access | Generate Microsite works after logout/in                                                 |

Payload formats: [OUTBOUND.md](./OUTBOUND.md) · [INBOUND.md](./INBOUND.md).

Optional Apex check (Developer Console → Execute Anonymous):

```apex
PropfocusConfigService.Config cfg = PropfocusConfigService.getUiConfiguration();
System.debug('ORG_ID=' + cfg.organizationId);
System.debug('BUYER_ID_FIELD=' + cfg.buyerIdField);
System.debug('API_NAMED_CREDENTIAL=' + cfg.apiNamedCredential);
System.debug('INBOUND=' + PropfocusConfigService.getInboundEndpoint());
```

---

## Master checklist

```
Before
[ ] Logged into production (login.salesforce.com), not UAT
[ ] Installed Packages checked: missing vs Released vs Beta
[ ] Prod Organization Id + Client Id/Secret received from Propfocus
[ ] server.crt received (Propfocus holds server.key)
[ ] Field API names confirmed (copy from UAT if validated)

Install
[ ] Propfocus AI 0.12.0.3 listed under Installed Packages
[ ] Third-party access / CSP for propfocus.in approved

Users
[ ] Integration user created and activated
[ ] Propfocus Integration assigned; FLS on mapped customer fields
[ ] Propfocus User assigned to sales
[ ] Local Propfocus Callout Access assigned; users logged out/in
[ ] Propfocus AI Admin assigned to admins

Config
[ ] Organization Id = production UUID
[ ] Embed Base Url = https://propfocus.in/embed/salesforce
[ ] Lead / Opportunity / Site Visit mappings filled
[ ] Auto_* statuses and Site Visit Scheduled Status set (or intentionally blank)
[ ] External Credential principal: prod Client Id + Secret
[ ] Named Credential URL + token URL = https://propfocus.in (not dev)
[ ] CSP Trusted Site https://propfocus.in Active (frame-src)
[ ] propfocusLeadLinkGen on Lead page — Saved AND Activated
[ ] propfocusLeadLinkGen on Opportunity page — Saved AND Activated
[ ] Optional Visit Flow activated

Inbound
[ ] New production External Client App (not UAT Consumer Key)
[ ] JWT Bearer enabled; server.crt uploaded
[ ] Admin approved + Propfocus Integration pre-authorized
[ ] Consumer Key + integration username sent to Propfocus
[ ] aud / token URL = https://login.salesforce.com
[ ] Cert expiry recorded (365 days)

Verify
[ ] Admin Setup → Test Connection succeeds
[ ] Microsite / iframe / site visit / post visit work
[ ] Auto-open works if Auto_* statuses are set
[ ] Sales user can generate a microsite
[ ] Platform Event + inbound notification + write-back confirmed by Propfocus
```

---

## Troubleshooting

| Symptom                                                              | Fix                                                                                                                                     |
| -------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Install wizard is a sandbox org                                      | You used `test.salesforce.com` or were already logged into UAT. Log out, log into production, reopen the install URL.                   |
| Upgrade not offered                                                  | Org is on a **beta**, or the package is not installed. Betas cannot upgrade — uninstall first (destructive) or do a first-time install. |
| Buttons missing on Lead / Opportunity                                | Phase 4.6 / 4.7 — add LWC **and Activate**. Confirm Show Site Visit / Show Post Visit Button.                                           |
| Test Connection fails                                                | Phase 4.1 Client Id/Secret + token URL `propfocus.in`; Phase 3 production Organization Id.                                              |
| Admin works, sales user cannot generate links                        | Assign **Propfocus User** + **Propfocus Callout Access**; user must log out/in.                                                         |
| "don't have read permissions on the User External Credential object" | Phase 2.3 local Callout Access set.                                                                                                     |
| Iframe blank                                                         | CSP `https://propfocus.in` + Embed Base Url; hard-refresh.                                                                              |
| 403 Organization ID mismatch                                         | Config Organization Id ≠ Propfocus production org. Do not leave the UAT UUID in prod.                                                   |
| `invalid_grant` on JWT                                               | Phase 6.6 pre-authorize integration user; or wrong `aud` (must be login.salesforce.com); or cert/key mismatch / expiry.                 |
| Auto-open does nothing                                               | Status value must match Config **exactly** (including spaces). Link must not already exist. Panel must be on the page.                  |
| Site Visit Scheduled Status not applied                              | Value must be a valid picklist entry on the mapped status field.                                                                        |
| Write-back / inbound 400 on fields                                   | Phase 3.3 integration user FLS.                                                                                                         |

More: [SETUP_GUIDE.md](./SETUP_GUIDE.md) troubleshooting · [FAQ.txt](./FAQ.txt).

---

## Rollback

Managed packages do not downgrade.

- **Config toggles first** — blank an `Auto_*` field to disable auto-open; uncheck Show Site/Post Visit Button.
- **Fix-forward** — Propfocus builds and promotes a new Released version; customer upgrades in place.
- **Uninstall** — last resort; deletes package data. Export Config and secrets first. Ask Propfocus to disable the Organization Id.

---

## Appendix A — Amberstone: copy from UAT

Use these **field API names** from Amberstone UAT (`uat2026`). They were validated there. **Do not copy** Organization Id, embed URL, Named Credential host, or JWT Consumer Key — production gets new values.

UAT itself is on beta `0.12.0.2`. Production should install Released **`0.12.0.3`**, then apply this Config.

| Config field                         | Copy from UAT                                                                                                                |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------- |
| API Named Credential                 | `Propfocus_API`                                                                                                              |
| Organization Id                      | **New production UUID from Propfocus** (UAT used a `dev` org id — do not reuse)                                              |
| Embed Base Url                       | `https://propfocus.in/embed/salesforce` (UAT is `dev.propfocus.in`)                                                          |
| Embed Uses Salesforce Lead Id        | true                                                                                                                         |
| Embed Uses Salesforce Opportunity Id | true                                                                                                                         |
| Show Copy Modal                      | true                                                                                                                         |
| Show Site Visit Button               | true                                                                                                                         |
| Show Post Visit Button               | true                                                                                                                         |
| Buyer Id Field                       | `Id`                                                                                                                         |
| Buyer Name Field                     | `Name`                                                                                                                       |
| Lead Status Field                    | `Status`                                                                                                                     |
| Project Field                        | `Project__r.Name`                                                                                                            |
| Lead Source Field                    | `LeadSource`                                                                                                                 |
| Opportunity Buyer Id Field           | `Id`                                                                                                                         |
| Opportunity Buyer Name Field         | `Name`                                                                                                                       |
| Opportunity Status Field             | `StageName`                                                                                                                  |
| Opportunity Project Field            | `Project__r.Name`                                                                                                            |
| Opportunity Lookup Field             | `Opportunity__c`                                                                                                             |
| Site Visit Object                    | `Visit__c`                                                                                                                   |
| Lead Lookup Field                    | `Lead__c`                                                                                                                    |
| Site Visit Status Field              | `Status__c`                                                                                                                  |
| Site Visit Project Field             | `Project__r.Name`                                                                                                            |
| Site Visit Datetime Field            | `SV_Confirmed_Date__c` _(confirm this is still the field UAT uses; a second Default row had `Site_Visit_Scheduled_Date__c`)_ |
| Site Visit Scheduled Status          | `Site Visit Planned/ Scheduled` _(must exist as a Lead/Opportunity status value in prod)_                                    |
| Auto Microsite Statuses              | `Contacted, Qualified, Not Connected`                                                                                        |
| Auto Site Visit Statuses             | `Site Visit Planned/ Scheduled`                                                                                              |
| Auto Post Visit Statuses             | `Converted, Cost Sheet Approved, Site Visit Done`                                                                            |

**Also in production (not copied from UAT):**

| Setting                                | Production                                |
| -------------------------------------- | ----------------------------------------- |
| Named Credential **Propfocus API** URL | `https://propfocus.in`                    |
| External Credential token URL          | `https://propfocus.in/api/oauth2/token`   |
| External Credential Client Id/Secret   | **production** credentials from Propfocus |
| CSP Trusted Site                       | `https://propfocus.in`                    |
| JWT token `aud`                        | `https://login.salesforce.com`            |
| External Client App                    | **New** in production                     |

If a mapping is blank in UAT, leave it blank in prod unless the business asks to fill it.

---

## Related documents

| Document                                     | Use when                                                   |
| -------------------------------------------- | ---------------------------------------------------------- |
| [RELEASE_PROCESS.md](./RELEASE_PROCESS.md)   | How versions are built, promoted, and installed            |
| [E2E_INSTALLATION.md](./E2E_INSTALLATION.md) | Generic new-org e2e (still lists an older package version) |
| [SETUP_GUIDE.md](./SETUP_GUIDE.md)           | Same setup with Hosachiguru examples                       |
| [JWT_SETUP.txt](./JWT_SETUP.txt)             | Full inbound JWT steps                                     |
| [FIELDS.md](./FIELDS.md)                     | Field API reference                                        |
| [INBOUND.md](./INBOUND.md)                   | Inbound REST payloads                                      |
| [OUTBOUND.md](./OUTBOUND.md)                 | Outbound payloads                                          |
| [FAQ.txt](./FAQ.txt)                         | Upgrades, uninstall, common Q&A                            |
