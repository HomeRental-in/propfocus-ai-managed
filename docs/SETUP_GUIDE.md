# Propfocus AI — Setup & Test Guide

**Audience:** Salesforce admin + sales test user + Propfocus backend team  
**Time:** ~45–60 minutes for first-time setup and smoke tests  
**Example org (Hosachiguru sandbox):** `https://hosachiguru--consultefy.sandbox.my.salesforce.com`

---

## Before you start

### What you need

| Item                                          | Where you get it                    |
| --------------------------------------------- | ----------------------------------- |
| Salesforce admin login                        | Your IT / Salesforce admin          |
| Propfocus **Organization Id**                 | Propfocus team                      |
| OAuth **Client Id** + **Client Secret**       | Propfocus team                      |
| A Lead record with **Enquiry Ref No.** filled | Your sandbox data                   |
| Sales test user login                         | Admin creates or uses existing user |

### Two paths

| Path                                  | When to use                                                    |
| ------------------------------------- | -------------------------------------------------------------- |
| **Path A — Existing sandbox**         | Package or code already deployed. Do **Part 2–4** only.        |
| **Path B — Fresh org (install link)** | Install the managed package first, then **Part 1 + Part 2–4**. |

**Managed package install link (v0.5.0-1):**

```
https://login.salesforce.com/packaging/installPackage.apexp?p0=04tdL000000iXWXQA2
```

---

## Part 1 — Install package (Path B only)

| Step | Where                             | What to do                                                     | What to check                                                          |
| ---- | --------------------------------- | -------------------------------------------------------------- | ---------------------------------------------------------------------- |
| 1.0  | Setup → **Object Manager → Lead** | **Set History Tracking** → enable (e.g. **Status**) → **Save** | Required; without this, install fails with `Lead.FieldHistoryTracking` |
| 1.1  | Install URL (above)               | Log in as admin → **Install for Admins Only** → Install        | No errors                                                              |
| 1.2  | Setup → **Installed Packages**    |                                                                | **Propfocus AI** version **0.5.0.1** listed                            |

---

## Part 2 — Post-install setup

### 2.1 Assign permission sets

**Sales / test user:** **Propfocus User** + **Propfocus AI Admin**  
**Integration user:** **Propfocus Integration** (e.g. `propfocus.integration@yourcompany.com`, Minimum Access profile)

| Step | Action                                                                                |
| ---- | ------------------------------------------------------------------------------------- |
| 2.1a | Setup → Permission Sets → **Propfocus User** → Manage Assignments → assign sales user |
| 2.1b | Repeat for **Propfocus AI Admin** → assign admin user                                 |
| 2.1c | Create or select integration user                                                     |
| 2.1d | Assign **Propfocus Integration** to integration user                                  |

### 2.2 Configure Propfocus Config

**Where:** Setup → **Custom Metadata Types → Propfocus Config** (namespace **PropfocusAI**) → **Default → Edit**

If Edit shows only Label/Name, add a **Page Layout** first (Page Layouts → New → drag all fields → Save).

#### Hosachiguru sandbox values

| Config field                  | Value                                       |
| ----------------------------- | ------------------------------------------- |
| API Named Credential          | `Propfocus_API`                             |
| Organization Id               | _(from Propfocus team)_                     |
| Embed Base Url                | `https://dev.propfocus.in/embed/salesforce` |
| Embed Uses Salesforce Lead Id | **Checked**                                 |
| OAuth Token Url               | `https://dev.propfocus.in/api/oauth2/token` |
| OAuth Grant Type              | `client_credentials`                        |
| OAuth Client Id / Secret      | _(from Propfocus team)_                     |
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
| Site Visit Status Field       | `Status__c`                                 |
| Site Visit Project Field      | `Project_Interested__c`                     |
| Site Visit Type Field         | `sv_type__c`                                |
| Site Visit Datetime Field     | `Site_Visit_Date__c`                        |
| Site Visit Team Field         | `Sv_Team__c`                                |

> **Other orgs:** See [FIELDS.md](./FIELDS.md) for field API names.

### 2.3 Integration user field access

Grant **Read + Edit** on every mapped Lead field to the integration user (Permission Set → Object Settings → Lead).

### 2.4 Named Credential

Setup → **Named Credentials → Propfocus API** → URL = `https://dev.propfocus.in`

### 2.5 CSP Trusted Site

Setup → **CSP Trusted Sites → New** → URL `https://dev.propfocus.in`, Active, **frame-src** enabled. Hard-refresh browser (Ctrl+F5).

### 2.6 Admin Setup tab

Setup → **App Manager** → your app → Edit → add **propfocusAI Admin Setup** to navigation.

### 2.7 Lead record page

Lead record → gear → **Edit Page** → add **propfocusLeadLinkGen** → Save → Activate.

---

## Part 3 — Admin verification

App → **propfocusAI Admin Setup**

| Step | Check                        | Pass? |
| ---- | ---------------------------- | ----- |
| 3.1  | Page loads                   | ☐     |
| 3.2  | Inbound REST URL shown       | ☐     |
| 3.3  | **Test Connection** succeeds | ☐     |

Copy the Inbound REST URL for the Propfocus backend team.

---

## Part 4 — Feature tests (sales user)

Use a Lead with **Enquiry Ref No.** populated. Mark Pass / Fail.

| #   | Test                      | Do                                 | Check                                   | Pass? |
| --- | ------------------------- | ---------------------------------- | --------------------------------------- | ----- |
| 1   | Generate Microsite        | Click button → select project      | `Propfocus_Link__c` populated; no error | ☐     |
| 2   | Buyer Insights iframe     | After microsite                    | Iframe loads (not blank)                | ☐     |
| 3   | Confirm Site Visit        | Click button                       | `Propfocus_Site_Visit__c` has URL       | ☐     |
| 4   | Notification              | Propfocus POSTs to inbound REST    | Lead owner bell notification            | ☐     |
| 5   | SF → Propfocus sync       | Change Lead Status → Save          | Propfocus receives Platform Event       | ☐     |
| 6   | Propfocus → SF write-back | Propfocus POSTs write-back payload | Lead + child records update             | ☐     |

Payload format: [INBOUND.md](./INBOUND.md)

---

## Part 5 — Propfocus backend checklist

| #   | Task                                      |
| --- | ----------------------------------------- |
| 5.1 | Register Salesforce org (Organization Id) |
| 5.2 | OAuth credentials in Salesforce Config    |
| 5.3 | Inbound REST URL from Admin Setup         |
| 5.4 | Subscribe to `Propfocus_Lead_Event__e`    |
| 5.5 | Connected App OAuth for inbound REST      |

---

## Part 6 — Results summary

| #   | Test                      | Pass / Fail | Notes |
| --- | ------------------------- | ----------- | ----- |
| 1   | Admin — Test Connection   |             |       |
| 2   | Generate Microsite        |             |       |
| 3   | Buyer Insights iframe     |             |       |
| 4   | Confirm Site Visit        |             |       |
| 5   | Notification              |             |       |
| 6   | SF → Propfocus sync       |             |       |
| 7   | Propfocus → SF write-back |             |       |

**Tested by:** ******\_\_\_****** **Date:** ******\_\_\_******

---

## Troubleshooting

| Symptom                      | Fix                                                        |
| ---------------------------- | ---------------------------------------------------------- |
| Buttons not visible          | Part 2.7 — add `propfocusLeadLinkGen`                      |
| Insufficient privileges      | Part 2.1 — permission sets                                 |
| API / OAuth errors           | Part 2.2, 2.4; verify Propfocus credentials                |
| Iframe blank                 | Part 2.5 CSP + Embed Base Url                              |
| Write-back fails             | Part 2.3 integration user FLS                              |
| No Lead found for buyer_id   | `buyer_id` must match Buyer Id Field on Lead               |
| 403 Organization ID mismatch | Organization Id in Config                                  |
| OAuth fields greyed out      | Upgrade package to **0.1.0-2+** — see [FAQ.txt](./FAQ.txt) |

---

## Related documents

| Document                                                               | Purpose                         |
| ---------------------------------------------------------------------- | ------------------------------- |
| [FAQ.txt](./FAQ.txt)                                                   | FAQ + package upgrade           |
| [FIELDS.md](./FIELDS.md)                                               | Field API reference             |
| [INBOUND.md](./INBOUND.md)                                             | REST API + auth + Postman fixes |
| [../propfocus-admin-setup-guide.md](../propfocus-admin-setup-guide.md) | Short admin checklist           |
