# Propfocus Salesforce Setup Guide

**New org (complete e2e):** [docs/E2E_INSTALLATION.md](docs/E2E_INSTALLATION.md)  
**Full walkthrough:** [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)

Short reference below. The setup guide has navigation paths, field values, pass/fail checks, and troubleshooting.

> **Security:** Outbound Client Id/Secret go in **External Credential** (encrypted), not Propfocus Config or change sets.

---

## Quick links

| Item                    | Value                                                                                          |
| ----------------------- | ---------------------------------------------------------------------------------------------- |
| **Install link**        | `https://login.salesforce.com/packaging/installPackage.apexp?p0=04tdL000000iXWXQA2` (v0.5.0-1) |
| **Hosachiguru sandbox** | `https://hosachiguru--consultefy.sandbox.my.salesforce.com`                                    |
| **Organization Id**     | _(from Propfocus team)_                                                                        |
| **API base (production)** | `https://propfocus.in`                                                                         |
| **API base (sandbox)**    | `https://dev.propfocus.in`                                                                     |

---

## 1) Show the Admin Tab in the App

1. **Setup → App Manager** → your app → **Edit → Navigation Items**
2. Add **propfocusAI Admin Setup** → **Save**

---

## 2) Add Lead LWC to Lead Record Page

1. Lead record → gear → **Edit Page**
2. Add **propfocusLeadLinkGen** → **Save → Activate**

---

## 3) Custom Metadata page layout (if fields missing)

**Setup → Custom Metadata Types → Propfocus Config → Page Layouts → Edit** → add all fields → Save

---

## 4) Configure Propfocus Config → Default

**Setup → Custom Metadata Types → Propfocus Config → Manage → Default → Edit**

Field values: [docs/FIELDS.md](docs/FIELDS.md) or [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md) section 2.2.  
OAuth credentials are **not** Config fields — see step 6.

> Integration user needs **Read/Edit** on all mapped Lead fields.

---

## 5) CSP Trusted Site

**Setup → CSP Trusted Sites** → confirm `https://propfocus.in` (production default). Sandboxes: change to `https://dev.propfocus.in`.

---

## 6) Outbound API auth (External Credential)

**Setup → Named Credentials → External Credentials → Propfocus API**

1. Confirm token endpoint: `https://propfocus.in/api/oauth2/token` (sandbox: `https://dev.propfocus.in/api/oauth2/token`)
2. Open **Propfocus Principal** → enter Client Id + Client Secret from Propfocus team → Save
3. **Setup → Named Credentials → Propfocus API** → confirm URL `https://propfocus.in` (sandbox: `https://dev.propfocus.in`) and **Generate Authorization Header** enabled
4. Confirm **Propfocus User** and **Propfocus AI Admin** permission sets include External Credential principal access (packaged)

**Check:** Admin Setup → **Test Connection** succeeds.

---

## 7) Permission sets

| Permission set            | Who                             |
| ------------------------- | ------------------------------- |
| **Propfocus User**        | Sales reps                      |
| **Propfocus AI Admin**    | Admins                          |
| **Propfocus Integration** | Integration user (inbound REST) |

---

## 8) Test

1. Admin Setup → **Test Connection**
2. Lead → **Generate Microsite** / **Confirm Site Visit**
3. Verify iframe
4. Propfocus backend: sync + write-back + notifications

Full test matrix: [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)
