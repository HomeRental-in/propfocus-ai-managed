@IsTest
private class PropfocusLeadTrackingServiceTest {
    private static Lead makeLead() {
        Lead ld = new Lead(
            LastName = 'Tracking Buyer',
            Company = 'Tracking Co'
        );
        insert ld;
        return ld;
    }

    @IsTest
    static void getLeadForTracking_returnsWrapper() {
        Lead ld = makeLead();

        Test.startTest();
        PropfocusLeadTrackingWrapper wrapper =
            PropfocusLeadTrackingService.getLeadForTracking(ld.Id);
        Test.stopTest();

        System.assertNotEquals(null, wrapper);
        System.assertEquals(true, wrapper.success);
        System.assertEquals(ld.Id, wrapper.lead.Id);
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
}
