@IsTest
private class PropFocusLeadServiceTest {
    private static String lastRequestBody;

    private class StaticResponseMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        StaticResponseMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HTTPResponse respond(HTTPRequest req) {
            lastRequestBody = req.getBody();
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(responseBody);
            return res;
        }
    }

    private static Lead makeLead() {
        Lead ld = new Lead(
            LastName = 'Coverage Buyer',
            Company = 'Coverage Co'
        );
        insert ld;
        return ld;
    }

    @IsTest
    static void generateMicrositeLink_success_updatesLeadAndHistory() {
        Lead ld = makeLead();
        Test.setMock(
            HttpCalloutMock.class,
            new StaticResponseMock(200, '{"success":true,"micrositeUrl":"https://example.test/micro"}')
        );

        Test.startTest();
        String url = PropFocusLeadService.generateMicrositeLink(
            ld.Id,
            'Client 1',
            new List<String>{ 'Project A', 'Project B' }
        );
        Test.stopTest();

        System.assertEquals('https://example.test/micro', url);
        Lead updatedLead = [
            SELECT Propfocus_Link__c
            FROM Lead
            WHERE Id = :ld.Id
        ];
        System.assertEquals('https://example.test/micro', updatedLead.Propfocus_Link__c);

        List<Propfocus_Link__c> historyRows = [
            SELECT Type__c, Project_Name__c, URL__c, Status__c
            FROM Propfocus_Link__c
            WHERE Lead__c = :ld.Id
        ];
        System.assertEquals(1, historyRows.size());
        System.assertEquals('Microsite', historyRows[0].Type__c);
        System.assertEquals('Project A, Project B', historyRows[0].Project_Name__c);
        System.assertEquals('https://example.test/micro', historyRows[0].URL__c);
        System.assertEquals('Generated', historyRows[0].Status__c);
        System.assert(
            lastRequestBody.contains('"brokerName"')
        );
    }

    @IsTest
    static void generateMicrositeLink_httpError_throwsHandledException() {
        Lead ld = makeLead();

        Test.setMock(
            HttpCalloutMock.class,
            new StaticResponseMock(503, '{"success":false}')
        );
        Boolean firstCallFailedAsExpected = false;
        Test.startTest();
        try {
            PropFocusLeadService.generateMicrositeLink(
                ld.Id,
                'Client 1',
                new List<String>{ 'Project A' }
            );
        } catch (AuraHandledException e) {
            firstCallFailedAsExpected = true;
            String errorMessage = e.getMessage();
            System.assert(
                errorMessage != null && (
                    errorMessage.contains('Propfocus API failed with status 503') ||
                    errorMessage.contains('Script-thrown exception')
                )
            );
        }
        Test.stopTest();
        System.assert(firstCallFailedAsExpected, 'Expected non-200 status to throw AuraHandledException');
    }

    @IsTest
    static void generateMicrositeLink_missingMicrositeUrl_throwsHandledException() {
        Lead ld = makeLead();

        Test.setMock(
            HttpCalloutMock.class,
            new StaticResponseMock(200, '{"success":true}')
        );
        Boolean secondCallFailedAsExpected = false;
        Test.startTest();
        try {
            PropFocusLeadService.generateMicrositeLink(
                ld.Id,
                'Client 1',
                new List<String>{ 'Project A' }
            );
        } catch (AuraHandledException e2) {
            secondCallFailedAsExpected = true;
            String errorMessage = e2.getMessage();
            System.assert(
                errorMessage != null && (
                    errorMessage.contains('Microsite URL not returned by Propfocus') ||
                    errorMessage.contains('Script-thrown exception')
                )
            );
        }
        Test.stopTest();
        System.assert(secondCallFailedAsExpected, 'Expected missing micrositeUrl to throw AuraHandledException');
    }

    @IsTest
    static void generateSiteVisit_wrappers_coverSuccessAndFailurePaths() {
        Lead ld = makeLead();

        Datetime requestedDt = Datetime.newInstance(2026, 1, 15, 9, 30, 0);
        Test.setMock(
            HttpCalloutMock.class,
            new StaticResponseMock(
                200,
                '{"success":true,"data":{"sv_url":"https://example.test/sv"}}'
            )
        );

        Test.startTest();
        String svUrl;
        try {
            svUrl = PropFocusLeadService.generateSiteVisitWithProjectAndDateTime(
                ld.Id,
                'Buyer Override',
                'Project Override',
                requestedDt
            );
        } finally {
            Test.stopTest();
        }

        System.assertEquals('https://example.test/sv', svUrl);
        Lead updatedLead = [
            SELECT Propfocus_Site_Visit__c
            FROM Lead
            WHERE Id = :ld.Id
        ];
        System.assertEquals('https://example.test/sv', updatedLead.Propfocus_Site_Visit__c);

        List<Propfocus_Link__c> historyRows = [
            SELECT Type__c, Project_Name__c, URL__c, Status__c
            FROM Propfocus_Link__c
            WHERE Lead__c = :ld.Id
            ORDER BY CreatedDate DESC
        ];
        System.assert(!historyRows.isEmpty());
        System.assertEquals('Site Visit', historyRows[0].Type__c);
        System.assertEquals('Project Override', historyRows[0].Project_Name__c);
        System.assertEquals('https://example.test/sv', historyRows[0].URL__c);
        System.assertEquals('Confirmed', historyRows[0].Status__c);

    }

    @IsTest
    static void generateSiteVisit_httpError_throwsHandledException() {
        Lead ld = makeLead();
        Test.setMock(
            HttpCalloutMock.class,
            new StaticResponseMock(500, '{"success":false,"message":"error"}')
        );

        Boolean httpErrorFailedAsExpected = false;
        Test.startTest();
        try {
            PropFocusLeadService.generateSiteVisit(ld.Id);
        } catch (AuraHandledException e) {
            httpErrorFailedAsExpected = true;
            String errorMessage = e.getMessage();
            System.assert(
                errorMessage != null && (
                    errorMessage.contains('Propfocus API failed with status 500') ||
                    errorMessage.contains('Script-thrown exception')
                )
            );
        }
        Test.stopTest();
        System.assert(httpErrorFailedAsExpected, 'Expected non-200 status to throw AuraHandledException');
    }

    @IsTest
    static void generateSiteVisit_missingSvUrl_throwsHandledException() {
        Lead ld = makeLead();
        Test.setMock(
            HttpCalloutMock.class,
            new StaticResponseMock(200, '{"success":true,"data":{}}')
        );

        Boolean missingUrlFailedAsExpected = false;
        Test.startTest();
        try {
            PropFocusLeadService.generateSiteVisitWithProject(ld.Id, 'Buyer X', 'Project X');
        } catch (AuraHandledException e2) {
            missingUrlFailedAsExpected = true;
            String errorMessage = e2.getMessage();
            System.assert(
                errorMessage != null && (
                    errorMessage.contains('Site Visit URL not returned by Propfocus') ||
                    errorMessage.contains('Script-thrown exception')
                )
            );
        }
        Test.stopTest();
        System.assert(missingUrlFailedAsExpected, 'Expected missing sv_url to throw AuraHandledException');
    }

    @IsTest
    static void generateSiteVisit_nullLead_throws() {
        try {
            Test.startTest();
            PropFocusLeadService.generateSiteVisit(null);
            Test.stopTest();
            System.assert(false, 'Expected null lead Id to throw AuraHandledException');
        } catch (AuraHandledException e) {
            Test.stopTest();
            String errorMessage = e.getMessage();
            System.assert(
                errorMessage != null && (
                    errorMessage.contains('Lead Id is required') ||
                    errorMessage.contains('Script-thrown exception')
                )
            );
        }
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

        Test.startTest();
        List<Propfocus_Link__c> history = PropFocusLeadService.getLinkHistory(ld.Id);
        Test.stopTest();

        System.assertEquals(2, history.size());
        System.assertEquals('https://example.test/new', history[0].URL__c);
        System.assertEquals('https://example.test/old', history[1].URL__c);
    }
}
