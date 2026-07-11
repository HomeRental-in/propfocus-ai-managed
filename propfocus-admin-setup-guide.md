# Propfocus Salesforce Setup Guide

**Full walkthrough:** [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)

Short reference below. The setup guide has navigation paths, field values, pass/fail checks, and troubleshooting.

---

## Quick links

| Item                    | Value                                                                                          |
| ----------------------- | ---------------------------------------------------------------------------------------------- |
| **Install link**        | `https://login.salesforce.com/packaging/installPackage.apexp?p0=04tdL000000iXWXQA2` (v0.5.0-1) |
| **Hosachiguru sandbox** | `https://hosachiguru--consultefy.sandbox.my.salesforce.com`                                    |
| **Organization Id**     | _(from Propfocus team)_                                                                        |
| **API base (dev)**      | `https://dev.propfocus.in`                                                                     |

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

> Integration user needs **Read/Edit** on all mapped Lead fields.

---

## 5) CSP Trusted Site

**Setup → CSP Trusted Sites → New** → URL `https://dev.propfocus.in`

---

## 6) Named Credential

**Setup → Named Credentials → Propfocus API** → URL `https://dev.propfocus.in`

---

## 7) OAuth (outbound API)

In **Propfocus Config → Default**: Token URL, Grant Type `client_credentials`, Client Id/Secret from Propfocus team.

**Check:** Admin Setup → **Test Connection** succeeds.

---

## 8) Permission sets

| Permission set            | Who                             |
| ------------------------- | ------------------------------- |
| **Propfocus User**        | Sales reps                      |
| **Propfocus AI Admin**    | Admins                          |
| **Propfocus Integration** | Integration user (inbound REST) |

---

## 9) Test

1. Admin Setup → **Test Connection**
2. Lead → **Generate Microsite** / **Confirm Site Visit**
3. Verify iframe
4. Propfocus backend: sync + write-back + notifications

Full test matrix: [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)
