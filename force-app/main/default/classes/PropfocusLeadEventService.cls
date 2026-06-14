public class PropfocusLeadEventService {
  // Fields watched for changes. Read from CMDT so customer field mappings
  // are respected. Evaluated against Trigger.oldMap on every Lead update.
  @TestVisible
  private static final Set<String> ALWAYS_WATCHED = new Set<String>{
    'Status',
    'IsConverted'
  };

  public static void handleLeadChanges(
    List<Lead> newLeads,
    Map<Id, Lead> oldMap
  ) {
    PropfocusConfigService.Config cfg;
    String organizationId;

    try {
      cfg = PropfocusConfigService.getConfig();
      organizationId = PropfocusConfigService.requireOrganizationId();
    } catch (Exception e) {
      // PropFocus not configured on this org — skip silently
      return;
    }

    // Build the full set of watched field API names from config + always-watched
    Set<String> watchedFields = new Set<String>(ALWAYS_WATCHED);
    if (String.isNotBlank(cfg.leadStatusField))
      watchedFields.add(cfg.leadStatusField);
    if (String.isNotBlank(cfg.projectField))
      watchedFields.add(cfg.projectField);
    if (String.isNotBlank(cfg.buyerIdField))
      watchedFields.add(cfg.buyerIdField);
    if (String.isNotBlank(cfg.buyerNameField))
      watchedFields.add(cfg.buyerNameField);

    if (String.isBlank(cfg.buyerIdField)) {
      return;
    }
    if (
      !Schema.SObjectType.Lead.fields.getMap().containsKey(cfg.buyerIdField)
    ) {
      return;
    }

    String buyerIdField = cfg.buyerIdField;

    List<Propfocus_Lead_Event__e> events = new List<Propfocus_Lead_Event__e>();
    Boolean isInsert = (oldMap == null || oldMap.isEmpty());

    for (Lead ld : newLeads) {
      Lead old = isInsert ? null : oldMap.get(ld.Id);
      String buyerId = String.valueOf(ld.get(buyerIdField));

      if (isInsert) {
        // New Lead inserted — fire a single lead_created event
        events.add(
          buildEvent(
            ld.Id,
            buyerId,
            organizationId,
            'lead_created',
            null,
            null,
            null
          )
        );
        continue;
      }

      // Update — check each watched field for changes
      for (String fieldName : watchedFields) {
        if (!Schema.SObjectType.Lead.fields.getMap().containsKey(fieldName)) {
          continue;
        }
        Object oldVal = getFieldValueSafely(old, fieldName);
        Object newVal = getFieldValueSafely(ld, fieldName);

        if (oldVal == newVal)
          continue;
        if (oldVal == null && newVal == null)
          continue;
        if (oldVal != null && oldVal.equals(newVal))
          continue;

        String eventType = resolveEventType(fieldName, cfg);

        events.add(
          buildEvent(
            ld.Id,
            buyerId,
            organizationId,
            eventType,
            fieldName,
            oldVal != null ? String.valueOf(oldVal) : null,
            newVal != null ? String.valueOf(newVal) : null
          )
        );
      }
    }

    if (!events.isEmpty()) {
      List<Database.SaveResult> results = EventBus.publish(events);
      // Log failures — do not throw; trigger must not block Lead saves
      for (Database.SaveResult sr : results) {
        if (!sr.isSuccess()) {
          System.debug(
            LoggingLevel.ERROR,
            'PropfocusLeadEventService: failed to publish event — ' +
            sr.getErrors()[0].getMessage()
          );
        }
      }
    }
  }

  private static String resolveEventType(
    String fieldName,
    PropfocusConfigService.Config cfg
  ) {
    if (fieldName == 'IsConverted')
      return 'lead_converted';
    if (fieldName == 'Status' || fieldName == cfg.leadStatusField)
      return 'status_changed';
    if (fieldName == cfg.projectField)
      return 'project_changed';
    if (fieldName == cfg.buyerIdField)
      return 'buyer_id_changed';
    if (fieldName == cfg.buyerNameField)
      return 'buyer_name_changed';
    return 'field_changed';
  }

  private static Object getFieldValueSafely(SObject row, String fieldName) {
    if (row == null || String.isBlank(fieldName)) {
      return null;
    }
    try {
      return row.get(fieldName);
    } catch (SObjectException e) {
      return null;
    }
  }

  private static Propfocus_Lead_Event__e buildEvent(
    Id leadId,
    String buyerId,
    String organizationId,
    String eventType,
    String fieldName,
    String oldValue,
    String newValue
  ) {
    Propfocus_Lead_Event__e evt = new Propfocus_Lead_Event__e();
    evt.Lead_Id__c = String.valueOf(leadId);
    evt.Buyer_Id__c = buyerId;
    evt.Organization_Id__c = organizationId;
    evt.Event_Type__c = eventType;
    evt.Field_Name__c = fieldName;
    evt.Old_Value__c = oldValue;
    evt.New_Value__c = newValue;
    evt.Occurred_At__c = System.now();
    return evt;
  }
}
