/**
 * Generic Site Visit record → Propfocus site visit link.
 * Field/object API names come from Propfocus Config (CMDT), so each subscriber's
 * Site Visit modal/object can differ without package changes.
 *
 * Wire via Record-Triggered Flow on the configured Site Visit object (after save)
 * → Apex action "Generate Propfocus Site Visit Link From Record".
 * Callouts run asynchronously so Save is not blocked.
 */
public without sharing class PropFocusSiteVisitLinkService {
  public class GenerateFromSiteVisitRequest {
    @InvocableVariable(
      required=true
      label='Site Visit Record Id'
      description='Id of a record on the configured Site Visit object (Propfocus Config → Site Visit Object).'
    )
    public Id siteVisitRecordId;
  }

  @InvocableMethod(
    label='Generate Propfocus Site Visit Link From Record'
    description='Maps configured Site Visit fields to a Propfocus site visit link on the parent Lead or Opportunity. Runs asynchronously (HTTP callout).'
  )
  public static void generateFromSiteVisitRecords(
    List<GenerateFromSiteVisitRequest> requests
  ) {
    Set<Id> siteVisitIds = new Set<Id>();
    if (requests == null) {
      return;
    }
    for (GenerateFromSiteVisitRequest req : requests) {
      if (req != null && req.siteVisitRecordId != null) {
        siteVisitIds.add(req.siteVisitRecordId);
      }
    }
    if (siteVisitIds.isEmpty()) {
      return;
    }
    System.enqueueJob(new GenerateSiteVisitLinkQueueable(siteVisitIds));
  }

  /**
   * Synchronous path used by the queueable and by tests.
   * Reads mapped fields from the Site Visit record and calls generatePropfocusTemplate.
   */
  public static PropFocusLeadService.PropfocusTemplateResult generateFromSiteVisitRecord(
    Id siteVisitRecordId
  ) {
    MappedSiteVisit mapped = mapSiteVisitRecord(siteVisitRecordId);
    Map<String, Object> context = buildSiteVisitContext(mapped);
    // Subscriber orgs with a managed package install: use the packaged Named
    // Credential (unpackaged External Credential often has no principal access).
    if (!PropFocusSiteVisitLinkService.class.getName().contains('.')) {
      PropfocusConfigService.Config cfg = PropfocusConfigService.getConfig();
      if (
        Schema.getGlobalDescribe().containsKey('PropfocusAI__Propfocus_Config__mdt')
      ) {
        cfg.apiNamedCredential = 'PropfocusAI__Propfocus_API';
      }
    }
    PropFocusLeadService.PropfocusTemplateResult result = PropFocusLeadService.generatePropfocusTemplate(
      mapped.parentRecordId,
      PropFocusLeadService.COMM_TYPE_SITE_VISIT,
      JSON.serialize(context)
    );
    mirrorPackagedLeadArtifacts(
      mapped.parentRecordId,
      result == null ? null : result.url,
      mapped.projectName
    );
    return result;
  }

  private static void mirrorPackagedLeadArtifacts(
    Id parentRecordId,
    String linkUrl,
    String projectName
  ) {
    if (
      parentRecordId == null ||
      String.isBlank(linkUrl) ||
      PropFocusSiteVisitLinkService.class.getName().contains('.')
    ) {
      return;
    }
    Boolean isOpportunity =
      parentRecordId.getSObjectType() == Opportunity.SObjectType;
    String parentField = 'PropfocusAI__Propfocus_Site_Visit__c';
    Map<String, Schema.SObjectField> parentFields = parentRecordId.getSObjectType()
      .getDescribe()
      .fields.getMap();
    if (parentFields.containsKey(parentField)) {
      SObject parent = parentRecordId.getSObjectType().newSObject(parentRecordId);
      parent.put(parentField, linkUrl);
      update parent;
    }

    Schema.SObjectType linkType = Schema.getGlobalDescribe()
      .get('PropfocusAI__Propfocus_Link__c');
    if (linkType == null) {
      return;
    }
    SObject history = linkType.newSObject();
    if (isOpportunity) {
      history.put('PropfocusAI__Opportunity__c', parentRecordId);
    } else {
      history.put('PropfocusAI__Lead__c', parentRecordId);
    }
    history.put('PropfocusAI__Type__c', 'Site Visit Confirmation');
    history.put('PropfocusAI__URL__c', linkUrl);
    history.put('PropfocusAI__Project_Name__c', projectName);
    history.put('PropfocusAI__Status__c', 'Pending');
    history.put('PropfocusAI__Created_At__c', System.now());
    insert history;
  }

  @TestVisible
  private class MappedSiteVisit {
    public Id parentRecordId;
    public String projectName;
    public Datetime visitDateTime;
    public String managerName;
    public String managerPhone;
    public String managerEmail;
  }

  @TestVisible
  private static MappedSiteVisit mapSiteVisitRecord(Id siteVisitRecordId) {
    if (siteVisitRecordId == null) {
      PropFocusServiceException.throwUserFacing('Site Visit Record Id is required');
    }

    PropfocusConfigService.Config cfg = resolveConfig();
    String objectApiName = requireConfiguredApiName(
      cfg.siteVisitObject,
      'Site_Visit_Object__c'
    );
    Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
    if (objectType == null) {
      PropFocusServiceException.throwUserFacing(
        'Configured site visit object not found: ' + objectApiName
      );
    }
    if (siteVisitRecordId.getSObjectType() != objectType) {
      PropFocusServiceException.throwUserFacing(
        'Record is not a ' + objectApiName + ' (configured Site Visit Object)'
      );
    }

    Map<String, Schema.SObjectField> fieldsByApiName = objectType.getDescribe()
      .fields.getMap();

    String leadLookupField = optionalConfiguredField(
      cfg.siteVisitLeadLookupField,
      'Lead_Lookup_Field__c',
      fieldsByApiName
    );
    String opportunityLookupField = optionalConfiguredField(
      cfg.siteVisitOpportunityLookupField,
      'Opportunity_Lookup_Field__c',
      fieldsByApiName
    );
    String projectField = requireConfiguredField(
      cfg.siteVisitProjectField,
      'Site_Visit_Project_Field__c',
      fieldsByApiName
    );
    String datetimeField = optionalConfiguredField(
      cfg.siteVisitDatetimeField,
      'Site_Visit_Datetime_Field__c',
      fieldsByApiName
    );
    String managerNameField = optionalConfiguredField(
      cfg.siteVisitManagerNameField,
      'Site_Visit_Manager_Name_Field__c',
      fieldsByApiName
    );
    String managerPhoneField = optionalConfiguredField(
      cfg.siteVisitManagerPhoneField,
      'Site_Visit_Manager_Phone_Field__c',
      fieldsByApiName
    );
    String managerEmailField = optionalConfiguredField(
      cfg.siteVisitManagerEmailField,
      'Site_Visit_Manager_Email_Field__c',
      fieldsByApiName
    );

    List<String> selectParts = new List<String>{ 'Id' };
    addSelectField(selectParts, leadLookupField, fieldsByApiName);
    addSelectField(selectParts, opportunityLookupField, fieldsByApiName);
    addSelectField(selectParts, projectField, fieldsByApiName);
    addSelectField(selectParts, datetimeField, fieldsByApiName);
    addSelectField(selectParts, managerNameField, fieldsByApiName);
    addSelectField(selectParts, managerPhoneField, fieldsByApiName);
    addSelectField(selectParts, managerEmailField, fieldsByApiName);

    String soql =
      'SELECT ' +
      String.join(selectParts, ', ') +
      ' FROM ' +
      objectApiName +
      ' WHERE Id = :siteVisitRecordId LIMIT 1';
    List<SObject> rows = Database.query(soql);
    if (rows.isEmpty()) {
      PropFocusServiceException.throwUserFacing('Site Visit record not found');
    }
    SObject row = rows[0];

    MappedSiteVisit mapped = new MappedSiteVisit();
    mapped.parentRecordId = resolveParentRecordId(
      row,
      leadLookupField,
      opportunityLookupField
    );
    if (mapped.parentRecordId == null) {
      PropFocusServiceException.throwUserFacing(
        'Site Visit must have a Lead or Opportunity (mapped lookup fields)'
      );
    }

    mapped.projectName = resolveDisplayValue(row, projectField, fieldsByApiName);
    if (String.isBlank(mapped.projectName)) {
      PropFocusServiceException.throwUserFacing(
        'Site Visit project is required (mapped Site Visit Project Field)'
      );
    }

    if (!String.isBlank(datetimeField)) {
      mapped.visitDateTime = asDatetime(row.get(datetimeField));
    }
    if (mapped.visitDateTime == null) {
      mapped.visitDateTime = System.now();
    }

    mapped.managerName = resolveDisplayValue(
      row,
      managerNameField,
      fieldsByApiName
    );
    mapped.managerPhone = asTrimmedString(
      String.isBlank(managerPhoneField) ? null : row.get(managerPhoneField)
    );
    mapped.managerEmail = asTrimmedString(
      String.isBlank(managerEmailField) ? null : row.get(managerEmailField)
    );
    return mapped;
  }

  private static PropfocusConfigService.Config resolveConfig() {
    // Unpackaged class in a subscriber org: prefer managed-package CMDT mappings.
    if (
      !PropFocusSiteVisitLinkService.class.getName().contains('.') &&
      Schema.getGlobalDescribe().containsKey('PropfocusAI__Propfocus_Config__mdt')
    ) {
      List<SObject> rows = Database.query(
        'SELECT PropfocusAI__Site_Visit_Object__c, PropfocusAI__Site_Visit_Project_Field__c, ' +
          'PropfocusAI__Site_Visit_Datetime_Field__c, PropfocusAI__Lead_Lookup_Field__c, ' +
          'PropfocusAI__Opportunity_Lookup_Field__c, PropfocusAI__Site_Visit_Manager_Name_Field__c, ' +
          'PropfocusAI__Site_Visit_Manager_Phone_Field__c, PropfocusAI__Site_Visit_Manager_Email_Field__c, ' +
          'PropfocusAI__Buyer_Id_Field__c, PropfocusAI__Buyer_Name_Field__c, ' +
          'PropfocusAI__Project_Field__c, PropfocusAI__Lead_Status_Field__c ' +
          'FROM PropfocusAI__Propfocus_Config__mdt WHERE DeveloperName = \'Default\' ' +
          'AND PropfocusAI__Site_Visit_Project_Field__c != null LIMIT 1'
      );
      if (!rows.isEmpty()) {
        SObject row = rows[0];
        return PropfocusConfigService.fromConfigMap(
          new Map<String, Object>{
            'siteVisitObject' => row.get('PropfocusAI__Site_Visit_Object__c'),
            'siteVisitProjectField' => row.get(
              'PropfocusAI__Site_Visit_Project_Field__c'
            ),
            'siteVisitDatetimeField' => row.get(
              'PropfocusAI__Site_Visit_Datetime_Field__c'
            ),
            'siteVisitLeadLookupField' => row.get(
              'PropfocusAI__Lead_Lookup_Field__c'
            ),
            'siteVisitOpportunityLookupField' => row.get(
              'PropfocusAI__Opportunity_Lookup_Field__c'
            ),
            'siteVisitManagerNameField' => row.get(
              'PropfocusAI__Site_Visit_Manager_Name_Field__c'
            ),
            'siteVisitManagerPhoneField' => row.get(
              'PropfocusAI__Site_Visit_Manager_Phone_Field__c'
            ),
            'siteVisitManagerEmailField' => row.get(
              'PropfocusAI__Site_Visit_Manager_Email_Field__c'
            ),
            'buyerIdField' => row.get('PropfocusAI__Buyer_Id_Field__c'),
            'buyerNameField' => row.get('PropfocusAI__Buyer_Name_Field__c'),
            'projectField' => row.get('PropfocusAI__Project_Field__c'),
            'leadStatusField' => row.get('PropfocusAI__Lead_Status_Field__c')
          }
        );
      }
    }
    return PropfocusConfigService.getConfig();
  }

  @TestVisible
  private static Map<String, Object> buildSiteVisitContext(MappedSiteVisit mapped) {
    String userTimeZoneId = UserInfo.getTimeZone().getID();
    Datetime visitAt = mapped.visitDateTime == null
      ? System.now()
      : mapped.visitDateTime;
    Map<String, Object> context = new Map<String, Object>{
      'projectName' => mapped.projectName,
      'visitDate' => visitAt.format('yyyy-MM-dd', userTimeZoneId),
      'visitTime' => visitAt.format('HH:mm', userTimeZoneId),
      'visitDateTime' => visitAt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')
    };
    if (
      !String.isBlank(mapped.managerName) ||
      !String.isBlank(mapped.managerPhone) ||
      !String.isBlank(mapped.managerEmail)
    ) {
      Map<String, Object> manager = new Map<String, Object>();
      if (!String.isBlank(mapped.managerName)) {
        manager.put('name', mapped.managerName);
      }
      if (!String.isBlank(mapped.managerPhone)) {
        manager.put('phone', mapped.managerPhone);
      }
      if (!String.isBlank(mapped.managerEmail)) {
        manager.put('email', mapped.managerEmail);
      }
      context.put('siteVisitManager', manager);
    }
    return context;
  }

  private static Id resolveParentRecordId(
    SObject row,
    String leadLookupField,
    String opportunityLookupField
  ) {
    // Prefer Opportunity when both are set (common after Lead conversion).
    if (!String.isBlank(opportunityLookupField)) {
      Id opportunityId = (Id) row.get(opportunityLookupField);
      if (opportunityId != null) {
        return opportunityId;
      }
    }
    if (!String.isBlank(leadLookupField)) {
      return (Id) row.get(leadLookupField);
    }
    return null;
  }

  private static void addSelectField(
    List<String> selectParts,
    String fieldApiName,
    Map<String, Schema.SObjectField> fieldsByApiName
  ) {
    if (String.isBlank(fieldApiName) || !fieldsByApiName.containsKey(fieldApiName)) {
      return;
    }
    selectParts.add(fieldApiName);
    Schema.DescribeFieldResult describe = fieldsByApiName.get(fieldApiName)
      .getDescribe();
    if (
      describe.getType() == Schema.DisplayType.REFERENCE &&
      !String.isBlank(describe.getRelationshipName())
    ) {
      selectParts.add(describe.getRelationshipName() + '.Name');
    }
  }

  private static String resolveDisplayValue(
    SObject row,
    String fieldApiName,
    Map<String, Schema.SObjectField> fieldsByApiName
  ) {
    if (String.isBlank(fieldApiName) || row == null) {
      return null;
    }
    Schema.SObjectField fieldToken = fieldsByApiName.get(fieldApiName);
    if (fieldToken == null) {
      return null;
    }
    Schema.DescribeFieldResult describe = fieldToken.getDescribe();
    if (describe.getType() == Schema.DisplayType.REFERENCE) {
      String relationshipName = describe.getRelationshipName();
      if (!String.isBlank(relationshipName)) {
        SObject related = row.getSObject(relationshipName);
        if (related != null) {
          String relatedName = asTrimmedString(related.get('Name'));
          if (!String.isBlank(relatedName)) {
            return relatedName;
          }
        }
      }
      return null;
    }
    return asTrimmedString(row.get(fieldApiName));
  }

  private static String requireConfiguredApiName(
    String value,
    String configFieldApiName
  ) {
    if (String.isBlank(value) || !isSafeApiName(value)) {
      PropFocusServiceException.throwUserFacing(
        'Invalid API name configured for ' + configFieldApiName
      );
    }
    return value.trim();
  }

  private static String requireConfiguredField(
    String value,
    String configFieldApiName,
    Map<String, Schema.SObjectField> fieldsByApiName
  ) {
    String fieldApiName = requireConfiguredApiName(value, configFieldApiName);
    if (!fieldsByApiName.containsKey(fieldApiName)) {
      PropFocusServiceException.throwUserFacing(
        'Configured site visit field not found: ' + fieldApiName
      );
    }
    return fieldApiName;
  }

  private static String optionalConfiguredField(
    String value,
    String configFieldApiName,
    Map<String, Schema.SObjectField> fieldsByApiName
  ) {
    if (String.isBlank(value)) {
      return null;
    }
    if (!isSafeApiName(value)) {
      PropFocusServiceException.throwUserFacing(
        'Invalid API name configured for ' + configFieldApiName
      );
    }
    String fieldApiName = value.trim();
    return fieldsByApiName.containsKey(fieldApiName) ? fieldApiName : null;
  }

  private static Boolean isSafeApiName(String value) {
    // Allows standard, custom (__c), and namespaced (ns__Field__c) API names.
    return Pattern.matches('^[A-Za-z][A-Za-z0-9_]*(__[A-Za-z0-9_]+)*(__c)?$', value);
  }

  private static String asTrimmedString(Object value) {
    if (value == null) {
      return null;
    }
    String text = String.valueOf(value).trim();
    return String.isBlank(text) ? null : text;
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
    String text = asTrimmedString(value);
    if (String.isBlank(text)) {
      return null;
    }
    try {
      if (text.endsWith('Z')) {
        return (Datetime) JSON.deserialize('"' + text + '"', Datetime.class);
      }
      return Datetime.valueOf(text.replace('T', ' ').left(19));
    } catch (Exception e) {
      return null;
    }
  }

  private class GenerateSiteVisitLinkQueueable implements Queueable, Database.AllowsCallouts {
    private final Set<Id> siteVisitIds;

    public GenerateSiteVisitLinkQueueable(Set<Id> siteVisitIds) {
      this.siteVisitIds = siteVisitIds == null
        ? new Set<Id>()
        : new Set<Id>(siteVisitIds);
    }

    public void execute(QueueableContext context) {
      for (Id siteVisitId : siteVisitIds) {
        try {
          PropFocusSiteVisitLinkService.generateFromSiteVisitRecord(siteVisitId);
        } catch (Exception ex) {
          // Do not fail the whole job; Save already succeeded.
          System.debug(
            LoggingLevel.ERROR,
            'PropFocusSiteVisitLinkService failed for ' +
              siteVisitId +
              ': ' +
              ex.getMessage()
          );
        }
      }
    }
  }
}
