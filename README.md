# Propfocus AI Managed Package Project

This repository is a clean source project for the Propfocus AI Second-Generation Managed Package.

## Package Setup Required

Configure custom metadata record `Propfocus Config.Default` in subscriber org:

- `Api_Named_Credential__c` (must exactly match the Named Credential developer name: `Propfocus_API`)
- `Embed_Base_Url__c`
- `Organization_Id__c`

Without these values, API callouts and embed rendering will fail by design.

## Lead Field Dependencies

Lead custom fields required by this package are explicitly listed in
`manifest/package.xml` under `CustomField` members.

Use this manifest whenever generating or validating metadata package contents to avoid
missing Lead dependencies in subscriber/client orgs.

## 2GP Commands

Create package:

`sf package create --name "Propfocus AI" --package-type Managed --path force-app --target-dev-hub <devhub-alias> --namespace <namespace>`

Create package version:

`sf package version create --package "Propfocus AI" --installation-key-bypass --wait 30 --target-dev-hub <devhub-alias>`
