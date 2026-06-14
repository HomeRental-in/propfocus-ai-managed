@IsTest
public class PropfocusHttpCalloutMock implements HttpCalloutMock {
  public Integer apiStatusCode = 200;
  public String apiBody = '{"success":true}';
  public String lastApiRequestBody;

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

    lastApiRequestBody = req.getBody();
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
