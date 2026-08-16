# Propfocus AI — Outbound data contract (Salesforce → Propfocus)

What leaves the Salesforce org toward Propfocus (`propfocus.in` / `dev.propfocus.in`).  
For the reverse direction, see [INBOUND.md](./INBOUND.md).

**Audience:** Security / privacy reviewers, Salesforce admins, Propfocus backend.

---

## Channels

| Channel | When | Transport |
| ------- | ---- | --------- |
| REST callouts | Generate Microsite, Confirm Site Visit, Post Visit, project lists, Test Connection (from Lead or Opportunity panel) | HTTPS via Named Credential `Propfocus_API` + External Credential (OAuth `client_credentials`) |
| Platform Events | Lead insert/update on watched fields | `PropfocusAI__Propfocus_Lead_Event__e` (CometD / EMP subscription by Propfocus) |

Apex never reads the outbound client secret; Salesforce performs the token exchange.

---

## REST callout payloads

Base URL: Named Credential host (`https://propfocus.in` production; `https://dev.propfocus.in` sandbox).

### Microsite — `POST /api/broker-microsite/create`

| JSON field | Source | PII? |
| ---------- | ------ | ---- |
| `clientName` | Mapped Buyer Name Field on Lead or Opportunity (or UI override) | Yes — buyer name |
| `buyer_id` | Mapped Buyer Id Field on Lead or Opportunity | Yes — buyer / enquiry identifier |
| `salesforce_lead_id` | Lead `Id` (Lead panel only) | Indirect identifier |
| `salesforce_opportunity_id` | Opportunity `Id` (Opportunity panel only) | Indirect identifier |
| `projects` | UI selection and/or mapped Project Field | Usually business, not personal |
| lead status key (API status field) | Lead Status Field or Opportunity Status Field | Business |
| `lead_types` | UI context | Business |
| `configurationFilter` | UI context (may be empty) | Business |
| `brokerName` | Lead **Pre Sales Rep Source Field** (when set) | Possible — employee name |
| `organizationId` | Propfocus Config **Organization Id** (with `brokerName`) | Tenant id |
| `brokerNumber` | Lead **Owner.Phone** (only if `brokerName` blank) | Yes — phone |

### Site visit — `POST /api/site-visit/create-sv`

| JSON field | Source | PII? |
| ---------- | ------ | ---- |
| `buyer_id` | Mapped Buyer Id Field (Lead or Opportunity) | Yes |
| `buyer_name` | Mapped Buyer Name Field (Lead or Opportunity) | Yes |
| `salesforce_lead_id` | Lead `Id` (Lead panel only) | Indirect identifier |
| `salesforce_opportunity_id` | Opportunity `Id` (Opportunity panel only) | Indirect identifier |
| `project_name` | UI / Project Field | Business |
| `visit_date` / `visit_time` | UI | Business |
| `siteVisitManager` | UI (when selected) | Possible — manager details |
| `brokerName` / `brokerNumber` / `organizationId` | Same as microsite | See above |

### Post visit — `POST /api/post-visit/create-pv`

| JSON field | Source | PII? |
| ---------- | ------ | ---- |
| `buyer_id` / `buyer_name` | Mapped Lead or Opportunity fields | Yes |
| `salesforce_lead_id` | Lead `Id` (Lead panel) | Indirect identifier |
| `salesforce_opportunity_id` | Opportunity `Id` (Opportunity panel) | Indirect identifier |
| `project_name` | UI / Project Field | Business |
| `visited_configuration` | UI | Business |
| `visit_conducted_at` | UI | Business |
| `assignedBrokerId` | UI "Reassign to" (optional) | Indirect — Propfocus broker id |
| `brokerName` / `brokerNumber` / `organizationId` | Same as microsite | See above |

### Other callouts (lower PII)

| Endpoint | Purpose | Notable data |
| -------- | ------- | ------------ |
| OAuth token URL | Client credentials | Client Id (not Lead PII) |
| `/api/v1/organizations/{orgId}/accessible-projects` | Project picker | Organization Id |
| `/api/v1/organizations/{orgId}/projects?include=all` | Project list | Organization Id |
| `/api/dashboard/sales-team?organizationId=` | Post-visit "Reassign to" picker | Organization Id |
| `POST /api/v1/salesforce/link-history-status` | Lead/Opportunity history card status refresh (Pending/Confirmed/Rescheduled/Engaged) | Organization Id, Buyer Id, shared link URLs / project names (no phone/email unless Buyer Id maps to them) |

#### Link history status — `POST /api/v1/salesforce/link-history-status`

Called from `PropFocusLeadService.getLinkHistory` when the Lead/Opportunity panel loads history. PropFocus returns live statuses; Apex updates `Propfocus_Link__c.Status__c`. Callout failure leaves stored status unchanged.

| JSON field | Source | PII? |
| ---------- | ------ | ---- |
| `organization_id` | Propfocus Config Organization Id | Tenant id |
| `buyer_id` | Mapped Buyer Id Field on Lead or Opportunity | Yes — buyer / enquiry identifier |
| `links[].type` | History row type (Microsite / Site Visit / Post Visit) | No |
| `links[].url` | Shared PropFocus link URL from history | Indirect identifier |
| `links[].project_name` | History project name | Usually business |

Response `statuses[]` mirrors input order with `status` values: `Pending` / `Confirmed` / `Rescheduled` (site visit) or `Not engaged` / `Engaged` (microsite / post visit).

Idempotency: callouts send an `Idempotency-Key` header derived from operation + record Id (Lead or Opportunity) + body hash (not additional PII).

**Identity rule:** Never put an Opportunity Id in `salesforce_lead_id`. Use `salesforce_opportunity_id` when the panel is opened from Opportunity.

---

## Platform Event payload

Object: `PropfocusAI__Propfocus_Lead_Event__e`

| Field | Content | PII? |
| ----- | ------- | ---- |
| `Lead_Id__c` | Salesforce Lead Id | Indirect identifier |
| `Buyer_Id__c` | Value of mapped Buyer Id Field | Yes — buyer / enquiry identifier |
| `Organization_Id__c` | Config Organization Id | Tenant id |
| `Event_Type__c` | e.g. `lead_created`, `status_changed`, `project_changed`, `buyer_name_changed`, `lead_converted` | No |
| `Field_Name__c` | API name of changed field | No |
| `Old_Value__c` / `New_Value__c` | Prior/new field values | **Yes when the field is buyer name (or other mapped PII)** |
| `Occurred_At__c` | Timestamp | No |

**Watched fields** (publish on change): always `Status`, `IsConverted`, plus Config mappings for Lead Status, Project, Buyer Id, Buyer Name.

---

## What is *not* sent outbound by the package

- Lead Email, MobilePhone, Address (unless a mapped Config field points at them — avoid mapping those for Buyer Id/Name)
- Full Lead dump / arbitrary SOQL export
- Salesforce session cookies or user passwords
- JWT private key (`server.key`) — inbound only; never sent outbound

---

## Data residency and legal

| Topic | Answer |
| ----- | ------ |
| Hosting | Production API / embed default to **`propfocus.in`** (India TLD). Sandbox/UAT typically uses **`dev.propfocus.in`**. |
| Data processing | Propfocus processes buyer identifiers and names required to generate microsites and sync lead state. Exact subprocessors and retention: **see the Propfocus DPA / MSA** (request from Propfocus legal / account team). |
| DPA | Customers requiring a Data Processing Agreement should obtain it from Propfocus before production go-live. This package doc is a technical field inventory, not a legal agreement. |
| Minimization | Map Buyer Id / Buyer Name to the least-sensitive fields that still identify the buyer for Propfocus (prefer enquiry refs over email/phone). |

---

## Related documents

| Document | Use |
| -------- | --- |
| [INBOUND.md](./INBOUND.md) | Propfocus → Salesforce REST payloads |
| [FIELDS.md](./FIELDS.md) | Which Lead fields to map |
| [E2E_INSTALLATION.md](./E2E_INSTALLATION.md) | Install and External Credential setup |
| [JWT_SETUP.txt](./JWT_SETUP.txt) | Inbound JWT (separate from outbound OAuth) |
