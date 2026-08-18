@IsTest
private class PropFocusLeadServiceTest {
  private static PropfocusHttpCalloutMock apiMock;
  private static final String CUSTOMER_SUPPORT_MESSAGE =
    PropFocusLeadService.CUSTOMER_SUPPORT_MESSAGE;

  private static Lead makeLead() {
    return PropfocusTestUtil.createLead('Coverage Buyer');
  }

  private static void setApiMock(Integer statusCode, String responseBody) {
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
    PropFocusLeadService.PropfocusLinkResult result = PropFocusLeadService.generateMicrositeLink(
      ld.Id,
      'Client 1',
      new List<String>{ 'Project A', 'Project B' },
      'new',
      ''
    );
    String capturedBody = apiMock.lastApiRequestBody;
    String capturedIdempotencyKey = apiMock.lastApiIdempotencyKey;
    Test.stopTest();

    System.assertEquals(
      'https://example.test/micro',
      result.url,
      'Unexpected microsite URL: ' + result.url
    );
    System.assert(
      result.whatsappMessage != null && result.whatsappMessage.contains('https://example.test/micro'),
      'Expected whatsapp message to include microsite URL'
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
    System.assertEquals('Microsite Generation', historyRows[0].Type__c);
    System.assertEquals('Project A, Project B', historyRows[0].Project_Name__c);
    System.assertEquals('https://example.test/micro', historyRows[0].URL__c);
    System.assertEquals('Not engaged', historyRows[0].Status__c);

    Map<String, Object> requestBody = (Map<String, Object>) JSON.deserializeUntyped(
      capturedBody
    );
    System.assertEquals(
      String.valueOf(ld.Id),
      requestBody.get('salesforce_lead_id')
    );
    System.assertEquals('Client 1', requestBody.get('clientName'));
    System.assert(
      !String.isBlank(capturedIdempotencyKey),
      'Expected Idempotency-Key header for microsite create'
    );
  }

  @IsTest
  static void generateMicrositeLink_reused_marksHistoryAsReused() {
    Lead ld = makeLead();
    setApiMock(
      200,
      '{"success":true,"reused":true,"data":{"microsite_url":"https://example.test/micro-reused"}}'
    );

    Test.startTest();
    PropFocusLeadService.PropfocusLinkResult result = PropFocusLeadService.generateMicrositeLink(
      ld.Id,
      'Client Reuse',
      new List<String>{ 'Project A' },
      'new',
      ''
    );
    Test.stopTest();

    System.assertEquals('https://example.test/micro-reused', result.url);
    List<Propfocus_Link__c> historyRows = [
      SELECT Status__c
      FROM Propfocus_Link__c
      WHERE Lead__c = :ld.Id
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    System.assertEquals(1, historyRows.size());
    System.assertEquals('Reused', historyRows[0].Status__c);
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
        new List<String>{ 'Project A' },
        'new',
        ''
      );
    } catch (Exception e) {
      firstCallFailedAsExpected =
        e instanceof AuraHandledException || e instanceof PropFocusServiceException;
      String errorMessage = e.getMessage();
      System.assert(
        errorMessage != null &&
        (errorMessage.contains(CUSTOMER_SUPPORT_MESSAGE) ||
        errorMessage.contains('Script-thrown exception'))
      );
    }
    Test.stopTest();
    System.assert(
      firstCallFailedAsExpected,
      'Expected non-200 status to throw user-facing exception'
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
        new List<String>{ 'Project A' },
        'new',
        ''
      );
    } catch (Exception e2) {
      secondCallFailedAsExpected =
        e2 instanceof AuraHandledException || e2 instanceof PropFocusServiceException;
      String errorMessage = e2.getMessage();
      System.assert(
        errorMessage != null &&
        (errorMessage.contains(CUSTOMER_SUPPORT_MESSAGE) ||
        errorMessage.contains('Script-thrown exception'))
      );
    }
    Test.stopTest();
    System.assert(
      secondCallFailedAsExpected,
      'Expected missing micrositeUrl to throw user-facing exception'
    );
  }

  @IsTest
  static void generateMicrositeLink_sendsUnifiedCommunicationPayload() {
    Lead ld = makeLead();
    setApiMock(
      200,
      '{"success":true,"link":"https://example.test/micro","template":"Hi there"}'
    );

    Test.startTest();
    PropFocusLeadService.generateMicrositeLink(
      ld.Id,
      'Client 1',
      new List<String>{ 'Project A' },
      'new',
      ''
    );
    String capturedBody = apiMock.lastApiRequestBody;
    String capturedEndpoint = apiMock.lastApiEndpoint;
    Test.stopTest();

    Map<String, Object> requestBody = (Map<String, Object>) JSON.deserializeUntyped(
      capturedBody
    );
    System.assertEquals('Client 1', requestBody.get('clientName'));
    System.assertEquals(
      String.valueOf(ld.get('Email')),
      String.valueOf(requestBody.get('buyer_id'))
    );
    System.assert(
      capturedEndpoint != null &&
      capturedEndpoint.contains('/api/broker-microsite/create'),
      'Unexpected endpoint: ' + capturedEndpoint
    );
    List<Object> projects = (List<Object>) requestBody.get('projects');
    System.assertNotEquals(null, projects);
    System.assertEquals(1, projects.size());
    System.assertEquals('Project A', String.valueOf(projects[0]));
  }

  @IsTest
  static void generateMicrositeLink_prefersApiWhatsappMessage() {
    Lead ld = makeLead();
    setApiMock(
      200,
      '{"success":true,"link":"https://example.test/micro","template":"Custom WhatsApp template"}'
    );

    Test.startTest();
    PropFocusLeadService.PropfocusLinkResult result = PropFocusLeadService.generateMicrositeLink(
      ld.Id,
      'Client 1',
      new List<String>{ 'Project A' },
      'new',
      ''
    );
    Test.stopTest();

    System.assertEquals('Custom WhatsApp template', result.whatsappMessage);
  }

  @IsTest
  static void generateMicrositeLink_sendsLeadTypesAndConfigurationFilter() {
    Lead ld = makeLead();
    setApiMock(
      200,
      '{"success":true,"link":"https://example.test/micro"}'
    );

    Test.startTest();
    PropFocusLeadService.generateMicrositeLink(
      ld.Id,
      'Client 1',
      new List<String>{ 'Project A' },
      'rnr',
      '2 BHK, 3 BHK'
    );
    String capturedBody = apiMock.lastApiRequestBody;
    Test.stopTest();

    Map<String, Object> requestBody = (Map<String, Object>) JSON.deserializeUntyped(
      capturedBody
    );
    List<Object> leadTypes = (List<Object>) requestBody.get('lead_types');
    System.assertNotEquals(null, leadTypes);
    System.assertEquals(1, leadTypes.size());
    System.assertEquals('Open', String.valueOf(leadTypes[0]));
    System.assertEquals('2 BHK, 3 BHK', requestBody.get('configurationFilter'));
  }

  @IsTest
  static void resolveMicrositeLeadTypesForApi_mapsUiValues() {
    System.assertEquals(0, PropFocusLeadService.resolveMicrositeLeadTypesForApi('new').size());
    System.assertEquals(
      'Open',
      PropFocusLeadService.resolveMicrositeLeadTypesForApi('rnr')[0]
    );
    System.assertEquals(
      'Referral',
      PropFocusLeadService.resolveMicrositeLeadTypesForApi('refer')[0]
    );
    System.assertEquals(
      'Old Data',
      PropFocusLeadService.resolveMicrositeLeadTypesForApi('old data')[0]
    );
    System.assertEquals(
      'Investment',
      PropFocusLeadService.resolveMicrositeLeadTypesForApi('investor')[0]
    );
  }

  @IsTest
  static void getConfigurationsForProjects_returnsUnionLabels() {
    setApiMock(
      200,
      '{"success":true,"projects":["Project A","Project B"],"projectConfigurations":{"Project A":["3 BHK","2 BHK"],"Project B":["3 BHK"]}}'
    );

    Test.startTest();
    List<String> labels = PropFocusLeadService.getConfigurationsForProjects(
      new List<String>{ 'Project A', 'Project B' }
    );
    Test.stopTest();

    System.assert(apiMock.lastApiEndpoint.contains('/accessible-projects'));
    System.assertEquals(2, labels.size());
    System.assertEquals('2 BHK', labels[0]);
    System.assertEquals('3 BHK', labels[1]);
  }

  @IsTest
  static void getConfigurationsForProjects_matchesCaseInsensitiveAndObjectLabels() {
    setApiMock(
      200,
      '{"success":true,"projectConfigurations":{"Project A":[{"label":"4 BHK"},{"name":" Studio "},{"unit_type":"1 BHK"},null,"2 BHK"],"Other":["ignored"]}}'
    );

    Test.startTest();
    List<String> labels = PropFocusLeadService.getConfigurationsForProjects(
      new List<String>{ '  project a  ', '', null, 'Missing Project' }
    );
    Test.stopTest();

    System.assertEquals(4, labels.size());
    System.assertEquals('1 BHK', labels[0]);
    System.assertEquals('2 BHK', labels[1]);
    System.assertEquals('4 BHK', labels[2]);
    System.assertEquals('Studio', labels[3]);
  }

  @IsTest
  static void getConfigurationsForProjects_returnsEmptyForBlankInput() {
    Test.startTest();
    List<String> labels = PropFocusLeadService.getConfigurationsForProjects(
      new List<String>()
    );
    List<String> nullLabels = PropFocusLeadService.getConfigurationsForProjects(
      null
    );
    Test.stopTest();

    System.assertEquals(0, labels.size());
    System.assertEquals(0, nullLabels.size());
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
    PropFocusLeadService.PropfocusLinkResult svResult = PropFocusLeadService.generateSiteVisitWithProjectAndDateTime(
      ld.Id,
      'Buyer Override',
      'Project Override',
      requestedDt,
      null
    );
    String capturedIdempotencyKey = apiMock.lastApiIdempotencyKey;
    Test.stopTest();

    System.assertEquals('https://example.test/sv', svResult.url);
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
    System.assertEquals('Site Visit Confirmation', historyRows[0].Type__c);
    System.assertEquals('Project Override', historyRows[0].Project_Name__c);
    System.assertEquals('https://example.test/sv', historyRows[0].URL__c);
    System.assertEquals('Pending', historyRows[0].Status__c);
    System.assert(
      !String.isBlank(capturedIdempotencyKey),
      'Expected Idempotency-Key header for site visit create'
    );
  }

  @IsTest
  static void generateSiteVisitWithProjectAndDateTime_includesSiteVisitManagerObject() {
    Lead ld = makeLead();
    setApiMock(
      200,
      '{"success":true,"data":{"sv_url":"https://example.test/sv"}}'
    );

    Test.startTest();
    PropFocusLeadService.generateSiteVisitWithProjectAndDateTime(
      ld.Id,
      'Buyer Override',
      'Project Override',
      System.now(),
      'mgr-1'
    );
    String capturedBody = apiMock.lastApiRequestBody;
    Test.stopTest();

    Map<String, Object> requestBody = (Map<String, Object>) JSON.deserializeUntyped(
      capturedBody
    );
    Map<String, Object> siteVisitManager = (Map<String, Object>) requestBody.get(
      'siteVisitManager'
    );
    System.assertNotEquals(null, siteVisitManager);
    System.assertEquals('mgr-1', siteVisitManager.get('id'));
  }

  @IsTest
  static void generateSiteVisitWithProjectAndDateTime_reused_marksHistoryAsReused() {
    Lead ld = makeLead();
    setApiMock(
      200,
      '{"success":true,"reused":true,"sv_url":"https://example.test/sv-reused"}'
    );

    Test.startTest();
    PropFocusLeadService.PropfocusLinkResult svResult = PropFocusLeadService.generateSiteVisitWithProjectAndDateTime(
      ld.Id,
      'Buyer Reuse',
      'Project Reuse',
      System.now(),
      null
    );
    Test.stopTest();

    System.assertEquals('https://example.test/sv-reused', svResult.url);
    List<Propfocus_Link__c> historyRows = [
      SELECT Status__c
      FROM Propfocus_Link__c
      WHERE Lead__c = :ld.Id
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    System.assertEquals(1, historyRows.size());
    System.assertEquals('Reused', historyRows[0].Status__c);
  }

  @IsTest
  static void generatePostVisitWithProjectAndConfiguration_success_updatesLeadAndHistory() {
    Lead ld = makeLead();
    Date visitDate = Date.newInstance(2026, 1, 20);
    setApiMock(
      200,
      '{"success":true,"data":{"postVisitUrl":"https://example.test/pv"}}'
    );

    Test.startTest();
    PropFocusLeadService.PropfocusLinkResult pvResult = PropFocusLeadService.generatePostVisitWithProjectAndConfiguration(
      ld.Id,
      'Buyer Post',
      'Project Post',
      '3 BHK',
      visitDate
    );
    String capturedBody = apiMock.lastApiRequestBody;
    String capturedIdempotencyKey = apiMock.lastApiIdempotencyKey;
    Test.stopTest();

    System.assertEquals('https://example.test/pv', pvResult.url);
    Lead updatedLead = [
      SELECT Propfocus_Post_Visit__c
      FROM Lead
      WHERE Id = :ld.Id
    ];
    System.assertEquals('https://example.test/pv', updatedLead.Propfocus_Post_Visit__c);

    List<Propfocus_Link__c> historyRows = [
      SELECT Type__c, Project_Name__c, URL__c, Status__c
      FROM Propfocus_Link__c
      WHERE Lead__c = :ld.Id
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    System.assertEquals(1, historyRows.size());
    System.assertEquals('Post Visit Page', historyRows[0].Type__c);
    System.assertEquals('Project Post', historyRows[0].Project_Name__c);
    System.assertEquals('https://example.test/pv', historyRows[0].URL__c);
    System.assertEquals('Not engaged', historyRows[0].Status__c);

    Map<String, Object> requestBody = (Map<String, Object>) JSON.deserializeUntyped(
      capturedBody
    );
    System.assertEquals('3 BHK', requestBody.get('visited_configuration'));
    System.assertEquals(String.valueOf(visitDate), requestBody.get('visit_conducted_at'));
    System.assertEquals(String.valueOf(ld.Id), requestBody.get('salesforce_lead_id'));
    System.assert(
      !String.isBlank(capturedIdempotencyKey),
      'Expected Idempotency-Key header for post visit create'
    );
  }

  @IsTest
  static void generatePostVisitWithProjectAndConfiguration_reused_marksHistoryAsReused() {
    Lead ld = makeLead();
    setApiMock(
      200,
      '{"success":true,"reused":true,"post_visit_url":"https://example.test/pv-reused"}'
    );

    Test.startTest();
    PropFocusLeadService.PropfocusLinkResult pvResult = PropFocusLeadService.generatePostVisitWithProjectAndConfiguration(
      ld.Id,
      'Buyer Post',
      'Project Post',
      '2 BHK',
      Date.today()
    );
    Test.stopTest();

    System.assertEquals('https://example.test/pv-reused', pvResult.url);
    List<Propfocus_Link__c> historyRows = [
      SELECT Status__c
      FROM Propfocus_Link__c
      WHERE Lead__c = :ld.Id
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    System.assertEquals(1, historyRows.size());
    System.assertEquals('Reused', historyRows[0].Status__c);
  }

  @IsTest
  static void generatePostVisitWithProjectAndConfiguration_missingUrl_throwsHandledException() {
    Lead ld = makeLead();
    setApiMock(200, '{"success":true,"data":{}}');

    Boolean failedAsExpected = false;
    Test.startTest();
    try {
      PropFocusLeadService.generatePostVisitWithProjectAndConfiguration(
        ld.Id,
        'Buyer Post',
        'Project Post',
        '2 BHK',
        Date.today()
      );
    } catch (Exception e) {
      failedAsExpected =
        e instanceof AuraHandledException || e instanceof PropFocusServiceException;
      String errorMessage = e.getMessage();
      System.assert(
        errorMessage != null &&
        (errorMessage.contains(CUSTOMER_SUPPORT_MESSAGE) ||
        errorMessage.contains('Script-thrown exception'))
      );
    }
    Test.stopTest();
    System.assert(
      failedAsExpected,
      'Expected missing post visit URL to throw user-facing exception'
    );
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
        System.now(),
        null
      );
    } catch (Exception e) {
      httpErrorFailedAsExpected =
        e instanceof AuraHandledException || e instanceof PropFocusServiceException;
      String errorMessage = e.getMessage();
      System.assert(
        errorMessage != null &&
        (errorMessage.contains(CUSTOMER_SUPPORT_MESSAGE) ||
        errorMessage.contains('Script-thrown exception'))
      );
    }
    Test.stopTest();
    System.assert(
      httpErrorFailedAsExpected,
      'Expected non-200 status to throw user-facing exception'
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
        System.now(),
        null
      );
    } catch (Exception e2) {
      missingUrlFailedAsExpected =
        e2 instanceof AuraHandledException || e2 instanceof PropFocusServiceException;
      String errorMessage = e2.getMessage();
      System.assert(
        errorMessage != null &&
        (errorMessage.contains(CUSTOMER_SUPPORT_MESSAGE) ||
        errorMessage.contains('Script-thrown exception'))
      );
    }
    Test.stopTest();
    System.assert(
      missingUrlFailedAsExpected,
      'Expected missing sv_url to throw user-facing exception'
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
        System.now(),
        null
      );
      Test.stopTest();
      System.assert(
        false,
        'Expected null lead Id to throw user-facing exception'
      );
    } catch (Exception e) {
      Test.stopTest();
      System.assert(
        e instanceof AuraHandledException || e instanceof PropFocusServiceException,
        'Unexpected exception type: ' + e
      );
      String errorMessage = e.getMessage();
      System.assert(
        errorMessage != null &&
        (errorMessage.contains('Lead Id is required') ||
        errorMessage.contains('Record Id is required') ||
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
  static void getSalesTeam_returnsMembers() {
    setApiMock(
      200,
      '{"success":true,"members":[{"id":"sales-1","name":"Alex Sales","displayName":"Alex Sales (Sales)"}]}'
    );

    Test.startTest();
    List<PropFocusLeadService.SalesTeamMemberItem> members = PropFocusLeadService.getSalesTeam();
    Test.stopTest();

    System.assertEquals(1, members.size());
    System.assertEquals('sales-1', members[0].id);
    System.assertEquals('Alex Sales', members[0].name);
    System.assertEquals('Alex Sales (Sales)', members[0].displayName);
    System.assert(
      apiMock.lastApiEndpoint != null &&
      apiMock.lastApiEndpoint.contains('/api/dashboard/sales-team'),
      'Expected sales-team endpoint'
    );
    System.assert(
      apiMock.lastApiEndpoint.contains('organizationId='),
      'Expected organizationId query param for Salesforce auth'
    );
  }

  @IsTest
  static void getSalesTeam_returnsEmptyWhenNoMembers() {
    setApiMock(200, '{"success":true,"members":[]}');

    Test.startTest();
    List<PropFocusLeadService.SalesTeamMemberItem> members = PropFocusLeadService.getSalesTeam();
    Test.stopTest();

    System.assertEquals(0, members.size());
  }

  @IsTest
  static void getSiteVisitManagers_returnsEmptyWhenProjectMissing() {
    Test.startTest();
    List<PropFocusLeadService.SiteVisitManagerItem> managers = PropFocusLeadService.getSiteVisitManagers(
      null
    );
    Test.stopTest();

    System.assertEquals(0, managers.size());
  }

  @IsTest
  static void getSiteVisitManagers_returnsManagersForProject() {
    setApiMock(
      200,
      '{"success":true,"siteVisitProjects":["Project A"],"siteVisitManagers":{"Project A":[{"id":"mgr-1","name":"Visit Lead","phone":"+91111"}]}}'
    );

    Test.startTest();
    List<PropFocusLeadService.SiteVisitManagerItem> managers = PropFocusLeadService.getSiteVisitManagers(
      'Project A'
    );
    Test.stopTest();

    System.assertEquals(1, managers.size());
    System.assertEquals('mgr-1', managers[0].id);
    System.assertEquals('Visit Lead', managers[0].name);
    System.assertEquals('+91111', managers[0].phone);
    System.assert(
      apiMock.lastApiEndpoint != null &&
      apiMock.lastApiEndpoint.contains('/accessible-projects'),
      'Expected accessible-projects endpoint'
    );
  }

  @IsTest
  static void getSiteVisitManagers_returnsEmptyWhenProjectHasNoManagers() {
    setApiMock(
      200,
      '{"success":true,"siteVisitManagers":{"Other Project":[{"id":"mgr-2","name":"Other","phone":"+91222"}]}}'
    );

    Test.startTest();
    List<PropFocusLeadService.SiteVisitManagerItem> managers = PropFocusLeadService.getSiteVisitManagers(
      'Project A'
    );
    Test.stopTest();

    System.assertEquals(0, managers.size());
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
    // Empty statuses → keep stored Status__c
    setApiMock(200, '{"success":true,"data":{"statuses":[]}}');

    Test.startTest();
    List<PropFocusLeadService.LinkHistoryItem> history = PropFocusLeadService.getLinkHistory(
      ld.Id
    );
    Test.stopTest();

    System.assertEquals(2, history.size());
    System.assertEquals('https://example.test/new', history[0].url);
    System.assertEquals('https://example.test/old', history[1].url);
    System.assertEquals('Site Visit Confirmation', history[0].type);
    System.assertEquals('Microsite Generation', history[1].type);
    System.assertEquals('Project B', history[0].projectName);
    System.assert(
      apiMock.lastApiEndpoint != null &&
      apiMock.lastApiEndpoint.contains('/api/v1/salesforce/link-history-status'),
      'Expected link-history-status callout'
    );
  }

  @IsTest
  static void getLinkHistory_formatsLegacyAndUnknownTypes() {
    Lead ld = makeLead();
    insert new Propfocus_Link__c(
      Lead__c = ld.Id,
      Type__c = 'Post Visit',
      Project_Name__c = 'Project PV',
      URL__c = 'https://example.test/pv-legacy',
      Created_At__c = System.now(),
      Status__c = 'Generated'
    );
    insert new Propfocus_Link__c(
      Lead__c = ld.Id,
      Type__c = 'Custom Type',
      Project_Name__c = 'Project X',
      URL__c = 'https://example.test/custom',
      Created_At__c = System.now().addMinutes(-1),
      Status__c = 'Generated'
    );
    insert new Propfocus_Link__c(
      Lead__c = ld.Id,
      Type__c = 'Post Visit Page',
      Project_Name__c = 'Project PV2',
      URL__c = 'https://example.test/pv-new',
      Created_At__c = System.now().addMinutes(-2),
      Status__c = 'Generated'
    );
    setApiMock(200, '{"success":true,"data":{"statuses":[]}}');

    Test.startTest();
    List<PropFocusLeadService.LinkHistoryItem> history = PropFocusLeadService.getLinkHistory(
      ld.Id
    );
    Test.stopTest();

    System.assertEquals(3, history.size());
    System.assertEquals('Post Visit Page', history[0].type);
    System.assertEquals('Custom Type', history[1].type);
    System.assertEquals('Post Visit Page', history[2].type);
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
  static void getProjectsForSiteVisit_returnsSiteVisitProjectList() {
    setApiMock(
      200,
      '{"success":true,"siteVisitProjects":["Visit Project","Phased Estate"]}'
    );

    Test.startTest();
    List<String> projects = PropFocusLeadService.getProjectsForSiteVisit();
    Test.stopTest();

    System.assertEquals(2, projects.size());
    System.assertEquals('Visit Project', projects[0]);
    System.assert(
      apiMock.lastApiEndpoint != null &&
      apiMock.lastApiEndpoint.contains('/accessible-projects'),
      'Expected accessible-projects endpoint'
    );
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
  static void getLatestSiteVisitDateTime_usesConfiguredDatetimeField() {
    Lead ld = makeLead();
    PropfocusConfigService.Config cfg = PropfocusConfigService.getConfig();
    cfg.siteVisitObject = Propfocus_Call_Log__c.SObjectType.getDescribe()
      .getName();
    cfg.siteVisitLeadLookupField = Propfocus_Call_Log__c.Lead__c.getDescribe()
      .getName();
    cfg.siteVisitStatusField = Propfocus_Call_Log__c.Duration__c.getDescribe()
      .getName();
    cfg.siteVisitProjectField = Propfocus_Call_Log__c.Disposition__c.getDescribe()
      .getName();
    cfg.siteVisitDatetimeField = Propfocus_Call_Log__c.Call_Time__c.getDescribe()
      .getName();

    Datetime visitAt = Datetime.newInstance(2026, 8, 20, 16, 45, 0);
    insert new Propfocus_Call_Log__c(
      Lead__c = ld.Id,
      Disposition__c = 'Project A',
      Duration__c = 'Scheduled',
      Call_Time__c = visitAt
    );

    Test.startTest();
    Datetime latest = PropFocusLeadService.getLatestSiteVisitDateTime(ld.Id);
    Test.stopTest();

    System.assertEquals(
      visitAt,
      latest,
      'Modal datetime must come from Site Visit Datetime Field, not CreatedDate'
    );
  }

  @IsTest
  static void getLinkHistory_excludesReusedAndDuplicateUrls() {
    Lead ld = makeLead();
    String reusedUrl = 'https://example.test/reused';
    insert new Propfocus_Link__c(
      Lead__c = ld.Id,
      Type__c = 'Microsite',
      Project_Name__c = 'Project A',
      URL__c = reusedUrl,
      Created_At__c = System.now(),
      Status__c = 'Reused'
    );
    insert new Propfocus_Link__c(
      Lead__c = ld.Id,
      Type__c = 'Microsite',
      Project_Name__c = 'Project A',
      URL__c = reusedUrl,
      Created_At__c = System.now().addMinutes(-5),
      Status__c = 'Generated'
    );
    insert new Propfocus_Link__c(
      Lead__c = ld.Id,
      Type__c = 'Microsite',
      Project_Name__c = 'Project B',
      URL__c = 'https://example.test/new',
      Created_At__c = System.now().addMinutes(-10),
      Status__c = 'Generated'
    );
    setApiMock(200, '{"success":true,"data":{"statuses":[]}}');

    Test.startTest();
    List<PropFocusLeadService.LinkHistoryItem> history = PropFocusLeadService.getLinkHistory(
      ld.Id
    );
    Test.stopTest();

    System.assertEquals(2, history.size());
    System.assertEquals(reusedUrl, history[0].url);
    System.assertEquals('https://example.test/new', history[1].url);
  }

  @IsTest
  static void getLinkHistory_deduplicatesDuplicateGeneratedUrls() {
    Lead ld = makeLead();
    String sharedUrl = 'https://example.test/shared';
    for (Integer i = 0; i < 4; i++) {
      insert new Propfocus_Link__c(
        Lead__c = ld.Id,
        Type__c = 'Microsite',
        Project_Name__c = 'Project A',
        URL__c = sharedUrl,
        Created_At__c = System.now().addMinutes(-i),
        Status__c = 'Generated'
      );
    }
    setApiMock(200, '{"success":true,"data":{"statuses":[]}}');

    Test.startTest();
    List<PropFocusLeadService.LinkHistoryItem> history = PropFocusLeadService.getLinkHistory(
      ld.Id
    );
    Test.stopTest();

    System.assertEquals(1, history.size());
    System.assertEquals(sharedUrl, history[0].url);
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
      'https://propfocus.in/embed/salesforce/00Q123',
      PropFocusLeadService.buildEmbedUrl(
        'https://propfocus.in/embed/salesforce/',
        '00Q123'
      )
    );
  }

  @IsTest
  static void generatePropfocusTemplate_microsite_success() {
    Lead ld = makeLead();
    setApiMock(
      200,
      '{"success":true,"link":"https://example.test/micro","template":"Hi Priya","mediaUrl":"https://example.test/m.jpg"}'
    );

    Test.startTest();
    PropFocusLeadService.PropfocusTemplateResult result = PropFocusLeadService.generatePropfocusTemplate(
      ld.Id,
      'MICROSITE',
      JSON.serialize(
        new Map<String, Object>{
          'buyerName' => 'Priya Sharma',
          'projects' => new List<String>{ 'Skyline Residences' },
          'leadType' => 'new',
          'configurationFilter' => '2 BHK'
        }
      )
    );
    String capturedEndpoint = apiMock.lastApiEndpoint;
    String capturedBody = apiMock.lastApiRequestBody;
    Test.stopTest();

    System.assertEquals('microsite', result.communicationType);
    System.assertEquals('https://example.test/micro', result.url);
    System.assertEquals('Hi Priya', result.whatsappMessage);
    System.assertEquals('https://example.test/m.jpg', result.mediaUrl);
    System.assert(
      capturedEndpoint != null &&
      capturedEndpoint.contains('/api/broker-microsite/create'),
      'Unexpected endpoint: ' + capturedEndpoint
    );

    Map<String, Object> requestBody = (Map<String, Object>) JSON.deserializeUntyped(
      capturedBody
    );
    System.assertEquals('Priya Sharma', requestBody.get('clientName'));
    System.assertEquals('2 BHK', requestBody.get('configurationFilter'));
    Lead updated = [
      SELECT Propfocus_Link__c, Propfocus_Buyer_Insights_Available__c
      FROM Lead
      WHERE Id = :ld.Id
    ];
    System.assertEquals('https://example.test/micro', updated.Propfocus_Link__c);
    System.assertEquals(true, updated.Propfocus_Buyer_Insights_Available__c);
  }

  @IsTest
  static void generatePropfocusTemplate_siteVisit_success() {
    Lead ld = makeLead();
    setApiMock(
      200,
      '{"success":true,"link":"https://example.test/sv","template":"Visit ready"}'
    );

    Test.startTest();
    PropFocusLeadService.PropfocusTemplateResult result = PropFocusLeadService.generatePropfocusTemplate(
      ld.Id,
      'site_visit',
      JSON.serialize(
        new Map<String, Object>{
          'buyerName' => 'Priya Sharma',
          'projectName' => 'Skyline Residences',
          'visitDate' => '2026-07-15',
          'visitTime' => '10:00',
          'siteVisitManager' => new Map<String, Object>{ 'id' => 'mgr-1' }
        }
      )
    );
    String capturedBody = apiMock.lastApiRequestBody;
    Test.stopTest();

    System.assertEquals('site_visit', result.communicationType);
    System.assertEquals('https://example.test/sv', result.url);
    System.assertEquals('Visit ready', result.whatsappMessage);
    Lead updated = [
      SELECT Propfocus_Site_Visit__c
      FROM Lead
      WHERE Id = :ld.Id
    ];
    System.assertEquals('https://example.test/sv', updated.Propfocus_Site_Visit__c);

    Map<String, Object> requestBody = (Map<String, Object>) JSON.deserializeUntyped(
      capturedBody
    );
    System.assertEquals('Skyline Residences', requestBody.get('project_name'));
    System.assertEquals('15/07/2026', requestBody.get('visit_date'));
    System.assertEquals('10:00', requestBody.get('visit_time'));
    System.assertEquals(
      'mgr-1',
      String.valueOf(((Map<String, Object>) requestBody.get('siteVisitManager')).get('id'))
    );
  }

  @IsTest
  static void generatePropfocusTemplate_siteVisit_setsScheduledStatus() {
    // Configure the "SV Scheduled" status value.
    PropfocusConfigService.fromConfigMap(
      new Map<String, Object>{
        'siteVisitScheduledStatus' => 'Working - Contacted'
      }
    );
    Lead ld = makeLead();
    System.assertEquals('Open - Not Contacted', ld.Status);
    setApiMock(
      200,
      '{"success":true,"link":"https://example.test/sv","template":"Visit ready"}'
    );

    Test.startTest();
    PropFocusLeadService.generatePropfocusTemplate(
      ld.Id,
      'site_visit',
      JSON.serialize(
        new Map<String, Object>{
          'buyerName' => 'Priya Sharma',
          'projectName' => 'Skyline Residences',
          'visitDate' => '2026-07-15',
          'visitTime' => '10:00'
        }
      )
    );
    Test.stopTest();

    Lead updated = [SELECT Status, Propfocus_Site_Visit__c FROM Lead WHERE Id = :ld.Id];
    System.assertEquals(
      'Working - Contacted',
      updated.Status,
      'Site visit link creation should stamp the configured scheduled status'
    );
    System.assertEquals(
      'https://example.test/sv',
      updated.Propfocus_Site_Visit__c,
      'Link write-back must still succeed alongside the status update'
    );
  }

  @IsTest
  static void generatePropfocusTemplate_siteVisit_blankStatusLeavesStatusUnchanged() {
    // Explicitly clear Default CMDT so blank-config behavior is testable.
    PropfocusConfigService.Config cfg = PropfocusConfigService.getConfig();
    cfg.siteVisitScheduledStatus = null;

    Lead ld = makeLead();
    setApiMock(
      200,
      '{"success":true,"link":"https://example.test/sv","template":"Visit ready"}'
    );

    Test.startTest();
    PropFocusLeadService.generatePropfocusTemplate(
      ld.Id,
      'site_visit',
      JSON.serialize(
        new Map<String, Object>{
          'buyerName' => 'Priya Sharma',
          'projectName' => 'Skyline Residences'
        }
      )
    );
    Test.stopTest();

    Lead updated = [SELECT Status FROM Lead WHERE Id = :ld.Id];
    System.assertEquals(
      'Open - Not Contacted',
      updated.Status,
      'Status must not change when no scheduled status is configured'
    );
  }

  @IsTest
  static void generatePropfocusTemplate_postVisit_success() {
    Lead ld = makeLead();
    setApiMock(
      200,
      '{"success":true,"link":"https://example.test/pv","template":"Post visit ready"}'
    );

    Test.startTest();
    PropFocusLeadService.PropfocusTemplateResult result = PropFocusLeadService.generatePropfocusTemplate(
      ld.Id,
      'post_visit',
      JSON.serialize(
        new Map<String, Object>{
          'buyerName' => 'Priya Sharma',
          'projectName' => 'Skyline Residences',
          'visitedConfiguration' => '2 BHK'
        }
      )
    );
    Test.stopTest();

    System.assertEquals('post_visit', result.communicationType);
    System.assertEquals('https://example.test/pv', result.url);
    Lead updated = [
      SELECT Propfocus_Post_Visit__c
      FROM Lead
      WHERE Id = :ld.Id
    ];
    System.assertEquals('https://example.test/pv', updated.Propfocus_Post_Visit__c);
  }

  @IsTest
  static void generatePropfocusTemplate_postVisit_includesAssignedBrokerId() {
    Lead ld = makeLead();
    setApiMock(
      200,
      '{"success":true,"data":{"postVisitUrl":"https://example.test/pv"}}'
    );

    Test.startTest();
    PropFocusLeadService.generatePropfocusTemplate(
      ld.Id,
      'post_visit',
      JSON.serialize(
        new Map<String, Object>{
          'buyerName' => 'Priya Sharma',
          'projectName' => 'Skyline Residences',
          'visitedConfiguration' => '2 BHK',
          'assignedBrokerId' => 'sales-1'
        }
      )
    );
    String capturedBody = apiMock.lastApiRequestBody;
    Test.stopTest();

    Map<String, Object> requestBody = (Map<String, Object>) JSON.deserializeUntyped(
      capturedBody
    );
    System.assertEquals('sales-1', requestBody.get('assignedBrokerId'));
  }

  @IsTest
  static void generatePropfocusTemplate_invalidType_throws() {
    Lead ld = makeLead();
    Boolean failed = false;
    Test.startTest();
    try {
      PropFocusLeadService.generatePropfocusTemplate(ld.Id, 'payment_reminder', '{}');
    } catch (Exception e) {
      failed =
        e instanceof AuraHandledException || e instanceof PropFocusServiceException;
    }
    Test.stopTest();
    System.assert(failed, 'Expected unsupported type to throw');
  }

  @IsTest
  static void generatePropfocusTemplate_invalidContextJson_throws() {
    Lead ld = makeLead();
    Boolean failed = false;
    Test.startTest();
    try {
      PropFocusLeadService.generatePropfocusTemplate(ld.Id, 'microsite', 'not-json');
    } catch (Exception e) {
      failed =
        e instanceof AuraHandledException || e instanceof PropFocusServiceException;
    }
    Test.stopTest();
    System.assert(failed, 'Expected invalid contextJson to throw');
  }

  @IsTest
  static void generatePropfocusTemplateInvocable_routesRequests() {
    Lead ld = makeLead();
    setApiMock(
      200,
      '{"success":true,"link":"https://example.test/micro","template":"Hi"}'
    );

    PropFocusLeadService.GenerateTemplateRequest req = new PropFocusLeadService.GenerateTemplateRequest();
    req.leadId = ld.Id;
    req.communicationType = 'microsite';
    req.contextJson = JSON.serialize(
      new Map<String, Object>{
        'buyerName' => 'Flow Buyer',
        'projectName' => 'Project A'
      }
    );

    Test.startTest();
    List<PropFocusLeadService.PropfocusTemplateResult> results = PropFocusLeadService.generatePropfocusTemplateInvocable(
      new List<PropFocusLeadService.GenerateTemplateRequest>{ req }
    );
    Test.stopTest();

    System.assertEquals(1, results.size());
    System.assertEquals('https://example.test/micro', results[0].url);
    System.assertEquals('Hi', results[0].whatsappMessage);
  }

  @IsTest
  static void normalizeCommunicationType_mapsAliases() {
    System.assertEquals(
      'microsite',
      PropFocusLeadService.normalizeCommunicationType('MICROSITE')
    );
    System.assertEquals(
      'site_visit',
      PropFocusLeadService.normalizeCommunicationType('Site Visit')
    );
    System.assertEquals(
      'post_visit',
      PropFocusLeadService.normalizeCommunicationType('postvisit')
    );
  }

  @IsTest
  static void getLeadDetails_opportunity_returnsMappedFields() {
    Opportunity opp = PropfocusTestUtil.createOpportunity('Opp Details Buyer');

    Test.startTest();
    Map<String, Object> details = PropFocusLeadService.getLeadDetails(opp.Id);
    Test.stopTest();

    System.assertEquals(opp.Id, details.get('Id'));
    System.assertEquals(true, details.get('isOpportunity'));
    System.assertEquals(opp.Name, details.get('buyerName'));
    System.assertEquals(opp.NextStep, details.get('projectName'));
    System.assertEquals(opp.StageName, details.get('leadStatus'));
  }

  @IsTest
  static void generatePropfocusTemplate_opportunity_siteVisit_success() {
    Opportunity opp = PropfocusTestUtil.createOpportunity('Opp Site Visit Buyer');
    setApiMock(
      200,
      '{"success":true,"link":"https://example.test/opp-sv","template":"Visit ready"}'
    );

    Test.startTest();
    PropFocusLeadService.PropfocusTemplateResult result = PropFocusLeadService.generatePropfocusTemplate(
      opp.Id,
      'site_visit',
      JSON.serialize(
        new Map<String, Object>{
          'buyerName' => 'Opp Buyer',
          'projectName' => 'Skyline Residences',
          'visitDate' => '2026-07-15',
          'visitTime' => '10:00'
        }
      )
    );
    String capturedBody = apiMock.lastApiRequestBody;
    Test.stopTest();

    System.assertEquals('https://example.test/opp-sv', result.url);
    Opportunity updated = [
      SELECT Propfocus_Site_Visit__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];
    System.assertEquals(
      'https://example.test/opp-sv',
      updated.Propfocus_Site_Visit__c
    );

    Map<String, Object> requestBody = (Map<String, Object>) JSON.deserializeUntyped(
      capturedBody
    );
    System.assertEquals(
      String.valueOf(opp.Id),
      requestBody.get('salesforce_opportunity_id')
    );
    System.assertEquals(null, requestBody.get('salesforce_lead_id'));

    List<Propfocus_Link__c> history = [
      SELECT Opportunity__c, Lead__c, Type__c
      FROM Propfocus_Link__c
      WHERE Opportunity__c = :opp.Id
    ];
    System.assertEquals(1, history.size());
    System.assertEquals(null, history[0].Lead__c);
    System.assert(
      history[0].Type__c.contains('Site Visit'),
      'Expected site visit history type'
    );
  }

  @IsTest
  static void getLinkHistory_opportunity_filtersByOpportunity() {
    Opportunity opp = PropfocusTestUtil.createOpportunity('Opp History Buyer');
    insert new Propfocus_Link__c(
      Opportunity__c = opp.Id,
      Type__c = 'Microsite Generation',
      Project_Name__c = 'Tower A',
      URL__c = 'https://example.test/opp-micro',
      Created_At__c = System.now(),
      Status__c = 'Not engaged'
    );
    setApiMock(200, '{"success":true,"data":{"statuses":[]}}');

    Test.startTest();
    List<PropFocusLeadService.LinkHistoryItem> items = PropFocusLeadService.getLinkHistory(
      opp.Id
    );
    Test.stopTest();

    System.assertEquals(1, items.size());
    System.assertEquals('https://example.test/opp-micro', items[0].url);
  }

  @IsTest
  static void normalizeSiteVisitHistoryStatus_mapsConductedAndReschedule() {
    System.assertEquals(
      'Confirmed',
      PropFocusLeadService.normalizeSiteVisitHistoryStatus('Conducted')
    );
    System.assertEquals(
      'Confirmed',
      PropFocusLeadService.normalizeSiteVisitHistoryStatus('Completed')
    );
    System.assertEquals(
      'Rescheduled',
      PropFocusLeadService.normalizeSiteVisitHistoryStatus('Reschedule')
    );
    System.assertEquals(
      'Pending',
      PropFocusLeadService.normalizeSiteVisitHistoryStatus('Scheduled')
    );
  }

  @IsTest
  static void syncLinkHistoryEngagement_marksMicrositeEngaged() {
    Lead ld = makeLead();
    insert new Propfocus_Link__c(
      Lead__c = ld.Id,
      Type__c = 'Microsite Generation',
      Project_Name__c = 'Project A',
      URL__c = 'https://example.test/micro-engage',
      Created_At__c = System.now(),
      Status__c = 'Not engaged'
    );
    insert new Propfocus_Link__c(
      Lead__c = ld.Id,
      Type__c = 'Post Visit Page',
      Project_Name__c = 'Project A',
      URL__c = 'https://example.test/pv-engage',
      Created_At__c = System.now(),
      Status__c = 'Not engaged'
    );

    Test.startTest();
    PropFocusLeadService.syncLinkHistoryEngagement(ld.Id, 'microsite', null);
    Test.stopTest();

    Propfocus_Link__c micro = [
      SELECT Status__c
      FROM Propfocus_Link__c
      WHERE Lead__c = :ld.Id AND Type__c = 'Microsite Generation'
      LIMIT 1
    ];
    Propfocus_Link__c postVisit = [
      SELECT Status__c
      FROM Propfocus_Link__c
      WHERE Lead__c = :ld.Id AND Type__c = 'Post Visit Page'
      LIMIT 1
    ];
    System.assertEquals('Engaged', micro.Status__c);
    System.assertEquals('Not engaged', postVisit.Status__c);

    setApiMock(200, '{"success":true,"data":{"statuses":[]}}');
    List<PropFocusLeadService.LinkHistoryItem> history = PropFocusLeadService.getLinkHistory(
      ld.Id
    );
    Boolean foundEngaged = false;
    for (PropFocusLeadService.LinkHistoryItem item : history) {
      if (item.type == 'Microsite Generation') {
        System.assertEquals('Engaged', item.status);
        foundEngaged = true;
      }
    }
    System.assertEquals(true, foundEngaged);
  }

  @IsTest
  static void getLinkHistory_pullsConfirmedAndEngagedFromPropfocus() {
    Lead ld = makeLead();
    insert new Propfocus_Link__c(
      Lead__c = ld.Id,
      Type__c = 'Site Visit Confirmation',
      Project_Name__c = 'Aamrut Farms',
      URL__c = 'https://propfocus.in/sv/org/sv-CONF1',
      Created_At__c = System.now(),
      Status__c = 'Pending'
    );
    insert new Propfocus_Link__c(
      Lead__c = ld.Id,
      Type__c = 'Microsite Generation',
      Project_Name__c = 'Hosachiguru Abhivrudhi',
      URL__c = 'https://propfocus.in/buyer-TOKEN',
      Created_At__c = System.now().addMinutes(-1),
      Status__c = 'Not engaged'
    );

    setApiMock(
      200,
      '{"success":true,"data":{"statuses":[' +
        '{"url":"https://propfocus.in/sv/org/sv-CONF1","type":"Site Visit Confirmation","project_name":"Aamrut Farms","status":"Confirmed"},' +
        '{"url":"https://propfocus.in/buyer-TOKEN","type":"Microsite Generation","project_name":"Hosachiguru Abhivrudhi","status":"Engaged"}' +
        ']}}'
    );

    Test.startTest();
    List<PropFocusLeadService.LinkHistoryItem> history = PropFocusLeadService.getLinkHistory(
      ld.Id
    );
    Test.stopTest();

    System.assertEquals(2, history.size());
    System.assertEquals('Confirmed', history[0].status);
    System.assertEquals('Engaged', history[1].status);

    Propfocus_Link__c svRow = [
      SELECT Status__c
      FROM Propfocus_Link__c
      WHERE Lead__c = :ld.Id AND Type__c = 'Site Visit Confirmation'
      LIMIT 1
    ];
    Propfocus_Link__c microRow = [
      SELECT Status__c
      FROM Propfocus_Link__c
      WHERE Lead__c = :ld.Id AND Type__c = 'Microsite Generation'
      LIMIT 1
    ];
    System.assertEquals('Confirmed', svRow.Status__c);
    System.assertEquals('Engaged', microRow.Status__c);
    System.assert(
      apiMock.lastApiRequestBody != null &&
      apiMock.lastApiRequestBody.contains('organization_id') &&
      apiMock.lastApiRequestBody.contains('buyer_id'),
      'Expected organization_id and buyer_id in callout body'
    );
  }

  @IsTest
  static void getLinkHistory_keepsStoredStatusWhenCalloutFails() {
    Lead ld = makeLead();
    insert new Propfocus_Link__c(
      Lead__c = ld.Id,
      Type__c = 'Site Visit Confirmation',
      Project_Name__c = 'Aamrut Farms',
      URL__c = 'https://propfocus.in/sv/org/sv-PEND',
      Created_At__c = System.now(),
      Status__c = 'Pending'
    );
    setApiMock(500, '{"success":false,"error":"boom"}');

    Test.startTest();
    List<PropFocusLeadService.LinkHistoryItem> history = PropFocusLeadService.getLinkHistory(
      ld.Id
    );
    Test.stopTest();

    System.assertEquals(1, history.size());
    System.assertEquals('Pending', history[0].status);
  }
}
