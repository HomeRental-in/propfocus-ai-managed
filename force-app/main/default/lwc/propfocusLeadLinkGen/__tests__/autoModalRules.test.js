import {
  normalizeStatusToken,
  parseStatusSet,
  pickAutoModalAction,
  isAutoCreateReady,
  resolveDefaultMicrositeLeadType
} from "../autoModalRules";

describe("normalizeStatusToken", () => {
  it("lowercases, trims, and collapses separators", () => {
    expect(normalizeStatusToken("  Not_Connected ")).toBe("not connected");
    expect(normalizeStatusToken("Site-Visit-Planned")).toBe(
      "site visit planned"
    );
  });

  it("handles null/undefined", () => {
    expect(normalizeStatusToken(null)).toBe("");
    expect(normalizeStatusToken(undefined)).toBe("");
  });
});

describe("parseStatusSet", () => {
  it("parses a comma-separated list into normalized tokens", () => {
    const set = parseStatusSet("Not Connected, Contacted ,Qualified");
    expect(set.has("not connected")).toBe(true);
    expect(set.has("contacted")).toBe(true);
    expect(set.has("qualified")).toBe(true);
    expect(set.size).toBe(3);
  });

  it("returns an empty set for blank/undefined/separators-only", () => {
    expect(parseStatusSet("").size).toBe(0);
    expect(parseStatusSet(null).size).toBe(0);
    expect(parseStatusSet("  ,  ").size).toBe(0);
  });
});

describe("pickAutoModalAction", () => {
  const base = {
    micrositeStatuses: parseStatusSet("contacted"),
    siteVisitStatuses: parseStatusSet("site visit planned"),
    postVisitStatuses: parseStatusSet("visited"),
    hasMicrosite: false,
    hasSiteVisit: false,
    hasPostVisit: false,
    siteVisitEnabled: true,
    postVisitEnabled: true
  };

  it("opens microsite when status matches and no microsite exists", () => {
    expect(pickAutoModalAction("contacted", base)).toBe("microsite");
  });

  it("does not open microsite when one already exists", () => {
    expect(
      pickAutoModalAction("contacted", { ...base, hasMicrosite: true })
    ).toBeNull();
  });

  it("opens site visit when its status matches and no link exists", () => {
    expect(pickAutoModalAction("site visit planned", base)).toBe("siteVisit");
  });

  it("does not open site visit when a link already exists", () => {
    expect(
      pickAutoModalAction("site visit planned", { ...base, hasSiteVisit: true })
    ).toBeNull();
  });

  it("opens post visit when its status matches and no link exists", () => {
    expect(pickAutoModalAction("visited", base)).toBe("postVisit");
  });

  it("respects precedence microsite > siteVisit > postVisit on overlap", () => {
    const overlap = {
      ...base,
      micrositeStatuses: parseStatusSet("contacted"),
      siteVisitStatuses: parseStatusSet("contacted"),
      postVisitStatuses: parseStatusSet("contacted")
    };
    expect(pickAutoModalAction("contacted", overlap)).toBe("microsite");
    expect(
      pickAutoModalAction("contacted", { ...overlap, hasMicrosite: true })
    ).toBe("siteVisit");
    expect(
      pickAutoModalAction("contacted", {
        ...overlap,
        hasMicrosite: true,
        hasSiteVisit: true
      })
    ).toBe("postVisit");
  });

  it("does not open site visit when its feature is disabled", () => {
    expect(
      pickAutoModalAction("site visit planned", {
        ...base,
        siteVisitEnabled: false
      })
    ).toBeNull();
  });

  it("does not open post visit when its feature is disabled", () => {
    expect(
      pickAutoModalAction("visited", { ...base, postVisitEnabled: false })
    ).toBeNull();
  });

  it("returns null when the status matches nothing configured", () => {
    expect(pickAutoModalAction("qualified", base)).toBeNull();
  });

  it("returns null for empty/undefined status", () => {
    expect(pickAutoModalAction("", base)).toBeNull();
    expect(pickAutoModalAction(undefined, base)).toBeNull();
  });

  it("tolerates missing state", () => {
    expect(pickAutoModalAction("contacted", undefined)).toBeNull();
  });
});

describe("resolveDefaultMicrositeLeadType", () => {
  const rnr = parseStatusSet("Not Connected, Open");

  it("defaults to rnr when the status is in the configured RNR set", () => {
    expect(resolveDefaultMicrositeLeadType("Not Connected", rnr)).toBe("rnr");
    expect(resolveDefaultMicrositeLeadType("open", rnr)).toBe("rnr");
  });

  it("is case/spacing-insensitive", () => {
    expect(resolveDefaultMicrositeLeadType("  NOT_CONNECTED ", rnr)).toBe("rnr");
  });

  it("defaults to new for any other status", () => {
    expect(resolveDefaultMicrositeLeadType("Contacted", rnr)).toBe("new");
    expect(resolveDefaultMicrositeLeadType("Qualified", rnr)).toBe("new");
  });

  it("defaults to new when no RNR statuses are configured", () => {
    expect(resolveDefaultMicrositeLeadType("Not Connected", new Set())).toBe(
      "new"
    );
    expect(resolveDefaultMicrositeLeadType("Not Connected", undefined)).toBe(
      "new"
    );
  });

  it("defaults to new for empty status", () => {
    expect(resolveDefaultMicrositeLeadType("", rnr)).toBe("new");
    expect(resolveDefaultMicrositeLeadType(null, rnr)).toBe("new");
  });
});

describe("isAutoCreateReady", () => {
  it("microsite: needs a valid name and at least one project", () => {
    expect(
      isAutoCreateReady("microsite", { nameValid: true, projectCount: 1 })
    ).toBe(true);
    expect(
      isAutoCreateReady("microsite", { nameValid: true, projectCount: 0 })
    ).toBe(false);
    expect(
      isAutoCreateReady("microsite", { nameValid: false, projectCount: 2 })
    ).toBe(false);
  });

  it("siteVisit: needs a valid name, a project, and a datetime", () => {
    expect(
      isAutoCreateReady("siteVisit", {
        nameValid: true,
        siteVisitProject: "Project A",
        siteVisitDateTime: "2026-08-15T10:00"
      })
    ).toBe(true);
    expect(
      isAutoCreateReady("siteVisit", {
        nameValid: true,
        siteVisitProject: "",
        siteVisitDateTime: "2026-08-15T10:00"
      })
    ).toBe(false);
  });

  it("postVisit: needs a project and a selected configuration", () => {
    expect(
      isAutoCreateReady("postVisit", {
        nameValid: true,
        postVisitProject: "Project A",
        postVisitConfigCount: 1
      })
    ).toBe(true);
    // The auto path never pre-selects a configuration → not ready.
    expect(
      isAutoCreateReady("postVisit", {
        nameValid: true,
        postVisitProject: "Project A",
        postVisitConfigCount: 0
      })
    ).toBe(false);
  });

  it("returns false for unknown action or missing state", () => {
    expect(isAutoCreateReady("microsite", undefined)).toBe(false);
    expect(isAutoCreateReady("other", { nameValid: true })).toBe(false);
  });
});
