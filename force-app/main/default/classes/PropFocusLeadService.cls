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

  @TestVisible
  private static final String CUSTOMER_SUPPORT_MESSAGE =
    'Something went wrong. Please contact the Propfocus support team.';

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

  private static String requireLeadFieldApiName(
    String value,
    String configFieldApiName
  ) {
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
    Set<String> selectedFields = new Set<String>{ 'Id' };
    for (String f : fieldApiNames) {
      if (!String.isBlank(f)) {
        selectedFields.add(f);
      }
    }
    String soql =
      'SELECT ' +
      String.join(new List<String>(selectedFields), ', ') +
      ' FROM Lead WHERE Id = :leadId LIMIT 1';
    return Database.query(soql);
  }

  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getLeadDetails(Id leadId) {
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
    String leadStatusFieldApiName = requireLeadFieldApiName(
      PropfocusConfigService.requireLeadStatusField(),
      'Lead_Status_Field__c'
    );
    SObject ld = queryLeadById(
      leadId,
      new List<String>{
        'Propfocus_Link__c',
        'Propfocus_Post_Visit__c',
        'Propfocus_Buyer_Insights_Available__c',
        buyerIdFieldApiName,
        buyerNameFieldApiName,
        projectFieldApiName,
        leadStatusFieldApiName
      }
    );
    return new Map<String, Object>{
      'Id' => ld.get('Id'),
      'Propfocus_Link__c' => ld.get('Propfocus_Link__c'),
      'Propfocus_Post_Visit__c' => ld.get('Propfocus_Post_Visit__c'),
      'buyerInsightsAvailable' => ld.get(
        'Propfocus_Buyer_Insights_Available__c'
      ),
      'buyerId' => ld.get(buyerIdFieldApiName),
      'buyerName' => ld.get(buyerNameFieldApiName),
      'projectName' => ld.get(projectFieldApiName),
      'leadStatus' => ld.get(leadStatusFieldApiName)
    };
  }

  @AuraEnabled
  public static BuyerInsightsEmbedContext getBuyerInsightsEmbedContext(
    Id leadId
  ) {
    if (leadId == null) {
      throw new AuraHandledException('Lead Id is required');
    }

    PropfocusConfigService.Config cfg = PropfocusConfigService.getConfig();
    Map<String, Object> leadDetails = getLeadDetails(leadId);

    BuyerInsightsEmbedContext context = new BuyerInsightsEmbedContext();
    context.usesSalesforceLeadId = cfg.embedUsesSalesforceLeadId == true;
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

  @AuraEnabled
  public static PropfocusLinkResult generateMicrositeLink(
    Id leadId,
    String clientName,
    List<String> listProj,
    String leadType,
    String configurationFilter
  ) {
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
      'Owner.Phone',
      'Propfocus_Link__c',
      'Propfocus_Buyer_Insights_Available__c',
      buyerIdFieldApiName,
      leadStatusFieldApiName
    };
    if (!String.isBlank(preSalesRepSourceFieldApiName)) {
      leadFieldApiNames.add(preSalesRepSourceFieldApiName);
    }
    SObject ld = queryLeadById(leadId, leadFieldApiNames);

    String organizationId = PropfocusConfigService.requireOrganizationId();
    HttpRequest req = new HttpRequest();
    req.setEndpoint(
      PropfocusConfigService.apiEndpoint('/api/broker-microsite/create')
    );
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');
    Map<String, Object> body = new Map<String, Object>{
      'clientName' => clientName,
      'projects' => listProj,
      API_LEAD_STATUS_KEY => ld.get(leadStatusFieldApiName),
      'buyer_id' => ld.get(buyerIdFieldApiName),
      'salesforce_lead_id' => String.valueOf(leadId)
    };
    putBrokerIdentification(
      body,
      ld,
      preSalesRepSourceFieldApiName,
      organizationId
    );
    List<String> leadTypesForApi = resolveMicrositeLeadTypesForApi(leadType);
    if (!leadTypesForApi.isEmpty()) {
      body.put('lead_types', leadTypesForApi);
    }
    body.put(
      'configurationFilter',
      String.isBlank(configurationFilter) ? '' : configurationFilter.trim()
    );

    req.setBody(JSON.serialize(body));
    req.setHeader(
      'Idempotency-Key',
      buildIdempotencyKey('microsite-create', leadId, body)
    );

    HttpResponse res = PropfocusHttpService.send(req);

    if (res.getStatusCode() != 200) {
      throwCustomerFacingHttpException('generateMicrositeLink', res);
    }

    Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(
      res.getBody()
    );

    if (asBoolean(response.get('success')) == false) {
      throwCustomerFacingApiException(
        'generateMicrositeLink',
        extractApiErrorMessage(response)
      );
    }

    String micrositeUrl = firstNonBlank(
      response,
      new List<String>{ 'micrositeUrl', 'microsite_url' }
    );
    if (String.isBlank(micrositeUrl)) {
      micrositeUrl = firstNonBlank(
        asMap(response.get('data')),
        new List<String>{ 'micrositeUrl', 'microsite_url' }
      );
    }
    if (String.isBlank(micrositeUrl)) {
      throwCustomerFacingApiException(
        'generateMicrositeLink',
        'Microsite URL not returned by Propfocus'
      );
    }
    ld.put('Propfocus_Link__c', micrositeUrl);
    ld.put('Propfocus_Buyer_Insights_Available__c', true);
    update ld;
    String historyStatus =
      asBoolean(response.get('reused')) == true ? 'Reused' : 'Generated';
    createPropfocusLinkHistory(
      ld.Id,
      'Microsite',
      (listProj == null || listProj.isEmpty())
        ? null
        : String.join(listProj, ', '),
      micrositeUrl,
      historyStatus
    );

    PropfocusLinkResult result = new PropfocusLinkResult();
    result.url = micrositeUrl;
    result.whatsappMessage = resolveWhatsAppMessage(
      response,
      buildDefaultMicrositeWhatsAppMessage(
        clientName,
        listProj,
        micrositeUrl,
        resolvePreSalesRepSource(ld, preSalesRepSourceFieldApiName)
      )
    );
    return result;
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

    Set<String> configurationLabels = new Set<String>();
    for (String projectName : projectNames) {
      if (String.isBlank(projectName) || !projectConfigurations.containsKey(projectName)) {
        continue;
      }
      Object configsObj = projectConfigurations.get(projectName);
      if (!(configsObj instanceof List<Object>)) {
        continue;
      }
      for (Object configObj : (List<Object>) configsObj) {
        String label = asString(configObj);
        if (!String.isBlank(label)) {
          configurationLabels.add(label.trim());
        }
      }
    }

    List<String> sortedLabels = new List<String>(configurationLabels);
    sortedLabels.sort();
    return sortedLabels;
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
    Map<String, Schema.SObjectField> fieldsByApiName = objectType.getDescribe()
      .fields.getMap();
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
      statusFieldApiName +
      ', ' +
      projectFieldApiName +
      ' FROM ' +
      objectApiName +
      ' WHERE ' +
      leadLookupFieldApiName +
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
    return null;
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
      'Owner.Phone',
      'Propfocus_Site_Visit__c',
      buyerIdFieldApiName,
      buyerNameFieldApiName,
      projectFieldApiName
    };
    if (!String.isBlank(preSalesRepSourceFieldApiName)) {
      leadFieldApiNames.add(preSalesRepSourceFieldApiName);
    }
    SObject ld = queryLeadById(leadId, leadFieldApiNames);

    Datetime effectiveVisitDateTime;
    if (requestedVisitDateTime != null) {
      effectiveVisitDateTime = requestedVisitDateTime;
    } else {
      effectiveVisitDateTime = System.now();
    }

    String userTimeZoneId = UserInfo.getTimeZone().getID();
    String visitDate = effectiveVisitDateTime.format(
      'dd/MM/yyyy',
      userTimeZoneId
    );
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
      'salesforce_lead_id' => String.valueOf(leadId)
    };
    putBrokerIdentification(
      body,
      ld,
      preSalesRepSourceFieldApiName,
      organizationId
    );
    if (!String.isBlank(siteVisitManagerId)) {
      body.put(
        'siteVisitManager',
        new Map<String, Object>{ 'id' => siteVisitManagerId }
      );
    }

    req.setBody(JSON.serialize(body));
    req.setHeader(
      'Idempotency-Key',
      buildIdempotencyKey('site-visit-create', leadId, body)
    );

    HttpResponse res = PropfocusHttpService.send(req);

    if (res.getStatusCode() != 200) {
      throwCustomerFacingHttpException('generateSiteVisit', res);
    }

    Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(
      res.getBody()
    );

    if (asBoolean(response.get('success')) == false) {
      throwCustomerFacingApiException(
        'generateSiteVisit',
        extractApiErrorMessage(response)
      );
    }

    String siteVisitUrl = firstNonBlank(
      response,
      new List<String>{ 'sv_url', 'siteVisitUrl', 'site_visit_url' }
    );
    if (String.isBlank(siteVisitUrl)) {
      siteVisitUrl = firstNonBlank(
        asMap(response.get('data')),
        new List<String>{ 'sv_url', 'siteVisitUrl', 'site_visit_url' }
      );
    }
    if (String.isBlank(siteVisitUrl)) {
      throwCustomerFacingApiException(
        'generateSiteVisit',
        'Site Visit URL not returned by Propfocus'
      );
    }

    ld.put('Propfocus_Site_Visit__c', siteVisitUrl);
    update ld;
    String historyStatus =
      asBoolean(response.get('reused')) == true ? 'Reused' : 'Confirmed';
    createPropfocusLinkHistory(
      ld.Id,
      'Site Visit',
      resolvedProjectName,
      siteVisitUrl,
      historyStatus
    );

    PropfocusLinkResult result = new PropfocusLinkResult();
    result.url = siteVisitUrl;
    result.whatsappMessage = resolveWhatsAppMessage(
      response,
      buildDefaultSiteVisitWhatsAppMessage(
        resolvedBuyerName,
        resolvedProjectName,
        siteVisitUrl
      )
    );
    return result;
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
      'Owner.Phone',
      'Propfocus_Post_Visit__c',
      buyerIdFieldApiName,
      buyerNameFieldApiName,
      projectFieldApiName
    };
    if (!String.isBlank(preSalesRepSourceFieldApiName)) {
      leadFieldApiNames.add(preSalesRepSourceFieldApiName);
    }
    SObject ld = queryLeadById(leadId, leadFieldApiNames);

    String resolvedProjectName = String.isBlank(projectName)
      ? asString(ld.get(projectFieldApiName))
      : projectName;
    String resolvedBuyerName = String.isBlank(buyerName)
      ? asString(ld.get(buyerNameFieldApiName))
      : buyerName;
    String resolvedVisitedConfiguration = String.isBlank(visitedConfiguration)
      ? null
      : visitedConfiguration.trim();
    if (String.isBlank(resolvedVisitedConfiguration)) {
      throw new AuraHandledException('Visited configuration is required');
    }
    Date resolvedVisitDate = visitConductedAt == null ? Date.today() : visitConductedAt;

    String organizationId = PropfocusConfigService.requireOrganizationId();
    HttpRequest req = new HttpRequest();
    req.setEndpoint(
      PropfocusConfigService.apiEndpoint('/api/post-visit/create-pv')
    );
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');

    Map<String, Object> body = new Map<String, Object>{
      'buyer_id' => ld.get(buyerIdFieldApiName),
      'buyer_name' => resolvedBuyerName,
      'project_name' => resolvedProjectName,
      'visited_configuration' => resolvedVisitedConfiguration,
      'visit_conducted_at' => String.valueOf(resolvedVisitDate),
      'salesforce_lead_id' => String.valueOf(leadId)
    };
    putBrokerIdentification(
      body,
      ld,
      preSalesRepSourceFieldApiName,
      organizationId
    );

    req.setBody(JSON.serialize(body));
    req.setHeader(
      'Idempotency-Key',
      buildIdempotencyKey('post-visit-create', leadId, body)
    );

    HttpResponse res = PropfocusHttpService.send(req);
    if (res.getStatusCode() != 200) {
      throwCustomerFacingHttpException('generatePostVisit', res);
    }

    Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(
      res.getBody()
    );
    if (asBoolean(response.get('success')) == false) {
      throwCustomerFacingApiException(
        'generatePostVisit',
        extractApiErrorMessage(response)
      );
    }

    String postVisitUrl = firstNonBlank(
      response,
      new List<String>{
        'post_visit_url',
        'postVisitUrl',
        'public_url',
        'pv_url'
      }
    );
    if (String.isBlank(postVisitUrl)) {
      postVisitUrl = firstNonBlank(
        asMap(response.get('data')),
        new List<String>{
          'post_visit_url',
          'postVisitUrl',
          'public_url',
          'pv_url'
        }
      );
    }
    if (String.isBlank(postVisitUrl)) {
      throwCustomerFacingApiException(
        'generatePostVisit',
        'Post Visit URL not returned by Propfocus'
      );
    }

    ld.put('Propfocus_Post_Visit__c', postVisitUrl);
    update ld;
    String historyStatus =
      asBoolean(response.get('reused')) == true ? 'Reused' : 'Generated';
    createPropfocusLinkHistory(
      ld.Id,
      'Post Visit',
      resolvedProjectName,
      postVisitUrl,
      historyStatus
    );

    PropfocusLinkResult result = new PropfocusLinkResult();
    result.url = postVisitUrl;
    result.whatsappMessage = resolveWhatsAppMessage(
      response,
      buildDefaultPostVisitWhatsAppMessage(
        resolvedBuyerName,
        resolvedProjectName,
        resolvedVisitedConfiguration,
        postVisitUrl
      )
    );
    return result;
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
    for (Propfocus_Link__c row : [
      SELECT Id, Type__c, Project_Name__c, URL__c, Created_At__c, Status__c
      FROM Propfocus_Link__c
      WHERE Lead__c = :leadId
      ORDER BY Created_At__c DESC
      LIMIT 50
    ]) {
      if (row.Status__c == 'Reused' || seenUrls.contains(row.URL__c)) {
        continue;
      }
      seenUrls.add(row.URL__c);
      LinkHistoryItem item = new LinkHistoryItem();
      item.id = row.Id;
      item.type = row.Type__c;
      item.projectName = row.Project_Name__c;
      item.status = row.Status__c;
      item.url = row.URL__c;
      item.createdAt = row.Created_At__c;
      items.add(item);
    }
    return items;
  }
}