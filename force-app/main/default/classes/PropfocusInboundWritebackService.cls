// without sharing: invoked from the inbound integration endpoint; must update
// the matched parent record regardless of the integration user's sharing.
public without sharing class PropfocusInboundWritebackService {
  public class WritebackResult {
    public Boolean leadUpdated = false;
    public Integer callLogsCreated = 0;
    public Integer historyRowsCreated = 0;
    public Boolean siteVisitSynced = false;
    public Boolean clientSiteVisitUpdated = false;
    public Boolean engagementSynced = false;
  }

  private class SiteVisitSyncResult {
    public Boolean packageSynced = false;
    public Boolean clientSynced = false;
  }

  public static WritebackResult applyWriteback(
    Id recordId,
    Map<String, Object> payloadRoot
  ) {
    WritebackResult result = new WritebackResult();
    if (recordId == null || payloadRoot == null || payloadRoot.isEmpty()) {
      return result;
    }

    PropfocusConfigService.Config cfg = PropfocusConfigService.getConfig();
    Boolean isOpportunity = recordId.getSObjectType() == Opportunity.SObjectType;

    Map<String, Object> leadData = asMap(payloadRoot.get('lead_data'));
    if (leadData != null && !leadData.isEmpty()) {
      result.leadUpdated = applyParentData(recordId, leadData, cfg, isOpportunity);
    }

    List<Object> callLogs = asList(payloadRoot.get('call_logs'));
    if (callLogs != null && !callLogs.isEmpty()) {
      result.callLogsCreated = insertCallLogs(recordId, callLogs, isOpportunity);
    }

    Map<String, Object> siteVisit = asMap(payloadRoot.get('site_visit'));
    if (siteVisit != null && !siteVisit.isEmpty()) {
      SiteVisitSyncResult svResult = syncSiteVisit(
        recordId,
        siteVisit,
        cfg,
        isOpportunity
      );
      result.siteVisitSynced = svResult.packageSynced;
      result.clientSiteVisitUpdated = svResult.clientSynced;
    }

    List<Object> leadHistory = asList(payloadRoot.get('lead_history'));
    if (leadHistory != null && !leadHistory.isEmpty()) {
      result.historyRowsCreated = insertSyncHistory(
        recordId,
        leadHistory,
        isOpportunity
      );
    }

    Map<String, Object> engagement = asMap(payloadRoot.get('engagement'));
    if (engagement != null && !engagement.isEmpty()) {
      result.engagementSynced = syncEngagement(recordId, engagement);
    } else {
      String engagementStatus = asString(
        firstPresent(
          payloadRoot,
          new List<String>{
            'engagement_status',
            'engagementStatus',
            'microsite_status',
            'micrositeStatus'
          }
        )
      );
      if (isEngagedStatus(engagementStatus)) {
        result.engagementSynced = syncEngagement(
          recordId,
          new Map<String, Object>{ 'status' => 'Engaged' }
        );
      }
    }

    return result;
  }

  public static Boolean hasWritebackPayload(Map<String, Object> payloadRoot) {
    if (payloadRoot == null || payloadRoot.isEmpty()) {
      return false;
    }
    Map<String, Object> leadData = asMap(payloadRoot.get('lead_data'));
    List<Object> callLogs = asList(payloadRoot.get('call_logs'));
    Map<String, Object> siteVisit = asMap(payloadRoot.get('site_visit'));
    List<Object> leadHistory = asList(payloadRoot.get('lead_history'));
    Map<String, Object> engagement = asMap(payloadRoot.get('engagement'));
    String engagementStatus = asString(
      firstPresent(
        payloadRoot,
        new List<String>{
          'engagement_status',
          'engagementStatus',
          'microsite_status',
          'micrositeStatus'
        }
      )
    );
    return (leadData != null && !leadData.isEmpty()) ||
      (callLogs != null && !callLogs.isEmpty()) ||
      (siteVisit != null && !siteVisit.isEmpty()) ||
      (leadHistory != null && !leadHistory.isEmpty()) ||
      (engagement != null && !engagement.isEmpty()) ||
      isEngagedStatus(engagementStatus);
  }

  /**
   * Marks microsite/post-visit history as Engaged from buyer activity signals
   * (notification title/message) when no explicit engagement write-back is present.
   */
  public static Boolean syncEngagementFromActivity(
    Id recordId,
    String eventType,
    String title,
    String message
  ) {
    if (recordId == null) {
      return false;
    }
    String engagementHint = resolveEngagementHintFromActivity(
      eventType,
      title,
      message
    );
    if (String.isBlank(engagementHint)) {
      return false;
    }
    PropFocusLeadService.syncLinkHistoryEngagement(
      recordId,
      engagementHint,
      null
    );
    return true;
  }

  @TestVisible
  private static String resolveEngagementHintFromActivity(
    String eventType,
    String title,
    String message
  ) {
    String haystack = (
      (eventType == null ? '' : eventType) +
      ' ' +
      (title == null ? '' : title) +
      ' ' +
      (message == null ? '' : message)
    )
      .trim()
      .toLowerCase();
    if (String.isBlank(haystack)) {
      return null;
    }
    // Site-visit notifications should not flip microsite/post-visit engagement.
    if (
      haystack.contains('site visit') &&
      !haystack.contains('post visit') &&
      !haystack.contains('microsite')
    ) {
      return null;
    }
    if (haystack.contains('post visit') || haystack.contains('post-visit')) {
      return 'post_visit';
    }
    if (
      haystack.contains('microsite') ||
      haystack.contains('engaged') ||
      haystack.contains('viewed') ||
      haystack.contains('opened')
    ) {
      return 'microsite';
    }
    return null;
  }

  private static Boolean syncEngagement(
    Id recordId,
    Map<String, Object> engagement
  ) {
    if (engagement == null || engagement.isEmpty()) {
      return false;
    }
    String status = asString(
      firstPresent(
        engagement,
        new List<String>{ 'status', 'engagement_status', 'engagementStatus' }
      )
    );
    if (String.isBlank(status)) {
      // engagement {} with type/project only still means Engaged.
      status = 'Engaged';
    } else if (!isEngagedStatus(status)) {
      return false;
    }
    String communicationTypeHint = asString(
      firstPresent(
        engagement,
        new List<String>{
          'communication_type',
          'communicationType',
          'type',
          'link_type',
          'linkType'
        }
      )
    );
    String projectName = asString(
      firstPresent(
        engagement,
        new List<String>{
          'primary_project_name',
          'project_name',
          'projectName'
        }
      )
    );
    PropFocusLeadService.syncLinkHistoryEngagement(
      recordId,
      communicationTypeHint,
      projectName
    );
    return true;
  }

  private static Boolean isEngagedStatus(String status) {
    if (String.isBlank(status)) {
      return false;
    }
    String normalized = status.trim().toLowerCase();
    return normalized == 'engaged' ||
      normalized == 'yes' ||
      normalized == 'true';
  }

  private static Boolean applyParentData(
    Id recordId,
    Map<String, Object> leadData,
    PropfocusConfigService.Config cfg,
    Boolean isOpportunity
  ) {
    if (isOpportunity) {
      String providedOppId = asString(
        firstPresent(
          leadData,
          new List<String>{
            'salesforce_opportunity_id',
            'salesforceOpportunityId'
          }
        )
      );
      if (
        !String.isBlank(providedOppId) &&
        providedOppId != String.valueOf(recordId)
      ) {
        throw new PropFocusServiceException(
          'salesforce_opportunity_id does not match resolved Opportunity'
        );
      }
    } else {
      String providedLeadId = asString(
        firstPresent(
          leadData,
          new List<String>{ 'salesforce_lead_id', 'salesforceLeadId' }
        )
      );
      if (
        !String.isBlank(providedLeadId) &&
        providedLeadId != String.valueOf(recordId)
      ) {
        throw new PropFocusServiceException(
          'salesforce_lead_id does not match resolved Lead'
        );
      }
    }

    SObject parent = isOpportunity
      ? (SObject) new Opportunity(Id = recordId)
      : (SObject) new Lead(Id = recordId);
    Boolean hasUpdates = false;

    String buyerNameField = isOpportunity
      ? cfg.opportunityBuyerNameField
      : cfg.buyerNameField;
    String preSalesOwnerNameField = isOpportunity
      ? cfg.opportunityPreSalesOwnerNameField
      : cfg.preSalesOwnerNameField;
    String preSalesOwnerPhoneField = isOpportunity
      ? cfg.opportunityPreSalesOwnerPhoneField
      : cfg.preSalesOwnerPhoneField;
    String salesOwnerNameField = isOpportunity
      ? cfg.opportunitySalesOwnerNameField
      : cfg.salesOwnerNameField;
    String salesOwnerPhoneField = isOpportunity
      ? cfg.opportunitySalesOwnerPhoneField
      : cfg.salesOwnerPhoneField;
    String buyerIdField = isOpportunity
      ? cfg.opportunityBuyerIdField
      : cfg.buyerIdField;
    String statusField = isOpportunity
      ? cfg.opportunityStatusField
      : cfg.leadStatusField;
    String leadSourceField = isOpportunity
      ? cfg.opportunityLeadSourceField
      : cfg.leadSourceField;
    String projectField = isOpportunity
      ? cfg.opportunityProjectField
      : cfg.projectField;
    String relatedDateSourceField = isOpportunity
      ? cfg.opportunityRelatedDateSourceField
      : cfg.relatedDateSourceField;

    hasUpdates =
      putMappedParentField(
        parent,
        buyerNameField,
        firstPresent(leadData, new List<String>{ 'buyer_name', 'buyerName' })
      ) || hasUpdates;
    hasUpdates =
      putMappedParentField(
        parent,
        preSalesOwnerNameField,
        firstPresent(
          leadData,
          new List<String>{ 'pre_sales_owner_name', 'preSalesOwnerName' }
        )
      ) || hasUpdates;
    hasUpdates =
      putMappedParentField(
        parent,
        preSalesOwnerPhoneField,
        firstPresent(
          leadData,
          new List<String>{ 'pre_sales_owner_phone', 'preSalesOwnerPhone' }
        )
      ) || hasUpdates;
    hasUpdates =
      putMappedParentField(
        parent,
        salesOwnerNameField,
        firstPresent(
          leadData,
          new List<String>{ 'sales_owner_name', 'salesOwnerName' }
        )
      ) || hasUpdates;
    hasUpdates =
      putMappedParentField(
        parent,
        salesOwnerPhoneField,
        firstPresent(
          leadData,
          new List<String>{ 'sales_owner_phone', 'salesOwnerPhone' }
        )
      ) || hasUpdates;
    hasUpdates =
      putMappedParentField(
        parent,
        buyerIdField,
        firstPresent(
          leadData,
          new List<String>{ 'uuid', 'buyer_id', 'buyer_ref_no', 'buyerRefNo' }
        )
      ) || hasUpdates;
    hasUpdates =
      putMappedParentField(
        parent,
        statusField,
        firstPresent(
          leadData,
          new List<String>{ 'current_lead_status', 'lead_status', 'leadStatus' }
        )
      ) || hasUpdates;
    hasUpdates =
      putMappedParentField(
        parent,
        leadSourceField,
        firstPresent(leadData, new List<String>{ 'lead_source', 'leadSource' })
      ) || hasUpdates;
    hasUpdates =
      putMappedParentField(
        parent,
        projectField,
        firstPresent(
          leadData,
          new List<String>{
            'primary_project_name',
            'project_name',
            'projectName'
          }
        )
      ) || hasUpdates;
    hasUpdates =
      putMappedParentField(
        parent,
        relatedDateSourceField,
        firstPresent(
          leadData,
          new List<String>{
            'related_date_created_date_source',
            'relatedDateCreatedDateSource'
          }
        )
      ) || hasUpdates;

    if (!hasUpdates) {
      return false;
    }

    update parent;
    return true;
  }

  private static Integer insertCallLogs(
    Id recordId,
    List<Object> callLogs,
    Boolean isOpportunity
  ) {
    List<Propfocus_Call_Log__c> rows = new List<Propfocus_Call_Log__c>();
    for (Object item : callLogs) {
      Map<String, Object> entry = asMap(item);
      if (entry == null || entry.isEmpty()) {
        continue;
      }
      Propfocus_Call_Log__c row = new Propfocus_Call_Log__c(
        Duration__c = asString(
          firstPresent(entry, new List<String>{ 'duration' })
        ),
        Disposition__c = asString(
          firstPresent(entry, new List<String>{ 'disposition' })
        ),
        Call_Time__c = asDatetime(
          firstPresent(entry, new List<String>{ 'call_time', 'callTime' })
        ),
        Recording_URL__c = asString(
          firstPresent(
            entry,
            new List<String>{ 'recording_url', 'recordingUrl' }
          )
        )
      );
      if (isOpportunity) {
        row.Opportunity__c = recordId;
      } else {
        row.Lead__c = recordId;
      }
      rows.add(row);
    }
    if (rows.isEmpty()) {
      return 0;
    }
    insert rows;
    return rows.size();
  }

  private static Integer insertSyncHistory(
    Id recordId,
    List<Object> leadHistory,
    Boolean isOpportunity
  ) {
    List<Propfocus_Sync_History__c> rows = new List<Propfocus_Sync_History__c>();
    for (Object item : leadHistory) {
      Map<String, Object> entry = asMap(item);
      if (entry == null || entry.isEmpty()) {
        continue;
      }
      Propfocus_Sync_History__c row = new Propfocus_Sync_History__c(
        Field_Changed__c = asString(
          firstPresent(
            entry,
            new List<String>{ 'field_changed', 'fieldChanged' }
          )
        ),
        Old_Value__c = asString(
          firstPresent(entry, new List<String>{ 'old_value', 'oldValue' })
        ),
        New_Value__c = asString(
          firstPresent(entry, new List<String>{ 'new_value', 'newValue' })
        ),
        Change_Date__c = asDatetime(
          firstPresent(entry, new List<String>{ 'change_date', 'changeDate' })
        ),
        Changed_By__c = asString(
          firstPresent(entry, new List<String>{ 'changed_by', 'changedBy' })
        )
      );
      if (isOpportunity) {
        row.Opportunity__c = recordId;
      } else {
        row.Lead__c = recordId;
      }
      rows.add(row);
    }
    if (rows.isEmpty()) {
      return 0;
    }
    insert rows;
    return rows.size();
  }

  private static SiteVisitSyncResult syncSiteVisit(
    Id recordId,
    Map<String, Object> siteVisit,
    PropfocusConfigService.Config cfg,
    Boolean isOpportunity
  ) {
    SiteVisitSyncResult result = new SiteVisitSyncResult();

    String siteVisitNumber = asString(
      firstPresent(
        siteVisit,
        new List<String>{ 'site_visit_number', 'siteVisitNumber' }
      )
    );
    String siteVisitType = asString(
      firstPresent(
        siteVisit,
        new List<String>{ 'site_visit_type', 'siteVisitType' }
      )
    );
    String siteVisitStatus = asString(
      firstPresent(
        siteVisit,
        new List<String>{ 'site_visit_status', 'siteVisitStatus' }
      )
    );
    Datetime siteVisitDatetime = asDatetime(
      firstPresent(
        siteVisit,
        new List<String>{ 'site_visit_datetime', 'siteVisitDatetime' }
      )
    );
    String svTeam = asString(
      firstPresent(siteVisit, new List<String>{ 'sv_team', 'svTeam' })
    );

    Map<String, Object> manager = asMap(siteVisit.get('manager'));
    String managerName = manager == null
      ? null
      : asString(firstPresent(manager, new List<String>{ 'name' }));
    String managerPhone = manager == null
      ? null
      : asString(firstPresent(manager, new List<String>{ 'phone' }));
    String managerEmail = manager == null
      ? null
      : asString(firstPresent(manager, new List<String>{ 'email' }));

    Propfocus_Site_Visit_Sync__c packageRow = findOrCreatePackageSiteVisit(
      recordId,
      siteVisitNumber,
      isOpportunity
    );
    if (isOpportunity) {
      packageRow.Opportunity__c = recordId;
      packageRow.Lead__c = null;
    } else {
      packageRow.Lead__c = recordId;
      packageRow.Opportunity__c = null;
    }
    packageRow.Site_Visit_Type__c = siteVisitType;
    packageRow.Site_Visit_Status__c = siteVisitStatus;
    packageRow.Site_Visit_Datetime__c = siteVisitDatetime;
    packageRow.SV_Team__c = svTeam;
    packageRow.Manager_Name__c = managerName;
    packageRow.Manager_Phone__c = managerPhone;
    packageRow.Manager_Email__c = managerEmail;
    if (!String.isBlank(siteVisitNumber)) {
      upsert packageRow Site_Visit_Number__c;
    } else {
      insert packageRow;
    }
    result.packageSynced = true;

    result.clientSynced = upsertClientSiteVisit(
      recordId,
      siteVisit,
      cfg,
      isOpportunity,
      siteVisitNumber,
      siteVisitType,
      siteVisitStatus,
      siteVisitDatetime,
      svTeam,
      managerName,
      managerPhone,
      managerEmail
    );

    String projectName = asString(
      firstPresent(
        siteVisit,
        new List<String>{
          'primary_project_name',
          'project_name',
          'projectName'
        }
      )
    );
    PropFocusLeadService.syncLinkHistoryStatusFromSiteVisit(
      recordId,
      projectName,
      siteVisitStatus
    );

    return result;
  }

  private static Propfocus_Site_Visit_Sync__c findOrCreatePackageSiteVisit(
    Id recordId,
    String siteVisitNumber,
    Boolean isOpportunity
  ) {
    if (!String.isBlank(siteVisitNumber)) {
      List<Propfocus_Site_Visit_Sync__c> existing = [
        SELECT Id, Lead__c, Opportunity__c, Site_Visit_Number__c
        FROM Propfocus_Site_Visit_Sync__c
        WHERE Site_Visit_Number__c = :siteVisitNumber
        LIMIT 1
      ];
      if (!existing.isEmpty()) {
        Propfocus_Site_Visit_Sync__c row = existing[0];
        if (isOpportunity) {
          row.Opportunity__c = recordId;
          row.Lead__c = null;
        } else {
          row.Lead__c = recordId;
          row.Opportunity__c = null;
        }
        return row;
      }
    }

    Propfocus_Site_Visit_Sync__c created = new Propfocus_Site_Visit_Sync__c(
      Site_Visit_Number__c = siteVisitNumber
    );
    if (isOpportunity) {
      created.Opportunity__c = recordId;
    } else {
      created.Lead__c = recordId;
    }
    return created;
  }

  private static Boolean upsertClientSiteVisit(
    Id recordId,
    Map<String, Object> siteVisit,
    PropfocusConfigService.Config cfg,
    Boolean isOpportunity,
    String siteVisitNumber,
    String siteVisitType,
    String siteVisitStatus,
    Datetime siteVisitDatetime,
    String svTeam,
    String managerName,
    String managerPhone,
    String managerEmail
  ) {
    if (String.isBlank(cfg.siteVisitObject)) {
      return false;
    }

    Schema.SObjectType objectType = Schema.getGlobalDescribe()
      .get(cfg.siteVisitObject);
    if (objectType == null) {
      return false;
    }

    SObject row = objectType.newSObject();
    Integer mappedFieldCount = 0;
    String parentLookupField = isOpportunity
      ? cfg.siteVisitOpportunityLookupField
      : cfg.siteVisitLeadLookupField;
    mappedFieldCount += putIfConfigured(row, parentLookupField, recordId)
      ? 1
      : 0;
    mappedFieldCount += putIfConfigured(
        row,
        cfg.siteVisitNumberField,
        siteVisitNumber
      )
      ? 1
      : 0;
    mappedFieldCount += putIfConfigured(
        row,
        cfg.siteVisitTypeField,
        siteVisitType
      )
      ? 1
      : 0;
    mappedFieldCount += putIfConfigured(
        row,
        cfg.siteVisitStatusField,
        siteVisitStatus
      )
      ? 1
      : 0;
    mappedFieldCount += putIfConfigured(
        row,
        cfg.siteVisitDatetimeField,
        siteVisitDatetime
      )
      ? 1
      : 0;
    mappedFieldCount += putIfConfigured(row, cfg.siteVisitTeamField, svTeam)
      ? 1
      : 0;
    mappedFieldCount += putIfConfigured(
        row,
        cfg.siteVisitProjectField,
        firstPresent(
          siteVisit,
          new List<String>{
            'primary_project_name',
            'project_name',
            'projectName'
          }
        )
      )
      ? 1
      : 0;
    mappedFieldCount += putIfConfigured(
        row,
        cfg.siteVisitManagerNameField,
        managerName
      )
      ? 1
      : 0;
    mappedFieldCount += putIfConfigured(
        row,
        cfg.siteVisitManagerPhoneField,
        managerPhone
      )
      ? 1
      : 0;
    mappedFieldCount += putIfConfigured(
        row,
        cfg.siteVisitManagerEmailField,
        managerEmail
      )
      ? 1
      : 0;

    if (mappedFieldCount == 0) {
      return false;
    }

    try {
      Id existingId = findExistingClientSiteVisitId(
        objectType,
        parentLookupField,
        cfg.siteVisitNumberField,
        recordId,
        siteVisitNumber
      );
      if (existingId != null) {
        row.put('Id', existingId);
        update row;
      } else {
        insert row;
      }
      return true;
    } catch (DmlException e) {
      return false;
    }
  }

  // Repeat inbound pushes for the same visit must update in place. Without a
  // mapped Site_Visit_Number_Field__c there is no stable key to match on, so
  // the caller falls back to insert.
  private static Id findExistingClientSiteVisitId(
    Schema.SObjectType objectType,
    String parentLookupField,
    String numberFieldApiName,
    Id recordId,
    String siteVisitNumber
  ) {
    if (String.isBlank(siteVisitNumber) || String.isBlank(numberFieldApiName)) {
      return null;
    }
    if (!isSafeApiName(numberFieldApiName)) {
      return null;
    }
    Map<String, Schema.SObjectField> fieldsByApiName = objectType.getDescribe()
      .fields.getMap();
    if (!fieldsByApiName.containsKey(numberFieldApiName)) {
      return null;
    }

    String soql =
      'SELECT Id FROM ' +
      objectType.getDescribe().getName() +
      ' WHERE ' +
      numberFieldApiName +
      ' = :siteVisitNumber';

    // Scope to the parent so a visit number that is only unique per Lead
    // cannot match another Lead's row.
    if (
      String.isNotBlank(parentLookupField) &&
      isSafeApiName(parentLookupField) &&
      fieldsByApiName.containsKey(parentLookupField)
    ) {
      soql += ' AND ' + parentLookupField + ' = :recordId';
    }
    soql += ' LIMIT 1';

    List<SObject> rows = Database.query(soql);
    return rows.isEmpty() ? null : (Id) rows[0].get('Id');
  }

  private static Boolean putMappedParentField(
    SObject parent,
    String fieldApiName,
    Object value
  ) {
    if (parent == null || String.isBlank(fieldApiName) || value == null) {
      return false;
    }
    if (!isSafeApiName(fieldApiName)) {
      return false;
    }
    Map<String, Schema.SObjectField> parentFields = parent.getSObjectType()
      .getDescribe()
      .fields.getMap();
    if (!parentFields.containsKey(fieldApiName)) {
      return false;
    }
    if (!parentFields.get(fieldApiName).getDescribe().isUpdateable()) {
      return false;
    }
    parent.put(fieldApiName, value);
    return true;
  }

  private static Boolean putIfConfigured(
    SObject row,
    String fieldApiName,
    Object value
  ) {
    if (String.isBlank(fieldApiName) || value == null) {
      return false;
    }
    if (!isSafeApiName(fieldApiName)) {
      return false;
    }
    Map<String, Schema.SObjectField> fieldsByApiName = row.getSObjectType()
      .getDescribe()
      .fields.getMap();
    if (!fieldsByApiName.containsKey(fieldApiName)) {
      return false;
    }
    row.put(fieldApiName, value);
    return true;
  }

  private static Object firstPresent(
    Map<String, Object> source,
    List<String> keys
  ) {
    if (source == null || keys == null) {
      return null;
    }
    for (String key : keys) {
      if (source.containsKey(key) && source.get(key) != null) {
        return source.get(key);
      }
    }
    return null;
  }

  private static Map<String, Object> asMap(Object value) {
    if (value == null) {
      return null;
    }
    if (value instanceof Map<String, Object>) {
      return (Map<String, Object>) value;
    }
    return null;
  }

  private static List<Object> asList(Object value) {
    if (value == null) {
      return null;
    }
    if (value instanceof List<Object>) {
      return (List<Object>) value;
    }
    return null;
  }

  private static String asString(Object value) {
    if (value == null) {
      return null;
    }
    String text = String.valueOf(value);
    return String.isBlank(text) ? null : text;
  }

  private static Datetime asDatetime(Object value) {
    if (value == null) {
      return null;
    }
    if (value instanceof Datetime) {
      return (Datetime) value;
    }
    if (value instanceof Long) {
      return Datetime.newInstance((Long) value);
    }
    if (value instanceof Integer) {
      return Datetime.newInstance((Integer) value);
    }
    String text = String.valueOf(value);
    if (String.isBlank(text)) {
      return null;
    }
    try {
      return (Datetime) JSON.deserialize('"' + text + '"', Datetime.class);
    } catch (Exception e) {
      return null;
    }
  }

  private static Boolean isSafeApiName(String value) {
    return !String.isBlank(value) &&
      Pattern.matches('^[A-Za-z][A-Za-z0-9_]*(__c)?$', value);
  }
}
