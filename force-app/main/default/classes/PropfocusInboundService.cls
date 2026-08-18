@RestResource(urlMapping='/propfocus/events/*')
// without sharing: inbound integration endpoint must resolve and write back to
// the matched Lead/Opportunity regardless of the integration user's record
// sharing. Access is still gated by the connected app / permission set.
global without sharing class PropfocusInboundService {
  global class InboundEventPayload {
    public String event_type;
    public String buyer_id;
    public String organization_id;
    public String title;
    public String message;
  }

  global class InboundEventResponse {
    public Boolean success;
    public String message;
    public String lead_id;
    public String opportunity_id;
    public String record_id;
    public String record_type;
    public Boolean lead_updated;
    public Integer call_logs_created;
    public Integer history_rows_created;
    public Boolean site_visit_synced;

    public InboundEventResponse(
      Boolean success,
      String message,
      Id recordId,
      PropfocusInboundWritebackService.WritebackResult writeback
    ) {
      this.success = success;
      this.message = message;
      if (recordId != null) {
        this.record_id = String.valueOf(recordId);
        if (recordId.getSObjectType() == Opportunity.SObjectType) {
          this.opportunity_id = String.valueOf(recordId);
          this.record_type = 'Opportunity';
        } else {
          this.lead_id = String.valueOf(recordId);
          this.record_type = 'Lead';
        }
      }
      if (writeback != null) {
        this.lead_updated = writeback.leadUpdated;
        this.call_logs_created = writeback.callLogsCreated;
        this.history_rows_created = writeback.historyRowsCreated;
        this.site_visit_synced = writeback.siteVisitSynced;
      }
    }
  }

  @HttpPost
  global static void handleEvent() {
    RestResponse res = RestContext.response;
    res.addHeader('Content-Type', 'application/json');

    try {
      String body = RestContext.request.requestBody?.toString();
      if (String.isBlank(body)) {
        respond(res, 400, false, 'Request body is required', null, null);
        return;
      }

      Map<String, Object> payloadRoot;
      try {
        payloadRoot = (Map<String, Object>) JSON.deserializeUntyped(body);
      } catch (Exception e) {
        respond(res, 400, false, 'Invalid JSON payload', null, null);
        return;
      }

      InboundEventPayload payload = parseCorePayload(payloadRoot);
      Boolean hasWriteback = PropfocusInboundWritebackService.hasWritebackPayload(
        payloadRoot
      );

      if (String.isBlank(payload.buyer_id)) {
        respond(res, 400, false, 'buyer_id is required', null, null);
        return;
      }
      if (String.isBlank(payload.event_type)) {
        respond(res, 400, false, 'event_type is required', null, null);
        return;
      }
      if (
        !hasWriteback &&
        (String.isBlank(payload.title) || String.isBlank(payload.message))
      ) {
        respond(
          res,
          400,
          false,
          'title and message are required unless write-back data is included',
          null,
          null
        );
        return;
      }

      String configuredOrgId;
      try {
        configuredOrgId = PropfocusConfigService.requireOrganizationId();
      } catch (AuraHandledException e) {
        respond(
          res,
          500,
          false,
          'PropFocus not configured on this org',
          null,
          null
        );
        return;
      }
      if (!configuredOrgId.equals(payload.organization_id)) {
        respond(res, 403, false, 'Organization ID mismatch', null, null);
        return;
      }

      Id matchedRecordId = resolveParentRecord(payload.buyer_id, payloadRoot);

      if (matchedRecordId == null) {
        respond(
          res,
          404,
          false,
          'No Lead or Opportunity found for buyer_id: ' + payload.buyer_id,
          null,
          null
        );
        return;
      }

      PropfocusInboundWritebackService.WritebackResult writebackResult = null;

      if (hasWriteback) {
        writebackResult = PropfocusInboundWritebackService.applyWriteback(
          matchedRecordId,
          payloadRoot
        );
      }

      if (!String.isBlank(payload.title) && !String.isBlank(payload.message)) {
        Map<String, Object> notif = new Map<String, Object>{
          'title' => payload.title,
          'message' => payload.message,
          'type' => payload.event_type
        };
        PropfocusLeadTrackingService.notifyLeadOwner(
          String.valueOf(matchedRecordId),
          notif
        );
      }

      // Flip microsite/post-visit history to Engaged when buyer activity indicates
      // engagement and write-back did not already handle an engagement section.
      if (
        writebackResult == null ||
        writebackResult.engagementSynced != true
      ) {
        PropfocusInboundWritebackService.syncEngagementFromActivity(
          matchedRecordId,
          payload.event_type,
          payload.title,
          payload.message
        );
      }

      respond(res, 200, true, 'Event processed', matchedRecordId, writebackResult);
    } catch (Exception e) {
      respond(res, 500, false, e.getMessage(), null, null);
    }
  }

  @TestVisible
  private static Id resolveParentRecord(
    String buyerId,
    Map<String, Object> payloadRoot
  ) {
    Id explicitId = extractExplicitSalesforceId(payloadRoot);
    if (explicitId != null) {
      return explicitId;
    }

    Lead matchedLead = resolveLead(buyerId);
    if (matchedLead != null) {
      return matchedLead.Id;
    }
    Opportunity matchedOpp = resolveOpportunity(buyerId);
    return matchedOpp == null ? null : matchedOpp.Id;
  }

  private static Id extractExplicitSalesforceId(Map<String, Object> payloadRoot) {
    if (payloadRoot == null) {
      return null;
    }
    Map<String, Object> leadData = asMap(payloadRoot.get('lead_data'));
    String opportunityId = firstNonBlank(
      payloadRoot,
      leadData,
      new List<String>{
        'salesforce_opportunity_id',
        'salesforceOpportunityId'
      }
    );
    if (!String.isBlank(opportunityId) && looksLikeSalesforceOpportunityId(opportunityId)) {
      List<Opportunity> rows = [
        SELECT Id
        FROM Opportunity
        WHERE Id = :opportunityId
        LIMIT 1
      ];
      if (!rows.isEmpty()) {
        return rows[0].Id;
      }
    }

    String leadId = firstNonBlank(
      payloadRoot,
      leadData,
      new List<String>{ 'salesforce_lead_id', 'salesforceLeadId' }
    );
    if (!String.isBlank(leadId) && looksLikeSalesforceLeadId(leadId)) {
      List<Lead> rows = [
        SELECT Id
        FROM Lead
        WHERE Id = :leadId AND IsConverted = FALSE
        LIMIT 1
      ];
      if (!rows.isEmpty()) {
        return rows[0].Id;
      }
    }
    return null;
  }

  @TestVisible
  private static Lead resolveLead(String buyerId) {
    if (String.isBlank(buyerId)) {
      return null;
    }

    String buyerIdFieldApiName;
    try {
      buyerIdFieldApiName = PropfocusConfigService.requireBuyerIdField();
    } catch (AuraHandledException e) {
      return null;
    }
    if (!Pattern.matches('^[A-Za-z][A-Za-z0-9_]*(__c)?$', buyerIdFieldApiName)) {
      return null;
    }

    if (looksLikeSalesforceLeadId(buyerId)) {
      List<Lead> byId = [
        SELECT Id
        FROM Lead
        WHERE Id = :buyerId AND IsConverted = FALSE
        LIMIT 1
      ];
      if (!byId.isEmpty()) {
        return byId[0];
      }
    }

    String soql =
      'SELECT Id FROM Lead' +
      ' WHERE ' +
      buyerIdFieldApiName +
      ' = :buyerId' +
      ' AND IsConverted = false' +
      ' LIMIT 1';
    List<Lead> leads = Database.query(soql);
    return leads.isEmpty() ? null : leads[0];
  }

  @TestVisible
  private static Opportunity resolveOpportunity(String buyerId) {
    if (String.isBlank(buyerId)) {
      return null;
    }

    String buyerIdFieldApiName;
    try {
      buyerIdFieldApiName = PropfocusConfigService.requireOpportunityBuyerIdField();
    } catch (AuraHandledException e) {
      return null;
    }
    if (!Pattern.matches('^[A-Za-z][A-Za-z0-9_]*(__c)?$', buyerIdFieldApiName)) {
      return null;
    }

    if (looksLikeSalesforceOpportunityId(buyerId)) {
      List<Opportunity> byId = [
        SELECT Id
        FROM Opportunity
        WHERE Id = :buyerId
        LIMIT 1
      ];
      if (!byId.isEmpty()) {
        return byId[0];
      }
    }

    String soql =
      'SELECT Id FROM Opportunity' +
      ' WHERE ' +
      buyerIdFieldApiName +
      ' = :buyerId' +
      ' LIMIT 1';
    try {
      List<Opportunity> rows = Database.query(soql);
      return rows.isEmpty() ? null : rows[0];
    } catch (QueryException e) {
      // Misconfigured buyer-id fields (e.g. long text) are not filterable.
      return null;
    }
  }

  @TestVisible
  private static Boolean looksLikeSalesforceLeadId(String value) {
    return Pattern.matches('^00Q[a-zA-Z0-9]{12}(?:[a-zA-Z0-9]{3})?$', value);
  }

  @TestVisible
  private static Boolean looksLikeSalesforceOpportunityId(String value) {
    return Pattern.matches('^006[a-zA-Z0-9]{12}(?:[a-zA-Z0-9]{3})?$', value);
  }

  private static InboundEventPayload parseCorePayload(
    Map<String, Object> payloadRoot
  ) {
    InboundEventPayload payload = new InboundEventPayload();
    payload.event_type = asString(payloadRoot.get('event_type'));
    payload.buyer_id = asString(payloadRoot.get('buyer_id'));
    payload.organization_id = asString(payloadRoot.get('organization_id'));
    payload.title = asString(payloadRoot.get('title'));
    payload.message = asString(payloadRoot.get('message'));
    return payload;
  }

  private static String firstNonBlank(
    Map<String, Object> root,
    Map<String, Object> nested,
    List<String> keys
  ) {
    for (String key : keys) {
      String fromRoot = asString(root == null ? null : root.get(key));
      if (!String.isBlank(fromRoot)) {
        return fromRoot;
      }
      String fromNested = asString(nested == null ? null : nested.get(key));
      if (!String.isBlank(fromNested)) {
        return fromNested;
      }
    }
    return null;
  }

  private static Map<String, Object> asMap(Object value) {
    return value instanceof Map<String, Object>
      ? (Map<String, Object>) value
      : null;
  }

  private static String asString(Object value) {
    return value == null ? null : String.valueOf(value);
  }

  private static void respond(
    RestResponse res,
    Integer statusCode,
    Boolean success,
    String message,
    Id recordId,
    PropfocusInboundWritebackService.WritebackResult writeback
  ) {
    res.statusCode = statusCode;
    res.responseBody = Blob.valueOf(
      JSON.serialize(
        new InboundEventResponse(success, message, recordId, writeback)
      )
    );
  }
}
