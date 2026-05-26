@IsTest
private class PropfocusConfigServiceTest {
    private class StatusMock implements HttpCalloutMock {
        private Integer code;
        private String body;

        StatusMock(Integer statusCode, String responseBody) {
            code = statusCode;
            body = responseBody;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(body);
            return res;
        }
    }

    @IsTest
    static void testGetInboundEndpoint_returnsUrl() {
        Test.startTest();
        String endpoint = PropfocusConfigService.getInboundEndpoint();
        Test.stopTest();

        System.assertNotEquals(null, endpoint);
        System.assert(endpoint.contains('/services/apexrest/PropfocusAI/propfocus/events/'));
    }

    @IsTest
    static void testGetUiConfiguration_FallbackInTests() {
        Test.startTest();
        PropfocusConfigService.Config cfg = PropfocusConfigService.getUiConfiguration();
        Test.stopTest();

        System.assertNotEquals(null, cfg);
        System.assert(!String.isBlank(cfg.apiNamedCredential));
        System.assert(!String.isBlank(cfg.embedBaseUrl));
        System.assert(!String.isBlank(cfg.organizationId));
        System.assert(!String.isBlank(cfg.logoUrl));
    }

    @IsTest
    static void testConnection_Success() {
        Test.setMock(HttpCalloutMock.class, new StatusMock(200, '{"success":true}'));

        Test.startTest();
        PropfocusConfigService.ConnectionCheckResult result =
            PropfocusConfigService.testConnection();
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(200, result.statusCode);
    }

    @IsTest
    static void testConnection_FailureStatus() {
        Test.setMock(HttpCalloutMock.class, new StatusMock(503, '{"success":false}'));

        Test.startTest();
        PropfocusConfigService.ConnectionCheckResult result =
            PropfocusConfigService.testConnection();
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals(503, result.statusCode);
    }
}
