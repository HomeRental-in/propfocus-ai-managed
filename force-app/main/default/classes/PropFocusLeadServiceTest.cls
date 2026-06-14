@IsTest
private class PropFocusLeadServiceTest {
  private static PropfocusHttpCalloutMock apiMock;

  private static Lead makeLead() {
    return PropfocusTestUtil.createLead('Coverage Buyer');
  }

  private static void setApiMock(Integer statusCode, String responseBody) {
    PropfocusOAuthService.clearCacheForTests();
    apiMock = new PropfocusHttpCalloutMock();
    apiMock.apiStatusCode = statusCode;
    apiMock.apiBody = responseBody;
    Test.setMock(HttpCalloutMock.class, apiMock);
  }

  @IsTest
  static void generateMicrositeLink_success_updatesLeadAndHistory() {
    Lead ld = makeLead();
    setApiMock(
      200,
      '{"success":true,"micrositeUrl":"https://example.test/micro"}'
    );

    Test.startTest();
    String url = PropFocusLeadService.generateMicrositeLink(
      ld.Id,
      'Client 1',
      new List<String>{ 'Project A', 'Project B' }
    );
    Test.stopTest();

    System.assertEquals(
      'https://example.test/micro',
      url,
      'Unexpected microsite URL: ' + url
    );
    Lead updatedLead = [
      SELECT Propfocus_Link__c, Propfocus_Buyer_Insights_Available__c
      FROM Lead
      WHERE Id = :ld.Id
    ];
    System.assertEquals(
      'https://example.test/micro',
      updatedLead.Propfocus_Link__c
    );
    System.assertEquals(
      true,
      updatedLead.Propfocus_Buyer_Insights_Available__c
    );

    List<Propfocus_Link__c> historyRows = [
      SELECT Type__c, Project_Name__c, URL__c, Status__c
      FROM Propfocus_Link__c
      WHERE Lead__c = :ld.Id
    ];
    System.assertEquals(1, historyRows.size());
    System.assertEquals('Microsite', historyRows[0].Type__c);
    System.assertEquals('Project A, Project B', historyRows[0].Project_Name__c);
    System.assertEquals('https://example.test/micro', historyRows[0].URL__c);
    System.assertEquals('Generated', historyRows[0].Status__c);

    Map<String, Object> requestBody = (Map<String, Object>) JSON.deserializeUntyped(
      apiMock.lastApiRequestBody
    );
    System.assertEquals(
      String.valueOf(ld.Id),
      requestBody.get('salesforce_lead_id')
    );
  }

  @IsTest
  static void generateMicrositeLink_httpError_throwsHandledException() {
    Lead ld = makeLead();
    setApiMock(503, '{"success":false}');

    Boolean firstCallFailedAsExpected = false;
    Test.startTest();
    try {
      PropFocusLeadService.generateMicrositeLink(
        ld.Id,
        'Client 1',
        new List<String>{ 'Project A' }
      );
    } catch (AuraHandledException e) {
      firstCallFailedAsExpected = true;
      String errorMessage = e.getMessage();
      System.assert(
        errorMessage != null &&
        (errorMessage.contains('Propfocus API failed with status 503') ||
        errorMessage.contains('Script-thrown exception'))
      );
    }
    Test.stopTest();
    System.assert(
      firstCallFailedAsExpected,
      'Expected non-200 status to throw AuraHandledException'
    );
  }

  @IsTest
  static void generateMicrositeLink_missingMicrositeUrl_throwsHandledException() {
    Lead ld = makeLead();
    setApiMock(200, '{"success":true}');

    Boolean secondCallFailedAsExpected = false;
    Test.startTest();
    try {
      PropFocusLeadService.generateMicrositeLink(
        ld.Id,
        'Client 1',
        new List<String>{ 'Project A' }
      );
    } catch (AuraHandledException e2) {
      secondCallFailedAsExpected = true;
      String errorMessage = e2.getMessage();
      System.assert(
        errorMessage != null &&
        (errorMessage.contains('Microsite URL not returned by Propfocus') ||
        errorMessage.contains('Script-thrown exception'))
      );
    }
    Test.stopTest();
    System.assert(
      secondCallFailedAsExpected,
      'Expected missing micrositeUrl to throw AuraHandledException'
    );
  }

  @IsTest
  static void generateSiteVisitWithProjectAndDateTime_success_updatesLeadAndHistory() {
    Lead ld = makeLead();
    Datetime requestedDt = Datetime.newInstance(2026, 1, 15, 9, 30, 0);
    setApiMock(
      200,
      '{"success":true,"data":{"sv_url":"https://example.test/sv"}}'
    );

    Test.startTest();
    String svUrl = PropFocusLeadService.generateSiteVisitWithProjectAndDateTime(
      ld.Id,
      'Buyer Override',
      'Project Override',
      requestedDt
    );
    Test.stopTest();

    System.assertEquals('https://example.test/sv', svUrl);
    Lead updatedLead = [
      SELECT Propfocus_Site_Visit__c
      FROM Lead
      WHERE Id = :ld.Id
    ];
    System.assertEquals(
      'https://example.test/sv',
      updatedLead.Propfocus_Site_Visit__c
    );

    List<Propfocus_Link__c> historyRows = [
      SELECT Type__c, Project_Name__c, URL__c, Status__c
      FROM Propfocus_Link__c
      WHERE Lead__c = :ld.Id
      ORDER BY CreatedDate DESC
    ];
    System.assert(!historyRows.isEmpty());
    System.assertEquals('Site Visit', historyRows[0].Type__c);
    System.assertEquals('Project Override', historyRows[0].Project_Name__c);
    System.assertEquals('https://example.test/sv', historyRows[0].URL__c);
    System.assertEquals('Confirmed', historyRows[0].Status__c);
  }

  @IsTest
  static void generateSiteVisitWithProjectAndDateTime_httpError_throwsHandledException() {
    Lead ld = makeLead();
    setApiMock(500, '{"success":false,"message":"error"}');

    Boolean httpErrorFailedAsExpected = false;
    Test.startTest();
    try {
      PropFocusLeadService.generateSiteVisitWithProjectAndDateTime(
        ld.Id,
        'Buyer X',
        'Project X',
        System.now()
      );
    } catch (AuraHandledException e) {
      httpErrorFailedAsExpected = true;
      String errorMessage = e.getMessage();
      System.assert(
        errorMessage != null &&
        (errorMessage.contains('Propfocus API failed with status 500') ||
        errorMessage.contains('Script-thrown exception'))
      );
    }
    Test.stopTest();
    System.assert(
      httpErrorFailedAsExpected,
      'Expected non-200 status to throw AuraHandledException'
    );
  }

  @IsTest
  static void generateSiteVisitWithProjectAndDateTime_missingSvUrl_throwsHandledException() {
    Lead ld = makeLead();
    setApiMock(200, '{"success":true,"data":{}}');

    Boolean missingUrlFailedAsExpected = false;
    Test.startTest();
    try {
      PropFocusLeadService.generateSiteVisitWithProjectAndDateTime(
        ld.Id,
        'Buyer X',
        'Project X',
        System.now()
      );
    } catch (AuraHandledException e2) {
      missingUrlFailedAsExpected = true;
      String errorMessage = e2.getMessage();
      System.assert(
        errorMessage != null &&
        (errorMessage.contains('Site Visit URL not returned by Propfocus') ||
        errorMessage.contains('Script-thrown exception'))
      );
    }
    Test.stopTest();
    System.assert(
      missingUrlFailedAsExpected,
      'Expected missing sv_url to throw AuraHandledException'
    );
  }

  @IsTest
  static void generateSiteVisitWithProjectAndDateTime_nullLead_throws() {
    try {
      Test.startTest();
      PropFocusLeadService.generateSiteVisitWithProjectAndDateTime(
        null,
        'Buyer X',
        'Project X',
        System.now()
      );
      Test.stopTest();
      System.assert(
        false,
        'Expected null lead Id to throw AuraHandledException'
      );
    } catch (AuraHandledException e) {
      Test.stopTest();
      String errorMessage = e.getMessage();
      System.assert(
        errorMessage != null &&
        (errorMessage.contains('Lead Id is required') ||
        errorMessage.contains('Script-thrown exception'))
      );
    }
  }

  @IsTest
  static void isBuyerInsightsAvailable_readsLeadFlag() {
    Lead ld = makeLead();
    ld.Propfocus_Buyer_Insights_Available__c = true;
    update ld;

    Test.startTest();
    Boolean available = PropFocusLeadService.isBuyerInsightsAvailable(ld.Id);
    Test.stopTest();

    System.assertEquals(true, available);
  }

  @IsTest
  static void getLinkHistory_returnsLatestRows() {
    Lead ld = makeLead();
    insert new Propfocus_Link__c(
      Lead__c = ld.Id,
      Type__c = 'Microsite',
      Project_Name__c = 'Project A',
      URL__c = 'https://example.test/old',
      Created_At__c = System.now().addHours(-1),
      Status__c = 'Generated'
    );
    insert new Propfocus_Link__c(
      Lead__c = ld.Id,
      Type__c = 'Site Visit',
      Project_Name__c = 'Project B',
      URL__c = 'https://example.test/new',
      Created_At__c = System.now(),
      Status__c = 'Confirmed'
    );

    Test.startTest();
    List<PropFocusLeadService.LinkHistoryItem> history = PropFocusLeadService.getLinkHistory(
      ld.Id
    );
    Test.stopTest();

    System.assertEquals(2, history.size());
    System.assertEquals('https://example.test/new', history[0].url);
    System.assertEquals('https://example.test/old', history[1].url);
    System.assertEquals('Site Visit', history[0].type);
    System.assertEquals('Project B', history[0].projectName);
  }

  @IsTest
  static void getLeadDetails_returnsMappedFields() {
    Lead ld = PropfocusTestUtil.createLead('Details Buyer');
    String expectedBuyerId = PropfocusTestUtil.buyerIdFor(ld);

    Test.startTest();
    Map<String, Object> details = PropFocusLeadService.getLeadDetails(ld.Id);
    Test.stopTest();

    System.assertEquals(ld.Id, details.get('Id'));
    System.assertEquals(expectedBuyerId, details.get('buyerId'));
    System.assertNotEquals(null, details.get('buyerName'));
    System.assertNotEquals(null, details.get('projectName'));
  }

  @IsTest
  static void getProjects_returnsProjectList() {
    setApiMock(
      200,
      '{"success":true,"data":{"projects":["Project A","Project B"]}}'
    );

    Test.startTest();
    List<String> projects = PropFocusLeadService.getProjects();
    Test.stopTest();

    System.assertEquals(2, projects.size());
    System.assertEquals('Project A', projects[0]);
  }

  @IsTest
  static void getProjectsForSiteVisit_returnsProjectList() {
    setApiMock(200, '{"success":true,"data":{"projects":["Visit Project"]}}');

    Test.startTest();
    List<String> projects = PropFocusLeadService.getProjectsForSiteVisit();
    Test.stopTest();

    System.assertEquals(1, projects.size());
    System.assertEquals('Visit Project', projects[0]);
  }

  @IsTest
  static void getLatestSiteVisitDateTime_nullWhenNoSiteVisitObject() {
    Lead ld = makeLead();

    Test.startTest();
    Datetime latest = PropFocusLeadService.getLatestSiteVisitDateTime(ld.Id);
    Test.stopTest();

    System.assertEquals(null, latest);
  }

  @IsTest
  static void getLinkHistory_emptyWhenNullLeadId() {
    Test.startTest();
    List<PropFocusLeadService.LinkHistoryItem> history = PropFocusLeadService.getLinkHistory(
      null
    );
    Test.stopTest();

    System.assertEquals(0, history.size());
  }

  @IsTest
  static void getBuyerInsightsEmbedContext_usesBuyerIdForEmbedLookup() {
    Lead ld = makeLead();
    String expectedBuyerId = PropfocusTestUtil.buyerIdFor(ld);

    Test.startTest();
    PropFocusLeadService.BuyerInsightsEmbedContext context = PropFocusLeadService.getBuyerInsightsEmbedContext(
      ld.Id
    );
    Test.stopTest();

    System.assertEquals(expectedBuyerId, context.embedKey);
    System.assertNotEquals(null, context.embedUrl);
    System.assert(
      context.embedUrl.endsWith(
        EncodingUtil.urlEncode(expectedBuyerId, 'UTF-8')
      )
    );
  }

  @IsTest
  static void buildEmbedUrl_trimsTrailingSlash() {
    System.assertEquals(
      'https://dev.propfocus.in/embed/salesforce/00Q123',
      PropFocusLeadService.buildEmbedUrl(
        'https://dev.propfocus.in/embed/salesforce/',
        '00Q123'
      )
    );
  }
}
