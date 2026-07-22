# Propfocus AI — Setup & Test Guide

**Audience:** Salesforce admin + sales test user + Propfocus backend team  
**Time:** Demo org click-path ~1–2 hours; enterprise (change control + JWT + pipeline) plan days — see [E2E_INSTALLATION.md](./E2E_INSTALLATION.md)  
**Example org (Hosachiguru sandbox):** `https://hosachiguru--consultefy.sandbox.my.salesforce.com`

---

## Before you start

### What you need

| Item                                          | Where you get it                    |
| --------------------------------------------- | ----------------------------------- |
| Salesforce admin login                        | Your IT / Salesforce admin          |
| Propfocus **Organization Id**                 | Propfocus team                      |
| Outbound **Client Id** + **Client Secret**    | Propfocus team — **External Credential** (Part 2.4), not Config |
| A Lead (and/or Opportunity) with buyer id filled | Your sandbox data                   |
| Sales test user login                         | Admin creates or uses existing user |

### Two paths

| Path                                  | When to use                                                    |
| ------------------------------------- | -------------------------------------------------------------- |
| **Path A — Existing sandbox**         | Package or code already deployed. Do **Part 2–4** only.        |
| **Path B — Fresh org (install link)** | Install the managed package first, then **Part 1 + Part 2–4**. |

**Managed package install link (v0.7.0-2):**

```
https://login.salesforce.com/packaging/installPackage.apexp?p0=04tdL000000kNpdQAE
```

---

## Part 1 — Install package (Path B only)

| Step | Where                          | What to do                                              | What to check                               |
| ---- | ------------------------------ | ------------------------------------------------------- | ------------------------------------------- |
| 1.1  | Install URL (above)            | Log in as admin → **Install for Admins Only** → Install | No errors                                   |
| 1.2  | Setup → **Installed Packages** |                                                         | **Propfocus AI** version **0.7.0.2** listed |

---

## Part 2 — Post-install setup

### 2.1 Assign permission sets

**Sales / test user:** **Propfocus User** + local **Propfocus Callout Access** (required — see 2.1e)  
**Admin:** **Propfocus AI Admin** (System Admin profiles usually already have User External Credentials Read)  
**Integration user:** **Propfocus Integration** (e.g. `propfocus.integration@yourcompany.com`, Minimum Access profile)

| Step | Action                                                                                |
| ---- | ------------------------------------------------------------------------------------- |
| 2.1a | Setup → Permission Sets → **Propfocus User** → Manage Assignments → assign sales user |
| 2.1b | Repeat for **Propfocus AI Admin** → assign admin user                                 |
| 2.1c | Create or select integration user                                                     |
| 2.1d | Assign **Propfocus Integration** to integration user                                  |
| 2.1e | Create and assign local **Propfocus Callout Access** (below) — required for sales users |

#### 2.1e Local permission set — Propfocus Callout Access (required for sales users)

Salesforce strips **User External Credentials** object Read from **managed** permission sets. Packaged **Propfocus User** alone is not enough for most sales profiles. Do this once per org:

| Step | Action |
| ---- | ------ |
| 1 | Setup → **Permission Sets** → **New** → Label: `Propfocus Callout Access` → Save |
| 2 | Open that permission set → **Object Settings** → **User External Credentials** → enable **Read** → Save |
| 3 | Same permission set → **External Credential Principal Access** → enable **Propfocus API — Propfocus Principal** (packaged under namespace PropfocusAI) → Save. *(Optional if users already have packaged Propfocus User, which includes principal access; still recommended so one local set is complete.)* |
| 4 | **Manage Assignments** → **Add Assignments** → select every sales user who creates Propfocus links (they must also have **Propfocus User**) |
| 5 | Users must **log out and log back in** so the object permission takes effect |

Without this, sales users often see empty Projects or: *You don't have read permissions on the User External Credential object.*

### 2.2 Configure Propfocus Config

**Where:** Setup → **Custom Metadata Types → Propfocus Config** (namespace **PropfocusAI**) → **Default → Edit**

If Edit shows only Label/Name, **or Opportunity fields are missing**, edit the page layout first:

1. Setup → Custom Metadata Types → **Propfocus Config** → **Page Layouts** → **Propfocus Config Layout** (or New)
2. Drag all **Opportunity_*** fields (and **Opportunity Lookup Field**, **Embed Uses Salesforce Opportunity Id**) onto the layout → Save
3. Re-open **Default → Edit** — Opportunity section should appear

#### Hosachiguru sandbox values

| Config field                  | Value                                       |
| ----------------------------- | ------------------------------------------- |
| API Named Credential          | `Propfocus_API`                             |
| Organization Id               | _(from Propfocus team)_                     |
| Embed Base Url                | `https://dev.propfocus.in/embed/salesforce` _(sandbox override; production default is `https://propfocus.in/embed/salesforce`)_ |
| Embed Uses Salesforce Lead Id | **Checked**                                 |
| Buyer Id Field                | `Enquiry_Ref_No__c`                         |
| Buyer Name Field              | `Full_Name__c`                              |
| Lead Status Field             | `Status`                                    |
| Project Field                 | `Project_Interested__c`                     |
| Lead Source Field             | `LeadSource`                                |
| Pre Sales Rep Source Field    | `Presales_Owner__c`                         |
| Pre-Sales Owner Name Field    | `Presales_Owner__c`                         |
| Sales Owner Name Field        | `Sales_Person__c`                           |
| Sales Owner Phone Field       | `Mobile_Phone__c`                           |
| Site Visit Object             | `Site_Visit__c`                             |
| Lead Lookup Field             | `Lead__c`                                   |
| Opportunity Lookup Field      | `Opportunity__c`                            |
| Opportunity Buyer Name Field  | `Name`                                      |
| Opportunity Status Field      | `StageName`                                 |
| Opportunity Buyer Id Field    | _(org-specific buyer / enquiry ref)_        |
| Opportunity Project Field     | _(org-specific project field)_              |
| Embed Uses Salesforce Opportunity Id | **Checked**                          |
| Site Visit Status Field       | `Status__c`                                 |
| Site Visit Project Field      | `Project_Interested__c`                     |
| Site Visit Type Field         | `sv_type__c`                                |
| Site Visit Datetime Field     | `Site_Visit_Date__c`                        |
| Site Visit Team Field         | `Sv_Team__c`                                |
| Site Visit Manager Name Field | _(optional — org field for SV manager name)_ |
| Site Visit Manager Phone Field | _(optional)_                               |
| Site Visit Manager Email Field | _(optional)_                              |

> **Other orgs:** See [FIELDS.md](./FIELDS.md) for Lead and Opportunity field API names.

### 2.3 Integration user field access

Grant **Read + Edit** on every mapped Lead field to the integration user (Permission Set → Object Settings → Lead).  
If using Opportunity site visits / write-back, also grant **Read + Edit** on mapped **Opportunity** fields.

### 2.4 Outbound auth (External Credential + Named Credential)

Client Id and Client Secret are **not** stored in Propfocus Config. Configure the packaged External Credential after install.

| Step | Where | Action |
| ---- | ----- | ------ |
| 2.4a | Setup → Named Credentials → **External Credentials → Propfocus API** | Protocol: OAuth 2.0 · Flow: Client Credentials with Client Secret · Token URL: `https://propfocus.in/api/oauth2/token` (sandbox: `https://dev.propfocus.in/api/oauth2/token`) |
| 2.4b | Same → **Propfocus Principal** | Enter Client Id + Client Secret → Save |
| 2.4c | Setup → Named Credentials → **Propfocus API** | URL = `https://propfocus.in` (sandbox: `https://dev.propfocus.in`) · External Credential linked · **Generate Authorization Header** enabled |
| 2.4d | Permission sets **Propfocus User** + **Propfocus AI Admin** | Confirm **External Credential Principal Access** includes `Propfocus API — Propfocus Principal` (packaged) |

> **Upgrading from 0.5.0-1 or earlier:** Copy Client Id/Secret from old Config OAuth fields into the External Credential principal **before** upgrading. See [FAQ.txt](./FAQ.txt).

### 2.5 CSP Trusted Site

Setup → **CSP Trusted Sites** → confirm `https://propfocus.in` is Active with **frame-src** enabled (packaged default). Sandboxes: change to `https://dev.propfocus.in`. Hard-refresh browser (Ctrl+F5).

### 2.6 Admin Setup tab

Setup → **App Manager** → your app → Edit → add **propfocusAI Admin Setup** to navigation.

### 2.7 Lead / Opportunity record page

The same LWC (`propfocusLeadLinkGen`) is used on both objects.

| Step | Action |
| ---- | ------ |
| 2.7a | Lead record → gear → **Edit Page** → add **propfocusLeadLinkGen** → Save → Activate |
| 2.7b | Opportunity record → gear → **Edit Page** → add **propfocusLeadLinkGen** → Save → Activate |

Ensure Opportunity Config mappings from section 2.2 are filled before testing on Opportunity.

### 2.8 Auto site visit link on Site Visit Save (optional)

The package does **not** own your Site Visit object or “New Site Visit” modal. Saving a Site Visit only creates the customer record unless you wire a **subscriber Flow**.

**What the package provides:** Apex invocable **Generate Propfocus Site Visit Link From Record** (`PropFocusSiteVisitLinkService`). It reads **only Propfocus Config** field maps (object, Lead/Opportunity lookups, project, datetime, optional manager name/phone/email), then enqueues a callout so Save is not blocked. The link is written to the parent Lead or Opportunity `Propfocus_Site_Visit__c` (same outcome as panel **Confirm Site Visit**).

**Prerequisites before the Flow will succeed**

- Config: Site Visit Object, Project Field, Datetime Field, Lead and/or Opportunity Lookup Field
- Optional Config: Site Visit Manager Name / Phone / Email Field (sent as `siteVisitManager` when filled)
- Parent Lead/Opportunity has **buyer id** populated
- Running user has **Propfocus User** + **Propfocus Callout Access** (Part 2.1 / 2.1e) and External Credential is configured (Part 2.4)
- Project value on the Site Visit must match a **Propfocus** project name (not only a Salesforce picklist label that Propfocus does not know)

#### Wire the Flow (once per org)

| Step | Action |
| ---- | ------ |
| 2.8a | Setup → **Flows** → **New** → **Record-Triggered Flow** |
| 2.8b | **Object** = your Site Visit object (same API name as Config → **Site Visit Object**, e.g. `Site_Visit__c`) |
| 2.8c | **Trigger** = **A record is created** (add **updated** only if you want regenerates on edit) · **Optimize for** = **Actions and Related Records** |
| 2.8d | Add element → **Action** → search Apex **Generate Propfocus Site Visit Link From Record** |
| 2.8e | Input **Site Visit Record Id** → open the resource picker → **`$Record` → `Id`** (inserts `{!$Record.Id}`). Do not paste a hard-coded Id — `$Record` is the Site Visit that just saved. |
| 2.8f | **Save** → **Activate** |

#### Verify

1. Create a Site Visit with Project + Datetime filled (project name known to Propfocus)
2. Shortly after Save, parent Lead/Opportunity **Propfocus_Site_Visit__c** and History show the new site visit link
3. If nothing appears: Setup → **Flows** → open the Flow → **View Run** / debug; confirm Config maps and Callout Access; check that the project name exists in Propfocus

---

## Part 3 — Admin verification

App → **propfocusAI Admin Setup**

| Step | Check                        | Pass? |
| ---- | ---------------------------- | ----- |
| 3.1  | Page loads                   | ☐     |
| 3.2  | Inbound REST URL shown       | ☐     |
| 3.3  | **Test Connection** succeeds | ☐     |
| 3.4  | Opportunity field mappings shown | ☐     |

Copy the Inbound REST URL for the Propfocus backend team.

---

## Part 4 — Feature tests (sales user)

Use a Lead with buyer id populated, then repeat site-visit tests on an Opportunity with Opportunity buyer id populated. Mark Pass / Fail.

| #   | Test                      | Do                                 | Check                                   | Pass? |
| --- | ------------------------- | ---------------------------------- | --------------------------------------- | ----- |
| 1   | Generate Microsite (Lead) | Lead → Generate Microsite          | `Propfocus_Link__c` populated; no error | ☐     |
| 2   | Buyer Insights iframe     | After microsite                    | Iframe loads (not blank)                | ☐     |
| 3   | Confirm Site Visit (Lead) | Lead → Confirm Site Visit          | Lead `Propfocus_Site_Visit__c` has URL  | ☐     |
| 4   | Confirm Site Visit (Opp)  | Opportunity → Confirm Site Visit   | Opp `Propfocus_Site_Visit__c` has URL; history on Opportunity | ☐     |
| 5   | Notification              | Propfocus POSTs to inbound REST    | Lead or Opportunity owner bell notification | ☐     |
| 6   | SF → Propfocus sync       | Change Lead Status → Save          | Propfocus receives Platform Event       | ☐     |
| 7   | Propfocus → SF write-back | Propfocus POSTs write-back payload | Parent + child records update (Lead or Opportunity) | ☐     |

Payload format: [INBOUND.md](./INBOUND.md)  
Outbound identity: Lead sends `salesforce_lead_id`; Opportunity sends `salesforce_opportunity_id` — see [OUTBOUND.md](./OUTBOUND.md).

---

## Part 5 — Propfocus backend checklist

| #   | Task                                      |
| --- | ----------------------------------------- |
| 5.1 | Register Salesforce org (Organization Id) |
| 5.2 | Client Id/Secret in External Credential principal |
| 5.3 | Inbound REST URL from Admin Setup         |
| 5.4 | Subscribe to `Propfocus_Lead_Event__e`    |
| 5.5 | Connected App OAuth for inbound REST      |

---

## Part 6 — Results summary

| #   | Test                      | Pass / Fail | Notes |
| --- | ------------------------- | ----------- | ----- |
| 1   | Admin — Test Connection   |             |       |
| 2   | Generate Microsite (Lead) |             |       |
| 3   | Buyer Insights iframe     |             |       |
| 4   | Confirm Site Visit (Lead) |             |       |
| 5   | Confirm Site Visit (Opp)  |             |       |
| 6   | Notification              |             |       |
| 7   | SF → Propfocus sync       |             |       |
| 8   | Propfocus → SF write-back |             |       |

**Tested by:** ******\_\_\_****** **Date:** ******\_\_\_******

---

## Troubleshooting

| Symptom                      | Fix                                                        |
| ---------------------------- | ---------------------------------------------------------- |
| Buttons not visible          | Part 2.7 — add `propfocusLeadLinkGen` on Lead **and** Opportunity pages |
| Insufficient privileges      | Part 2.1 — permission sets                                 |
| API / OAuth errors           | Part 2.2, 2.4; verify External Credential Client Id/Secret |
| Iframe blank                 | Part 2.5 CSP + Embed Base Url                              |
| Write-back fails             | Part 2.3 integration user FLS (Lead and/or Opportunity)   |
| No Lead/Opportunity for buyer_id | `buyer_id` must match mapped Buyer Id on Lead or Opportunity |
| Opportunity buttons fail     | Part 2.2 Opportunity mappings + buyer id populated         |
| 403 Organization ID mismatch | Organization Id in Config                                  |
| Outbound auth not configured | Part 2.4 — External Credential → Propfocus Principal |
| Callout unauthorized for sales user | Part 2.1a + **2.1e** + 2.4d — **Propfocus User** + local **Propfocus Callout Access** |
| "don't have read permissions on the User External Credential object" | Part **2.1e** — local permission set with Read on **User External Credentials**; users must log out/in |
| Site Visit Save creates SV but no Propfocus link | Part **2.8** — activate Record-Triggered Flow; project name must exist in Propfocus; Callout Access + buyer id |

---

## Related documents

| Document                                                               | Purpose                         |
| ---------------------------------------------------------------------- | ------------------------------- |
| [FAQ.txt](./FAQ.txt)                                                   | FAQ + package upgrade           |
| [FIELDS.md](./FIELDS.md)                                               | Field API reference             |
| [OUTBOUND.md](./OUTBOUND.md)                                           | Outbound payloads + PII         |
| [INBOUND.md](./INBOUND.md)                                             | REST API + auth + Postman fixes |
| [E2E_INSTALLATION.md](./E2E_INSTALLATION.md)                           | Full e2e + upgrade / uninstall  |
| [../propfocus-admin-setup-guide.md](../propfocus-admin-setup-guide.md) | Short admin checklist           |
