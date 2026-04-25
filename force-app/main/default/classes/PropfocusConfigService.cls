public with sharing class PropfocusConfigService {
    private static final String LOGO_URL =
        'https://propfocus.in/assets/logo-DSQFZbaE.png';
    private static final String DEFAULT_NOTIFICATION_TYPE_DEVELOPER_NAME =
        'PropFocus_Notification';
    private static final String DEFAULT_PRE_SALES_REP_SOURCE_FIELD =
        'Pre_Sales_Rep_Source__c';

    public class Config {
        @AuraEnabled public String apiNamedCredential;
        @AuraEnabled public String embedBaseUrl;
        @AuraEnabled public String organizationId;
        @AuraEnabled public String logoUrl;
        @AuraEnabled public String buyerIdField;
        @AuraEnabled public String leadStatusField;
        @AuraEnabled public String buyerNameField;
        @AuraEnabled public String projectField;
        @AuraEnabled public String siteVisitObject;
        @AuraEnabled public String siteVisitStatusField;
        @AuraEnabled public String siteVisitLeadLookupField;
    }
    public class ConnectionCheckResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Integer statusCode;
        @AuraEnabled public String message;
    }

    private static Config cachedConfig;

    public static Config getConfig() {
        if (cachedConfig != null) {
            return cachedConfig;
        }

        Propfocus_Config__mdt configured =
            Propfocus_Config__mdt.getInstance('Default');

        Config cfg = new Config();
        if (configured != null) {
            cfg.apiNamedCredential = normalizeNamedCredential(
                configured.Api_Named_Credential__c
            );
            cfg.embedBaseUrl = normalizeBaseUrl(configured.Embed_Base_Url__c);
            cfg.organizationId = configured.Organization_Id__c;
            cfg.buyerIdField = configured.Buyer_Id_Field__c;
            cfg.leadStatusField = configured.Lead_Status_Field__c;
            cfg.buyerNameField = configured.Buyer_Name_Field__c;
            cfg.projectField = configured.Project_Field__c;
            cfg.siteVisitObject = configured.Site_Visit_Object__c;
            cfg.siteVisitStatusField = configured.Site_Visit_Status_Field__c;
            cfg.siteVisitLeadLookupField = configured.Lead_Lookup_Field__c;
        }

        cfg.logoUrl = LOGO_URL;

        if (Test.isRunningTest()) {
            if (String.isBlank(cfg.apiNamedCredential)) {
                cfg.apiNamedCredential = 'Propfocus_API';
            }
            if (String.isBlank(cfg.embedBaseUrl)) {
                cfg.embedBaseUrl = 'https://test.embed.local/embed/salesforce';
            }
            if (String.isBlank(cfg.organizationId)) {
                cfg.organizationId = 'test-org-id';
            }
            if (String.isBlank(cfg.buyerIdField)) {
                cfg.buyerIdField = 'Enquiry_Ref_No__c';
            }
            if (String.isBlank(cfg.leadStatusField)) {
                cfg.leadStatusField = 'Lead_Status__c';
            }
            if (String.isBlank(cfg.buyerNameField)) {
                cfg.buyerNameField = 'Full_Name__c';
            }
            if (String.isBlank(cfg.projectField)) {
                cfg.projectField = 'Project_Interested__c';
            }
            if (String.isBlank(cfg.siteVisitObject)) {
                cfg.siteVisitObject = 'Site_Visit__c';
            }
            if (String.isBlank(cfg.siteVisitStatusField)) {
                cfg.siteVisitStatusField = 'Status__c';
            }
            if (String.isBlank(cfg.siteVisitLeadLookupField)) {
                cfg.siteVisitLeadLookupField = 'Lead__c';
            }
        }

        cachedConfig = cfg;
        return cachedConfig;
    }

    public static String requireApiNamedCredential() {
        String v = getConfig().apiNamedCredential;
        if (String.isBlank(v)) {
            throw new AuraHandledException(
                'Propfocus configuration missing: Api_Named_Credential__c'
            );
        }
        return v;
    }

    public static String apiEndpoint(String path) {
        String namedCredential = requireApiNamedCredential();
        String sanitizedPath = String.isBlank(path) ? '' : path.trim();
        if (!String.isBlank(sanitizedPath) && !sanitizedPath.startsWith('/')) {
            sanitizedPath = '/' + sanitizedPath;
        }
        return 'callout:' + namedCredential + sanitizedPath;
    }

    public static String requireEmbedBaseUrl() {
        String v = getConfig().embedBaseUrl;
        if (String.isBlank(v)) {
            throw new AuraHandledException(
                'Propfocus configuration missing: Embed_Base_Url__c'
            );
        }
        return v;
    }

    public static String requireOrganizationId() {
        String v = getConfig().organizationId;
        if (String.isBlank(v)) {
            throw new AuraHandledException(
                'Propfocus configuration missing: Organization_Id__c'
            );
        }
        return v;
    }

    public static String requireNotificationTypeDeveloperName() {
        return DEFAULT_NOTIFICATION_TYPE_DEVELOPER_NAME;
    }

    public static String requireBuyerIdField() {
        String v = getConfig().buyerIdField;
        if (String.isBlank(v)) {
            throw new AuraHandledException(
                'Propfocus configuration missing: Buyer_Id_Field__c'
            );
        }
        return v;
    }

    public static String requireLeadStatusField() {
        String v = getConfig().leadStatusField;
        if (String.isBlank(v)) {
            throw new AuraHandledException(
                'Propfocus configuration missing: Lead_Status_Field__c'
            );
        }
        return v;
    }

    public static String requireBuyerNameField() {
        String v = getConfig().buyerNameField;
        if (String.isBlank(v)) {
            throw new AuraHandledException(
                'Propfocus configuration missing: Buyer_Name_Field__c'
            );
        }
        return v;
    }

    public static String requireProjectField() {
        String v = getConfig().projectField;
        if (String.isBlank(v)) {
            throw new AuraHandledException(
                'Propfocus configuration missing: Project_Field__c'
            );
        }
        return v;
    }

    public static String getPreSalesRepSourceField() {
        return DEFAULT_PRE_SALES_REP_SOURCE_FIELD;
    }

    public static String requireSiteVisitObject() {
        String v = getConfig().siteVisitObject;
        if (String.isBlank(v)) {
            throw new AuraHandledException(
                'Propfocus configuration missing: Site_Visit_Object__c'
            );
        }
        return v;
    }

    public static String requireSiteVisitStatusField() {
        String v = getConfig().siteVisitStatusField;
        if (String.isBlank(v)) {
            throw new AuraHandledException(
                'Propfocus configuration missing: Site_Visit_Status_Field__c'
            );
        }
        return v;
    }

    public static String requireSiteVisitLeadLookupField() {
        String v = getConfig().siteVisitLeadLookupField;
        if (String.isBlank(v)) {
            throw new AuraHandledException(
                'Propfocus configuration missing: Lead_Lookup_Field__c'
            );
        }
        return v;
    }

    public static String requireSiteVisitProjectField() {
        return requireProjectField();
    }

    @AuraEnabled(cacheable=true)
    public static Config getUiConfiguration() {
        return getConfig();
    }

    @AuraEnabled
    public static ConnectionCheckResult testConnection() {
        ConnectionCheckResult result = new ConnectionCheckResult();
        result.success = false;

        try {
            String organizationId = EncodingUtil.urlEncode(
                requireOrganizationId(),
                'UTF-8'
            );
            HttpRequest req = new HttpRequest();
            req.setEndpoint(apiEndpoint(
                '/api/v1/organizations/' + organizationId + '/projects?include=all'
            ));
            req.setMethod('GET');
            req.setHeader('Accept', 'application/json');
            req.setTimeout(10000);

            HttpResponse res = (new Http()).send(req);
            result.statusCode = res.getStatusCode();
            if (res.getStatusCode() != 200) {
                result.message = 'Connection failed with status ' + res.getStatusCode();
                return result;
            }

            result.success = true;
            result.message = 'Connection successful';
            return result;
        } catch (Exception e) {
            result.message = e.getMessage();
            return result;
        }
    }

    private static String normalizeBaseUrl(String url) {
        if (String.isBlank(url)) {
            return url;
        }
        String trimmed = url.trim();
        while (trimmed.endsWith('/')) {
            trimmed = trimmed.substring(0, trimmed.length() - 1);
        }
        return trimmed;
    }

    private static String normalizeNamedCredential(String namedCredential) {
        if (String.isBlank(namedCredential)) {
            return namedCredential;
        }
        return namedCredential.trim();
    }
}
