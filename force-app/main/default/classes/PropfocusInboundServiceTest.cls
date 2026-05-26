@IsTest
private class PropfocusInboundServiceTest {

    // The buyer-id field used here is the one that PropfocusConfigService
    // resolves to in test context (standard Lead.Email by default). The
    // package itself ships no customer-specific Lead fields.
    private static final String TEST_BUYER_ID = 'inbound-001@example.com';

    private static Lead makeLead() {
        Lead ld = new Lead(
            LastName = 'Inbound Buyer',
            Company  = 'Test Co',
            Email    = TEST_BUYER_ID
        );
        insert ld;
        return ld;
    }

    private static void setContext(String body) {
        RestRequest req = new RestRequest();
        req.requestURI   = '/services/apexrest/propfocus/events/';
        req.httpMethod   = 'POST';
        req.requestBody  = Blob.valueOf(body);
        req.addHeader('Content-Type', 'application/json');
        RestContext.request  = req;
        RestContext.response = new RestResponse();
    }

    private static Map<String, Object> responseBody() {
        return (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
    }

    private static String validPayload(String buyerId, String orgId) {
        return JSON.serialize(new Map<String, Object>{
            'event_type'      => 'buyer_activity',
            'buyer_id'        => buyerId,
            'organization_id' => orgId,
            'title'           => 'Buyer Active',
            'message'         => 'Buyer viewed microsite'
        });
    }

    @IsTest
    static void success_notifiesLeadOwner() {
        Lead ld = makeLead();
        setContext(validPayload(TEST_BUYER_ID, 'test-org-id'));

        Test.startTest();
        PropfocusInboundService.handleEvent();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = responseBody();
        System.assertEquals(true, body.get('success'));
        System.assertEquals(String.valueOf(ld.Id), body.get('lead_id'));
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
        setContext(JSON.serialize(new Map<String, Object>{
            'event_type'      => 'buyer_activity',
            'organization_id' => 'test-org-id',
            'title'           => 'Test',
            'message'         => 'Test'
        }));

        Test.startTest();
        PropfocusInboundService.handleEvent();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @IsTest
    static void missingTitleOrMessage_returns400() {
        setContext(JSON.serialize(new Map<String, Object>{
            'event_type'      => 'buyer_activity',
            'buyer_id'        => TEST_BUYER_ID,
            'organization_id' => 'test-org-id'
        }));

        Test.startTest();
        PropfocusInboundService.handleEvent();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @IsTest
    static void wrongOrgId_returns403() {
        makeLead();
        setContext(validPayload(TEST_BUYER_ID, 'wrong-org-id'));

        Test.startTest();
        PropfocusInboundService.handleEvent();
        Test.stopTest();

        System.assertEquals(403, RestContext.response.statusCode);
        System.assertEquals(false, responseBody().get('success'));
    }

    @IsTest
    static void unknownBuyerId_returns404() {
        setContext(validPayload('DOES-NOT-EXIST', 'test-org-id'));

        Test.startTest();
        PropfocusInboundService.handleEvent();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
        System.assertEquals(false, responseBody().get('success'));
    }
}
