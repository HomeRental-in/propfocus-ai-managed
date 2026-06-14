# Field API Names & Mappings

How to find Lead and Site Visit field API names, plus Hosachiguru sandbox reference values.

---

## Find field API names in Salesforce UI

### Method 1: Object Manager (recommended)

1. Setup → **Object Manager → Lead**
2. **Fields & Relationships** → click a field
3. Read **Field Name** — that is the API name

Custom fields end in `__c`. Standard fields do not (e.g. `Status`, `LeadSource`).

### Method 2: Lightning App Builder

Lead record → gear → **Edit Page** → click a field → API Name in right panel.

### Method 3: Site Visit object

Setup → Object Manager → **Site Visit** (`Site_Visit__c`) → Fields & Relationships.

### Method 4: CLI

```powershell
sf data query --query "SELECT QualifiedApiName, Label FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName = 'Lead' AND QualifiedApiName LIKE '%__c'" --target-org <alias> --use-tooling-api
```

---

## Mapping checklist

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

Enter API names in **Setup → Custom Metadata Types → Propfocus Config → Default**.

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

### Site Visit object (`Site_Visit__c`)

| Concept             | API Name                |
| ------------------- | ----------------------- |
| Site Visit Object   | `Site_Visit__c`         |
| Lead lookup         | `Lead__c`               |
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
| Site Visit Object          | `Site_Visit__c`                             |
| Lead Lookup Field          | `Lead__c`                                   |
| Site Visit Status Field    | `Status__c`                                 |
| Site Visit Type Field      | `sv_type__c`                                |
| Site Visit Datetime Field  | `Site_Visit_Date__c`                        |
| Site Visit Team Field      | `Sv_Team__c`                                |
| API Named Credential       | `Propfocus_API`                             |
| Embed Base URL             | `https://dev.propfocus.in/embed/salesforce` |
| OAuth Token URL            | `https://dev.propfocus.in/api/oauth2/token` |
| OAuth Grant Type           | `client_credentials`                        |
| Organization Id            | _(from Propfocus team)_                     |

### Package Lead fields (already in org)

| Label                | API Name                  |
| -------------------- | ------------------------- |
| Propfocus Link       | `Propfocus_Link__c`       |
| Propfocus Site Visit | `Propfocus_Site_Visit__c` |
