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
}
