@IsTest
private class PropfocusInboundServiceTest {
  private static Lead makeLead() {
    return PropfocusTestUtil.createLead('Inbound Buyer');
  }

  private static String buyerIdFor(Lead ld) {
    return PropfocusTestUtil.buyerIdFor(ld);
  }

  private static String configuredOrgId() {
    return PropfocusTestUtil.configuredOrganizationId();
  }

  private static void setContext(String body) {
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/propfocus/events/';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(body);
    req.addHeader('Content-Type', 'application/json');
    RestContext.request = req;
    RestContext.response = new RestResponse();
  }

  private static Map<String, Object> responseBody() {
    return (Map<String, Object>) JSON.deserializeUntyped(
      RestContext.response.responseBody.toString()
    );
  }

  private static String validPayload(String buyerId, String orgId) {
    return JSON.serialize(
      new Map<String, Object>{
        'event_type' => 'buyer_activity',
        'buyer_id' => buyerId,
        'organization_id' => orgId,
        'title' => 'Buyer Active',
        'message' => 'Buyer viewed microsite'
      }
    );
  }

  @IsTest
  static void success_notifiesLeadOwner() {
    Lead ld = makeLead();
    insert new Propfocus_Link__c(
      Lead__c = ld.Id,
      Type__c = 'Microsite Generation',
      Project_Name__c = 'Project A',
      URL__c = 'https://example.test/micro',
      Created_At__c = System.now(),
      Status__c = 'Not engaged'
    );
    setContext(validPayload(buyerIdFor(ld), configuredOrgId()));

    Test.startTest();
    PropfocusInboundService.handleEvent();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    Map<String, Object> body = responseBody();
    System.assertEquals(true, body.get('success'));
    System.assertEquals(String.valueOf(ld.Id), body.get('lead_id'));
    System.assertEquals(
      'Engaged',
      [
          SELECT Status__c
          FROM Propfocus_Link__c
          WHERE Lead__c = :ld.Id
          LIMIT 1
        ]
        .Status__c
    );
  }

  @IsTest
  static void blankBody_returns400() {
    setContext('');

    Test.startTest();
    PropfocusInboundService.handleEvent();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
    System.assertEquals(false, responseBody().get('success'));
  }

  @IsTest
  static void invalidJson_returns400() {
    setContext('not-json{{{');

    Test.startTest();
    PropfocusInboundService.handleEvent();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
  }

  @IsTest
  static void missingBuyerId_returns400() {
    setContext(
      JSON.serialize(
        new Map<String, Object>{
          'event_type' => 'buyer_activity',
          'organization_id' => configuredOrgId(),
          'title' => 'Test',
          'message' => 'Test'
        }
      )
    );

    Test.startTest();
    PropfocusInboundService.handleEvent();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
  }

  @IsTest
  static void missingTitleOrMessage_returns400() {
    Lead ld = makeLead();
    setContext(
      JSON.serialize(
        new Map<String, Object>{
          'event_type' => 'buyer_activity',
          'buyer_id' => buyerIdFor(ld),
          'organization_id' => configuredOrgId()
        }
      )
    );

    Test.startTest();
    PropfocusInboundService.handleEvent();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
  }

  @IsTest
  static void wrongOrgId_returns403() {
    Lead ld = makeLead();
    setContext(validPayload(buyerIdFor(ld), 'wrong-org-id'));

    Test.startTest();
    PropfocusInboundService.handleEvent();
    Test.stopTest();

    System.assertEquals(403, RestContext.response.statusCode);
    System.assertEquals(false, responseBody().get('success'));
  }

  @IsTest
  static void salesforceLeadIdAsBuyerId_notifiesLeadOwner() {
    Lead ld = makeLead();
    setContext(validPayload(String.valueOf(ld.Id), configuredOrgId()));

    Test.startTest();
    PropfocusInboundService.handleEvent();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    Map<String, Object> body = responseBody();
    System.assertEquals(true, body.get('success'));
    System.assertEquals(String.valueOf(ld.Id), body.get('lead_id'));
  }

  @IsTest
  static void unknownBuyerId_returns404() {
    setContext(validPayload('DOES-NOT-EXIST', configuredOrgId()));

    Test.startTest();
    PropfocusInboundService.handleEvent();
    Test.stopTest();

    System.assertEquals(404, RestContext.response.statusCode);
    System.assertEquals(false, responseBody().get('success'));
  }

  @IsTest
  static void writebackWithoutNotification_updatesLeadAndReturnsSummary() {
    Lead ld = makeLead();
    setContext(
      JSON.serialize(
        new Map<String, Object>{
          'event_type' => 'lead_sync',
          'buyer_id' => buyerIdFor(ld),
          'organization_id' => configuredOrgId(),
          'lead_data' => new Map<String, Object>{
            'lead_status' => 'Working - Contacted',
            'lead_source' => 'PropFocus'
          }
        }
      )
    );

    Test.startTest();
    PropfocusInboundService.handleEvent();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    Map<String, Object> body = responseBody();
    System.assertEquals(true, body.get('success'));
    System.assertEquals(true, body.get('lead_updated'));
    System.assertEquals(String.valueOf(ld.Id), body.get('lead_id'));

    Lead updatedLead = [SELECT Status, LeadSource FROM Lead WHERE Id = :ld.Id];
    System.assertEquals('Working - Contacted', updatedLead.Status);
    System.assertEquals('PropFocus', updatedLead.LeadSource);
  }

  @IsTest
  static void fullWritebackPayload_updatesAllSections() {
    Lead ld = makeLead();
    setContext(
      JSON.serialize(
        new Map<String, Object>{
          'event_type' => 'lead_sync',
          'buyer_id' => buyerIdFor(ld),
          'organization_id' => configuredOrgId(),
          'lead_data' => new Map<String, Object>{
            'lead_status' => 'Working - Contacted',
            'lead_source' => 'PropFocus'
          },
          'call_logs' => new List<Object>{
            new Map<String, Object>{
              'duration' => '60',
              'disposition' => 'Answered',
              'call_time' => '2026-05-26T10:00:00.000Z'
            }
          },
          'lead_history' => new List<Object>{
            new Map<String, Object>{
              'field_changed' => 'Status',
              'old_value' => 'Open',
              'new_value' => 'Working',
              'changed_by' => 'PropFocus'
            }
          }
        }
      )
    );

    Test.startTest();
    PropfocusInboundService.handleEvent();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    Map<String, Object> body = responseBody();
    System.assertEquals(true, body.get('lead_updated'));
    System.assertEquals(1, body.get('call_logs_created'));
    System.assertEquals(1, body.get('history_rows_created'));
  }

  @IsTest
  static void success_resolvesOpportunityByBuyerId() {
    Opportunity opp = PropfocusTestUtil.createOpportunity('Inbound Opp Buyer');
    setContext(
      validPayload(PropfocusTestUtil.buyerIdFor(opp), configuredOrgId())
    );

    Test.startTest();
    PropfocusInboundService.handleEvent();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    Map<String, Object> body = responseBody();
    System.assertEquals(true, body.get('success'));
    System.assertEquals(String.valueOf(opp.Id), body.get('opportunity_id'));
    System.assertEquals('Opportunity', body.get('record_type'));
    System.assertEquals(null, body.get('lead_id'));
  }

  @IsTest
  static void success_writeback_opportunity_children() {
    Opportunity opp = PropfocusTestUtil.createOpportunity('Inbound Opp Writeback');
    setContext(
      JSON.serialize(
        new Map<String, Object>{
          'event_type' => 'buyer_activity',
          'buyer_id' => PropfocusTestUtil.buyerIdFor(opp),
          'organization_id' => configuredOrgId(),
          'lead_data' => new Map<String, Object>{
            'buyer_name' => 'Updated Opp Name',
            'salesforce_opportunity_id' => String.valueOf(opp.Id)
          },
          'call_logs' => new List<Object>{
            new Map<String, Object>{
              'duration' => '45',
              'disposition' => 'Answered',
              'call_time' => '2026-05-26T10:00:00.000Z'
            }
          },
          'site_visit' => new Map<String, Object>{
            'site_visit_number' => 'SV-OPP-1',
            'site_visit_status' => 'Scheduled',
            'project_name' => 'Tower A'
          }
        }
      )
    );

    Test.startTest();
    PropfocusInboundService.handleEvent();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    Map<String, Object> body = responseBody();
    System.assertEquals(true, body.get('lead_updated'));
    System.assertEquals(1, body.get('call_logs_created'));
    System.assertEquals(true, body.get('site_visit_synced'));

    List<Propfocus_Call_Log__c> logs = [
      SELECT Opportunity__c, Lead__c
      FROM Propfocus_Call_Log__c
      WHERE Opportunity__c = :opp.Id
    ];
    System.assertEquals(1, logs.size());
    System.assertEquals(null, logs[0].Lead__c);

    List<Propfocus_Site_Visit_Sync__c> syncRows = [
      SELECT Opportunity__c, Lead__c, Site_Visit_Number__c
      FROM Propfocus_Site_Visit_Sync__c
      WHERE Opportunity__c = :opp.Id
    ];
    System.assertEquals(1, syncRows.size());
    System.assertEquals('SV-OPP-1', syncRows[0].Site_Visit_Number__c);
    System.assertEquals(null, syncRows[0].Lead__c);
  }
}
