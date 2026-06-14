# Propfocus AI Managed Package

Second-generation managed package (`PropfocusAI` namespace) connecting Salesforce Leads to Propfocus.

**Current version:** `0.4.0-1`  
**Install:** `https://login.salesforce.com/packaging/installPackage.apexp?p0=04tdL000000dKWjQAM`

---

## Quick start

| Role                  | Start here                                              |
| --------------------- | ------------------------------------------------------- |
| **Salesforce admin**  | [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)              |
| **Package upgrade**   | [docs/FAQ.txt](docs/FAQ.txt) (Package Upgrades section) |
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

Edit **Setup → Custom Metadata Types → Propfocus Config → Default**:

- `Api_Named_Credential__c` = `Propfocus_API`
- `Organization_Id__c`, OAuth fields, Embed URL — from Propfocus team
- Field mappings — see [docs/FIELDS.md](docs/FIELDS.md)

Post-install: permission sets, Lead page component, CSP Trusted Site, Named Credential.

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
