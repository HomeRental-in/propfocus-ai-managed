# Developer Guide

Project overview, CLI setup, Dev Hub packaging, and definition of done.

---

## Project summary

Build a **managed package** (`PropfocusAI` namespace) connecting Salesforce Leads to Propfocus:

1. Microsite + site visit buttons on Lead records
2. Buyer Insights iframe embed
3. Bell notifications (inbound REST)
4. Two-way sync (Platform Events + inbound write-back)

**Deliverables:** install link, all features verified, 75%+ Apex coverage, setup docs.

---

## Repository layout

| Path                      | Purpose                                              |
| ------------------------- | ---------------------------------------------------- |
| `force-app/main/default/` | Package source (Apex, LWC, objects, permission sets) |
| `docs/`                   | Setup guides, API specs, FAQs                        |
| `sfdx-project.json`       | 2GP package definition                               |
| `manifest/package.xml`    | Lead custom field dependency list                    |

---

## Salesforce CLI setup

```powershell
cd E:\propfocus-ai-managed

# Sandbox login
sf org login web --instance-url https://test.salesforce.com --alias hosachiguru-sandbox

sf org list
sf org display --target-org hosachiguru-sandbox
```

Deploy and test (development only — subscribers use the managed package):

```powershell
sf project deploy start --source-dir force-app --target-org hosachiguru-sandbox
sf apex run test --target-org hosachiguru-sandbox `
  --class-names PropFocusLeadServiceTest,PropfocusConfigServiceTest,PropfocusInboundServiceTest,PropfocusInboundWritebackServiceTest,PropfocusLeadEventServiceTest,PropfocusLeadTrackingServiceTest,PropfocusOAuthServiceTest `
  --code-coverage --result-format human --wait 30
```

---

## Dev Hub & managed package

The package **cannot be published** without a Dev Hub org (Partner Business Org or Developer Edition with Dev Hub enabled).

**Namespace:** `PropfocusAI` — must match `sfdx-project.json`.

### Create package version

```powershell
sf org login web --instance-url https://login.salesforce.com --alias propfocus-devhub

sf package version create `
  --package "Propfocus AI" `
  --installation-key-bypass `
  --wait 30 `
  --target-dev-hub propfocus-devhub `
  --code-coverage

sf package version promote --package "Propfocus AI@<version>" --target-dev-hub propfocus-devhub

sf package version report --target-dev-hub propfocus-devhub
```

Share the **Installation URL** with subscribers. Upgrade steps: [FAQ.txt](./FAQ.txt).

### Dev Hub checklist

| #   | Task                                          | Done? |
| --- | --------------------------------------------- | ----- |
| 1   | Dev Hub org available                         | ☐     |
| 2   | Namespace `PropfocusAI` registered and linked | ☐     |
| 3   | Package version built (75%+ coverage)         | ☐     |
| 4   | Promoted to Released                          | ☐     |
| 5   | Install link generated                        | ☐     |
| 6   | Clean install tested in fresh org             | ☐     |

See [DEV_HUB_SETUP.md](./DEV_HUB_SETUP.md) for detailed Dev Hub steps (namespace linking, PBO vs DE).

---

## Definition of done

| Area         | Requirement                                              |
| ------------ | -------------------------------------------------------- |
| **Deploy**   | Code deploys; 43/43 Propfocus tests pass                 |
| **Config**   | Propfocus Config, permission sets, CSP, Named Credential |
| **Features** | All 5 capabilities + write-back verified                 |
| **Package**  | v0.4.0-1 Released; install link works in fresh org       |
| **Handoff**  | SETUP_GUIDE.md, FAQ.txt, INBOUND.md shared               |

Current status (2026-06-14):

```
Apex tests:     Pass (43/43 Propfocus test classes)
Package:        v0.4.0-1 Released
Install URL:    https://login.salesforce.com/packaging/installPackage.apexp?p0=04tdL000000dKWjQAM
Feature testing: Partial — verify with subscriber + Propfocus backend
```

---

## Trial run checklist (with subscriber)

| #   | Task                                                 |
| --- | ---------------------------------------------------- |
| 0.1 | Share install URL                                    |
| 0.2 | Subscriber enables Lead history                      |
| 0.3 | Package installed (0.4.0-1)                          |
| 1.x | Permission sets assigned                             |
| 2.x | Propfocus Config configured (see FIELDS.md)          |
| 3.x | CSP + Named Credential verified                      |
| 4.x | Lead component on page                               |
| 5.x | Test Connection + all feature tests (SETUP_GUIDE.md) |
| 6.x | Propfocus backend: Platform Events + inbound REST    |

---

## Security

- Never commit passwords, OAuth secrets, JWT keys, or access tokens.
- Internal templates live in `docs/internal/` (gitignored).
