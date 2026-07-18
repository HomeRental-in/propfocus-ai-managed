# JWT access token helper (local sandbox / Postman)

Generates a Salesforce `access_token` using the **JWT Bearer** OAuth flow.

**Sandbox-only testing.** For production inbound, Propfocus generates the key pair, keeps `server.key`, and sends the customer only `server.crt`. Do not use a locally generated key as a stand-in for production, and never send `server.key` to anyone.

## Prerequisites

1. External Client App in your Salesforce org with a certificate uploaded.
2. RSA private key file: `server.key` matching that cert (same directory as this script).
3. Node.js 18+.

## Setup

```powershell
cd propfocus-sf-jwt
npm install jsonwebtoken axios
```

For local sandbox tests only, you may generate a **separate** key pair (see [docs/JWT_SETUP.txt](../docs/JWT_SETUP.txt) OpenSSL commands). Upload that pair's `server.crt` to your sandbox app.  
**Do not commit** `server.key` or `server.crt` — they are gitignored.

## Run

Set environment variables, then run:

```powershell
$env:SF_CLIENT_ID = "<Connected_App_Consumer_Key>"
$env:SF_USERNAME  = "propfocus.integration@yourcompany.com"
$env:SF_LOGIN_URL = "https://test.salesforce.com"   # or https://login.salesforce.com
node run.js
```

Output: `access_token` and `instance_url` for Postman or backend testing.
