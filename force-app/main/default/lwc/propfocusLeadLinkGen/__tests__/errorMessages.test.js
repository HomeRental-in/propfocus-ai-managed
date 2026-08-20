import {
  resolveErrorMessage,
  GENERIC_ERROR_MESSAGE
} from "../errorMessages";

describe("resolveErrorMessage", () => {
  const body = (message) => ({ body: { message } });

  it("passes plain user-facing messages through", () => {
    expect(
      resolveErrorMessage(
        body(
          "Your user isn't registered as a broker in Propfocus. Please contact the Propfocus support team."
        )
      )
    ).toContain("registered as a broker");
    expect(
      resolveErrorMessage(body("This record has no Buyer ID yet."))
    ).toContain("Buyer ID");
  });

  it("maps configuration-missing messages to the plain setup message", () => {
    expect(
      resolveErrorMessage(body("Propfocus configuration missing: Organization_Id__c"))
    ).toBe(
      "Propfocus setup is incomplete. Ask your admin to finish the Propfocus configuration."
    );
  });

  it("maps credential / connection failures to the connection message", () => {
    for (const technical of [
      "The external credential isn't fully configured.",
      "Unable to fetch the OAuth token. Error: invalid_client.",
      "Callout failed: unauthorized"
    ]) {
      expect(resolveErrorMessage(body(technical))).toBe(
        "Couldn't connect to Propfocus. Ask your admin to check the Propfocus connection settings."
      );
    }
  });

  it("hides internal/technical messages behind the generic message", () => {
    expect(resolveErrorMessage(body("Script-thrown exception"))).toBe(
      GENERIC_ERROR_MESSAGE
    );
    expect(
      resolveErrorMessage(body("System.NullPointerException: null"))
    ).toBe(GENERIC_ERROR_MESSAGE);
    expect(resolveErrorMessage(body("x".repeat(300)))).toBe(
      GENERIC_ERROR_MESSAGE
    );
  });

  it("falls back to generic for empty/absent errors", () => {
    expect(resolveErrorMessage(undefined)).toBe(GENERIC_ERROR_MESSAGE);
    expect(resolveErrorMessage({})).toBe(GENERIC_ERROR_MESSAGE);
    expect(resolveErrorMessage(body("  "))).toBe(GENERIC_ERROR_MESSAGE);
  });

  it("supports array-shaped error bodies", () => {
    expect(
      resolveErrorMessage({ body: [{ message: "This project isn't available in Propfocus." }] })
    ).toContain("project");
  });
});
