@IsTest
private class PropfocusOAuthServiceTest {
  private class TokenMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody(
        '{"access_token":"test-token-123","token_type":"Bearer","expires_in":3600}'
      );
      return res;
    }
  }

  @IsTest
  static void getAccessToken_cachesBearerToken() {
    PropfocusOAuthService.clearCacheForTests();
    if (!PropfocusOAuthService.isOAuthConfigured()) {
      PropfocusOAuthService.cacheToken('test-token-123', 3600);
      Test.startTest();
      String first = PropfocusOAuthService.getAccessToken();
      String second = PropfocusOAuthService.getAccessToken();
      Test.stopTest();
      System.assertEquals('test-token-123', first);
      System.assertEquals(first, second);
      return;
    }

    Test.setMock(HttpCalloutMock.class, new TokenMock());

    Test.startTest();
    String first = PropfocusOAuthService.getAccessToken();
    String second = PropfocusOAuthService.getAccessToken();
    Test.stopTest();

    System.assertEquals('test-token-123', first);
    System.assertEquals(first, second);
  }

  @IsTest
  static void applyAuthorization_setsBearerHeaderWhenConfigured() {
    PropfocusOAuthService.clearCacheForTests();
    Test.setMock(HttpCalloutMock.class, new TokenMock());

    HttpRequest req = new HttpRequest();
    req.setEndpoint('https://example.test/api');
    req.setMethod('GET');

    Test.startTest();
    PropfocusOAuthService.applyAuthorization(req);
    Test.stopTest();

    if (PropfocusOAuthService.isOAuthConfigured()) {
      System.assertEquals(
        'Bearer test-token-123',
        req.getHeader('Authorization')
      );
    } else {
      System.assertEquals(null, req.getHeader('Authorization'));
    }
  }

  @IsTest
  static void getAccessToken_supportsWrappedDataResponse() {
    PropfocusOAuthService.clearCacheForTests();
    if (!PropfocusOAuthService.isOAuthConfigured()) {
      return;
    }

    Test.setMock(HttpCalloutMock.class, new WrappedTokenMock());

    Test.startTest();
    String token = PropfocusOAuthService.getAccessToken();
    Test.stopTest();

    System.assertEquals('wrapped-token-456', token);
  }

  private class WrappedTokenMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody(
        '{"success":true,"data":{"access_token":"wrapped-token-456","token_type":"Bearer","expires_in":3600}}'
      );
      return res;
    }
  }

  @IsTest
  static void getAccessToken_missingTokenInResponse_throws() {
    PropfocusOAuthService.clearCacheForTests();
    if (!PropfocusOAuthService.isOAuthConfigured()) {
      return;
    }

    Test.setMock(HttpCalloutMock.class, new ErrorTokenMock());

    Boolean failed = false;
    Test.startTest();
    try {
      PropfocusOAuthService.getAccessToken();
    } catch (PropFocusServiceException e) {
      failed = true;
      System.assert(e.getMessage().contains('access_token'));
    }
    Test.stopTest();

    System.assertEquals(true, failed);
  }

  private class ErrorTokenMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setBody('{"token_type":"Bearer","expires_in":3600}');
      return res;
    }
  }
}
