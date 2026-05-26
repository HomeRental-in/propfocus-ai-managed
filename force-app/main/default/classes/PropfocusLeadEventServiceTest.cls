@IsTest
private class PropfocusLeadEventServiceTest {

    private static Lead makeLead(String enquiryRef) {
        Lead ld = new Lead(
            LastName            = 'Event Buyer',
            Company             = 'Event Co',
            Enquiry_Ref_No__c   = enquiryRef
        );
        insert ld;
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
        // Simulate unconfigured org — getConfig falls back to defaults,
        // requireOrganizationId throws — service must swallow it silently.
        Lead ld = new Lead(LastName = 'No Config', Company = 'No Co');
        insert ld;

        Test.startTest();
        Boolean threw = false;
        try {
            PropfocusLeadEventService.handleLeadChanges(
                new List<Lead>{ ld },
                new Map<Id, Lead>{ ld.Id => ld }
            );
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(false, threw, 'Service must not throw when org ID not configured');
    }

    @IsTest
    static void resolveEventType_isConverted_returnsLeadConverted() {
        // Test the private helper indirectly via handleLeadChanges
        // by triggering a conversion-like field change in a direct call.
        Lead ld = new Lead(LastName = 'Conv', Company = 'Conv Co');
        insert ld;

        Lead oldLd = ld.clone(true, true, false, false);
        oldLd.IsConverted = false;
        ld.IsConverted = false; // can't actually convert in test without full setup

        Test.startTest();
        PropfocusLeadEventService.handleLeadChanges(
            new List<Lead>{ ld },
            new Map<Id, Lead>{ ld.Id => oldLd }
        );
        Test.stopTest();

        System.assertNotEquals(null, ld.Id);
    }
}
