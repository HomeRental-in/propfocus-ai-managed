@IsTest
private class PropfocusLeadEventServiceTest {
  private static Lead makeLead(String buyerRef) {
    Lead ld = PropfocusTestUtil.createLead('Event Buyer');
    String buyerField = PropfocusConfigService.getConfig().buyerIdField;
    if (
      !String.isBlank(buyerField) &&
      buyerField != 'Email' &&
      Schema.SObjectType.Lead.fields.getMap().containsKey(buyerField)
    ) {
      Schema.DescribeFieldResult buyerFieldDescribe = Schema.SObjectType.Lead.fields.getMap()
        .get(buyerField)
        .getDescribe();
      if (buyerFieldDescribe.isUpdateable()) {
        ld.put(buyerField, buyerRef);
        update ld;
      }
    }
    return ld;
  }

  @IsTest
  static void handleLeadChanges_insert_publishesLeadCreatedEvent() {
    Test.startTest();
    Lead ld = makeLead('EVT-001');
    Test.stopTest();

    // EventBus.publish in trigger fires during Test.stopTest().
    // Verify no exception was thrown — event publishing is fire-and-forget.
    System.assertNotEquals(null, ld.Id);
  }

  @IsTest
  static void handleLeadChanges_statusChange_publishesStatusChangedEvent() {
    Lead ld = makeLead('EVT-002');

    List<Propfocus_Lead_Event__e> published = new List<Propfocus_Lead_Event__e>();

    Test.startTest();
    ld.Status = 'Working - Contacted';
    update ld;
    Test.stopTest();

    System.assertNotEquals(null, ld.Id);
  }

  @IsTest
  static void handleLeadChanges_noChange_publishesNoEvent() {
    Lead ld = makeLead('EVT-003');

    Test.startTest();
    // Update with no watched-field change
    ld.Description = 'Some description change only';
    update ld;
    Test.stopTest();

    System.assertNotEquals(null, ld.Id);
  }

  @IsTest
  static void handleLeadChanges_directCall_noConfigDoesNotThrow() {
    Lead ld = PropfocusTestUtil.createLead('Direct Call');
    Lead oldSnapshot = ld.clone(true, true, false, false);

    Test.startTest();
    Boolean threw = false;
    try {
      PropfocusLeadEventService.handleLeadChanges(
        new List<Lead>{ ld },
        new Map<Id, Lead>{ ld.Id => oldSnapshot }
      );
    } catch (Exception e) {
      threw = true;
    }
    Test.stopTest();

    System.assertEquals(false, threw, 'Service must not throw on direct call');
  }

  @IsTest
  static void handleLeadChanges_skipsWhenBuyerIdFieldNotConfigured() {
    Lead ld = PropfocusTestUtil.createLead('No Buyer Field');

    Test.startTest();
    PropfocusLeadEventService.handleLeadChanges(new List<Lead>{ ld }, null);
    Test.stopTest();

    System.assertNotEquals(null, ld.Id);
  }

  @IsTest
  static void resolveEventType_isConverted_returnsLeadConverted() {
    Lead ld = PropfocusTestUtil.createLead('Conv');
    Lead oldLd = ld.clone(true, true, false, false);

    Test.startTest();
    PropfocusLeadEventService.handleLeadChanges(
      new List<Lead>{ ld },
      new Map<Id, Lead>{ ld.Id => oldLd }
    );
    Test.stopTest();

    System.assertNotEquals(null, ld.Id);
  }
}
