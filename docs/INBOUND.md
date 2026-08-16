# Propfocus AI — Inbound REST & Two-Way Sync

Covers architecture, authentication, API payloads, and Postman troubleshooting.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        SALESFORCE                                │
│  Lead changes ──► Platform Event (Propfocus_Lead_Event__e)      │
│  Outbound API ──► PropfocusHttpService + Named Credential (OAuth client_credentials) │
│  Inbound REST ◄── POST .../PropfocusAI/propfocus/events/        │
└─────────────────────────────────────────────────────────────────┘
         │                                    ▲
         │ Platform Events                    │ REST + OAuth
         ▼                                    │
┌─────────────────────────────────────────────────────────────────┐
│                     PROPFOCUS (propfocus.in)                     │
│  Subscribe to Platform Events · POST write-back · Issue OAuth   │
└─────────────────────────────────────────────────────────────────┘
```

### Salesforce → Propfocus (outbound)

| Mechanism                               | Package support              |
| --------------------------------------- | ---------------------------- |
| Button callouts (microsite, site visit) from Lead or Opportunity | ✅ |
| OAuth `client_credentials`              | ✅ (External Credential + Named Credential) |
| Platform Events on Lead changes         | ✅                           |

**Payload / PII / residency contract:** [OUTBOUND.md](./OUTBOUND.md).

Configure: Client Id/Secret in **External Credential → Propfocus Principal** + Organization Id in Propfocus Config; Named Credential URL = `https://propfocus.in` (sandboxes: `https://dev.propfocus.in`).

#### Outbound auth setup (Salesforce admin)

| Step | Action |
| ---- | ------ |
| 1 | Setup → External Credentials → **Propfocus API** — confirm token endpoint for your environment |
| 2 | Open **Propfocus Principal** → enter Client Id + Client Secret from Propfocus team |
| 3 | Setup → Named Credentials → **Propfocus API** — confirm API URL and Generate Authorization Header |
| 4 | Assign **Propfocus User** (sales) and **Propfocus AI Admin** — both include External Credential principal access |

Verify: **propfocusAI Admin Setup → Test Connection**.

### Propfocus → Salesforce (inbound)

| Mechanism                             | Package support |
| ------------------------------------- | --------------- |
| REST notifications                    | ✅              |
| Lead / Opportunity field write-back   | ✅              |
| Call logs / history / site visit sync (Lead or Opportunity parent) | ✅ |

Authenticate via External Client App (JWT Bearer recommended) and POST to the inbound REST endpoint.

---

## Endpoint

```text
POST https://<your-org-host>/services/apexrest/PropfocusAI/propfocus/events/
Authorization: Bearer <salesforce_access_token>
Content-Type: application/json
```

- Does **not** return a token on GET — POST only with Bearer header.
- Exact URL shown on **propfocusAI Admin Setup** tab.

### Two OAuth systems (do not mix)

| Direction      | Token from                                           | Used by                  |
| -------------- | ---------------------------------------------------- | ------------------------ |
| SF → Propfocus | `https://propfocus.in/api/oauth2/token` (sandbox: `https://dev.propfocus.in/api/oauth2/token`) | Buttons, Test Connection |
| Propfocus → SF | `https://login.salesforce.com/services/oauth2/token` | Inbound REST POST        |

## Inbound authentication

### Get `access_token`

**Option A — Username-Password** (Postman / initial testing):

```http
POST https://login.salesforce.com/services/oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=password
&client_id=<Connected_App_Consumer_Key>
&client_secret=<Connected_App_Consumer_Secret>
&username=<integration_user>
&password=<password><security_token>
```

Sandboxes: use `https://test.salesforce.com/services/oauth2/token`.

**Option B — JWT Bearer** (production): see [JWT_SETUP.txt](./JWT_SETUP.txt).

### Inbound auth setup (Salesforce admin)

1. Create integration user (Minimum Access, not System Administrator).
2. Assign **Propfocus Integration** permission set.
3. Grant Read + Edit on mapped Lead fields (and Opportunity fields if using Opp write-back).
4. Receive **`server.crt` only** from Propfocus (Propfocus generates the key pair and keeps `server.key` — never share or request the private key).
5. Create **External Client App** with JWT Bearer flow; upload `server.crt`; scope **api** only; **Admin approved** + permission set; note Consumer Key.
6. Copy inbound REST URL from Admin Setup tab.

Send Propfocus backend: org host, Consumer Key, integration username, Organization Id, inbound REST URL. **Do not** send admin password or any private key. Cert is valid **365 days** — Propfocus rotates and sends a new `server.crt` before expiry (see [JWT_SETUP.txt](./JWT_SETUP.txt) Step 10).

---

## Event types & payloads

| event_type       | Purpose                                                            |
| ---------------- | ------------------------------------------------------------------ |
| `buyer_activity` | Notification (title + message required unless write-back included) |
| `lead_sync`      | Data write-back (title/message optional)                           |

### Notification example

```json
{
  "event_type": "buyer_activity",
  "buyer_id": "lead@example.com",
  "organization_id": "<from Propfocus Config>",
  "title": "New Site Visit Scheduled",
  "message": "Customer has scheduled a site visit for tomorrow at 11 AM"
}
```

### Write-back example (Lead)

```json
{
  "event_type": "lead_sync",
  "buyer_id": "BUYER-UUID-123",
  "organization_id": "<from Propfocus Config>",
  "lead_data": {
    "buyer_name": "John Doe",
    "current_lead_status": "Working",
    "lead_source": "Website",
    "primary_project_name": "Project Alpha",
    "salesforce_lead_id": "00Qxxxxxxxxxxxx"
  },
  "call_logs": [
    {
      "duration": "120",
      "disposition": "Answered",
      "call_time": "2026-05-26T10:15:00.000Z",
      "recording_url": "https://example.com/rec/1"
    }
  ],
  "site_visit": {
    "site_visit_number": "SV-1001",
    "site_visit_type": "Physical",
    "site_visit_status": "Scheduled",
    "site_visit_datetime": "2026-05-27T14:00:00.000Z"
  },
  "lead_history": [
    {
      "field_changed": "Status",
      "old_value": "Open",
      "new_value": "Working",
      "change_date": "2026-05-26T09:00:00.000Z",
      "changed_by": "PropFocus"
    }
  ]
}
```

### Write-back example (Opportunity)

Same payload shape. Prefer explicit Opportunity identity when known:

```json
{
  "event_type": "lead_sync",
  "buyer_id": "BUYER-UUID-123",
  "organization_id": "<from Propfocus Config>",
  "lead_data": {
    "buyer_name": "John Doe",
    "current_lead_status": "Qualification",
    "primary_project_name": "Project Alpha",
    "salesforce_opportunity_id": "006xxxxxxxxxxxx"
  },
  "site_visit": {
    "site_visit_number": "SV-1001",
    "site_visit_status": "Scheduled",
    "project_name": "Project Alpha"
  }
}
```

### Field mapping (`lead_data` → Salesforce)

Mappings come from **Propfocus Config → Default**. Only configured fields are written.  
When the resolved parent is a **Lead**, Lead Config fields are used. When it is an **Opportunity**, Opportunity Config fields are used (same payload keys).

| Payload key                          | Lead Config field          | Opportunity Config field |
| ------------------------------------ | -------------------------- | ------------------------ |
| `buyer_name`                         | Buyer Name Field           | Opportunity Buyer Name Field |
| `pre_sales_owner_name`               | Pre-Sales Owner Name Field | Opportunity Pre-Sales Owner Name Field |
| `sales_owner_name`                   | Sales Owner Name Field     | Opportunity Sales Owner Name Field |
| `uuid`, `buyer_id`                   | Buyer Id Field             | Opportunity Buyer Id Field |
| `current_lead_status`, `lead_status` | Lead Status Field          | Opportunity Status Field |
| `lead_source`                        | Lead Source Field          | Opportunity Lead Source Field |
| `primary_project_name`               | Project Field              | Opportunity Project Field |
| `salesforce_lead_id`                 | Must match resolved Lead   | — |
| `salesforce_opportunity_id`          | —                          | Must match resolved Opportunity |

### Child records

| Payload section | Stored in                                                   | Parent lookup |
| --------------- | ----------------------------------------------------------- | ------------- |
| `call_logs`     | `Propfocus_Call_Log__c`                                     | `Lead__c` or `Opportunity__c` |
| `lead_history`  | `Propfocus_Sync_History__c`                                 | `Lead__c` or `Opportunity__c` |
| `site_visit`    | `Propfocus_Site_Visit_Sync__c` (+ optional `Site_Visit__c`) | Same parent; client SV uses Lead Lookup Field or Opportunity Lookup Field |

### Link history status (Propfocus → Salesforce)

History card statuses are stored on `Propfocus_Link__c.Status__c`. They are updated when Salesforce pulls live status from PropFocus on history load (`POST /api/v1/salesforce/link-history-status` — see [OUTBOUND.md](./OUTBOUND.md)), and can also be updated from PropFocus inbound events. They are **not** overlaid from Salesforce CRM Site Visit picklists.

| Communication | Initial status | Updated when Propfocus sends |
| ------------- | -------------- | ---------------------------- |
| Microsite / Post Visit | `Not engaged` | `engagement` (or `engagement_status` / `microsite_status`) → `Engaged`; also buyer_activity notifications that mention microsite/post visit viewed/engaged |
| Site Visit Confirmation | `Pending` | `site_visit.site_visit_status` → `Pending` / `Confirmed` / `Rescheduled` |

Site visit status mapping (case-insensitive): values containing `resched` → Rescheduled; `confirm` / `complete` / `conduct` / `visited` / `done` → Confirmed; otherwise Pending.

Engagement example:

```json
{
  "event_type": "buyer_activity",
  "buyer_id": "BUYER-UUID-123",
  "organization_id": "<from Propfocus Config>",
  "engagement": {
    "status": "Engaged",
    "communication_type": "microsite",
    "project_name": "Project Alpha"
  }
}
```

Or root-level: `"engagement_status": "Engaged"`.

Site visit status example (updates matching history card):

```json
{
  "event_type": "lead_sync",
  "buyer_id": "BUYER-UUID-123",
  "organization_id": "<from Propfocus Config>",
  "site_visit": {
    "site_visit_number": "SV-1001",
    "site_visit_status": "Confirmed",
    "project_name": "Project Alpha"
  }
}
```

### Response & errors

Success (Lead): `{ "success": true, "lead_id": "00Q...", "record_id": "00Q...", "record_type": "Lead", "lead_updated": true, ... }`  
Success (Opportunity): `{ "success": true, "opportunity_id": "006...", "record_id": "006...", "record_type": "Opportunity", "lead_updated": true, ... }`

Resolution order: explicit `salesforce_opportunity_id` / `salesforce_lead_id` (root or `lead_data`) → Lead by `buyer_id` → Opportunity by `buyer_id`.

| HTTP | Meaning                        |
| ---- | ------------------------------ |
| 400  | Missing/invalid payload        |
| 403  | Organization ID mismatch       |
| 404  | No Lead or Opportunity found for `buyer_id` |
| 500  | Config missing or server error |

**Rules:** `buyer_id` and `organization_id` always required. Lead lookup uses Buyer Id Field and only **unconverted** Leads. Opportunity lookup uses Opportunity Buyer Id Field.

---

## Postman troubleshooting

Use when you have a valid token but requests fail.

### Error: PUT `/integrations/salesforce/leads` (NOT_FOUND)

**Wrong:** PUT to a path that does not exist; body uses `leadId` and nested `notification`.

**Correct:**

```http
POST https://<your-org-host>/services/apexrest/PropfocusAI/propfocus/events
Authorization: Bearer <access_token>
Content-Type: application/json
```

Use flat `title` and `message`; field name is `buyer_id`, not `leadId`.

### Error: POST correct URL but 404 No Lead found

**Wrong:** `buyer_id` is a Salesforce Lead Id (`00Q...`).

**Fix:** Use the value from the configured Buyer Id Field (e.g. Email or Enquiry Ref No.).

> **Note:** "Embed Uses Salesforce Lead Id" applies to microsite links only — not inbound REST lookup.

### Postman variables

1. Propfocus Config → Default → note Buyer Id Field and Organization Id.
2. On Lead record, copy the Buyer Id Field value.
3. Set: `buyer_id`, `organization_id`, `access_token` (refresh when expired).

### Also verify

- Lead exists in the same org as the token.
- Lead is not converted.
- `organization_id` matches Propfocus Config exactly.

---

## Testing two-way sync

| Test           | Steps                                              |
| -------------- | -------------------------------------------------- |
| SF → Propfocus | Change Lead → Propfocus confirms Platform Event    |
| Propfocus → SF | POST write-back → Lead updates + bell notification |
| OAuth outbound | Admin Setup → Test Connection → Generate Microsite |

See also [FAQ.txt](./FAQ.txt) and [SETUP_GUIDE.md](./SETUP_GUIDE.md).
