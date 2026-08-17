@IsTest
public class PropfocusHttpCalloutMock implements HttpCalloutMock {
  public Integer apiStatusCode = 200;
  public String apiBody = '{"success":true}';
  public String lastApiRequestBody;
  public String lastApiIdempotencyKey;
  public String lastApiEndpoint;

  public HTTPResponse respond(HTTPRequest req) {
    if (isTokenRequest(req)) {
      HttpResponse tokenResponse = new HttpResponse();
      tokenResponse.setStatusCode(200);
      tokenResponse.setHeader('Content-Type', 'application/json');
      tokenResponse.setBody(
        '{"access_token":"test-token","token_type":"Bearer","expires_in":3600}'
      );
      return tokenResponse;
    }

    // Only capture Propfocus's own callouts (they go through the Named
    // Credential, i.e. a "callout:" endpoint). This prevents unrelated
    // subscriber-org integrations (e.g. marketing callouts to direct URLs)
    // from overwriting the captured Propfocus request during tests.
    String endpoint = req.getEndpoint();
    if (endpoint != null && endpoint.startsWith('callout:')) {
      lastApiRequestBody = req.getBody();
      lastApiIdempotencyKey = req.getHeader('Idempotency-Key');
      lastApiEndpoint = endpoint;
    }
    HttpResponse apiResponse = new HttpResponse();
    apiResponse.setStatusCode(apiStatusCode);
    apiResponse.setHeader('Content-Type', 'application/json');
    apiResponse.setBody(apiBody);
    return apiResponse;
  }

  private static Boolean isTokenRequest(HttpRequest req) {
    String body = req.getBody();
    String endpoint = req.getEndpoint();
    return (body != null && body.contains('grant_type')) ||
      (endpoint != null && endpoint.contains('/oauth2/token'));
  }
}
