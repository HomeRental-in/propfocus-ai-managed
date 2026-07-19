# Field API Names & Mappings

How to find Lead, Opportunity, and Site Visit field API names, plus Hosachiguru sandbox reference values.

The Propfocus panel (`propfocusLeadLinkGen`) works on **Lead** and **Opportunity**. Configure both object mappings when you use both.

---

## Find field API names in Salesforce UI

### Method 1: Object Manager (recommended)

1. Setup → **Object Manager → Lead** (or **Opportunity**)
2. **Fields & Relationships** → click a field
3. Read **Field Name** — that is the API name

Custom fields end in `__c`. Standard fields do not (e.g. `Status`, `StageName`, `LeadSource`).

### Method 2: Lightning App Builder

Lead or Opportunity record → gear → **Edit Page** → click a field → API Name in right panel.

### Method 3: Site Visit object

Setup → Object Manager → **Site Visit** (`Site_Visit__c`) → Fields & Relationships.

Confirm both a **Lead** lookup and an **Opportunity** lookup exist if you create site visits on Opportunities.

### Method 4: CLI

```powershell
sf data query --query "SELECT QualifiedApiName, Label FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName = 'Lead' AND QualifiedApiName LIKE '%__c'" --target-org <alias> --use-tooling-api

sf data query --query "SELECT QualifiedApiName, Label FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName = 'Opportunity' AND QualifiedApiName LIKE '%__c'" --target-org <alias> --use-tooling-api
```

---

## Mapping checklist

### Lead

| Propfocus concept     | Search Lead fields for              |
| --------------------- | ----------------------------------- |
| Buyer Name            | Full Name, Name, LastName           |
| UUID / Enquiry Ref    | Enquiry Ref, Buyer Ref, OTP         |
| Pre-Sales Owner Name  | Presales Owner, Pre Sales           |
| Pre-Sales Owner Phone | Presales Phone, Owner Phone         |
| Sales Owner Name      | Sales Person, Sales Owner           |
| Sales Owner Phone     | Mobile Phone, Sales Phone           |
| Lead Status           | Status                              |
| Lead Source           | Lead Source, Primary Source         |
| Primary Project       | Project Interested, Primary Project |

### Opportunity

| Propfocus concept     | Search Opportunity fields for       |
| --------------------- | ----------------------------------- |
| Buyer Name            | Name, Account Name, Contact Name    |
| UUID / Enquiry Ref    | Enquiry Ref, Buyer Ref, Description |
| Status / Stage        | StageName, Stage                    |
| Primary Project       | Project, Next Step, custom project  |
| Lead Source           | LeadSource                          |
| Owners / phone        | Owner, custom owner phone fields    |

Enter API names in **Setup → Custom Metadata Types → Propfocus Config → Default**.

---

## Config field reference (Propfocus Config → Default)

### Lead mappings

| Config field (label) | CMDT API name | Typical value |
| -------------------- | ------------- | ------------- |
| Buyer Id Field | `Buyer_Id_Field__c` | `Enquiry_Ref_No__c` |
| Buyer Name Field | `Buyer_Name_Field__c` | `Full_Name__c` |
| Lead Status Field | `Lead_Status_Field__c` | `Status` |
| Project Field | `Project_Field__c` | `Project_Interested__c` |
| Lead Source Field | `Lead_Source_Field__c` | `LeadSource` |
| Pre Sales Rep Source Field | `Pre_Sales_Rep_Source_Field__c` | org-specific |
| Pre-Sales Owner Name / Phone | `Pre_Sales_Owner_*_Field__c` | org-specific |
| Sales Owner Name / Phone | `Sales_Owner_*_Field__c` | org-specific |

### Opportunity mappings

| Config field (label) | CMDT API name | Typical value |
| -------------------- | ------------- | ------------- |
| Opportunity Buyer Id Field | `Opportunity_Buyer_Id_Field__c` | custom enquiry / buyer ref |
| Opportunity Buyer Name Field | `Opportunity_Buyer_Name_Field__c` | `Name` |
| Opportunity Status Field | `Opportunity_Status_Field__c` | `StageName` |
| Opportunity Project Field | `Opportunity_Project_Field__c` | custom project / `NextStep` |
| Opportunity Lead Source Field | `Opportunity_Lead_Source_Field__c` | `LeadSource` |
| Opportunity Pre Sales Rep Source | `Opportunity_Pre_Sales_Rep_Source_Field__c` | org-specific |
| Opportunity owner name/phone fields | `Opportunity_*_Owner_*_Field__c` | org-specific |
| Embed Uses Salesforce Opportunity Id | `Embed_Uses_Salesforce_Opportunity_Id__c` | checked |

### Site Visit mappings

| Config field (label) | CMDT API name | Typical value |
| -------------------- | ------------- | ------------- |
| Site Visit Object | `Site_Visit_Object__c` | `Site_Visit__c` |
| Lead Lookup Field | `Lead_Lookup_Field__c` | `Lead__c` |
| Opportunity Lookup Field | `Opportunity_Lookup_Field__c` | `Opportunity__c` |
| Site Visit Status / Project / Type / Datetime / Team | `Site_Visit_*_Field__c` | org-specific |

**Auto link on Site Visit Save:** Apex invocable `PropFocusSiteVisitLinkService` (`Generate Propfocus Site Visit Link From Record`) reads only these Config mappings (parent lookup, project, datetime, optional manager name/phone/email). Wire a Record-Triggered Flow on the configured Site Visit object — see [SETUP_GUIDE.md](./SETUP_GUIDE.md) §2.8. No package dependency on a specific Site Visit layout or field set.

**Critical:** Buyer Id (Lead and/or Opportunity) must be populated on records you test. Inbound REST matches `buyer_id` to the mapped field on the resolved parent.

---

## Outbound auth (External Credential — not in Config)

These values are **not** Propfocus Config fields. Configure after package install:

| Setting | Where | Production (package default) | Sandbox override |
| ------- | ----- | -------------------------- | ---------------- |
| Token endpoint | Setup → External Credentials → **Propfocus API** | `https://propfocus.in/api/oauth2/token` | `https://dev.propfocus.in/api/oauth2/token` |
| Client Id + Secret | Same → **Propfocus Principal** (Named Principal) | From Propfocus team | Dev credentials from Propfocus team |
| API base URL | Setup → Named Credentials → **Propfocus API** | `https://propfocus.in` | `https://dev.propfocus.in` |
| Embed Base URL | Propfocus Config → **Embed Base Url** (subscriber-editable) | `https://propfocus.in/embed/salesforce` | `https://dev.propfocus.in/embed/salesforce` |
| Named Credential in Config | Propfocus Config → **API Named Credential** | `Propfocus_API` | `Propfocus_API` |

Salesforce performs the OAuth `client_credentials` token exchange automatically; Apex never reads the client secret.

---

## Hosachiguru sandbox mappings

Pulled from org `hosachiguru-sandbox`. Use when configuring **Propfocus Config → Default**.

### Lead fields

| Propfocus concept     | Label                      | **API Name**            |
| --------------------- | -------------------------- | ----------------------- |
| Buyer Name            | Full Name                  | `Full_Name__c`          |
| UUID / Enquiry Ref    | Enquiry Ref No.            | `Enquiry_Ref_No__c`     |
| Pre-Sales Owner Name  | Presales Owner             | `Presales_Owner__c`     |
| Pre-Sales Owner Phone | _(confirm in UI)_          | TBD                     |
| Sales Owner Name      | Sales Person               | `Sales_Person__c`       |
| Sales Owner Phone     | Mobile Phone MC            | `Mobile_Phone__c`       |
| Lead Status           | Status                     | `Status`                |
| Lead Source           | Primary Source             | `LeadSource`            |
| Primary Project       | Primary Project Interested | `Project_Interested__c` |

### Opportunity fields

Map your org’s Opportunity buyer-id / project fields in Config. Package defaults for display/status:

| Propfocus concept | Typical starter |
| ----------------- | --------------- |
| Buyer Name | `Name` |
| Status | `StageName` |
| Project | org-specific (or `NextStep` for smoke tests) |
| Buyer Id | org-specific enquiry / buyer ref field |

### Site Visit object (`Site_Visit__c`)

| Concept             | API Name                |
| ------------------- | ----------------------- |
| Site Visit Object   | `Site_Visit__c`         |
| Lead lookup         | `Lead__c`               |
| Opportunity lookup  | `Opportunity__c` (add if missing) |
| Status              | `Status__c`             |
| Primary Project     | `Project_Interested__c` |
| Site visit type     | `sv_type__c`            |
| SV Team             | `Sv_Team__c`            |
| Site visit datetime | `Site_Visit_Date__c`    |

### Propfocus Config starter (Hosachiguru)

| Config field               | Value                                       |
| -------------------------- | ------------------------------------------- |
| Buyer Id Field             | `Enquiry_Ref_No__c`                         |
| Buyer Name Field           | `Full_Name__c`                              |
| Lead Status Field          | `Status`                                    |
| Project Field              | `Project_Interested__c`                     |
| Lead Source Field          | `LeadSource`                                |
| Pre-Sales Owner Name Field | `Presales_Owner__c`                         |
| Sales Owner Name Field     | `Sales_Person__c`                           |
| Sales Owner Phone Field    | `Mobile_Phone__c`                           |
| Opportunity Buyer Name Field | `Name`                                    |
| Opportunity Status Field   | `StageName`                                 |
| Opportunity Lookup Field   | `Opportunity__c`                            |
| Site Visit Object          | `Site_Visit__c`                             |
| Lead Lookup Field          | `Lead__c`                                   |
| Site Visit Status Field    | `Status__c`                                 |
| Site Visit Type Field      | `sv_type__c`                                |
| Site Visit Datetime Field  | `Site_Visit_Date__c`                        |
| Site Visit Team Field      | `Sv_Team__c`                                |
| API Named Credential       | `Propfocus_API`                             |
| Embed Base URL             | `https://dev.propfocus.in/embed/salesforce` _(Hosachiguru sandbox; production default is `https://propfocus.in/embed/salesforce`)_ |
| Organization Id            | _(from Propfocus team)_                     |

Outbound OAuth (Client Id/Secret, token URL): see **Outbound auth** section above — configured in External Credential, not Config.

### Package fields on Lead and Opportunity

| Label                              | API Name                               | Objects |
| ---------------------------------- | -------------------------------------- | ------- |
| Propfocus Link                     | `Propfocus_Link__c`                    | Lead, Opportunity |
| Propfocus Site Visit               | `Propfocus_Site_Visit__c`              | Lead, Opportunity |
| Propfocus Post Visit               | `Propfocus_Post_Visit__c`              | Lead, Opportunity |
| Propfocus Buyer Insights Available | `Propfocus_Buyer_Insights_Available__c` | Lead, Opportunity |

### Package child lookups

| Object | Parent lookups |
| ------ | -------------- |
| `Propfocus_Link__c` | `Lead__c`, `Opportunity__c` |
| `Propfocus_Call_Log__c` | `Lead__c`, `Opportunity__c` |
| `Propfocus_Sync_History__c` | `Lead__c`, `Opportunity__c` |
| `Propfocus_Site_Visit_Sync__c` | `Lead__c`, `Opportunity__c` |
