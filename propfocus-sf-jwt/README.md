# JWT access token helper (local dev / Postman)

Generates a Salesforce `access_token` using the **JWT Bearer** OAuth flow.

## Prerequisites

1. Connected App in your Salesforce org with a certificate uploaded.
2. RSA private key file: `server.key` (same directory as this script).
3. Node.js 18+.

## Setup

```powershell
cd propfocus-sf-jwt
npm install jsonwebtoken axios
```

Create `server.key` locally (see [docs/JWT_SETUP.txt](../docs/JWT_SETUP.txt)).  
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
