// Resolves a server error into a short, plain-English toast message.
// Apex throws user-facing messages (AuraHandledException) for known causes;
// anything technical or unrecognized falls back to the generic support line.

export const GENERIC_ERROR_MESSAGE =
  "Something went wrong. Please contact the Propfocus support team.";

const CONFIG_INCOMPLETE_MESSAGE =
  "Propfocus setup is incomplete. Ask your admin to finish the Propfocus configuration.";
const CONNECTION_MESSAGE =
  "Couldn't connect to Propfocus. Ask your admin to check the Propfocus connection settings.";

// Technical fragments that must never surface to a rep.
const INTERNAL_MARKERS =
  /script-thrown|internal salesforce|internal server|stack ?trace|null ?pointer|system\.[a-z]+exception/i;
const CONNECTION_MARKERS =
  /external credential|oauth token|unable to fetch|invalid_client|unauthorized|callout/i;
const CONFIG_MARKERS = /propfocus configuration missing/i;

export function resolveErrorMessage(error) {
  const raw =
    error?.body?.message ||
    (Array.isArray(error?.body) ? error.body[0]?.message : "") ||
    error?.message ||
    "";
  const message = String(raw).trim();
  if (!message) {
    return GENERIC_ERROR_MESSAGE;
  }
  if (CONFIG_MARKERS.test(message)) {
    return CONFIG_INCOMPLETE_MESSAGE;
  }
  if (CONNECTION_MARKERS.test(message)) {
    return CONNECTION_MESSAGE;
  }
  if (INTERNAL_MARKERS.test(message) || message.length > 220) {
    return GENERIC_ERROR_MESSAGE;
  }
  return message;
}
