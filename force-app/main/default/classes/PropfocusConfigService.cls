public with sharing class PropfocusConfigService {
  private static final String LOGO_URL = 'https://propfocus.in/assets/logo-DSQFZbaE.png';
  private static final String DEFAULT_NOTIFICATION_TYPE_DEVELOPER_NAME = 'PropFocus_Notification';

  public class Config {
    @AuraEnabled
    public String apiNamedCredential;
    @AuraEnabled
    public String embedBaseUrl;
    @AuraEnabled
    public String organizationId;
    @AuraEnabled
    public String logoUrl;
    @AuraEnabled
    public String buyerIdField;
    @AuraEnabled
    public String leadStatusField;
    @AuraEnabled
    public String buyerNameField;
    @AuraEnabled
    public String projectField;
    @AuraEnabled
    public String preSalesRepSourceField;
    @AuraEnabled
    public String siteVisitObject;
    @AuraEnabled
    public String siteVisitStatusField;
    @AuraEnabled
    public String siteVisitLeadLookupField;
    @AuraEnabled
    public String siteVisitProjectField;
    @AuraEnabled
    public String preSalesOwnerNameField;
    @AuraEnabled
    public String preSalesOwnerPhoneField;
    @AuraEnabled
    public String salesOwnerNameField;
    @AuraEnabled
    public String salesOwnerPhoneField;
    @AuraEnabled
    public String leadSourceField;
    @AuraEnabled
    public String relatedDateSourceField;
    @AuraEnabled
    public String siteVisitNumberField;
    @AuraEnabled
    public String siteVisitTypeField;
    @AuraEnabled
    public String siteVisitDatetimeField;
    @AuraEnabled
    public String siteVisitTeamField;
    @AuraEnabled
    public String siteVisitManagerNameField;
    @AuraEnabled
    public String siteVisitManagerPhoneField;
    @AuraEnabled
    public String siteVisitManagerEmailField;
    @AuraEnabled
    public Boolean embedUsesSalesforceLeadId;
    @AuraEnabled
    public Boolean showCopyModal;
    @AuraEnabled
    public String opportunityBuyerIdField;
    @AuraEnabled
    public String opportunityBuyerNameField;
    @AuraEnabled
    public String opportunityStatusField;
    @AuraEnabled
    public String opportunityProjectField;
    @AuraEnabled
    public String opportunityPreSalesRepSourceField;
    @AuraEnabled
    public String opportunityLeadSourceField;
    @AuraEnabled
    public String opportunityPreSalesOwnerNameField;
    @AuraEnabled
    public String opportunityPreSalesOwnerPhoneField;
    @AuraEnabled
    public String opportunitySalesOwnerNameField;
    @AuraEnabled
    public String opportunitySalesOwnerPhoneField;
    @AuraEnabled
    public String opportunityRelatedDateSourceField;
    @AuraEnabled
    public String siteVisitOpportunityLookupField;
    @AuraEnabled
    public Boolean embedUsesSalesforceOpportunityId;
  }
  public class ConnectionCheckResult {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public Integer statusCode;
    @AuraEnabled
    public String message;
  }

  private static Config cachedConfig;

  public static Config getConfig() {
    if (cachedConfig != null) {
      return cachedConfig;
    }

    Propfocus_Config__mdt configured = Propfocus_Config__mdt.getInstance(
      'Default'
    );

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
      cfg.preSalesRepSourceField = configured.Pre_Sales_Rep_Source_Field__c;
      cfg.siteVisitObject = configured.Site_Visit_Object__c;
      cfg.siteVisitStatusField = configured.Site_Visit_Status_Field__c;
      cfg.siteVisitLeadLookupField = configured.Lead_Lookup_Field__c;
      cfg.siteVisitProjectField = configured.Site_Visit_Project_Field__c;
      cfg.preSalesOwnerNameField = configured.Pre_Sales_Owner_Name_Field__c;
      cfg.preSalesOwnerPhoneField = configured.Pre_Sales_Owner_Phone_Field__c;
      cfg.salesOwnerNameField = configured.Sales_Owner_Name_Field__c;
      cfg.salesOwnerPhoneField = configured.Sales_Owner_Phone_Field__c;
      cfg.leadSourceField = configured.Lead_Source_Field__c;
      cfg.relatedDateSourceField = configured.Related_Date_Source_Field__c;
      cfg.siteVisitNumberField = configured.Site_Visit_Number_Field__c;
      cfg.siteVisitTypeField = configured.Site_Visit_Type_Field__c;
      cfg.siteVisitDatetimeField = configured.Site_Visit_Datetime_Field__c;
      cfg.siteVisitTeamField = configured.Site_Visit_Team_Field__c;
      cfg.siteVisitManagerNameField = configured.Site_Visit_Manager_Name_Field__c;
      cfg.siteVisitManagerPhoneField = configured.Site_Visit_Manager_Phone_Field__c;
      cfg.siteVisitManagerEmailField = configured.Site_Visit_Manager_Email_Field__c;
      cfg.embedUsesSalesforceLeadId =
        configured.Embed_Uses_Salesforce_Lead_Id__c == true;
      cfg.showCopyModal = configured.Show_Copy_Modal__c == true;
      cfg.opportunityBuyerIdField = configured.Opportunity_Buyer_Id_Field__c;
      cfg.opportunityBuyerNameField = configured.Opportunity_Buyer_Name_Field__c;
      cfg.opportunityStatusField = configured.Opportunity_Status_Field__c;
      cfg.opportunityProjectField = configured.Opportunity_Project_Field__c;
      cfg.opportunityPreSalesRepSourceField = configured.Opportunity_Pre_Sales_Rep_Source_Field__c;
      cfg.opportunityLeadSourceField = configured.Opportunity_Lead_Source_Field__c;
      cfg.opportunityPreSalesOwnerNameField = configured.Opportunity_Pre_Sales_Owner_Name_Field__c;
      cfg.opportunityPreSalesOwnerPhoneField = configured.Opportunity_Pre_Sales_Owner_Phone_Field__c;
      cfg.opportunitySalesOwnerNameField = configured.Opportunity_Sales_Owner_Name_Field__c;
      cfg.opportunitySalesOwnerPhoneField = configured.Opportunity_Sales_Owner_Phone_Field__c;
      cfg.opportunityRelatedDateSourceField = configured.Opportunity_Related_Date_Source_Field__c;
      cfg.siteVisitOpportunityLookupField = configured.Opportunity_Lookup_Field__c;
      cfg.embedUsesSalesforceOpportunityId =
        configured.Embed_Uses_Salesforce_Opportunity_Id__c == true;
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
        cfg.buyerIdField = 'Email';
      }
      if (String.isBlank(cfg.leadStatusField)) {
        cfg.leadStatusField = 'Status';
      }
      if (String.isBlank(cfg.buyerNameField)) {
        cfg.buyerNameField = 'LastName';
      }
      if (String.isBlank(cfg.projectField)) {
        cfg.projectField = 'Company';
      }
      if (String.isBlank(cfg.leadSourceField)) {
        cfg.leadSourceField = 'LeadSource';
      }
      if (String.isBlank(cfg.opportunityBuyerIdField)) {
        cfg.opportunityBuyerIdField = 'Description';
      }
      if (String.isBlank(cfg.opportunityBuyerNameField)) {
        cfg.opportunityBuyerNameField = 'Name';
      }
      if (String.isBlank(cfg.opportunityStatusField)) {
        cfg.opportunityStatusField = 'StageName';
      }
      if (String.isBlank(cfg.opportunityProjectField)) {
        cfg.opportunityProjectField = 'NextStep';
      }
      if (String.isBlank(cfg.opportunityLeadSourceField)) {
        cfg.opportunityLeadSourceField = 'LeadSource';
      }
      if (String.isBlank(cfg.siteVisitOpportunityLookupField)) {
        cfg.siteVisitOpportunityLookupField = 'Opportunity__c';
      }
      cfg.embedUsesSalesforceLeadId = true;
      cfg.embedUsesSalesforceOpportunityId = true;
      cfg.showCopyModal = false;
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

  public static List<String> notificationTypeLookupDeveloperNames() {
    List<String> names = new List<String>{
      DEFAULT_NOTIFICATION_TYPE_DEVELOPER_NAME
    };
    String ns = packageNamespace();
    if (String.isNotBlank(ns)) {
      names.add(ns + '__' + DEFAULT_NOTIFICATION_TYPE_DEVELOPER_NAME);
    }
    return names;
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
    return getConfig().preSalesRepSourceField;
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

  public static String requireOpportunityBuyerIdField() {
    String v = getConfig().opportunityBuyerIdField;
    if (String.isBlank(v)) {
      throw new AuraHandledException(
        'Propfocus configuration missing: Opportunity_Buyer_Id_Field__c'
      );
    }
    return v;
  }

  public static String requireOpportunityBuyerNameField() {
    String v = getConfig().opportunityBuyerNameField;
    if (String.isBlank(v)) {
      throw new AuraHandledException(
        'Propfocus configuration missing: Opportunity_Buyer_Name_Field__c'
      );
    }
    return v;
  }

  public static String requireOpportunityStatusField() {
    String v = getConfig().opportunityStatusField;
    if (String.isBlank(v)) {
      throw new AuraHandledException(
        'Propfocus configuration missing: Opportunity_Status_Field__c'
      );
    }
    return v;
  }

  public static String requireOpportunityProjectField() {
    String v = getConfig().opportunityProjectField;
    if (String.isBlank(v)) {
      throw new AuraHandledException(
        'Propfocus configuration missing: Opportunity_Project_Field__c'
      );
    }
    return v;
  }

  public static String getOpportunityPreSalesRepSourceField() {
    return getConfig().opportunityPreSalesRepSourceField;
  }

  public static String requireSiteVisitOpportunityLookupField() {
    String v = getConfig().siteVisitOpportunityLookupField;
    if (String.isBlank(v)) {
      throw new AuraHandledException(
        'Propfocus configuration missing: Opportunity_Lookup_Field__c'
      );
    }
    return v;
  }

  public static String requireSiteVisitProjectField() {
    String v = getConfig().siteVisitProjectField;
    if (String.isBlank(v)) {
      return requireProjectField();
    }
    return v;
  }

  @AuraEnabled(cacheable=true)
  public static Config getUiConfiguration() {
    return getConfig();
  }

  @AuraEnabled(cacheable=true)
  public static String getInboundEndpoint() {
    String base = System.URL.getOrgDomainUrl().toExternalForm();
    return base + '/services/apexrest/PropfocusAI/propfocus/events/';
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
      req.setEndpoint(
        apiEndpoint(
          '/api/v1/organizations/' + organizationId + '/projects?include=all'
        )
      );
      req.setMethod('GET');
      req.setHeader('Accept', 'application/json');
      req.setTimeout(10000);

      HttpResponse res = PropfocusHttpService.send(req);
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

  @TestVisible
  private static String packageNamespace() {
    String objectName = Propfocus_Config__mdt.SObjectType.getDescribe().getName();
    if (!objectName.endsWith('__mdt')) {
      return null;
    }
    String withoutMdt = objectName.substring(0, objectName.length() - 5);
    Integer separatorIndex = withoutMdt.indexOf('__');
    if (separatorIndex <= 0) {
      return null;
    }
    return withoutMdt.substring(0, separatorIndex);
  }

  @TestVisible
  private static String resolveNamedCredential(String namedCredential) {
    return normalizeNamedCredential(namedCredential);
  }

  private static String normalizeNamedCredential(String namedCredential) {
    if (String.isBlank(namedCredential)) {
      return namedCredential;
    }
    String trimmed = namedCredential.trim();
    if (trimmed.contains('__')) {
      return trimmed;
    }
    String ns = packageNamespace();
    if (String.isNotBlank(ns)) {
      return ns + '__' + trimmed;
    }
    return trimmed;
  }
}
