// Framework-free helpers for the auto-open-modal feature so the decision logic
// can be unit-tested without mounting the LWC. Imported by propfocusLeadLinkGen.

export function normalizeStatusToken(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[_-]+/g, " ");
}

// Parses an admin-entered comma-separated status list into a normalized Set.
export function parseStatusSet(raw) {
  return new Set(
    String(raw || "")
      .split(",")
      .map((token) => normalizeStatusToken(token))
      .filter(Boolean)
  );
}

// Default microsite Lead Type for a lead status. Statuses in the admin-
// configured RNR Set (Rnr_Microsite_Statuses__c) default to "rnr"; everything
// else defaults to "new". `rnrStatuses` is a Set of normalized tokens.
export function resolveDefaultMicrositeLeadType(leadStatus, rnrStatuses) {
  const normalized = normalizeStatusToken(leadStatus);
  if (normalized && rnrStatuses?.has(normalized)) {
    return "rnr";
  }
  return "new";
}

// Derives "does this buyer already have a link of each type" from the
// buyer-scoped history (which includes links created from the bot/dashboard
// or on sibling records, where the record's own link fields stay empty).
// `historyItems` are the rows returned by getLinkHistory ({ type, ... }).
export function resolveJourneyFlags(historyItems) {
  const flags = { hasMicrosite: false, hasSiteVisit: false, hasPostVisit: false };
  for (const item of historyItems || []) {
    const type = String(item?.type || "").toLowerCase();
    if (type.includes("microsite")) {
      flags.hasMicrosite = true;
    } else if (type.includes("post visit")) {
      flags.hasPostVisit = true;
    } else if (type.includes("site visit")) {
      flags.hasSiteVisit = true;
    }
  }
  return flags;
}

// Pure check: are all mandatory fields for an auto-opened action already
// populated, so the link can be created without showing the modal? `state`
// carries the already-validated pieces from the component.
export function isAutoCreateReady(action, state) {
  const s = state || {};
  if (!s.nameValid) {
    return false;
  }
  if (action === "microsite") {
    return (s.projectCount || 0) > 0;
  }
  if (action === "siteVisit") {
    return Boolean(s.siteVisitProject) && Boolean(s.siteVisitDateTime);
  }
  if (action === "postVisit") {
    return Boolean(s.postVisitProject) && (s.postVisitConfigCount || 0) > 0;
  }
  return false;
}

// Pure decision: which modal (if any) should auto-open for `status`, in
// precedence order microsite -> site visit -> post visit. A modal is a
// candidate only when the status is in its configured Set, its feature is
// enabled, and its link does not exist yet. `status` must already be
// normalized. Returns "microsite" | "siteVisit" | "postVisit" | null.
export function pickAutoModalAction(status, state) {
  const s = state || {};
  if (status && s.micrositeStatuses?.has(status) && !s.hasMicrosite) {
    return "microsite";
  }
  if (
    status &&
    s.siteVisitEnabled &&
    s.siteVisitStatuses?.has(status) &&
    !s.hasSiteVisit
  ) {
    return "siteVisit";
  }
  if (
    status &&
    s.postVisitEnabled &&
    s.postVisitStatuses?.has(status) &&
    !s.hasPostVisit
  ) {
    return "postVisit";
  }
  return null;
}
