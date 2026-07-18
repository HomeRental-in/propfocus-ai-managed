public class PropfocusInboundWritebackService {
  public class WritebackResult {
    public Boolean leadUpdated = false;
    public Integer callLogsCreated = 0;
    public Integer historyRowsCreated = 0;
    public Boolean siteVisitSynced = false;
    public Boolean clientSiteVisitUpdated = false;
  }

  private class SiteVisitSyncResult {
    public Boolean packageSynced = false;
    public Boolean clientSynced = false;
  }

  public static WritebackResult applyWriteback(
    Id leadId,
    Map<String, Object> payloadRoot
  ) {
    WritebackResult result = new WritebackResult();
    if (leadId == null || payloadRoot == null || payloadRoot.isEmpty()) {
      return result;
    }

    PropfocusConfigService.Config cfg = PropfocusConfigService.getConfig();

    Map<String, Object> leadData = asMap(payloadRoot.get('lead_data'));
    if (leadData != null && !leadData.isEmpty()) {
      result.leadUpdated = applyLeadData(leadId, leadData, cfg);
    }

    List<Object> callLogs = asList(payloadRoot.get('call_logs'));
    if (callLogs != null && !callLogs.isEmpty()) {
      result.callLogsCreated = insertCallLogs(leadId, callLogs);
    }

    Map<String, Object> siteVisit = asMap(payloadRoot.get('site_visit'));
    if (siteVisit != null && !siteVisit.isEmpty()) {
      SiteVisitSyncResult svResult = syncSiteVisit(leadId, siteVisit, cfg);
      result.siteVisitSynced = svResult.packageSynced;
      result.clientSiteVisitUpdated = svResult.clientSynced;
    }

    List<Object> leadHistory = asList(payloadRoot.get('lead_history'));
    if (leadHistory != null && !leadHistory.isEmpty()) {
      result.historyRowsCreated = insertSyncHistory(leadId, leadHistory);
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
    return (leadData != null && !leadData.isEmpty()) ||
      (callLogs != null && !callLogs.isEmpty()) ||
      (siteVisit != null && !siteVisit.isEmpty()) ||
      (leadHistory != null && !leadHistory.isEmpty());
  }

  private static Boolean applyLeadData(
    Id leadId,
    Map<String, Object> leadData,
    PropfocusConfigService.Config cfg
  ) {
    String providedLeadId = asString(
      firstPresent(
        leadData,
        new List<String>{ 'salesforce_lead_id', 'salesforceLeadId' }
      )
    );
    if (
      !String.isBlank(providedLeadId) &&
      providedLeadId != String.valueOf(leadId)
    ) {
      throw new PropFocusServiceException(
        'salesforce_lead_id does not match resolved Lead'
      );
    }

    Lead ld = new Lead(Id = leadId);
    Boolean hasUpdates = false;

    hasUpdates =
      putMappedLeadField(
        ld,
        cfg.buyerNameField,
        firstPresent(leadData, new List<String>{ 'buyer_name', 'buyerName' })
      ) || hasUpdates;
    hasUpdates =
      putMappedLeadField(
        ld,
        cfg.preSalesOwnerNameField,
        firstPresent(
          leadData,
          new List<String>{ 'pre_sales_owner_name', 'preSalesOwnerName' }
        )
      ) || hasUpdates;
    hasUpdates =
      putMappedLeadField(
        ld,
        cfg.preSalesOwnerPhoneField,
        firstPresent(
          leadData,
          new List<String>{ 'pre_sales_owner_phone', 'preSalesOwnerPhone' }
        )
      ) || hasUpdates;
    hasUpdates =
      putMappedLeadField(
        ld,
        cfg.salesOwnerNameField,
        firstPresent(
          leadData,
          new List<String>{ 'sales_owner_name', 'salesOwnerName' }
        )
      ) || hasUpdates;
    hasUpdates =
      putMappedLeadField(
        ld,
        cfg.salesOwnerPhoneField,
        firstPresent(
          leadData,
          new List<String>{ 'sales_owner_phone', 'salesOwnerPhone' }
        )
      ) || hasUpdates;
    hasUpdates =
      putMappedLeadField(
        ld,
        cfg.buyerIdField,
        firstPresent(
          leadData,
          new List<String>{ 'uuid', 'buyer_id', 'buyer_ref_no', 'buyerRefNo' }
        )
      ) || hasUpdates;
    hasUpdates =
      putMappedLeadField(
        ld,
        cfg.leadStatusField,
        firstPresent(
          leadData,
          new List<String>{ 'current_lead_status', 'lead_status', 'leadStatus' }
        )
      ) || hasUpdates;
    hasUpdates =
      putMappedLeadField(
        ld,
        cfg.leadSourceField,
        firstPresent(leadData, new List<String>{ 'lead_source', 'leadSource' })
      ) || hasUpdates;
    hasUpdates =
      putMappedLeadField(
        ld,
        cfg.projectField,
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
      putMappedLeadField(
        ld,
        cfg.relatedDateSourceField,
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

    update ld;
    return true;
  }

  private static Integer insertCallLogs(Id leadId, List<Object> callLogs) {
    List<Propfocus_Call_Log__c> rows = new List<Propfocus_Call_Log__c>();
    for (Object item : callLogs) {
      Map<String, Object> entry = asMap(item);
      if (entry == null || entry.isEmpty()) {
        continue;
      }
      Propfocus_Call_Log__c row = new Propfocus_Call_Log__c(
        Lead__c = leadId,
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
      rows.add(row);
    }
    if (rows.isEmpty()) {
      return 0;
    }
    insert rows;
    return rows.size();
  }

  private static Integer insertSyncHistory(
    Id leadId,
    List<Object> leadHistory
  ) {
    List<Propfocus_Sync_History__c> rows = new List<Propfocus_Sync_History__c>();
    for (Object item : leadHistory) {
      Map<String, Object> entry = asMap(item);
      if (entry == null || entry.isEmpty()) {
        continue;
      }
      Propfocus_Sync_History__c row = new Propfocus_Sync_History__c(
        Lead__c = leadId,
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
      rows.add(row);
    }
    if (rows.isEmpty()) {
      return 0;
    }
    insert rows;
    return rows.size();
  }

  private static SiteVisitSyncResult syncSiteVisit(
    Id leadId,
    Map<String, Object> siteVisit,
    PropfocusConfigService.Config cfg
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
      leadId,
      siteVisitNumber
    );
    packageRow.Lead__c = leadId;
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
      leadId,
      siteVisit,
      cfg,
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
      leadId,
      projectName,
      siteVisitStatus
    );

    return result;
  }

  private static Propfocus_Site_Visit_Sync__c findOrCreatePackageSiteVisit(
    Id leadId,
    String siteVisitNumber
  ) {
    if (!String.isBlank(siteVisitNumber)) {
      List<Propfocus_Site_Visit_Sync__c> existing = [
        SELECT Id, Lead__c, Site_Visit_Number__c
        FROM Propfocus_Site_Visit_Sync__c
        WHERE Site_Visit_Number__c = :siteVisitNumber
        LIMIT 1
      ];
      if (!existing.isEmpty()) {
        Propfocus_Site_Visit_Sync__c row = existing[0];
        row.Lead__c = leadId;
        return row;
      }
    }

    return new Propfocus_Site_Visit_Sync__c(
      Lead__c = leadId,
      Site_Visit_Number__c = siteVisitNumber
    );
  }

  private static Boolean upsertClientSiteVisit(
    Id leadId,
    Map<String, Object> siteVisit,
    PropfocusConfigService.Config cfg,
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
    mappedFieldCount += putIfConfigured(
        row,
        cfg.siteVisitLeadLookupField,
        leadId
      )
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
      insert row;
      return true;
    } catch (DmlException e) {
      return false;
    }
  }

  private static Boolean putMappedLeadField(
    Lead ld,
    String fieldApiName,
    Object value
  ) {
    if (String.isBlank(fieldApiName) || value == null) {
      return false;
    }
    if (!isSafeApiName(fieldApiName)) {
      return false;
    }
    Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
    if (!leadFields.containsKey(fieldApiName)) {
      return false;
    }
    if (!leadFields.get(fieldApiName).getDescribe().isUpdateable()) {
      return false;
    }
    ld.put(fieldApiName, value);
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
