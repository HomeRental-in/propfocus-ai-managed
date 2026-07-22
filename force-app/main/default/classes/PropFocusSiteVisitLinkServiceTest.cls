@IsTest
private class PropFocusSiteVisitLinkServiceTest {
  private static PropfocusHttpCalloutMock apiMock;

  private static Lead makeLead() {
    return PropfocusTestUtil.createLead('Site Visit Link Buyer');
  }

  private static void setApiMock(Integer statusCode, String responseBody) {
    apiMock = new PropfocusHttpCalloutMock();
    apiMock.apiStatusCode = statusCode;
    apiMock.apiBody = responseBody;
    Test.setMock(HttpCalloutMock.class, apiMock);
  }

  /**
   * Customer Site Visit object is not packaged. Stand in Propfocus_Call_Log__c
   * (Lead lookup + text + datetime) and remap Config for the test.
   */
  private static void mapClientSiteVisitObjectForTest() {
    PropfocusConfigService.Config cfg = PropfocusConfigService.getConfig();
    cfg.siteVisitObject = Propfocus_Call_Log__c.SObjectType.getDescribe()
      .getName();
    cfg.siteVisitLeadLookupField = Propfocus_Call_Log__c.Lead__c.getDescribe()
      .getName();
    cfg.siteVisitOpportunityLookupField = Propfocus_Call_Log__c.Opportunity__c.getDescribe()
      .getName();
    cfg.siteVisitProjectField = Propfocus_Call_Log__c.Disposition__c.getDescribe()
      .getName();
    cfg.siteVisitDatetimeField = Propfocus_Call_Log__c.Call_Time__c.getDescribe()
      .getName();
    cfg.siteVisitManagerNameField = null;
    cfg.siteVisitManagerPhoneField = null;
    cfg.siteVisitManagerEmailField = null;
  }

  private static Propfocus_Call_Log__c insertStandInSiteVisit(
    Id leadId,
    Id opportunityId,
    String projectName,
    Datetime visitAt
  ) {
    Propfocus_Call_Log__c row = new Propfocus_Call_Log__c(
      Lead__c = leadId,
      Opportunity__c = opportunityId,
      Disposition__c = projectName,
      Call_Time__c = visitAt
    );
    insert row;
    return row;
  }

  @IsTest
  static void mapSiteVisitRecord_readsConfiguredFields() {
    Lead ld = makeLead();
    mapClientSiteVisitObjectForTest();
    Datetime visitAt = Datetime.newInstance(2026, 7, 19, 10, 30, 0);
    Propfocus_Call_Log__c sv = insertStandInSiteVisit(
      ld.Id,
      null,
      'Farm Showcase',
      visitAt
    );

    Test.startTest();
    PropFocusSiteVisitLinkService.MappedSiteVisit mapped = PropFocusSiteVisitLinkService.mapSiteVisitRecord(
      sv.Id
    );
    Test.stopTest();

    System.assertEquals(ld.Id, mapped.parentRecordId);
    System.assertEquals('Farm Showcase', mapped.projectName);
    System.assertEquals(visitAt, mapped.visitDateTime);
  }

  @IsTest
  static void mapSiteVisitRecord_prefersOpportunityWhenBothSet() {
    Lead ld = makeLead();
    Opportunity opp = PropfocusTestUtil.createOpportunity('SV Opp Buyer');
    mapClientSiteVisitObjectForTest();
    Propfocus_Call_Log__c sv = insertStandInSiteVisit(
      ld.Id,
      opp.Id,
      'Skyline',
      System.now()
    );

    PropFocusSiteVisitLinkService.MappedSiteVisit mapped = PropFocusSiteVisitLinkService.mapSiteVisitRecord(
      sv.Id
    );

    System.assertEquals(opp.Id, mapped.parentRecordId);
  }

  @IsTest
  static void generateFromSiteVisitRecord_createsLinkOnLead() {
    Lead ld = makeLead();
    mapClientSiteVisitObjectForTest();
    Propfocus_Call_Log__c sv = insertStandInSiteVisit(
      ld.Id,
      null,
      'Farm Showcase',
      Datetime.newInstance(2026, 7, 19, 16, 0, 0)
    );
    setApiMock(
      200,
      '{"success":true,"link":"https://example.test/sv-from-record","template":"Visit ready"}'
    );

    Test.startTest();
    PropFocusLeadService.PropfocusTemplateResult result = PropFocusSiteVisitLinkService.generateFromSiteVisitRecord(
      sv.Id
    );
    String capturedBody = apiMock.lastApiRequestBody;
    Test.stopTest();

    System.assertEquals('site_visit', result.communicationType);
    System.assertEquals('https://example.test/sv-from-record', result.url);
    Lead updated = [
      SELECT Propfocus_Site_Visit__c
      FROM Lead
      WHERE Id = :ld.Id
    ];
    System.assertEquals(
      'https://example.test/sv-from-record',
      updated.Propfocus_Site_Visit__c
    );

    Map<String, Object> requestBody = (Map<String, Object>) JSON.deserializeUntyped(
      capturedBody
    );
    System.assertEquals('Farm Showcase', requestBody.get('project_name'));
    System.assertEquals(
      String.valueOf(ld.Id),
      requestBody.get('salesforce_lead_id')
    );
  }

  @IsTest
  static void generateFromSiteVisitRecords_invocableEnqueuesCallout() {
    Lead ld = makeLead();
    mapClientSiteVisitObjectForTest();
    Propfocus_Call_Log__c sv = insertStandInSiteVisit(
      ld.Id,
      null,
      'Queue Project',
      System.now()
    );
    setApiMock(
      200,
      '{"success":true,"link":"https://example.test/sv-queued"}'
    );

    PropFocusSiteVisitLinkService.GenerateFromSiteVisitRequest req = new PropFocusSiteVisitLinkService.GenerateFromSiteVisitRequest();
    req.siteVisitRecordId = sv.Id;

    Test.startTest();
    PropFocusSiteVisitLinkService.generateFromSiteVisitRecords(
      new List<PropFocusSiteVisitLinkService.GenerateFromSiteVisitRequest>{ req }
    );
    Test.stopTest();

    Lead updated = [
      SELECT Propfocus_Site_Visit__c
      FROM Lead
      WHERE Id = :ld.Id
    ];
    System.assertEquals(
      'https://example.test/sv-queued',
      updated.Propfocus_Site_Visit__c
    );
  }

  @IsTest
  static void mapSiteVisitRecord_rejectsWrongObjectType() {
    Lead ld = makeLead();
    mapClientSiteVisitObjectForTest();
    Boolean threw = false;
    try {
      PropFocusSiteVisitLinkService.mapSiteVisitRecord(ld.Id);
    } catch (Exception ex) {
      threw =
        ex instanceof AuraHandledException || ex instanceof PropFocusServiceException;
    }
    System.assert(threw, 'Expected user-facing exception for wrong object type');
  }

  @IsTest
  static void mapSiteVisitRecord_requiresProject() {
    Lead ld = makeLead();
    mapClientSiteVisitObjectForTest();
    Propfocus_Call_Log__c sv = insertStandInSiteVisit(
      ld.Id,
      null,
      null,
      System.now()
    );
    Boolean threw = false;
    try {
      PropFocusSiteVisitLinkService.mapSiteVisitRecord(sv.Id);
    } catch (Exception ex) {
      threw =
        ex instanceof AuraHandledException || ex instanceof PropFocusServiceException;
    }
    System.assert(threw, 'Expected user-facing exception for blank project');
  }
}
