# Propfocus Salesforce Setup Guide

**New org (complete e2e):** [docs/E2E_INSTALLATION.md](docs/E2E_INSTALLATION.md)  
**Full walkthrough:** [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)

Short reference below. The setup guide has navigation paths, field values, pass/fail checks, and troubleshooting.

> **Security:** Outbound Client Id/Secret go in **External Credential** (encrypted), not Propfocus Config or change sets.

---

## Quick links

| Item                    | Value                                                                                          |
| ----------------------- | ---------------------------------------------------------------------------------------------- |
| **Install link**        | `https://login.salesforce.com/packaging/installPackage.apexp?p0=04tdL000000lEh3QAE` (v0.10.0-1) |
| **Hosachiguru sandbox** | `https://hosachiguru--consultefy.sandbox.my.salesforce.com`                                    |
| **Organization Id**     | _(from Propfocus team)_                                                                        |
| **API base (production)** | `https://propfocus.in`                                                                         |
| **API base (sandbox)**    | `https://dev.propfocus.in`                                                                     |

---

## 1) Show the Admin Tab in the App

1. **Setup → App Manager** → your app → **Edit → Navigation Items**
2. Add **propfocusAI Admin Setup** → **Save**

---

## 2) Add Propfocus panel to Lead and Opportunity pages

The same component (`propfocusLeadLinkGen`) is used on both objects.

1. Lead record → gear → **Edit Page** → add **propfocusLeadLinkGen** → **Save → Activate**
2. Opportunity record → gear → **Edit Page** → add **propfocusLeadLinkGen** → **Save → Activate**

---

## 3) Custom Metadata page layout (if fields missing)

**Setup → Custom Metadata Types → Propfocus Config → Page Layouts → Edit** → add all fields (including Opportunity mappings) → Save

---

## 4) Configure Propfocus Config → Default

**Setup → Custom Metadata Types → Propfocus Config → Manage → Default → Edit**

Field values: [docs/FIELDS.md](docs/FIELDS.md) or [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md) section 2.2.  
Configure **Lead** mappings and, if using the Opportunity panel, **Opportunity** mappings (`Opportunity Buyer Id/Name/Status/Project`, `Opportunity Lookup Field`).  
Optional UI: **Show Site Visit Button** / **Show Post Visit Button** (both default on) control Confirm Site Visit and Generate Post Visit on the panel.  
OAuth credentials are **not** Config fields — see step 6.

> Integration user needs **Read/Edit** on all mapped Lead and Opportunity fields.

---

## 5) CSP Trusted Site

**Setup → CSP Trusted Sites** → confirm `https://propfocus.in` (production default). Sandboxes: the dev host is **not** packaged — manually create a new CSP Trusted Site for `https://dev.propfocus.in` (Active, context All, frame-src + connect-src enabled).

---

## 6) Outbound API auth (External Credential)

**Setup → Named Credentials → External Credentials → Propfocus API**

1. Confirm token endpoint: `https://propfocus.in/api/oauth2/token` (sandbox: `https://dev.propfocus.in/api/oauth2/token`)
2. Open **Propfocus Principal** → enter Client Id + Client Secret from Propfocus team → Save
3. **Setup → Named Credentials → Propfocus API** → confirm URL `https://propfocus.in` (sandbox: `https://dev.propfocus.in`) and **Generate Authorization Header** enabled
4. Confirm **Propfocus User** and **Propfocus AI Admin** permission sets include External Credential principal access (packaged)
5. Create local **Propfocus Callout Access** (UEC Read) and assign to sales users — [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md) §2.1e; users must log out/in

**Check:** Admin Setup → **Test Connection** succeeds. Sales user can load Projects / generate links.

---

## 7) Permission sets

| Permission set                 | Who                             |
| ------------------------------ | ------------------------------- |
| **Propfocus User**             | Sales reps                      |
| **Propfocus Callout Access** (local) | Sales reps — required; see SETUP_GUIDE §2.1e |
| **Propfocus AI Admin**         | Admins                          |
| **Propfocus Integration**      | Integration user (inbound REST) |

---

## 7b) Optional — auto site visit link on Save

Record-Triggered Flow on your Site Visit object → Apex **Generate Propfocus Site Visit Link From Record** → **Site Visit Record Id** = `{!$Record.Id}`.  
Full steps: [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md) §2.8

---

## 8) Test

1. Admin Setup → **Test Connection**
2. Lead → **Generate Microsite** / **Confirm Site Visit**
3. Opportunity → **Confirm Site Visit** (and microsite/post-visit if used)
4. (If Flow wired) Create Site Visit → parent gets Propfocus site visit link
5. Verify iframe / history on each parent
6. Propfocus backend: sync + write-back + notifications (Lead or Opportunity)

Full test matrix: [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)
