# Propfocus AI — Documentation

| Document                                                               | Audience             | Purpose                                     |
| ---------------------------------------------------------------------- | -------------------- | ------------------------------------------- |
| [E2E_INSTALLATION.md](./E2E_INSTALLATION.md)                           | Salesforce admin     | **Start here (new org)** — full e2e, upgrade, uninstall |
| [SETUP_GUIDE.md](./SETUP_GUIDE.md)                                     | Salesforce admin     | Install + configure + test (w/ examples)    |
| [FAQ.txt](./FAQ.txt)                                                   | Admin / stakeholders | FAQ, upgrades, troubleshooting              |
| [FIELDS.md](./FIELDS.md)                                               | Admin                | Lead + Opportunity + Site Visit field maps  |
| [OUTBOUND.md](./OUTBOUND.md)                                           | Security / backend   | SF → Propfocus payloads, PII, residency/DPA |
| [INBOUND.md](./INBOUND.md)                                             | Propfocus backend    | REST API, auth, sync, Postman fixes         |
| [JWT_SETUP.txt](./JWT_SETUP.txt)                                       | Backend / DevOps     | JWT Bearer token flow (inbound)             |
| [DEV_GUIDE.md](./DEV_GUIDE.md)                                         | Dev team             | CLI, Dev Hub, package build, done checklist |
| [DEV_HUB_SETUP.md](./DEV_HUB_SETUP.md)                                 | Dev team             | Detailed Dev Hub + namespace linking        |
| [../propfocus-admin-setup-guide.md](../propfocus-admin-setup-guide.md) | Admin                | Short checklist                             |

## Outbound vs inbound auth (quick reference)

| Direction | Configure in | Secret storage |
| --------- | ------------ | -------------- |
| SF → Propfocus | **External Credential** (`Propfocus API` → `Propfocus Principal`) + Named Credential `Propfocus_API` | Client Id/Secret encrypted in Named Principal |
| Propfocus → SF | **External Client App** + JWT cert | Propfocus generates keys, holds `server.key`; customer uploads `server.crt` only (365-day expiry) |

Propfocus Config (CMDT) holds Organization Id, embed URL, and field mappings — **not** outbound OAuth credentials.

**Security:** Never commit passwords, OAuth secrets, JWT private keys, or access tokens.
