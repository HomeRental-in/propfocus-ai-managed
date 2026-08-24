# Release Process — Development → Production

How Propfocus AI (2GP managed package, namespace `PropfocusAI`) goes from source
to a customer's production org, and how to deploy/onboard a production org.

```
develop → validate → build version (beta) → test in scratch org
        → promote (released) → install in customer prod → per-customer setup → verify
```

> **Two rules that cause the most pain (learned the hard way):**
>
> 1. **Production only accepts _released_ (promoted) versions** — never a beta.
> 2. **A beta installed in an org cannot be upgraded in place** — it must be
>    uninstalled first (which deletes package data). So only ever put a beta in
>    a **throwaway scratch org**, and keep every persistent org (UAT/prod) on the
>    **released** line.

---

## 0. Prerequisites (one-time, for the release engineer)

- Salesforce CLI (`sf`) installed and up to date.
- **Dev Hub** authorized: `sf org login web --alias DevHub` (must have 2GP + namespace registered).
- Repo cloned; `npm install` run once (installs jest/eslint/prettier + husky hooks).
- The package is already defined in `sfdx-project.json`
  (`package: "Propfocus AI"`, `namespace: PropfocusAI`).

Confirm the setup:

```bash
sf org list                       # DevHub shows Connected
sf package list --target-dev-hub DevHub
```

---

## 1. Develop & validate locally

Work in a scratch org or dev sandbox; commit source to `force-app`.

```bash
npm run test:unit                                   # LWC jest
npx prettier --check "**/*.{cls,js,xml,md}"         # formatting
npx eslint "force-app/**/{aura,lwc}/**/*.js"        # LWC lint
```

Bump the version line in `sfdx-project.json` when starting a new one, e.g.
`"versionNumber": "0.13.0.NEXT"`. Commit everything.

---

## 2. Build a package version

```bash
sf package version create \
  --package "Propfocus AI" \
  --code-coverage \
  --installation-key-bypass \
  --target-dev-hub DevHub \
  --wait 60
```

- Compiles all metadata, spins a build org, **runs the full Apex test suite**,
  and records code coverage. **≥ 75 % coverage is required to promote.**
- Produces a **beta** subscriber package version id (`04t…`). Note it.

Check status / coverage later:

```bash
sf package version list --packages "Propfocus AI" --target-dev-hub DevHub
sf package version report --package 04t… --target-dev-hub DevHub   # Code Coverage Met = true
```

---

## 3. Test the beta — in a **scratch org only**

```bash
sf org create scratch -f config/project-scratch-def.json -a pkgtest --no-ancestors --target-dev-hub DevHub --duration-days 7
sf package install --package 04t… --target-org pkgtest --wait 30 --no-prompt
# …exercise the feature manually…
sf org delete scratch --target-org pkgtest --no-prompt
```

**Never** install a beta in a UAT/prod org — you will be stuck (see the rules at top).

> `--no-ancestors` is required: with ancestry (the default, since `ancestorVersion: HIGHEST`),
> the scratch org is born with the released ancestor's metadata baked in and the beta install
> fails with _"Cannot install component … because it was used as a scratch org ancestor"_.

---

## 4. Promote to released

Only when the version is final and validated:

```bash
sf package version promote --package 04t… --target-dev-hub DevHub --no-prompt
sf package version report  --package 04t… --target-dev-hub DevHub   # Released = true
```

> ⚠️ **Promotion is permanent and irreversible** — the version's contents are
> locked forever. Only promote code you are ready to ship to production.

**Version-numbering rules (learned the hard way, all enforced by Salesforce):**

- Once a version is **released**, its `major.minor.patch` line is closed — no
  more builds on it (no "0.13.0.2 after 0.13.0.1 is released").
- The **patch** segment needs "patch versioning" enabled via a Partner case;
  without it, bump the **minor** after every release (0.13 → 0.14 → …). Update
  `versionNumber` in `sfdx-project.json` right after promoting.
- Keep `"ancestorVersion": "HIGHEST"` in `sfdx-project.json` — a hardcoded
  `ancestorId` breaks the next build as soon as a newer version is released.
- **Removing a component** from the package also needs a Partner Community case
  ("metadata removal" for 2GP) — without it the build fails with _"you must first
  request access to this feature"_. Until that case is approved, retire a component
  by **repointing/emptying it** instead of deleting the file. This is why the CSP
  Trusted Site named `Propfocus_Dev` now holds `https://www.propfocus.in` (0.16.0):
  the customer-facing install screen shows CSP **URLs**, never developer names.

A released version can be **installed in production** and **upgrades in place**
(non-destructive: config records, `Propfocus_Link__c` data, permission sets, and
Lightning pages are all preserved).

---

## 5. Deploy to a customer **production** org

**Customer-facing click path for Released `0.16.0.1`:** [PROD_INSTALLATION.md](./PROD_INSTALLATION.md)
(install URL, permission sets, Config, JWT, Amberstone UAT → prod field map, verification).

### 5.1 Install the released package

Get the install URL or use the CLI. In production, log in via
`https://login.salesforce.com`.

```bash
sf org login web --instance-url https://login.salesforce.com --alias custprod
sf package install --package 04t… --target-org custprod --wait 30 \
  --security-type AdminsOnly --upgrade-type Mixed --no-prompt
```

Or, hand the admin the managed-package **install URL**:
`https://login.salesforce.com/packaging/installPackage.apexp?p0=04t…`
On the _Approve Third-Party Access_ screen, approve the CSP trusted site(s).

Confirm:

```bash
sf package installed list --target-org custprod | grep -i propfocus
```

### 5.2 Create the integration user (free license)

Setup → Users → New User:

| Field        | Value                                                                                   |
| ------------ | --------------------------------------------------------------------------------------- |
| User License | **Salesforce Integration** (free; ~5 per prod org)                                      |
| Profile      | **Salesforce API Only System Integrations** (or Minimum Access – API Only Integrations) |
| Username     | e.g. `propfocus.integration@<customer>.com` (globally unique)                           |
| Email        | a monitored inbox (for activation)                                                      |

Complete the activation email. This user is your JWT `sub` / Client-Credentials
**Run As** user. (You may reuse an existing active user instead — trade-offs in
`docs/SETUP_GUIDE.md`, but a dedicated integration user is recommended.)

### 5.3 Inbound authentication (Propfocus → Salesforce)

Preferred: **JWT Bearer** using the packaged **`PropFocus AI` connected app**
(same consumer key in every org).

1. Generate a key pair **once** (reused across all customers):
   ```bash
   openssl genrsa -out server.key 2048
   openssl req -new -x509 -key server.key -out server.crt -days 730 -subj "/CN=propfocus"
   ```
   `server.key` → Propfocus secrets manager (never share). `server.crt` → upload
   to each org's connected app.
2. On the connected app (App Manager → PropFocus AI → OAuth Settings):
   **Enable JWT Bearer Flow** and upload `server.crt`.
3. **OAuth Policies → Permitted Users = "Admin approved users are pre-authorized"**;
   attach the app to a permission set the integration user has (→ **Manage
   Permission Sets**).
4. Propfocus backend mints tokens with:
   `iss = <consumer key>`, `sub = <integration username>`,
   `aud = https://login.salesforce.com` (**production**),
   signed RS256 with `server.key`, POSTed to
   `https://login.salesforce.com/services/oauth2/token`.
   Cache the access token; re-mint on `401 INVALID_SESSION_ID`.

Full detail: `docs/JWT_SETUP.txt`. Client-Credentials alternative (no cert):
`docs/SETUP_GUIDE.md`.

### 5.4 Assign permission sets

- **Propfocus Integration** → the integration user (grants the inbound REST +
  object access).
- **Propfocus User** → sales/pre-sales reps (panel + link generation).
- **Propfocus AI Admin** → admins.

### 5.4a Local "Propfocus Callout Access" permission set (required for sales reps)

The panel makes **outbound callouts** to the Propfocus API (generate links, Test
Connection, link-history) via the Named Credential `Propfocus_API` → External
Credential `Propfocus_API_External`. To use an External Credential a user needs
**User External Credentials → Read** _and_ **External Credential Principal
Access**. Salesforce **strips "User External Credentials Read" from _managed_
permission sets on install**, so the packaged **Propfocus User** set cannot grant
it — you must create a **local (unmanaged) permission set per org**:

| Step | Action                                                                                                                     |
| ---- | -------------------------------------------------------------------------------------------------------------------------- |
| 1    | Setup → **Permission Sets** → **New** → Label: `Propfocus Callout Access` → Save                                           |
| 2    | **Object Settings** → **User External Credentials** → enable **Read** → Save                                               |
| 3    | **External Credential Principal Access** → enable **Propfocus API — Propfocus Principal** (namespace `PropfocusAI`) → Save |
| 4    | **Manage Assignments** → assign to all **sales / pre-sales users** (alongside Propfocus User)                              |

**Who needs it:** sales/pre-sales reps → **yes**. Admins (System Administrator
profile) usually already have User External Credentials Read → no. The inbound
**integration user** → no (it receives events, it doesn't run the panel callouts).

**Symptom if missing:** reps see **empty Projects**, or
_"You don't have read permissions on the User External Credential object."_

This step is **per-org and manual** — it cannot ship in the managed package
because of the managed-permission-set stripping above. (Detail: `docs/SETUP_GUIDE.md` §2.1e.)

### 5.5 Configure Propfocus Config (Custom Metadata)

Setup → Custom Metadata Types → **Propfocus Config** → **Default** → Edit:

| Field                                             | Production value                                                                                                                                                                        |
| ------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Organization Id                                   | the customer's **Propfocus org id** (unique per customer)                                                                                                                               |
| Api Named Credential                              | `Propfocus_API`                                                                                                                                                                         |
| Embed Base Url                                    | `https://propfocus.in/embed/salesforce` (**prod**, not dev)                                                                                                                             |
| Buyer Id / Name / Project / Lead Status Field     | map to the customer's fields                                                                                                                                                            |
| Site Visit Object + field mappings                | the customer's site-visit object/fields                                                                                                                                                 |
| Auto Microsite / Site Visit / Post Visit Statuses | the statuses that auto-open each modal                                                                                                                                                  |
| **RNR Microsite Statuses**                        | statuses whose microsite Lead Type defaults to **RNR** (e.g. `Not Connected, Open`). **Required** — there is no built-in default; blank means every microsite defaults to New.          |
| Site Visit Datetime Field                         | the **Site Visit object's** date/time field (e.g. `Site_Visit_Scheduled_Date_Time__c`) — prefills the Confirm Site Visit modal. Must be a field on the Site Visit object, not the Lead. |
| Site Visit Scheduled Status                       | the Lead status to stamp on site-visit generation (Leads only; never touches Opportunity stage)                                                                                         |
| Site Visit Planned / Confirmed Date Field         | Lead date fields stamped with the visit date alongside the status (satisfies validation rules requiring them)                                                                           |
| Site Visit Time Of Day Field / Value              | optional Lead picklist + value (e.g. `Site_Visit_Time_of_Day__c` / `Morning`) stamped with the status                                                                                   |

See the full field list in `docs/FIELDS.md`. Named Credential / External
Credential (outbound OAuth to Propfocus) per `docs/SETUP_GUIDE.md` §2.4.

### 5.6 Place the panel on record pages

Lightning App Builder → the Lead **and** Opportunity record pages → drag the
**`propfocusLeadLinkGen`** component onto the page → Save & Activate.
(Use the packaged `PropfocusAI:propfocusLeadLinkGen`, not an unmanaged copy.)

### 5.7 Enable notifications

Setup → Custom Notifications → **PropFocus Notification** → ensure delivery to the
users who should receive bell alerts.

### 5.8 Verify

1. Open a Lead → the Propfocus panel loads, **Generate Microsite** works.
2. Move a Lead into an **Auto\_\*** status → the corresponding modal auto-opens.
3. From Propfocus, POST a `buyer_activity` and a `lead_sync` event (see
   `docs/INBOUND.md`) → owner gets a bell / lead status updates.
4. Test Connection on the Admin Setup tab (outbound).

Full E2E checklist: `docs/E2E_INSTALLATION.md`.

---

## 6. Upgrades (existing production orgs)

For an org already on a **released** version:

```bash
sf package install --package <new 04t…> --target-org custprod --wait 30 --no-prompt
```

In-place and non-destructive — config and data are preserved. New config fields
from the new version appear (blank) for the admin to set.

If an org is on a **beta**, it cannot be upgraded — it must be uninstalled first
(destructive). Snapshot its config before doing so:

```bash
sf data query --target-org <org> --json \
  --query "SELECT FIELDS(ALL) FROM PropfocusAI__Propfocus_Config__mdt WHERE DeveloperName='Default' LIMIT 1"
```

---

## 7. Rollback

Managed packages don't "downgrade." Options if a release misbehaves:

- **Config toggles** — most behavior is CMDT-driven (e.g. blank an `Auto_*` field
  to disable auto-open). Prefer this.
- **Fix-forward** — build + promote a new version and upgrade.
- **Uninstall** — last resort; deletes package data (export first).

---

## 8. Sandbox / UAT differences

- **Login/aud:** `https://test.salesforce.com` (sandbox) vs
  `https://login.salesforce.com` (prod).
- **URLs:** sandboxes point at `https://dev.propfocus.in`; prod at
  `https://propfocus.in`.
- Keep persistent sandboxes on **released** versions too (same beta rule).

---

## Quick reference — CLI

```bash
# build
sf package version create --package "Propfocus AI" --code-coverage --installation-key-bypass --target-dev-hub DevHub --wait 60
# promote
sf package version promote --package 04t… --target-dev-hub DevHub --no-prompt
# install / upgrade
sf package install --package 04t… --target-org <org> --wait 30 --no-prompt
# what's installed
sf package installed list --target-org <org>
```
