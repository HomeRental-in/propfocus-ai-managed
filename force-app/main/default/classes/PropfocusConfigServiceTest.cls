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

  // The admin panel flags configured statuses that match no picklist value.
  // Its normalizer must agree with normalizeStatusToken in autoModalRules.js,
  // or it would warn about statuses the runtime happily matches.
  @IsTest
  static void normalizeStatusToken_matchesJsRules() {
    System.assertEquals(
      'not connected',
      PropfocusConfigService.normalizeStatusToken('  Not_Connected ')
    );
    System.assertEquals(
      'site visit planned',
      PropfocusConfigService.normalizeStatusToken('Site-Visit-Planned')
    );
    System.assertEquals(
      'not connected',
      PropfocusConfigService.normalizeStatusToken('NOT__CONNECTED')
    );
    System.assertEquals('', PropfocusConfigService.normalizeStatusToken(null));
  }

  @IsTest
  static void parseStatusTokens_splitsNormalizesAndDedupes() {
    List<String> tokens = PropfocusConfigService.parseStatusTokens(
      'Not Connected, Contacted ,Qualified, not_connected'
    );
    System.assertEquals(
      new List<String>{ 'not connected', 'contacted', 'qualified' },
      tokens,
      'Expected normalized, de-duplicated tokens in order'
    );
  }

  @IsTest
  static void parseStatusTokens_handlesBlankInput() {
    System.assertEquals(
      0,
      PropfocusConfigService.parseStatusTokens(null).size()
    );
    System.assertEquals(0, PropfocusConfigService.parseStatusTokens('').size());
    System.assertEquals(
      0,
      PropfocusConfigService.parseStatusTokens('  ,  ').size()
    );
  }

  @IsTest
  static void getStatusConfigWarnings_returnsListWithoutError() {
    Test.startTest();
    List<PropfocusConfigService.StatusConfigWarning> warnings = PropfocusConfigService.getStatusConfigWarnings();
    Test.stopTest();

    System.assertNotEquals(null, warnings);
    // The packaged Default config ships every status list blank, so nothing
    // should be flagged out of the box.
    System.assertEquals(
      0,
      warnings.size(),
      'Blank status config must not raise warnings'
    );
  }
}
