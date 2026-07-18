# Propfocus AI Managed Package

Second-generation managed package (`PropfocusAI` namespace) connecting Salesforce Leads and Opportunities to Propfocus.

**Current version:** `0.5.0-1`  
**Install:** `https://login.salesforce.com/packaging/installPackage.apexp?p0=04tdL000000iXWXQA2`

---

## Quick start

| Role                  | Start here                                              |
| --------------------- | ------------------------------------------------------- |
| **New org install**   | [docs/E2E_INSTALLATION.md](docs/E2E_INSTALLATION.md)    |
| **Salesforce admin**  | [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)              |
| **Package upgrade**   | [docs/E2E_INSTALLATION.md](docs/E2E_INSTALLATION.md#upgrade-from-05x) · [docs/FAQ.txt](docs/FAQ.txt) |
| **Outbound / privacy**| [docs/OUTBOUND.md](docs/OUTBOUND.md)                    |
| **Propfocus backend** | [docs/INBOUND.md](docs/INBOUND.md)                      |
| **Developers (2GP)**  | [docs/DEV_GUIDE.md](docs/DEV_GUIDE.md)                  |
| **All documentation** | [docs/README.md](docs/README.md)                        |

Short checklist: [propfocus-admin-setup-guide.md](propfocus-admin-setup-guide.md)

---

## Repository layout

```
force-app/main/default/   Package source
docs/                     Setup guides, API specs, FAQs
propfocus-sf-jwt/         Local JWT helper (keys gitignored)
sfdx-project.json         2GP package definition
```

---

## Configure in subscriber org

### Propfocus Config (Custom Metadata)

**Setup → Custom Metadata Types → Propfocus Config → Default**

| Field | Value |
| ----- | ----- |
| `Api_Named_Credential__c` | `Propfocus_API` |
| `Organization_Id__c` | From Propfocus team |
| Embed URL + field mappings | See [docs/FIELDS.md](docs/FIELDS.md) |

### Outbound auth (External Credential — not in Config)

**Setup → Named Credentials → External Credentials → Propfocus API**

1. Token endpoint: `https://propfocus.in/api/oauth2/token`
2. **Propfocus Principal** → Client Id + Client Secret from Propfocus team

**Setup → Named Credentials → Propfocus API** → URL `https://propfocus.in`, Generate Authorization Header enabled.

**Sandboxes:** override URLs to `https://dev.propfocus.in` — see [docs/E2E_INSTALLATION.md](docs/E2E_INSTALLATION.md#sandbox--uat--point-at-dev).

Permission sets **Propfocus User** and **Propfocus AI Admin** include External Credential principal access (packaged).

### Other post-install

Permission sets, Lead/Opportunity page component (`propfocusLeadLinkGen`), CSP Trusted Site.

---

## Inbound REST

```
POST https://<your-org-host>/services/apexrest/PropfocusAI/propfocus/events/
Authorization: Bearer <salesforce_access_token>
```

Details: [docs/INBOUND.md](docs/INBOUND.md)

---

## Build new package version

```powershell
sf package version create --package "Propfocus AI" --installation-key-bypass `
  --wait 30 --target-dev-hub propfocus-devhub --code-coverage
sf package version promote --package "Propfocus AI@<version>" --target-dev-hub propfocus-devhub
```

Full steps: [docs/DEV_GUIDE.md](docs/DEV_GUIDE.md)

---

## Security

Never commit passwords, OAuth secrets, JWT private keys, or access tokens.
