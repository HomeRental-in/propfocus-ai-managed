public class PropFocusLeadService {
  // Fixed JSON key in the Propfocus API request body. This is a wire-contract
  // with the Propfocus backend and is intentionally independent of any
  // Salesforce field API name or namespace.
  private static final String API_LEAD_STATUS_KEY = 'leadStatus';

  public class LinkHistoryItem {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String type;
    @AuraEnabled
    public String projectName;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String url;
    @AuraEnabled
    public Datetime createdAt;
  }

  public class SiteVisitManagerItem {
    @AuraEnabled
    public String id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String phone;
  }

  public class SalesTeamMemberItem {
    @AuraEnabled
    public String id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String displayName;
  }

  public class BuyerInsightsEmbedContext {
    @AuraEnabled
    public String embedUrl;
    @AuraEnabled
    public String embedKey;
    @AuraEnabled
    public Boolean usesSalesforceLeadId;
    @AuraEnabled
    public Boolean buyerInsightsAvailable;
  }

  public class PropfocusLinkResult {
    @AuraEnabled
    public String url;
    @AuraEnabled
    public String whatsappMessage;
  }

  public class PropfocusTemplateResult {
    @AuraEnabled
    @InvocableVariable
    public String url;
    @AuraEnabled
    @InvocableVariable
    public String whatsappMessage;
    @AuraEnabled
    @InvocableVariable
    public String mediaUrl;
    @AuraEnabled
    @InvocableVariable
    public String communicationType;
  }

  public class GenerateTemplateRequest {
    @InvocableVariable(required=true label='Record Id' description='Lead or Opportunity Id')
    public Id leadId;
    @InvocableVariable(
      required=true
      label='Communication Type'
      description='microsite | site_visit | post_visit'
    )
    public String communicationType;
    @InvocableVariable(
      label='Context JSON'
      description='Optional JSON object with type-specific fields (projects, visitDate, etc.)'
    )
    public String contextJson;
  }

  public static final String COMM_TYPE_MICROSITE = 'microsite';
  public static final String COMM_TYPE_SITE_VISIT = 'site_visit';
  public static final String COMM_TYPE_POST_VISIT = 'post_visit';

  @TestVisible
  private static final String CUSTOMER_SUPPORT_MESSAGE =
    'Something went wrong. Please contact the Propfocus support team.';

  private class ParentFields {
    Id recordId;
    Boolean isOpportunity;
    String buyerIdField;
    String buyerNameField;
    String projectField;
    String statusField;
    String preSalesRepSourceField;
    Boolean embedUsesSalesforceId;
  }

  private static Boolean isOpportunityRecord(Id recordId) {
    return recordId != null &&
      recordId.getSObjectType() == Opportunity.SObjectType;
  }

  private static ParentFields resolveParentFields(Id recordId) {
    if (recordId == null) {
      throw new AuraHandledException('Record Id is required');
    }
    ParentFields fields = new ParentFields();
    fields.recordId = recordId;
    fields.isOpportunity = isOpportunityRecord(recordId);
    if (fields.isOpportunity) {
      fields.buyerIdField = requireParentFieldApiName(
        Opportunity.SObjectType,
        PropfocusConfigService.requireOpportunityBuyerIdField(),
        'Opportunity_Buyer_Id_Field__c'
      );
      fields.buyerNameField = requireParentFieldApiName(
        Opportunity.SObjectType,
        PropfocusConfigService.requireOpportunityBuyerNameField(),
        'Opportunity_Buyer_Name_Field__c'
      );
      fields.projectField = requireParentFieldApiName(
        Opportunity.SObjectType,
        PropfocusConfigService.requireOpportunityProjectField(),
        'Opportunity_Project_Field__c'
      );
      fields.statusField = requireParentFieldApiName(
        Opportunity.SObjectType,
        PropfocusConfigService.requireOpportunityStatusField(),
        'Opportunity_Status_Field__c'
      );
      fields.preSalesRepSourceField = getOpportunityPreSalesRepSourceFieldApiName();
      fields.embedUsesSalesforceId =
        PropfocusConfigService.getConfig().embedUsesSalesforceOpportunityId ==
        true;
    } else if (recordId.getSObjectType() == Lead.SObjectType) {
      fields.buyerIdField = requireParentFieldApiName(
        Lead.SObjectType,
        PropfocusConfigService.requireBuyerIdField(),
        'Buyer_Id_Field__c'
      );
      fields.buyerNameField = requireParentFieldApiName(
        Lead.SObjectType,
        PropfocusConfigService.requireBuyerNameField(),
        'Buyer_Name_Field__c'
      );
      fields.projectField = requireParentFieldApiName(
        Lead.SObjectType,
        PropfocusConfigService.requireProjectField(),
        'Project_Field__c'
      );
      fields.statusField = requireParentFieldApiName(
        Lead.SObjectType,
        PropfocusConfigService.requireLeadStatusField(),
        'Lead_Status_Field__c'
      );
      fields.preSalesRepSourceField = getLeadPreSalesRepSourceFieldApiName();
      fields.embedUsesSalesforceId =
        PropfocusConfigService.getConfig().embedUsesSalesforceLeadId == true;
    } else {
      throw new AuraHandledException(
        'Unsupported record type. Use Lead or Opportunity.'
      );
    }
    return fields;
  }

  private static void putSalesforceIdentity(Map<String, Object> body, Id recordId) {
    if (body == null || recordId == null) {
      return;
    }
    if (isOpportunityRecord(recordId)) {
      body.put('salesforce_opportunity_id', String.valueOf(recordId));
    } else {
      body.put('salesforce_lead_id', String.valueOf(recordId));
    }
  }

  @TestVisible
  private static void logPropfocusError(String operation, String technicalDetail) {
    String detail = String.isBlank(technicalDetail)
      ? 'No technical detail provided'
      : technicalDetail;
    System.debug(
      LoggingLevel.ERROR,
      'PROFOCUS_ERROR|operation=' + operation + '|detail=' + detail
    );
  }

  private static void throwCustomerFacingApiException(
    String operation,
    String technicalDetail
  ) {
    logPropfocusError(operation, technicalDetail);
    throw new AuraHandledException(CUSTOMER_SUPPORT_MESSAGE);
  }

  private static void throwCustomerFacingHttpException(
    String operation,
    HttpResponse res
  ) {
    String technical = buildHttpFailureMessage(res, operation + ' failed');
    if (res != null && !String.isBlank(res.getBody())) {
      technical += '|responseBody=' + res.getBody();
    }
    throwCustomerFacingApiException(operation, technical);
  }

  private static void createPropfocusLinkHistory(
    Id recordId,
    String typeValue,
    String projectName,
    String urlValue,
    String statusValue
  ) {
    if (recordId == null || String.isBlank(urlValue)) {
      return;
    }
    Propfocus_Link__c historyRow = new Propfocus_Link__c(
      Type__c = typeValue,
      Project_Name__c = projectName,
      URL__c = urlValue,
      Created_At__c = System.now(),
      Status__c = statusValue
    );
    if (isOpportunityRecord(recordId)) {
      historyRow.Opportunity__c = recordId;
    } else {
      historyRow.Lead__c = recordId;
    }
    insert historyRow;
  }

  private static String formatLinkHistoryType(String typeValue) {
    if (typeValue == 'Post Visit') {
      return 'Post Visit Page';
    }
    if (typeValue == 'Site Visit') {
      return 'Site Visit Confirmation';
    }
    if (typeValue == 'Microsite') {
      return 'Microsite Generation';
    }
    return typeValue;
  }

  @TestVisible
  private static String normalizeSiteVisitHistoryStatus(String rawStatus) {
    String normalized = rawStatus == null ? '' : rawStatus.trim().toLowerCase();
    if (String.isBlank(normalized)) {
      return 'Pending';
    }
    if (normalized.contains('resched')) {
      return 'Rescheduled';
    }
    if (
      normalized.contains('confirm') ||
      normalized.contains('complete') ||
      normalized.contains('visited') ||
      normalized.contains('done')
    ) {
      return 'Confirmed';
    }
    return 'Pending';
  }

  @TestVisible
  private static String normalizeEngagementHistoryStatus(String rawStatus) {
    String normalized = rawStatus == null ? '' : rawStatus.trim().toLowerCase();
    if (normalized == 'engaged') {
      return 'Engaged';
    }
    return 'Not engaged';
  }

  public static void syncLinkHistoryStatusFromSiteVisit(
    Id recordId,
    String projectName,
    String siteVisitStatus
  ) {
    if (recordId == null || String.isBlank(projectName)) {
      return;
    }
    String mappedStatus = normalizeSiteVisitHistoryStatus(siteVisitStatus);
    List<Propfocus_Link__c> rows;
    if (isOpportunityRecord(recordId)) {
      rows = [
        SELECT Id, Status__c
        FROM Propfocus_Link__c
        WHERE Opportunity__c = :recordId
          AND Type__c IN ('Site Visit Confirmation', 'Site Visit')
          AND Project_Name__c = :projectName
          AND Status__c != 'Reused'
        ORDER BY Created_At__c DESC
        LIMIT 1
      ];
    } else {
      rows = [
        SELECT Id, Status__c
        FROM Propfocus_Link__c
        WHERE Lead__c = :recordId
          AND Type__c IN ('Site Visit Confirmation', 'Site Visit')
          AND Project_Name__c = :projectName
          AND Status__c != 'Reused'
        ORDER BY Created_At__c DESC
        LIMIT 1
      ];
    }
    if (rows.isEmpty() || rows[0].Status__c == mappedStatus) {
      return;
    }
    rows[0].Status__c = mappedStatus;
    update rows;
  }

  private static Map<String, String> resolveSiteVisitStatusByProject(Id leadId) {
    Map<String, String> byProject = new Map<String, String>();
    PropfocusConfigService.Config cfg = PropfocusConfigService.getConfig();
    if (
      String.isBlank(cfg.siteVisitObject) ||
      String.isBlank(cfg.siteVisitProjectField) ||
      String.isBlank(cfg.siteVisitStatusField)
    ) {
      return byProject;
    }
    String projectFieldApiName = cfg.siteVisitProjectField;
    String statusFieldApiName = cfg.siteVisitStatusField;
    for (SObject row : queryLatestSiteVisits(leadId, 50)) {
      String projectName = asString(row.get(projectFieldApiName));
      String rawStatus = asString(row.get(statusFieldApiName));
      if (String.isBlank(projectName)) {
        continue;
      }
      String key = normalizeProjectKey(projectName);
      if (!byProject.containsKey(key)) {
        byProject.put(key, normalizeSiteVisitHistoryStatus(rawStatus));
      }
    }
    return byProject;
  }

  private static List<LinkHistoryItem> enrichLinkHistoryStatuses(
    Id leadId,
    List<LinkHistoryItem> items
  ) {
    if (items.isEmpty()) {
      return items;
    }
    Map<String, String> siteVisitByProject = resolveSiteVisitStatusByProject(
      leadId
    );
    for (LinkHistoryItem item : items) {
      if (item == null || String.isBlank(item.type)) {
        continue;
      }
      String typeLower = item.type.toLowerCase();
      if (typeLower.contains('site visit')) {
        String projectKey = normalizeProjectKey(item.projectName);
        if (siteVisitByProject.containsKey(projectKey)) {
          item.status = siteVisitByProject.get(projectKey);
        } else {
          item.status = normalizeSiteVisitHistoryStatus(item.status);
        }
      } else if (
        typeLower.contains('microsite') ||
        typeLower.contains('post visit')
      ) {
        item.status = normalizeEngagementHistoryStatus(item.status);
      }
    }
    return items;
  }

  private static String requireParentFieldApiName(
    Schema.SObjectType objectType,
    String value,
    String configFieldApiName
  ) {
    String fieldApiName = requireSafeApiName(value, configFieldApiName);
    if (!objectType.getDescribe().fields.getMap().containsKey(fieldApiName)) {
      throw new AuraHandledException(
        'Configured field not found on ' +
          objectType.getDescribe().getName() +
          ': ' +
          fieldApiName
      );
    }
    return fieldApiName;
  }

  private static String requireLeadFieldApiName(
    String value,
    String configFieldApiName
  ) {
    return requireParentFieldApiName(
      Lead.SObjectType,
      value,
      configFieldApiName
    );
  }

  private static String getLeadPreSalesRepSourceFieldApiName() {
    String configuredFieldApiName = PropfocusConfigService.getPreSalesRepSourceField();
    if (String.isBlank(configuredFieldApiName)) {
      return null;
    }
    return requireParentFieldApiName(
      Lead.SObjectType,
      configuredFieldApiName,
      'Pre_Sales_Rep_Source_Field__c'
    );
  }

  private static String getOpportunityPreSalesRepSourceFieldApiName() {
    String configuredFieldApiName = PropfocusConfigService.getOpportunityPreSalesRepSourceField();
    if (String.isBlank(configuredFieldApiName)) {
      return null;
    }
    return requireParentFieldApiName(
      Opportunity.SObjectType,
      configuredFieldApiName,
      'Opportunity_Pre_Sales_Rep_Source_Field__c'
    );
  }

  private static String getPreSalesRepSourceFieldApiName() {
    return getLeadPreSalesRepSourceFieldApiName();
  }

  private static String resolvePreSalesRepSource(
    SObject leadRecord,
    String preSalesRepSourceFieldApiName
  ) {
    if (!String.isBlank(preSalesRepSourceFieldApiName)) {
      String mappedValue = asString(
        leadRecord.get(preSalesRepSourceFieldApiName)
      );
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

  @TestVisible
  private static void putBrokerIdentification(
    Map<String, Object> body,
    SObject leadRecord,
    String preSalesRepSourceFieldApiName,
    String organizationId
  ) {
    String brokerName = resolvePreSalesRepSource(
      leadRecord,
      preSalesRepSourceFieldApiName
    );
    if (!String.isBlank(brokerName)) {
      body.put('brokerName', brokerName);
      body.put('organizationId', organizationId);
      return;
    }
    String brokerNumber = resolveBrokerNumber(leadRecord);
    if (!String.isBlank(brokerNumber)) {
      body.put('brokerNumber', brokerNumber);
    }
  }

  private static SObject queryLeadById(Id leadId, List<String> fieldApiNames) {
    return queryParentById(leadId, fieldApiNames);
  }

  private static SObject queryParentById(Id recordId, List<String> fieldApiNames) {
    Set<String> selectedFields = new Set<String>{ 'Id' };
    for (String f : fieldApiNames) {
      if (!String.isBlank(f)) {
        selectedFields.add(f);
      }
    }
    String objectApiName = isOpportunityRecord(recordId) ? 'Opportunity' : 'Lead';
    String soql =
      'SELECT ' +
      String.join(new List<String>(selectedFields), ', ') +
      ' FROM ' +
      objectApiName +
      ' WHERE Id = :recordId LIMIT 1';
    return Database.query(soql);
  }

  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getLeadDetails(Id leadId) {
    ParentFields fields = resolveParentFields(leadId);
    SObject ld = queryParentById(
      leadId,
      new List<String>{
        'Propfocus_Link__c',
        'Propfocus_Post_Visit__c',
        'Propfocus_Buyer_Insights_Available__c',
        fields.buyerIdField,
        fields.buyerNameField,
        fields.projectField,
        fields.statusField
      }
    );
    return new Map<String, Object>{
      'Id' => ld.get('Id'),
      'Propfocus_Link__c' => ld.get('Propfocus_Link__c'),
      'Propfocus_Post_Visit__c' => ld.get('Propfocus_Post_Visit__c'),
      'buyerInsightsAvailable' => ld.get(
        'Propfocus_Buyer_Insights_Available__c'
      ),
      'buyerId' => ld.get(fields.buyerIdField),
      'buyerName' => ld.get(fields.buyerNameField),
      'projectName' => ld.get(fields.projectField),
      'leadStatus' => ld.get(fields.statusField),
      'isOpportunity' => fields.isOpportunity
    };
  }

  @AuraEnabled
  public static BuyerInsightsEmbedContext getBuyerInsightsEmbedContext(
    Id leadId
  ) {
    if (leadId == null) {
      throw new AuraHandledException('Record Id is required');
    }

    PropfocusConfigService.Config cfg = PropfocusConfigService.getConfig();
    ParentFields fields = resolveParentFields(leadId);
    Map<String, Object> leadDetails = getLeadDetails(leadId);

    BuyerInsightsEmbedContext context = new BuyerInsightsEmbedContext();
    context.usesSalesforceLeadId = fields.embedUsesSalesforceId == true;
    context.buyerInsightsAvailable =
      leadDetails.get('buyerInsightsAvailable') == true;
    context.embedKey = resolveEmbedKey(
      leadId,
      leadDetails,
      context.usesSalesforceLeadId
    );
    context.embedUrl = buildEmbedUrl(cfg.embedBaseUrl, context.embedKey);
    return context;
  }

  @TestVisible
  private static String resolveEmbedKey(
    Id leadId,
    Map<String, Object> leadDetails,
    Boolean usesSalesforceLeadId
  ) {
    Object buyerId = leadDetails.get('buyerId');
    String buyerIdStr = buyerId == null ? null : String.valueOf(buyerId).trim();

    // Propfocus embed currently resolves buyers by buyer_id (same key sent on
    // microsite create). salesforce_lead_id is sent for sync; use it for embed
    // only when buyer_id is unavailable.
    if (!String.isBlank(buyerIdStr)) {
      return buyerIdStr;
    }
    if (usesSalesforceLeadId == true && leadId != null) {
      return String.valueOf(leadId);
    }
    return null;
  }

  @TestVisible
  private static String buildEmbedUrl(String embedBaseUrl, String embedKey) {
    if (String.isBlank(embedBaseUrl) || String.isBlank(embedKey)) {
      return null;
    }
    String base = embedBaseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length() - 1);
    }
    return base + '/' + EncodingUtil.urlEncode(embedKey, 'UTF-8');
  }

  /**
   * Unified PropFocus communication generator.
   * Routes to the Propfocus API via Named Credential (OAuth client credentials).
   * (microsite / site visit / post visit) and returns WhatsApp-ready
   * template + link + mediaUrl. Reusable from LWC, Flow, and Apex.
   *
   * @param leadId Salesforce Lead or Opportunity Id
   * @param communicationType microsite | site_visit | post_visit
   * @param contextJson Optional JSON object with type-specific fields
   */
  @AuraEnabled
  public static PropfocusTemplateResult generatePropfocusTemplate(
    Id leadId,
    String communicationType,
    String contextJson
  ) {
    if (leadId == null) {
      throw new AuraHandledException('Record Id is required');
    }
    String normalizedType = normalizeCommunicationType(communicationType);
    if (String.isBlank(normalizedType)) {
      throw new AuraHandledException(
        'communicationType is required (microsite, site_visit, or post_visit)'
      );
    }
    if (
      normalizedType != COMM_TYPE_MICROSITE &&
      normalizedType != COMM_TYPE_SITE_VISIT &&
      normalizedType != COMM_TYPE_POST_VISIT
    ) {
      throw new AuraHandledException(
        'Unsupported communicationType: ' + communicationType
      );
    }

    Map<String, Object> context = parseContextJson(contextJson);
    return generatePropfocusTemplateInternal(leadId, normalizedType, context);
  }

  @InvocableMethod(
    label='Generate Propfocus Template'
    description='Generates a PropFocus communication (microsite, site visit, or post visit) and returns WhatsApp template + link.'
  )
  public static List<PropfocusTemplateResult> generatePropfocusTemplateInvocable(
    List<GenerateTemplateRequest> requests
  ) {
    List<PropfocusTemplateResult> results = new List<PropfocusTemplateResult>();
    if (requests == null) {
      return results;
    }
    for (GenerateTemplateRequest req : requests) {
      if (req == null) {
        continue;
      }
      results.add(
        generatePropfocusTemplate(
          req.leadId,
          req.communicationType,
          req.contextJson
        )
      );
    }
    return results;
  }

  @AuraEnabled
  public static PropfocusLinkResult generateMicrositeLink(
    Id leadId,
    String clientName,
    List<String> listProj,
    String leadType,
    String configurationFilter
  ) {
    Map<String, Object> context = new Map<String, Object>();
    if (!String.isBlank(clientName)) {
      context.put('buyerName', clientName.trim());
      context.put('clientName', clientName.trim());
    }
    if (listProj != null && !listProj.isEmpty()) {
      context.put('projects', listProj);
      if (listProj.size() == 1) {
        context.put('projectName', listProj[0]);
      }
    }
    if (!String.isBlank(leadType)) {
      context.put('leadType', leadType.trim());
    }
    context.put(
      'configurationFilter',
      String.isBlank(configurationFilter) ? '' : configurationFilter.trim()
    );
    return toLinkResult(
      generatePropfocusTemplateInternal(leadId, COMM_TYPE_MICROSITE, context)
    );
  }

  private static Map<String, Object> fetchOrganizationAccessibleProjectsPayload() {
    String organizationId = EncodingUtil.urlEncode(
      PropfocusConfigService.requireOrganizationId(),
      'UTF-8'
    );
    HttpRequest req = new HttpRequest();
    req.setEndpoint(
      PropfocusConfigService.apiEndpoint(
        '/api/v1/organizations/' + organizationId + '/accessible-projects'
      )
    );
    req.setMethod('GET');
    req.setHeader('Content-Type', 'application/json');

    HttpResponse res = PropfocusHttpService.send(req);
    if (res.getStatusCode() != 200) {
      throwCustomerFacingHttpException(
        'fetchOrganizationAccessibleProjects',
        res
      );
    }

    Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(
      res.getBody()
    );
    if (asBoolean(response.get('success')) == false) {
      throwCustomerFacingApiException(
        'fetchOrganizationAccessibleProjects',
        extractApiErrorMessage(response)
      );
    }
    return response;
  }

  private static List<String> getStringListFromPayload(
    Map<String, Object> payload,
    String fieldName
  ) {
    List<String> values = new List<String>();
    if (payload == null || String.isBlank(fieldName)) {
      return values;
    }
    Object raw = payload.get(fieldName);
    if (raw == null) {
      Map<String, Object> dataMap = asMap(payload.get('data'));
      raw = dataMap == null ? null : dataMap.get(fieldName);
    }
    if (!(raw instanceof List<Object>)) {
      return values;
    }
    for (Object item : (List<Object>) raw) {
      String value = asString(item);
      if (!String.isBlank(value)) {
        values.add(value.trim());
      }
    }
    return values;
  }

  private static Map<String, Object> getMapFromPayload(
    Map<String, Object> payload,
    String fieldName
  ) {
    if (payload == null || String.isBlank(fieldName)) {
      return new Map<String, Object>();
    }
    Map<String, Object> value = asMap(payload.get(fieldName));
    if (value != null) {
      return value;
    }
    Map<String, Object> dataMap = asMap(payload.get('data'));
    value = dataMap == null ? null : asMap(dataMap.get(fieldName));
    return value == null ? new Map<String, Object>() : value;
  }

  private static List<String> getProjectsByEndpoint(String endpointPath) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(PropfocusConfigService.apiEndpoint(endpointPath));
    req.setMethod('GET');
    req.setHeader('Content-Type', 'application/json');

    HttpResponse res = PropfocusHttpService.send(req);

    if (res.getStatusCode() != 200) {
      throwCustomerFacingHttpException('getProjectsByEndpoint', res);
    }

    Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(
      res.getBody()
    );

    if (response.containsKey('success') && response.get('success') == false) {
      throwCustomerFacingApiException(
        'getProjectsByEndpoint',
        extractApiErrorMessage(response)
      );
    }

    Map<String, Object> dataMap = asMap(response.get('data'));
    if (dataMap == null) {
      dataMap = response;
    }
    List<Object> projectObjs = (List<Object>) dataMap.get('projects');
    List<String> projects = new List<String>();

    if (projectObjs == null) {
      return projects;
    }

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
    return getStringListFromPayload(
      fetchOrganizationAccessibleProjectsPayload(),
      'siteVisitProjects'
    );
  }

  @AuraEnabled
  public static List<String> getConfigurationsForProjects(
    List<String> projectNames
  ) {
    if (projectNames == null || projectNames.isEmpty()) {
      return new List<String>();
    }

    Map<String, Object> projectConfigurations = getMapFromPayload(
      fetchOrganizationAccessibleProjectsPayload(),
      'projectConfigurations'
    );

    Map<String, Object> normalizedProjectConfigurations = new Map<String, Object>();
    for (String key : projectConfigurations.keySet()) {
      String normalizedKey = normalizeProjectKey(key);
      if (!String.isBlank(normalizedKey)) {
        normalizedProjectConfigurations.put(normalizedKey, projectConfigurations.get(key));
      }
    }

    Set<String> configurationLabels = new Set<String>();
    for (String projectName : projectNames) {
      String normalizedProjectName = normalizeProjectKey(projectName);
      if (String.isBlank(normalizedProjectName)) {
        continue;
      }
      Object configsObj = projectConfigurations.containsKey(projectName)
        ? projectConfigurations.get(projectName)
        : normalizedProjectConfigurations.get(normalizedProjectName);
      if (!(configsObj instanceof List<Object>)) {
        continue;
      }
      for (Object configObj : (List<Object>) configsObj) {
        String label = resolveConfigurationLabel(configObj);
        if (!String.isBlank(label)) {
          configurationLabels.add(label.trim());
        }
      }
    }

    List<String> sortedLabels = new List<String>(configurationLabels);
    sortedLabels.sort();
    return sortedLabels;
  }

  private static String normalizeProjectKey(String value) {
    return String.isBlank(value) ? null : value.trim().toLowerCase();
  }

  private static String resolveConfigurationLabel(Object configObj) {
    if (configObj == null) {
      return null;
    }
    if (configObj instanceof String) {
      return ((String) configObj).trim();
    }
    Map<String, Object> configMap = asMap(configObj);
    if (configMap == null) {
      return asString(configObj);
    }
    return firstNonBlank(
      configMap,
      new List<String>{ 'label', 'name', 'configuration', 'unit_type', 'value' }
    );
  }

  @TestVisible
  private static List<String> resolveMicrositeLeadTypesForApi(String leadType) {
    if (String.isBlank(leadType)) {
      return new List<String>();
    }
    String normalized = leadType.trim().toLowerCase();
    if (normalized == 'rnr') {
      return new List<String>{ 'Open' };
    }
    if (normalized == 'refer' || normalized == 'referral') {
      return new List<String>{ 'Referral' };
    }
    if (normalized == 'old data' || normalized == 'old_data') {
      return new List<String>{ 'Old Data' };
    }
    if (normalized == 'investor' || normalized == 'investment') {
      return new List<String>{ 'Investment' };
    }
    return new List<String>();
  }

  private static String requireSafeApiName(
    String value,
    String configFieldApiName
  ) {
    if (
      String.isBlank(value) ||
      !Pattern.matches('^[A-Za-z][A-Za-z0-9_]*(__c)?$', value)
    ) {
      throw new AuraHandledException(
        'Invalid API name configured for ' + configFieldApiName
      );
    }
    return value;
  }

  private static Schema.SObjectType requireSiteVisitObjectType(
    String objectApiName
  ) {
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
    String parentLookupFieldApiName = isOpportunityRecord(leadId)
      ? requireSafeApiName(
          PropfocusConfigService.requireSiteVisitOpportunityLookupField(),
          'Opportunity_Lookup_Field__c'
        )
      : requireSafeApiName(
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
    Map<String, Schema.SObjectField> fieldsByApiName = objectType.getDescribe()
      .fields.getMap();
    List<String> requiredFields = new List<String>{
      'Id',
      'CreatedDate',
      statusFieldApiName,
      parentLookupFieldApiName,
      projectFieldApiName
    };
    for (String fieldApiName : requiredFields) {
      if (!fieldsByApiName.containsKey(fieldApiName)) {
        return new List<SObject>();
      }
    }

    String soql =
      'SELECT Id, CreatedDate, ' +
      statusFieldApiName +
      ', ' +
      projectFieldApiName +
      ' FROM ' +
      objectApiName +
      ' WHERE ' +
      parentLookupFieldApiName +
      ' = :leadId';
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
      return Datetime.newInstance(
        dateValue.year(),
        dateValue.month(),
        dateValue.day()
      );
    }
    String text = asString(value);
    if (String.isBlank(text)) {
      return null;
    }
    try {
      // Accept ISO-8601 (e.g. 2026-07-15T10:00:00.000Z) from LWC.
      if (text.endsWith('Z')) {
        return (Datetime) JSON.deserialize('"' + text + '"', Datetime.class);
      }
      return Datetime.valueOf(text.replace('T', ' ').left(19));
    } catch (Exception e) {
      return null;
    }
  }

  private static String asString(Object value) {
    return value == null ? null : String.valueOf(value);
  }

  private static Boolean asBoolean(Object value) {
    if (value == null) {
      return null;
    }
    if (value instanceof Boolean) {
      return (Boolean) value;
    }
    String text = String.valueOf(value).trim().toLowerCase();
    if (text == 'true') {
      return true;
    }
    if (text == 'false') {
      return false;
    }
    return null;
  }

  private static Map<String, Object> asMap(Object value) {
    return value instanceof Map<String, Object>
      ? (Map<String, Object>) value
      : null;
  }

  private static String firstNonBlank(
    Map<String, Object> source,
    List<String> keys
  ) {
    if (source == null || keys == null) {
      return null;
    }
    for (String key : keys) {
      String value = asString(source.get(key));
      if (!String.isBlank(value)) {
        return value;
      }
    }
    return null;
  }

  private static String extractWhatsAppMessage(Map<String, Object> response) {
    if (response == null) {
      return null;
    }
    String topLevel = firstNonBlank(
      response,
      new List<String>{
        'template',
        'whatsappMessage',
        'customerWhatsAppMessage',
        'whatsapp_message'
      }
    );
    if (!String.isBlank(topLevel)) {
      return topLevel;
    }
    Map<String, Object> dataMap = asMap(response.get('data'));
    return firstNonBlank(
      dataMap,
      new List<String>{
        'template',
        'whatsappMessage',
        'customerWhatsAppMessage',
        'whatsapp_message'
      }
    );
  }

  private static String resolveWhatsAppMessage(
    Map<String, Object> response,
    String fallbackMessage
  ) {
    String apiMessage = extractWhatsAppMessage(response);
    if (!String.isBlank(apiMessage)) {
      return apiMessage;
    }
    return String.isBlank(fallbackMessage) ? '' : fallbackMessage;
  }

  @TestVisible
  private static String buildDefaultMicrositeWhatsAppMessage(
    String clientName,
    List<String> projectNames,
    String micrositeUrl,
    String brokerName
  ) {
    if (String.isBlank(micrositeUrl)) {
      return '';
    }
    String name = String.isBlank(clientName) ? 'there' : clientName.trim();
    List<String> numberedProjects = new List<String>();
    Integer index = 1;
    if (projectNames != null) {
      for (String projectName : projectNames) {
        if (String.isBlank(projectName)) {
          continue;
        }
        numberedProjects.add(index + '. ' + projectName.trim());
        index++;
      }
    }
    String projectList = String.join(numberedProjects, '\n');
    String broker = String.isBlank(brokerName) ? '' : brokerName.trim();

    String message =
      'Hi ' +
      name +
      ',\n\nAs discussed, here\'s the link with all the details of the projects:\n\n' +
      projectList +
      ' \n\nCheck here 👉 ' +
      micrositeUrl +
      '\n\nIf you\'d like assistance in comparing options or scheduling a site visit, just let me know. I\'ll be happy to help.';

    if (!String.isBlank(broker)) {
      message += '\n\nRegards,\n' + broker;
    }

    message +=
      '\n\nNote: If the link isn\'t clickable, simply reply with any message (e.g. ok) and it will be activated.';
    return message;
  }

  @TestVisible
  private static String buildDefaultSiteVisitWhatsAppMessage(
    String clientName,
    String projectName,
    String siteVisitUrl
  ) {
    if (String.isBlank(siteVisitUrl)) {
      return '';
    }
    String greetingName = String.isBlank(clientName) ? 'there' : clientName.trim();
    String project = String.isBlank(projectName)
      ? 'your project'
      : projectName.trim();
    return 'Hi ' +
      greetingName +
      ',\n\nYour *site visit for ' +
      project +
      '* is scheduled.\n\nPlease confirm your visit here: ' +
      siteVisitUrl +
      '\n\nYou can also find the *location and visit details* in the link.\n\nLooking forward to meeting you.';
  }

  @TestVisible
  private static String buildDefaultPostVisitWhatsAppMessage(
    String clientName,
    String projectName,
    String visitedConfiguration,
    String postVisitUrl
  ) {
    if (String.isBlank(postVisitUrl)) {
      return '';
    }
    String greetingName = String.isBlank(clientName) ? 'there' : clientName.trim();
    String project = String.isBlank(projectName)
      ? 'your project'
      : projectName.trim();
    String config = String.isBlank(visitedConfiguration)
      ? 'the unit'
      : visitedConfiguration.trim();
    return '✅ Post-visit page ready for ' +
      greetingName +
      '\n\n' +
      config +
      ' · ' +
      project +
      '\n\nShare with your buyer:\n' +
      postVisitUrl;
  }

  private static String extractApiErrorMessage(Map<String, Object> response) {
    String topLevel = firstNonBlank(
      response,
      new List<String>{ 'error_message', 'message', 'error' }
    );
    if (!String.isBlank(topLevel)) {
      return topLevel;
    }
    Map<String, Object> dataMap = asMap(response.get('data'));
    return firstNonBlank(
      dataMap,
      new List<String>{ 'error_message', 'message', 'error' }
    );
  }

  @TestVisible
  private static String buildHttpFailureMessage(
    HttpResponse res,
    String fallback
  ) {
    if (res == null) {
      return fallback;
    }
    String statusPart =
      'Propfocus API failed with status ' + res.getStatusCode();
    String body = res.getBody();
    if (String.isBlank(body)) {
      return statusPart;
    }
    try {
      Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(
        body
      );
      String apiError = extractApiErrorMessage(response);
      if (!String.isBlank(apiError)) {
        return apiError;
      }
    } catch (Exception ex) {
      // Ignore malformed error bodies and fall back to status text.
    }
    return statusPart;
  }

  private static String hashSuffix(String seed) {
    if (String.isBlank(seed)) {
      return '0';
    }
    Blob digest = Crypto.generateDigest('SHA-256', Blob.valueOf(seed));
    String hex = EncodingUtil.convertToHex(digest);
    return hex.substring(0, Math.min(32, hex.length()));
  }

  private static String buildIdempotencyKey(
    String operation,
    Id leadId,
    Map<String, Object> body
  ) {
    String leadPart = leadId == null ? 'no-lead' : String.valueOf(leadId);
    String bodyHash = hashSuffix(JSON.serialize(body));
    return operation + '-' + leadPart + '-' + bodyHash;
  }

  private static PropfocusTemplateResult generatePropfocusTemplateInternal(
    Id leadId,
    String communicationType,
    Map<String, Object> contextInput
  ) {
    if (leadId == null) {
      throw new AuraHandledException('Record Id is required');
    }

    Map<String, Object> context = contextInput == null
      ? new Map<String, Object>()
      : new Map<String, Object>(contextInput);

    ParentFields fields = resolveParentFields(leadId);
    String buyerIdFieldApiName = fields.buyerIdField;
    String buyerNameFieldApiName = fields.buyerNameField;
    String projectFieldApiName = fields.projectField;
    String leadStatusFieldApiName = fields.statusField;
    String preSalesRepSourceFieldApiName = fields.preSalesRepSourceField;

    List<String> leadFieldApiNames = new List<String>{
      'Owner.Name',
      'Owner.Phone',
      'Propfocus_Link__c',
      'Propfocus_Site_Visit__c',
      'Propfocus_Post_Visit__c',
      'Propfocus_Buyer_Insights_Available__c',
      buyerIdFieldApiName,
      buyerNameFieldApiName,
      projectFieldApiName,
      leadStatusFieldApiName
    };
    if (!String.isBlank(preSalesRepSourceFieldApiName)) {
      leadFieldApiNames.add(preSalesRepSourceFieldApiName);
    }
    SObject ld = queryParentById(leadId, leadFieldApiNames);

    String buyerId = asString(ld.get(buyerIdFieldApiName));
    String buyerName = firstContextString(
      context,
      new List<String>{ 'buyerName', 'clientName', 'buyer_name', 'client_name' }
    );
    if (String.isBlank(buyerName)) {
      buyerName = asString(ld.get(buyerNameFieldApiName));
    }
    if (String.isBlank(buyerId)) {
      throw new AuraHandledException(
        'Buyer Id is required on the ' +
          (fields.isOpportunity ? 'Opportunity' : 'Lead')
      );
    }
    if (String.isBlank(buyerName)) {
      throw new AuraHandledException('Buyer name is required');
    }

    enrichContextFromLead(
      context,
      communicationType,
      ld,
      projectFieldApiName,
      leadStatusFieldApiName,
      preSalesRepSourceFieldApiName
    );

    if (communicationType == COMM_TYPE_POST_VISIT) {
      String visitedConfiguration = firstContextString(
        context,
        new List<String>{ 'visitedConfiguration', 'visited_configuration' }
      );
      if (String.isBlank(visitedConfiguration)) {
        throw new AuraHandledException('Visited configuration is required');
      }
    }

    String organizationId = PropfocusConfigService.requireOrganizationId();
    String endpointPath;
    String idempotencyOperation;
    Map<String, Object> body;
    if (communicationType == COMM_TYPE_MICROSITE) {
      endpointPath = '/api/broker-microsite/create';
      idempotencyOperation = 'microsite-create';
      body = buildLegacyMicrositeBody(
        leadId,
        buyerId,
        buyerName,
        context,
        ld,
        leadStatusFieldApiName,
        preSalesRepSourceFieldApiName,
        organizationId
      );
    } else if (communicationType == COMM_TYPE_SITE_VISIT) {
      endpointPath = '/api/site-visit/create-sv';
      idempotencyOperation = 'site-visit-create';
      body = buildLegacySiteVisitBody(
        leadId,
        buyerId,
        buyerName,
        context,
        ld,
        preSalesRepSourceFieldApiName,
        organizationId
      );
    } else {
      endpointPath = '/api/post-visit/create-pv';
      idempotencyOperation = 'post-visit-create';
      body = buildLegacyPostVisitBody(
        leadId,
        buyerId,
        buyerName,
        context,
        ld,
        preSalesRepSourceFieldApiName,
        organizationId
      );
    }

    HttpRequest req = new HttpRequest();
    req.setEndpoint(PropfocusConfigService.apiEndpoint(endpointPath));
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');
    req.setBody(JSON.serialize(body));
    req.setHeader(
      'Idempotency-Key',
      buildIdempotencyKey(idempotencyOperation, leadId, body)
    );

    HttpResponse res = PropfocusHttpService.send(req);
    if (res.getStatusCode() != 200) {
      throwCustomerFacingHttpException('generatePropfocusTemplate', res);
    }

    Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(
      res.getBody()
    );
    if (asBoolean(response.get('success')) == false) {
      throwCustomerFacingApiException(
        'generatePropfocusTemplate',
        extractApiErrorMessage(response)
      );
    }

    String linkUrl = extractCommunicationLink(response);
    if (String.isBlank(linkUrl)) {
      throwCustomerFacingApiException(
        'generatePropfocusTemplate',
        'Link not returned by Propfocus'
      );
    }

    String mediaUrl = firstNonBlank(
      response,
      new List<String>{ 'mediaUrl', 'media_url' }
    );
    if (String.isBlank(mediaUrl)) {
      mediaUrl = firstNonBlank(
        asMap(response.get('data')),
        new List<String>{ 'mediaUrl', 'media_url' }
      );
    }

    String projectNameForHistory = resolveProjectNameForHistory(context);
    applyCommunicationWriteback(
      ld,
      communicationType,
      linkUrl,
      projectNameForHistory,
      asBoolean(response.get('reused')) == true
    );

    String fallbackMessage = buildFallbackWhatsAppMessage(
      communicationType,
      buyerName,
      context,
      linkUrl,
      resolvePreSalesRepSource(ld, preSalesRepSourceFieldApiName)
    );

    PropfocusTemplateResult result = new PropfocusTemplateResult();
    result.communicationType = communicationType;
    result.url = linkUrl;
    result.mediaUrl = mediaUrl;
    result.whatsappMessage = resolveWhatsAppMessage(response, fallbackMessage);
    return result;
  }

  private static Map<String, Object> buildLegacyMicrositeBody(
    Id leadId,
    String buyerId,
    String buyerName,
    Map<String, Object> context,
    SObject ld,
    String leadStatusFieldApiName,
    String preSalesRepSourceFieldApiName,
    String organizationId
  ) {
    List<String> projects = resolveProjectsList(context);
    Map<String, Object> body = new Map<String, Object>{
      'clientName' => buyerName,
      'projects' => projects,
      API_LEAD_STATUS_KEY => context.containsKey(API_LEAD_STATUS_KEY)
        ? context.get(API_LEAD_STATUS_KEY)
        : ld.get(leadStatusFieldApiName),
      'buyer_id' => buyerId
    };
    putSalesforceIdentity(body, leadId);
    putBrokerIdentification(
      body,
      ld,
      preSalesRepSourceFieldApiName,
      organizationId
    );
      Object leadTypes = context.get('lead_types');
    if (leadTypes != null) {
      body.put('lead_types', leadTypes);
    } else {
      List<String> leadTypesForApi = resolveMicrositeLeadTypesForApi(
        firstContextString(context, new List<String>{ 'leadType', 'lead_type' })
      );
      if (!leadTypesForApi.isEmpty()) {
        body.put('lead_types', leadTypesForApi);
      }
    }
    String configurationFilter = firstContextString(
      context,
      new List<String>{ 'configurationFilter', 'configuration_filter' }
    );
    body.put(
      'configurationFilter',
      String.isBlank(configurationFilter) ? '' : configurationFilter.trim()
    );
    return body;
  }

  private static Map<String, Object> buildLegacySiteVisitBody(
    Id leadId,
    String buyerId,
    String buyerName,
    Map<String, Object> context,
    SObject ld,
    String preSalesRepSourceFieldApiName,
    String organizationId
  ) {
    String projectName = firstContextString(
      context,
      new List<String>{ 'projectName', 'project_name' }
    );
    String visitDate = firstContextString(
      context,
      new List<String>{ 'visitDate', 'visit_date' }
    );
    String visitTime = firstContextString(
      context,
      new List<String>{ 'visitTime', 'visit_time' }
    );
    // Legacy create-sv expects dd/MM/yyyy; context enrichment stores yyyy-MM-dd.
    visitDate = toLegacyVisitDate(visitDate);

    Map<String, Object> body = new Map<String, Object>{
      'buyer_id' => buyerId,
      'project_name' => projectName,
      'visit_date' => visitDate,
      'visit_time' => visitTime,
      'buyer_name' => buyerName
    };
    putSalesforceIdentity(body, leadId);
    putBrokerIdentification(
      body,
      ld,
      preSalesRepSourceFieldApiName,
      organizationId
    );
    Object siteVisitManager = context.get('siteVisitManager');
    if (siteVisitManager != null) {
      body.put('siteVisitManager', siteVisitManager);
    }
    return body;
  }

  private static Map<String, Object> buildLegacyPostVisitBody(
    Id leadId,
    String buyerId,
    String buyerName,
    Map<String, Object> context,
    SObject ld,
    String preSalesRepSourceFieldApiName,
    String organizationId
  ) {
    Map<String, Object> body = new Map<String, Object>{
      'buyer_id' => buyerId,
      'buyer_name' => buyerName,
      'project_name' => firstContextString(
        context,
        new List<String>{ 'projectName', 'project_name' }
      ),
      'visited_configuration' => firstContextString(
        context,
        new List<String>{ 'visitedConfiguration', 'visited_configuration' }
      ),
      'visit_conducted_at' => firstContextString(
        context,
        new List<String>{ 'visitConductedAt', 'visit_conducted_at' }
      )
    };
    putSalesforceIdentity(body, leadId);
    putBrokerIdentification(
      body,
      ld,
      preSalesRepSourceFieldApiName,
      organizationId
    );
    String assignedBrokerId = firstContextString(
      context,
      new List<String>{ 'assignedBrokerId', 'assigned_broker_id' }
    );
    if (!String.isBlank(assignedBrokerId)) {
      body.put('assignedBrokerId', assignedBrokerId.trim());
    }
    return body;
  }

  @TestVisible
  private static String toLegacyVisitDate(String visitDate) {
    if (String.isBlank(visitDate)) {
      return visitDate;
    }
    String trimmed = visitDate.trim();
    // yyyy-MM-dd -> dd/MM/yyyy
    if (Pattern.matches('^\\d{4}-\\d{2}-\\d{2}$', trimmed)) {
      return trimmed.substring(8, 10) +
        '/' +
        trimmed.substring(5, 7) +
        '/' +
        trimmed.substring(0, 4);
    }
    return trimmed;
  }

  private static void enrichContextFromLead(
    Map<String, Object> context,
    String communicationType,
    SObject ld,
    String projectFieldApiName,
    String leadStatusFieldApiName,
    String preSalesRepSourceFieldApiName
  ) {
    String projectFromLead = asString(ld.get(projectFieldApiName));
    if (
      String.isBlank(firstContextString(context, new List<String>{ 'projectName', 'project_name' })) &&
      context.get('projects') == null &&
      !String.isBlank(projectFromLead)
    ) {
      context.put('projectName', projectFromLead);
    }

    if (communicationType == COMM_TYPE_MICROSITE) {
      Object projectsObj = context.get('projects');
      if (projectsObj == null && !String.isBlank(asString(context.get('projectName')))) {
        context.put(
          'projects',
          new List<String>{ asString(context.get('projectName')) }
        );
      }
      if (!context.containsKey('configurationFilter')) {
        context.put('configurationFilter', '');
      }
      String leadType = firstContextString(
        context,
        new List<String>{ 'leadType', 'lead_type' }
      );
      List<String> leadTypesForApi = resolveMicrositeLeadTypesForApi(leadType);
      if (!leadTypesForApi.isEmpty()) {
        context.put('lead_types', leadTypesForApi);
      }
      if (!context.containsKey(API_LEAD_STATUS_KEY)) {
        context.put(API_LEAD_STATUS_KEY, ld.get(leadStatusFieldApiName));
      }
    }

    if (communicationType == COMM_TYPE_SITE_VISIT) {
      Object visitDateTimeRaw = context.get('visitDateTime');
      if (
        visitDateTimeRaw != null &&
        (String.isBlank(asString(context.get('visitDate'))) ||
          String.isBlank(asString(context.get('visitTime'))))
      ) {
        Datetime parsedDt = asDatetime(visitDateTimeRaw);
        if (parsedDt != null) {
          String tz = UserInfo.getTimeZone().getID();
          if (String.isBlank(asString(context.get('visitDate')))) {
            context.put('visitDate', parsedDt.format('yyyy-MM-dd', tz));
          }
          if (String.isBlank(asString(context.get('visitTime')))) {
            context.put('visitTime', parsedDt.format('HH:mm', tz));
          }
        }
      }
      if (String.isBlank(asString(context.get('visitDate')))) {
        Datetime nowDt = System.now();
        String tz = UserInfo.getTimeZone().getID();
        context.put('visitDate', nowDt.format('yyyy-MM-dd', tz));
        if (String.isBlank(asString(context.get('visitTime')))) {
          context.put('visitTime', nowDt.format('HH:mm', tz));
        }
      }
    }

    String preSales = resolvePreSalesRepSource(ld, preSalesRepSourceFieldApiName);
    if (
      !String.isBlank(preSales) &&
      String.isBlank(asString(context.get('preSalesPersonName')))
    ) {
      context.put('preSalesPersonName', preSales);
    }
  }

  private static String extractCommunicationLink(Map<String, Object> response) {
    String linkUrl = firstNonBlank(
      response,
      new List<String>{
        'link',
        'url',
        'micrositeUrl',
        'microsite_url',
        'sv_url',
        'siteVisitUrl',
        'site_visit_url',
        'post_visit_url',
        'postVisitUrl',
        'public_url',
        'pv_url'
      }
    );
    if (!String.isBlank(linkUrl)) {
      return linkUrl;
    }
    return firstNonBlank(
      asMap(response.get('data')),
      new List<String>{
        'link',
        'url',
        'micrositeUrl',
        'microsite_url',
        'sv_url',
        'siteVisitUrl',
        'site_visit_url',
        'post_visit_url',
        'postVisitUrl',
        'public_url',
        'pv_url'
      }
    );
  }

  private static void applyCommunicationWriteback(
    SObject ld,
    String communicationType,
    String linkUrl,
    String projectNameForHistory,
    Boolean reused
  ) {
    if (communicationType == COMM_TYPE_MICROSITE) {
      ld.put('Propfocus_Link__c', linkUrl);
      ld.put('Propfocus_Buyer_Insights_Available__c', true);
      update ld;
      createPropfocusLinkHistory(
        ld.Id,
        'Microsite Generation',
        projectNameForHistory,
        linkUrl,
        reused == true ? 'Reused' : 'Not engaged'
      );
      return;
    }
    if (communicationType == COMM_TYPE_SITE_VISIT) {
      ld.put('Propfocus_Site_Visit__c', linkUrl);
      update ld;
      createPropfocusLinkHistory(
        ld.Id,
        'Site Visit Confirmation',
        projectNameForHistory,
        linkUrl,
        reused == true ? 'Reused' : 'Pending'
      );
      return;
    }
    if (communicationType == COMM_TYPE_POST_VISIT) {
      ld.put('Propfocus_Post_Visit__c', linkUrl);
      update ld;
      createPropfocusLinkHistory(
        ld.Id,
        'Post Visit Page',
        projectNameForHistory,
        linkUrl,
        reused == true ? 'Reused' : 'Not engaged'
      );
    }
  }

  private static String buildFallbackWhatsAppMessage(
    String communicationType,
    String buyerName,
    Map<String, Object> context,
    String linkUrl,
    String brokerName
  ) {
    if (communicationType == COMM_TYPE_MICROSITE) {
      return buildDefaultMicrositeWhatsAppMessage(
        buyerName,
        resolveProjectsList(context),
        linkUrl,
        brokerName
      );
    }
    if (communicationType == COMM_TYPE_SITE_VISIT) {
      return buildDefaultSiteVisitWhatsAppMessage(
        buyerName,
        firstContextString(context, new List<String>{ 'projectName', 'project_name' }),
        linkUrl
      );
    }
    if (communicationType == COMM_TYPE_POST_VISIT) {
      return buildDefaultPostVisitWhatsAppMessage(
        buyerName,
        firstContextString(context, new List<String>{ 'projectName', 'project_name' }),
        firstContextString(
          context,
          new List<String>{ 'visitedConfiguration', 'visited_configuration' }
        ),
        linkUrl
      );
    }
    return '';
  }

  private static String resolveProjectNameForHistory(Map<String, Object> context) {
    String projectName = firstContextString(
      context,
      new List<String>{ 'projectName', 'project_name' }
    );
    if (!String.isBlank(projectName)) {
      return projectName;
    }
    List<String> projects = resolveProjectsList(context);
    return projects.isEmpty() ? null : String.join(projects, ', ');
  }

  private static List<String> resolveProjectsList(Map<String, Object> context) {
    List<String> projects = new List<String>();
    if (context == null) {
      return projects;
    }
    Object raw = context.get('projects');
    if (raw instanceof List<Object>) {
      for (Object item : (List<Object>) raw) {
        String value = asString(item);
        if (!String.isBlank(value)) {
          projects.add(value.trim());
        }
      }
    } else if (raw instanceof List<String>) {
      for (String value : (List<String>) raw) {
        if (!String.isBlank(value)) {
          projects.add(value.trim());
        }
      }
    }
    if (projects.isEmpty()) {
      String single = firstContextString(
        context,
        new List<String>{ 'projectName', 'project_name' }
      );
      if (!String.isBlank(single)) {
        projects.add(single);
      }
    }
    return projects;
  }

  private static String firstContextString(
    Map<String, Object> context,
    List<String> keys
  ) {
    if (context == null || keys == null) {
      return null;
    }
    for (String key : keys) {
      String value = asString(context.get(key));
      if (!String.isBlank(value)) {
        return value.trim();
      }
    }
    return null;
  }

  @TestVisible
  private static String normalizeCommunicationType(String communicationType) {
    if (String.isBlank(communicationType)) {
      return null;
    }
    String normalized = communicationType.trim().toLowerCase().replace(' ', '_');
    if (normalized == 'sitevisit') {
      return COMM_TYPE_SITE_VISIT;
    }
    if (normalized == 'postvisit') {
      return COMM_TYPE_POST_VISIT;
    }
    return normalized;
  }

  @TestVisible
  private static Map<String, Object> parseContextJson(String contextJson) {
    if (String.isBlank(contextJson)) {
      return new Map<String, Object>();
    }
    try {
      Object parsed = JSON.deserializeUntyped(contextJson);
      Map<String, Object> asObject = asMap(parsed);
      return asObject == null
        ? new Map<String, Object>()
        : new Map<String, Object>(asObject);
    } catch (Exception e) {
      throw new AuraHandledException('contextJson must be a valid JSON object');
    }
  }

  private static PropfocusLinkResult toLinkResult(PropfocusTemplateResult templateResult) {
    PropfocusLinkResult result = new PropfocusLinkResult();
    if (templateResult == null) {
      return result;
    }
    result.url = templateResult.url;
    result.whatsappMessage = templateResult.whatsappMessage;
    return result;
  }

  private static String resolveBrokerNumber(SObject leadRecord) {
    SObject ownerRecord = leadRecord.getSObject('Owner');
    if (ownerRecord == null) {
      return null;
    }
    String phone = asString(ownerRecord.get('Phone'));
    if (String.isBlank(phone)) {
      return null;
    }
    String normalizedPhone = phone.replaceAll('[^0-9+]', '');
    return String.isBlank(normalizedPhone) ? null : normalizedPhone;
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

  private static PropfocusLinkResult generateSiteVisitInternal(
    Id leadId,
    String buyerName,
    String projectName,
    Datetime requestedVisitDateTime,
    String siteVisitManagerId
  ) {
    Map<String, Object> context = new Map<String, Object>();
    if (!String.isBlank(buyerName)) {
      context.put('buyerName', buyerName.trim());
    }
    if (!String.isBlank(projectName)) {
      context.put('projectName', projectName.trim());
    }
    Datetime effectiveVisitDateTime = requestedVisitDateTime != null
      ? requestedVisitDateTime
      : System.now();
    String userTimeZoneId = UserInfo.getTimeZone().getID();
    context.put(
      'visitDate',
      effectiveVisitDateTime.format('yyyy-MM-dd', userTimeZoneId)
    );
    context.put(
      'visitTime',
      effectiveVisitDateTime.format('HH:mm', userTimeZoneId)
    );
    if (!String.isBlank(siteVisitManagerId)) {
      context.put(
        'siteVisitManager',
        new Map<String, Object>{ 'id' => siteVisitManagerId }
      );
    }
    return toLinkResult(
      generatePropfocusTemplateInternal(leadId, COMM_TYPE_SITE_VISIT, context)
    );
  }

  @AuraEnabled
  public static PropfocusLinkResult generateSiteVisitWithProjectAndDateTime(
    Id leadId,
    String buyerName,
    String projectName,
    Datetime visitDateTime,
    String siteVisitManagerId
  ) {
    return generateSiteVisitInternal(
      leadId,
      buyerName,
      projectName,
      visitDateTime,
      siteVisitManagerId
    );
  }

  @AuraEnabled
  public static List<SiteVisitManagerItem> getSiteVisitManagers(
    String projectName
  ) {
    if (String.isBlank(projectName)) {
      return new List<SiteVisitManagerItem>();
    }

    Map<String, Object> managersByProject = getMapFromPayload(
      fetchOrganizationAccessibleProjectsPayload(),
      'siteVisitManagers'
    );
    Object managerRows = managersByProject.get(projectName.trim());
    if (!(managerRows instanceof List<Object>)) {
      return new List<SiteVisitManagerItem>();
    }
    return parseSiteVisitManagerRows((List<Object>) managerRows);
  }

  /**
   * Sales reps + sales managers for post-visit "Reassign to".
   * Calls Propfocus GET /api/dashboard/sales-team (organizationId for
   * Salesforce Named Credential auth; browser uses broker JWT instead).
   */
  @AuraEnabled
  public static List<SalesTeamMemberItem> getSalesTeam() {
    String organizationId = EncodingUtil.urlEncode(
      PropfocusConfigService.requireOrganizationId(),
      'UTF-8'
    );
    HttpRequest req = new HttpRequest();
    req.setEndpoint(
      PropfocusConfigService.apiEndpoint(
        '/api/dashboard/sales-team?organizationId=' + organizationId
      )
    );
    req.setMethod('GET');
    req.setHeader('Content-Type', 'application/json');

    HttpResponse res = PropfocusHttpService.send(req);
    if (res.getStatusCode() != 200) {
      throwCustomerFacingHttpException('getSalesTeam', res);
    }

    Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(
      res.getBody()
    );
    if (asBoolean(response.get('success')) == false) {
      throwCustomerFacingApiException(
        'getSalesTeam',
        extractApiErrorMessage(response)
      );
    }
    return parseSalesTeamMemberRows(getListFromPayload(response, 'members'));
  }

  private static List<Object> getListFromPayload(
    Map<String, Object> payload,
    String fieldName
  ) {
    if (payload == null || String.isBlank(fieldName)) {
      return new List<Object>();
    }
    Object raw = payload.get(fieldName);
    if (raw == null) {
      Map<String, Object> dataMap = asMap(payload.get('data'));
      raw = dataMap == null ? null : dataMap.get(fieldName);
    }
    if (!(raw instanceof List<Object>)) {
      return new List<Object>();
    }
    return (List<Object>) raw;
  }

  private static List<SalesTeamMemberItem> parseSalesTeamMemberRows(
    List<Object> memberRows
  ) {
    List<SalesTeamMemberItem> items = new List<SalesTeamMemberItem>();
    if (memberRows == null || memberRows.isEmpty()) {
      return items;
    }

    for (Object rowObj : memberRows) {
      Map<String, Object> row = asMap(rowObj);
      if (row == null) {
        continue;
      }
      String memberId = asString(row.get('id'));
      String memberName = asString(row.get('name'));
      if (String.isBlank(memberId) || String.isBlank(memberName)) {
        continue;
      }
      SalesTeamMemberItem item = new SalesTeamMemberItem();
      item.id = memberId;
      item.name = memberName;
      String displayName = asString(row.get('displayName'));
      item.displayName = String.isBlank(displayName) ? memberName : displayName;
      items.add(item);
    }
    return items;
  }

  private static List<SiteVisitManagerItem> parseSiteVisitManagerRows(
    List<Object> managerRows
  ) {
    List<SiteVisitManagerItem> items = new List<SiteVisitManagerItem>();
    if (managerRows == null || managerRows.isEmpty()) {
      return items;
    }

    for (Object rowObj : managerRows) {
      Map<String, Object> row = asMap(rowObj);
      if (row == null) {
        continue;
      }
      String managerId = asString(row.get('id'));
      String managerName = asString(row.get('name'));
      if (String.isBlank(managerId) || String.isBlank(managerName)) {
        continue;
      }
      SiteVisitManagerItem item = new SiteVisitManagerItem();
      item.id = managerId;
      item.name = managerName;
      item.phone = asString(row.get('phone'));
      items.add(item);
    }
    return items;
  }

  private static PropfocusLinkResult generatePostVisitInternal(
    Id leadId,
    String buyerName,
    String projectName,
    String visitedConfiguration,
    Date visitConductedAt
  ) {
    String resolvedVisitedConfiguration = String.isBlank(visitedConfiguration)
      ? null
      : visitedConfiguration.trim();
    if (String.isBlank(resolvedVisitedConfiguration)) {
      throw new AuraHandledException('Visited configuration is required');
    }

    Map<String, Object> context = new Map<String, Object>();
    if (!String.isBlank(buyerName)) {
      context.put('buyerName', buyerName.trim());
    }
    if (!String.isBlank(projectName)) {
      context.put('projectName', projectName.trim());
    }
    context.put('visitedConfiguration', resolvedVisitedConfiguration);
    Date resolvedVisitDate = visitConductedAt == null
      ? Date.today()
      : visitConductedAt;
    context.put('visitConductedAt', String.valueOf(resolvedVisitDate));
    return toLinkResult(
      generatePropfocusTemplateInternal(leadId, COMM_TYPE_POST_VISIT, context)
    );
  }

  @AuraEnabled
  public static PropfocusLinkResult generatePostVisitWithProjectAndConfiguration(
    Id leadId,
    String buyerName,
    String projectName,
    String visitedConfiguration,
    Date visitConductedAt
  ) {
    return generatePostVisitInternal(
      leadId,
      buyerName,
      projectName,
      visitedConfiguration,
      visitConductedAt
    );
  }

  @AuraEnabled(cacheable=true)
  public static Boolean isBuyerInsightsAvailable(Id leadId) {
    if (leadId == null) {
      return false;
    }

    if (isOpportunityRecord(leadId)) {
      List<Opportunity> opportunities = [
        SELECT Propfocus_Buyer_Insights_Available__c
        FROM Opportunity
        WHERE Id = :leadId
        LIMIT 1
      ];
      return !opportunities.isEmpty() &&
        opportunities[0].Propfocus_Buyer_Insights_Available__c == true;
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
  public static List<LinkHistoryItem> getLinkHistory(Id leadId) {
    List<LinkHistoryItem> items = new List<LinkHistoryItem>();
    if (leadId == null) {
      return items;
    }
    Set<String> seenUrls = new Set<String>();
    List<Propfocus_Link__c> rows;
    if (isOpportunityRecord(leadId)) {
      rows = [
        SELECT Id, Type__c, Project_Name__c, URL__c, Created_At__c, Status__c
        FROM Propfocus_Link__c
        WHERE Opportunity__c = :leadId
        ORDER BY Created_At__c DESC
        LIMIT 50
      ];
    } else {
      rows = [
        SELECT Id, Type__c, Project_Name__c, URL__c, Created_At__c, Status__c
        FROM Propfocus_Link__c
        WHERE Lead__c = :leadId
        ORDER BY Created_At__c DESC
        LIMIT 50
      ];
    }
    for (Propfocus_Link__c row : rows) {
      if (row.Status__c == 'Reused' || seenUrls.contains(row.URL__c)) {
        continue;
      }
      seenUrls.add(row.URL__c);
      LinkHistoryItem item = new LinkHistoryItem();
      item.id = row.Id;
      item.type = formatLinkHistoryType(row.Type__c);
      item.projectName = row.Project_Name__c;
      item.status = row.Status__c;
      item.url = row.URL__c;
      item.createdAt = row.Created_At__c;
      items.add(item);
    }
    return enrichLinkHistoryStatuses(leadId, items);
  }
}