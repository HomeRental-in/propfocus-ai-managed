# Dev Hub Setup — Steps for Your Team

The managed package **cannot be published** without a Salesforce **Dev Hub** org. This document is for your Salesforce admin / partner team to set up Dev Hub and hand access back to the development team.

---

## What is Dev Hub?

Dev Hub is a Salesforce org (usually a **Partner Business Org** or **Developer Edition** with Dev Hub enabled) used to:

- Register the package **namespace** (`PropfocusAI`)
- Create the **managed package**
- Build **installable package versions**
- Generate the **package install link** for subscribers

The sandbox (`hosachiguru--consultefy`) is for **testing only** — not for publishing packages.

---

## Prerequisites

Your team needs ONE of:

| Option                                    | Who typically has it                   |
| ----------------------------------------- | -------------------------------------- |
| **Salesforce Partner Business Org (PBO)** | ISV partners building AppExchange apps |
| **Developer Edition + Dev Hub enabled**   | Free at developer.salesforce.com       |

Also required:

- Namespace **`PropfocusAI`** registered (or chosen alternative — must match `sfdx-project.json`)
- Salesforce CLI user authorized to the Dev Hub org

---

## Step 1 — Enable Dev Hub

### Important: namespace org ≠ Dev Hub org

Salesforce **does not allow** the same Developer Edition org to be **both**:

- the org where the **namespace is registered**, and
- the **Dev Hub** org.

If you see:

> _You can't enable Dev Hub in a Developer Edition org with a registered namespace._

then that org is your **namespace org** (correct for `PropfocusAI`). You need a **second org** as Dev Hub and must **link** the namespace to it.

```
┌─────────────────────────────┐         link          ┌─────────────────────────────┐
│  Namespace org (DE)         │  ──────────────────►  │  Dev Hub org (DE or PBO)    │
│  PropfocusAI registered     │   Namespace Registry  │  Dev Hub enabled            │
│  Dev Hub = OFF (required)   │                       │  package create / publish   │
└─────────────────────────────┘                       └─────────────────────────────┘
```

Reference: [Link a Namespace to a Dev Hub Org](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_reg_namespace.htm)

### If namespace is already registered (your situation)

**Keep** `orgfarm-c1782b2e2b-dev-ed` as the namespace org. Do **not** try to enable Dev Hub there.

Do **one** of the following:

| Option                             | Best for                   | Steps                                                                                                           |
| ---------------------------------- | -------------------------- | --------------------------------------------------------------------------------------------------------------- |
| **A — Partner Business Org (PBO)** | ISV / AppExchange partners | Use company PBO as Dev Hub → **Namespace Registries → Link Namespace** → log in to namespace DE org             |
| **B — New Developer Edition**      | No PBO available           | Sign up new DE → **enable Dev Hub first** (before any namespace) → **Link Namespace** to existing namespace org |

### If starting fresh (no namespace yet)

1. Sign up at https://developer.salesforce.com/signup
2. Log in → **Setup**
3. Quick Find: **Dev Hub**
4. Toggle **Enable Dev Hub** → ON
5. Register / link namespace **after** Dev Hub is enabled (via Namespace Registries)

### If using Partner Business Org

1. Log in to your PBO
2. Dev Hub is usually already enabled
3. Verify: Setup → **Dev Hub** → enabled
4. App Launcher → **Namespace Registries** → **Link Namespace** → authenticate to namespace DE org

---

## Step 1b — Link namespace to Dev Hub (required for 2GP)

In the **Dev Hub org** (not the namespace org):

1. App Launcher → **Namespace Registries**
2. Click **Link Namespace**
3. Log in to the Developer Edition org where **`PropfocusAI`** is registered  
   (`aakashbh2.da9808e0b796@agentforce.com` / orgfarm org)
4. Confirm link succeeds

Then point Salesforce CLI at the **Dev Hub org**:

```powershell
sf org login web --instance-url https://login.salesforce.com --alias propfocus-devhub
sf package create --name "Propfocus AI" --path force-app --package-type Managed --target-dev-hub propfocus-devhub
```

---

## Step 2 — Register namespace

1. In Dev Hub org → Setup → **Namespace Registries** (or **Package Manager** → namespace)
2. Register namespace: **`PropfocusAI`**
3. Wait for approval (can take a few days for new namespaces)

> Namespace must match `sfdx-project.json` in the repo: `"namespace": "PropfocusAI"`

---

## Step 3 — Grant developer access

Give the development team ONE of:

**Option A — Dev Hub user login (simplest)**

- Create a user in Dev Hub org with **System Administrator** profile
- Share username/password (or add to SSO)

**Option B — Salesforce CLI authorization**

- Admin runs locally:
  ```powershell
  sf org login web --instance-url https://login.salesforce.com --alias propfocus-devhub
  ```
- Or create a **Connected App** + JWT for CI/CD (advanced)

**What we need from you:**

- Dev Hub login URL
- Username with permission to create packages
- Confirmation that namespace `PropfocusAI` is registered

---

## Step 4 — Create managed package (development team runs this)

Once Dev Hub access is granted, the dev team runs:

```powershell
# Authorize Dev Hub
sf org login web --instance-url https://login.salesforce.com --alias propfocus-devhub

# Create package (once)
sf package create \
  --name "Propfocus AI" \
  --package-type Managed \
  --path force-app \
  --target-dev-hub propfocus-devhub \
  --namespace PropfocusAI

# Create installable version
sf package version create \
  --package "Propfocus AI" \
  --installation-key-bypass \
  --wait 30 \
  --target-dev-hub propfocus-devhub \
  --code-coverage

# Get install link
sf package version report --target-dev-hub propfocus-devhub
```

Output includes **Package Installation URL** — this is what subscribers use to install the app.

---

## Step 5 — Security review (AppExchange)

Before listing publicly on AppExchange:

1. Submit package for **Salesforce Security Review**
2. Provide test credentials and documentation
3. Address any findings

For **private installs** (single subscriber org), security review may not be required — but recommended for production.

---

## Checklist for your team

| #   | Task                                       | Owner            | Done? |
| --- | ------------------------------------------ | ---------------- | ----- |
| 1   | Dev Hub org available                      | Salesforce admin | ☐     |
| 2   | Dev Hub enabled                            | Salesforce admin | ☐     |
| 3   | Namespace `PropfocusAI` registered         | Salesforce admin | ☐     |
| 4   | Dev Hub login shared with dev team         | Salesforce admin | ☐     |
| 5   | Package created                            | Dev team         | ☐     |
| 6   | Package version built (75%+ test coverage) | Dev team         | ☐     |
| 7   | Install link generated                     | Dev team         | ☐     |
| 8   | Test install in fresh org                  | Dev team         | ☐     |

---

## FAQ

**Q: We see "You can't enable Dev Hub in a Developer Edition org with a registered namespace" — what now?**  
That org is your **namespace org**. Leave Dev Hub OFF there. Create or use a **separate Dev Hub org** (new DE with Dev Hub enabled first, or PBO) and **Link Namespace** from Namespace Registries.

**Q: Can we use the sandbox as Dev Hub?**  
No. Sandboxes cannot be Dev Hubs. You need a production-type org (DE or PBO).

**Q: We already have an unmanaged app — do we still need Dev Hub?**  
Yes, to publish a **managed** package with an install link.

**Q: How long does namespace registration take?**  
Usually instant to a few business days depending on org type.

**Q: Who pays for Dev Hub?**  
Developer Edition is free. Partner Business Org requires Salesforce Partner Program membership.

---

## Message you can forward to your team

```
We need Dev Hub access to publish the Propfocus AI managed package.

Please:
1. Confirm we have a Partner Business Org or Developer Edition with Dev Hub enabled
2. Register namespace "PropfocusAI" if not already done
3. Provide a Dev Hub admin login (or authorize our CLI user)

Once done, our dev team will create the package and share the install link.

Reference: docs/DEV_HUB_SETUP.md in the project repo.
```
