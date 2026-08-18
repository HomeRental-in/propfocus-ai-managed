@IsTest
private class PropfocusLeadTrackingServiceTest {
  private static Lead makeLead() {
    return PropfocusTestUtil.createLead('Tracking Buyer');
  }

  @IsTest
  static void getLeadForTracking_returnsWrapper() {
    Lead ld = makeLead();

    Test.startTest();
    PropfocusLeadTrackingWrapper wrapper = PropfocusLeadTrackingService.getLeadForTracking(
      ld.Id
    );
    Test.stopTest();

    System.assertNotEquals(null, wrapper);
    System.assertEquals(true, wrapper.success);
    System.assertEquals(ld.Id, wrapper.lead.Id);
    System.assertNotEquals(null, wrapper.history);
    System.assertEquals(0, wrapper.history.size());
  }

  @IsTest
  static void notifyLeadOwner_requiresTitleAndMessage() {
    Lead ld = makeLead();
    Boolean failedAsExpected = false;

    Test.startTest();
    try {
      PropfocusLeadTrackingService.notifyLeadOwner(
        String.valueOf(ld.Id),
        new Map<String, Object>{ 'title' => 'Test' }
      );
    } catch (IllegalArgumentException e) {
      failedAsExpected = true;
      System.assert(e.getMessage().contains('title and message'));
    }
    Test.stopTest();

    System.assertEquals(true, failedAsExpected);
  }

  @IsTest
  static void notifyLeadOwner_requiresMessageWhenOnlyTitle() {
    Lead ld = makeLead();
    Boolean failedAsExpected = false;

    Test.startTest();
    try {
      PropfocusLeadTrackingService.notifyLeadOwner(
        String.valueOf(ld.Id),
        new Map<String, Object>{ 'message' => 'Body only, no title' }
      );
    } catch (IllegalArgumentException e) {
      failedAsExpected = true;
      System.assert(
        e.getMessage().contains('title and message'),
        'Expected title/message validation message'
      );
    }
    Test.stopTest();

    System.assertEquals(true, failedAsExpected);
  }

  @IsTest
  static void notifyLeadOwner_blankRecordId_throws() {
    Boolean failedAsExpected = false;

    Test.startTest();
    try {
      PropfocusLeadTrackingService.notifyLeadOwner(
        '',
        new Map<String, Object>{ 'title' => 'T', 'message' => 'M' }
      );
    } catch (IllegalArgumentException e) {
      failedAsExpected = true;
      System.assert(
        e.getMessage().contains('Record Id is required'),
        'Expected blank record id message'
      );
    }
    Test.stopTest();

    System.assertEquals(true, failedAsExpected);
  }

  @IsTest
  static void notifyLeadOwner_invalidRecordId_throws() {
    Boolean failedAsExpected = false;

    Test.startTest();
    try {
      PropfocusLeadTrackingService.notifyLeadOwner(
        'not-a-valid-id',
        new Map<String, Object>{ 'title' => 'T', 'message' => 'M' }
      );
    } catch (IllegalArgumentException e) {
      failedAsExpected = true;
      System.assert(
        e.getMessage().contains('Invalid Record Id'),
        'Expected invalid record id message'
      );
    }
    Test.stopTest();

    System.assertEquals(true, failedAsExpected);
  }

  @IsTest
  static void notifyLeadOwner_success_returnsOwnerId() {
    Lead ld = makeLead();

    Test.startTest();
    Id ownerId = PropfocusLeadTrackingService.notifyLeadOwner(
      String.valueOf(ld.Id),
      new Map<String, Object>{
        'title' => 'Buyer Active',
        'message' => 'Buyer viewed microsite'
      }
    );
    Test.stopTest();

    System.assertEquals(ld.OwnerId, ownerId);
  }

  @IsTest
  static void notifyLeadOwner_opportunity_returnsOwnerId() {
    Opportunity opp = PropfocusTestUtil.createOpportunity('Tracking Opp');

    Test.startTest();
    Id ownerId = PropfocusLeadTrackingService.notifyLeadOwner(
      String.valueOf(opp.Id),
      new Map<String, Object>{
        'title' => 'Buyer Active',
        'message' => 'Buyer viewed post-visit page'
      }
    );
    Test.stopTest();

    // Resolves the Opportunity owner via the Opportunity SObjectType branch.
    System.assertEquals(opp.OwnerId, ownerId);
  }
}
