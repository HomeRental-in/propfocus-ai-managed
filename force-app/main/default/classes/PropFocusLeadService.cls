public class PropFocusLeadService {
    // Fixed JSON key in the Propfocus API request body. This is a wire-contract
    // with the Propfocus backend and is intentionally independent of any
    // Salesforce field API name or namespace.
    private static final String API_LEAD_STATUS_KEY = 'leadStatus';

    private static void createPropfocusLinkHistory(
        Id leadId,
        String typeValue,
        String projectName,
        String urlValue,
        String statusValue
    ) {
        if (leadId == null || String.isBlank(urlValue)) {
            return;
        }
        Propfocus_Link__c historyRow = new Propfocus_Link__c(
            Lead__c = leadId,
            Type__c = typeValue,
            Project_Name__c = projectName,
            URL__c = urlValue,
            Created_At__c = System.now(),
            Status__c = statusValue
        );
        insert historyRow;
    }

    private static String requireLeadFieldApiName(String value, String configFieldApiName) {
        String fieldApiName = requireSafeApiName(value, configFieldApiName);
        if (!Schema.SObjectType.Lead.fields.getMap().containsKey(fieldApiName)) {
            throw new AuraHandledException(
                'Configured lead field not found: ' + fieldApiName
            );
        }
        return fieldApiName;
    }

    private static String getPreSalesRepSourceFieldApiName() {
        String configuredFieldApiName = PropfocusConfigService.getPreSalesRepSourceField();
        if (String.isBlank(configuredFieldApiName)) {
            return null;
        }
        return requireLeadFieldApiName(
            configuredFieldApiName,
            'Pre_Sales_Rep_Source_Field__c'
        );
    }

    private static String resolvePreSalesRepSource(
        SObject leadRecord,
        String preSalesRepSourceFieldApiName
    ) {
        if (!String.isBlank(preSalesRepSourceFieldApiName)) {
            String mappedValue = asString(leadRecord.get(preSalesRepSourceFieldApiName));
            if (!String.isBlank(mappedValue)) {
                return mappedValue;
            }
        }
        SObject ownerRecord = leadRecord.getSObject('Owner');
        if (ownerRecord == null) {
            return null;
        }
        return asString(ownerRecord.get('Name'));
    }

    private static SObject queryLeadById(Id leadId, List<String> fieldApiNames) {
        Set<String> selectedFields = new Set<String>{ 'Id' };
        for (String f : fieldApiNames) {
            if (!String.isBlank(f)) {
                selectedFields.add(f);
            }
        }
        String soql =
            'SELECT ' + String.join(new List<String>(selectedFields), ', ') +
            ' FROM Lead WHERE Id = :leadId LIMIT 1';
        return Database.query(soql);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getLeadDetails(Id leadId){
        String buyerIdFieldApiName = requireLeadFieldApiName(
            PropfocusConfigService.requireBuyerIdField(),
            'Buyer_Id_Field__c'
        );
        String buyerNameFieldApiName = requireLeadFieldApiName(
            PropfocusConfigService.requireBuyerNameField(),
            'Buyer_Name_Field__c'
        );
        String projectFieldApiName = requireLeadFieldApiName(
            PropfocusConfigService.requireProjectField(),
            'Project_Field__c'
        );
        SObject ld = queryLeadById(
            leadId,
            new List<String>{
                'Propfocus_Link__c',
                'Propfocus_Buyer_Insights_Available__c',
                buyerIdFieldApiName,
                buyerNameFieldApiName,
                projectFieldApiName
            }
        );
        return new Map<String, Object>{
            'Id' => ld.get('Id'),
            'Propfocus_Link__c' => ld.get('Propfocus_Link__c'),
            'buyerInsightsAvailable' => ld.get('Propfocus_Buyer_Insights_Available__c'),
            'buyerId' => ld.get(buyerIdFieldApiName),
            'buyerName' => ld.get(buyerNameFieldApiName),
            'projectName' => ld.get(projectFieldApiName)
        };
    }

    @AuraEnabled
    public static String generateMicrositeLink(Id leadId, String clientName, List<String> listProj) {
        if (leadId == null) {
            throw new AuraHandledException('Lead Id is required');
        }

        String buyerIdFieldApiName = requireLeadFieldApiName(
            PropfocusConfigService.requireBuyerIdField(),
            'Buyer_Id_Field__c'
        );
        String leadStatusFieldApiName = requireLeadFieldApiName(
            PropfocusConfigService.requireLeadStatusField(),
            'Lead_Status_Field__c'
        );
        String preSalesRepSourceFieldApiName = getPreSalesRepSourceFieldApiName();
        List<String> leadFieldApiNames = new List<String>{
            'Owner.Name',
            'Propfocus_Link__c',
            'Propfocus_Buyer_Insights_Available__c',
            buyerIdFieldApiName,
            leadStatusFieldApiName
        };
        if (!String.isBlank(preSalesRepSourceFieldApiName)) {
            leadFieldApiNames.add(preSalesRepSourceFieldApiName);
        }
        SObject ld = queryLeadById(
            leadId,
            leadFieldApiNames
        );

        String organizationId = PropfocusConfigService.requireOrganizationId();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            PropfocusConfigService.apiEndpoint('/api/broker-microsite/create')
        );
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        Map<String, Object> body = new Map<String, Object>{
            'brokerName' => resolvePreSalesRepSource(ld, preSalesRepSourceFieldApiName),
            'clientName' => clientName,
            'projects' => listProj,
            API_LEAD_STATUS_KEY => ld.get(leadStatusFieldApiName),
            'organizationId' => organizationId,
            'buyer_id' => ld.get(buyerIdFieldApiName)
        };

        req.setBody(JSON.serialize(body));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new AuraHandledException(
                'Propfocus API failed with status ' + res.getStatusCode()
            );
        }

        Map<String, Object> response =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        if (response.containsKey('success') && response.get('success') == false) {
            String apiError = (String) response.get('error_message');
            throw new AuraHandledException(apiError);
        }

        if (!response.containsKey('micrositeUrl')) {
            throw new AuraHandledException('Microsite URL not returned by Propfocus');
        }

        String micrositeUrl = (String) response.get('micrositeUrl');
        ld.put('Propfocus_Link__c', micrositeUrl);
        ld.put('Propfocus_Buyer_Insights_Available__c', true);
        update ld;
        createPropfocusLinkHistory(
            ld.Id,
            'Microsite',
            (listProj == null || listProj.isEmpty()) ? null : String.join(listProj, ', '),
            micrositeUrl,
            'Generated'
        );

        return micrositeUrl;
    }

    private static List<String> getProjectsByEndpoint(String endpointPath) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(PropfocusConfigService.apiEndpoint(endpointPath));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new AuraHandledException(
                'Propfocus API failed with status ' + res.getStatusCode()
            );
        }

        Map<String, Object> response =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        if (response.containsKey('success') && response.get('success') == false) {
            String apiError = (String) response.get('error_message');
            throw new AuraHandledException(apiError);
        }

        Map<String, Object> dataMap =
            (Map<String, Object>) response.get('data');
        List<Object> projectObjs =
            (List<Object>) dataMap.get('projects');
        List<String> projects = new List<String>();

        for (Object proj : projectObjs) {
            projects.add((String) proj);
        }

        return projects;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getProjects() {
        String organizationId = EncodingUtil.urlEncode(
            PropfocusConfigService.requireOrganizationId(),
            'UTF-8'
        );
        return getProjectsByEndpoint(
            '/api/v1/organizations/' + organizationId + '/projects?include=all'
        );
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getProjectsForSiteVisit() {
        String organizationId = EncodingUtil.urlEncode(
            PropfocusConfigService.requireOrganizationId(),
            'UTF-8'
        );
        return getProjectsByEndpoint(
            '/api/v1/organizations/' + organizationId + '/projects'
        );
    }

    private static String requireSafeApiName(String value, String configFieldApiName) {
        if (String.isBlank(value) || !Pattern.matches('^[A-Za-z][A-Za-z0-9_]*(__c)?$', value)) {
            throw new AuraHandledException(
                'Invalid API name configured for ' + configFieldApiName
            );
        }
        return value;
    }

    private static Schema.SObjectType requireSiteVisitObjectType(String objectApiName) {
        return Schema.getGlobalDescribe().get(objectApiName);
    }

    public static List<SObject> queryLatestSiteVisitsForTracking(
        Id leadId,
        Integer rowLimit
    ) {
        return queryLatestSiteVisits(leadId, rowLimit);
    }

    private static List<SObject> queryLatestSiteVisits(
        Id leadId,
        Integer rowLimit
    ) {
        String objectApiName = requireSafeApiName(
            PropfocusConfigService.requireSiteVisitObject(),
            'Site_Visit_Object__c'
        );
        String statusFieldApiName = requireSafeApiName(
            PropfocusConfigService.requireSiteVisitStatusField(),
            'Site_Visit_Status_Field__c'
        );
        String leadLookupFieldApiName = requireSafeApiName(
            PropfocusConfigService.requireSiteVisitLeadLookupField(),
            'Lead_Lookup_Field__c'
        );
        String projectFieldApiName = requireSafeApiName(
            PropfocusConfigService.requireSiteVisitProjectField(),
            'Site_Visit_Project_Field__c'
        );

        Schema.SObjectType objectType = requireSiteVisitObjectType(objectApiName);
        if (objectType == null) {
            return new List<SObject>();
        }
        Map<String, Schema.SObjectField> fieldsByApiName =
            objectType.getDescribe().fields.getMap();
        List<String> requiredFields = new List<String>{
            'Id',
            'CreatedDate',
            statusFieldApiName,
            leadLookupFieldApiName,
            projectFieldApiName
        };
        for (String fieldApiName : requiredFields) {
            if (!fieldsByApiName.containsKey(fieldApiName)) {
                return new List<SObject>();
            }
        }

        String soql =
            'SELECT Id, CreatedDate, ' +
            statusFieldApiName + ', ' + projectFieldApiName +
            ' FROM ' + objectApiName +
            ' WHERE ' + leadLookupFieldApiName + ' = :leadId';
        soql += ' ORDER BY CreatedDate DESC LIMIT ' + rowLimit;
        return Database.query(soql);
    }

    private static Datetime asDatetime(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Datetime) {
            return (Datetime) value;
        }
        if (value instanceof Date) {
            Date dateValue = (Date) value;
            return Datetime.newInstance(dateValue.year(), dateValue.month(), dateValue.day());
        }
        return null;
    }

    private static String asString(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static Boolean isMissingSiteVisitMetadata(Exception ex) {
        if (ex == null || String.isBlank(ex.getMessage())) {
            return false;
        }
        String message = ex.getMessage();
        return message.startsWith('Configured site visit object not found:') ||
            message.startsWith('Configured site visit field not found:');
    }

    @AuraEnabled(cacheable=true)
    public static Datetime getLatestSiteVisitDateTime(Id leadId) {
        if (leadId == null) {
            return null;
        }
        List<SObject> svList;
        try {
            svList = queryLatestSiteVisits(leadId, 1);
        } catch (AuraHandledException ex) {
            if (!isMissingSiteVisitMetadata(ex)) {
                throw ex;
            }
            return null;
        }
        if (svList == null || svList.isEmpty()) {
            return null;
        }
        return (Datetime) svList[0].get('CreatedDate');
    }

    private static String generateSiteVisitInternal(
        Id leadId,
        String buyerName,
        String projectName,
        Datetime requestedVisitDateTime
    ) {
        if (leadId == null) {
            throw new AuraHandledException('Lead Id is required');
        }

        String buyerIdFieldApiName = requireLeadFieldApiName(
            PropfocusConfigService.requireBuyerIdField(),
            'Buyer_Id_Field__c'
        );
        String buyerNameFieldApiName = requireLeadFieldApiName(
            PropfocusConfigService.requireBuyerNameField(),
            'Buyer_Name_Field__c'
        );
        String projectFieldApiName = requireLeadFieldApiName(
            PropfocusConfigService.requireProjectField(),
            'Project_Field__c'
        );
        String preSalesRepSourceFieldApiName = getPreSalesRepSourceFieldApiName();
        List<String> leadFieldApiNames = new List<String>{
            'Owner.Name',
            'Propfocus_Site_Visit__c',
            buyerIdFieldApiName,
            buyerNameFieldApiName,
            projectFieldApiName
        };
        if (!String.isBlank(preSalesRepSourceFieldApiName)) {
            leadFieldApiNames.add(preSalesRepSourceFieldApiName);
        }
        SObject ld = queryLeadById(
            leadId,
            leadFieldApiNames
        );

        Datetime effectiveVisitDateTime;
        if (requestedVisitDateTime != null) {
            effectiveVisitDateTime = requestedVisitDateTime;
        } else {
            effectiveVisitDateTime = System.now();
        }

        String userTimeZoneId = UserInfo.getTimeZone().getID();
        String visitDate = effectiveVisitDateTime.format('dd/MM/yyyy', userTimeZoneId);
        String visitTime = effectiveVisitDateTime.format('HH:mm', userTimeZoneId);

        String organizationId = PropfocusConfigService.requireOrganizationId();

        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            PropfocusConfigService.apiEndpoint('/api/site-visit/create-sv')
        );
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        String resolvedProjectName = String.isBlank(projectName)
            ? asString(ld.get(projectFieldApiName))
            : projectName;
        String resolvedBuyerName = String.isBlank(buyerName)
            ? asString(ld.get(buyerNameFieldApiName))
            : buyerName;

        Map<String, Object> body = new Map<String, Object>{
            'buyer_id' => ld.get(buyerIdFieldApiName),
            'project_name' => resolvedProjectName,
            'visit_date' => visitDate,
            'visit_time' => visitTime,
            'buyer_name' => resolvedBuyerName,
            'brokerName' => resolvePreSalesRepSource(ld, preSalesRepSourceFieldApiName),
            'organizationId' => organizationId
        };

        req.setBody(JSON.serialize(body));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new AuraHandledException(
                'Propfocus API failed with status ' + res.getStatusCode()
            );
        }

        Map<String, Object> response =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        if (!(Boolean) response.get('success')) {
            throw new AuraHandledException((String) response.get('message'));
        }

        Map<String, Object> dataMap =
            (Map<String, Object>) response.get('data');

        if (dataMap == null || !dataMap.containsKey('sv_url')) {
            throw new AuraHandledException('Site Visit URL not returned by Propfocus');
        }

        String micrositeUrl = (String) dataMap.get('sv_url');
        ld.put('Propfocus_Site_Visit__c', micrositeUrl);
        update ld;
        createPropfocusLinkHistory(
            ld.Id,
            'Site Visit',
            resolvedProjectName,
            micrositeUrl,
            'Confirmed'
        );

        return micrositeUrl;
    }

    @AuraEnabled
    public static String generateSiteVisitWithProjectAndDateTime(
        Id leadId,
        String buyerName,
        String projectName,
        Datetime visitDateTime
    ) {
        return generateSiteVisitInternal(leadId, buyerName, projectName, visitDateTime);
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isBuyerInsightsAvailable(Id leadId) {
        if (leadId == null) {
            return false;
        }

        List<Lead> leads = [
            SELECT Propfocus_Buyer_Insights_Available__c
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];
        if (leads.isEmpty()) {
            return false;
        }
        return leads[0].Propfocus_Buyer_Insights_Available__c == true;
    }

    @AuraEnabled(cacheable=true)
    public static List<Propfocus_Link__c> getLinkHistory(Id leadId) {
        if (leadId == null) {
            return new List<Propfocus_Link__c>();
        }
        return [
            SELECT Id, Type__c, Project_Name__c, URL__c, Created_At__c, Status__c
            FROM Propfocus_Link__c
            WHERE Lead__c = :leadId
            ORDER BY Created_At__c DESC
            LIMIT 50
        ];
    }
}
