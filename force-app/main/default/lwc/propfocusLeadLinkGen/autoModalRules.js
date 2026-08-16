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
