import fs from "fs";
import jwt from "jsonwebtoken";
import axios from "axios";

const CLIENT_ID = process.env.SF_CLIENT_ID;
const USERNAME = process.env.SF_USERNAME;
const LOGIN_URL = process.env.SF_LOGIN_URL || "https://login.salesforce.com";

if (!CLIENT_ID || !USERNAME) {
  console.error("Set SF_CLIENT_ID and SF_USERNAME environment variables.");
  process.exit(1);
}

const privateKey = fs.readFileSync("./server.key", "utf8");

const token = jwt.sign(
  {
    iss: CLIENT_ID,
    sub: USERNAME,
    aud: LOGIN_URL
  },
  privateKey,
  { algorithm: "RS256", expiresIn: "3m" }
);

const params = new URLSearchParams({
  grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
  assertion: token
});

const { data } = await axios.post(
  `${LOGIN_URL}/services/oauth2/token`,
  params.toString(),
  { headers: { "Content-Type": "application/x-www-form-urlencoded" } }
);

console.log("access_token:", data.access_token);
console.log("instance_url:", data.instance_url);
