@IsTest
private class PropfocusConfigServiceTest {
  @IsTest
  static void testGetInboundEndpoint_returnsUrl() {
    Test.startTest();
    String endpoint = PropfocusConfigService.getInboundEndpoint();
    Test.stopTest();

    System.assertNotEquals(null, endpoint);
    System.assert(
      endpoint.contains('/services/apexrest/PropfocusAI/propfocus/events/')
    );
  }

  @IsTest
  static void testGetUiConfiguration_FallbackInTests() {
    Test.startTest();
    PropfocusConfigService.Config cfg = PropfocusConfigService.getUiConfiguration();
    Test.stopTest();

    System.assertNotEquals(null, cfg);
    System.assert(!String.isBlank(cfg.apiNamedCredential));
    System.assert(!String.isBlank(cfg.embedBaseUrl));
    System.assert(!String.isBlank(cfg.organizationId));
    System.assert(!String.isBlank(cfg.logoUrl));
  }

  @IsTest
  static void testConnection_Success() {
    PropfocusOAuthService.clearCacheForTests();
    PropfocusHttpCalloutMock mock = new PropfocusHttpCalloutMock();
    mock.apiStatusCode = 200;
    mock.apiBody = '{"success":true}';
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    PropfocusConfigService.ConnectionCheckResult result = PropfocusConfigService.testConnection();
    Test.stopTest();

    System.assertEquals(true, result.success);
    System.assertEquals(200, result.statusCode);
  }

  @IsTest
  static void resolveNamedCredential_addsPackageNamespaceWhenInstalled() {
    String ns = PropfocusConfigService.packageNamespace();
    String resolved = PropfocusConfigService.resolveNamedCredential(
      'Propfocus_API'
    );

    if (String.isBlank(ns)) {
      System.assertEquals('Propfocus_API', resolved);
    } else {
      System.assertEquals(ns + '__Propfocus_API', resolved);
    }

    System.assertEquals(
      'PropfocusAI__Propfocus_API',
      PropfocusConfigService.resolveNamedCredential(
        'PropfocusAI__Propfocus_API'
      )
    );
  }

  @IsTest
  static void testConnection_FailureStatus() {
    PropfocusOAuthService.clearCacheForTests();
    PropfocusHttpCalloutMock mock = new PropfocusHttpCalloutMock();
    mock.apiStatusCode = 503;
    mock.apiBody = '{"success":false}';
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    PropfocusConfigService.ConnectionCheckResult result = PropfocusConfigService.testConnection();
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assertEquals(503, result.statusCode);
  }
}
