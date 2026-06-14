@RestResource(urlMapping='/propfocus/events/*')
global class PropfocusInboundService {
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
    public Boolean lead_updated;
    public Integer call_logs_created;
    public Integer history_rows_created;
    public Boolean site_visit_synced;

    public InboundEventResponse(
      Boolean success,
      String message,
      String leadId,
      PropfocusInboundWritebackService.WritebackResult writeback
    ) {
      this.success = success;
      this.message = message;
      this.lead_id = leadId;
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

      String buyerIdFieldApiName;
      try {
        buyerIdFieldApiName = PropfocusConfigService.requireBuyerIdField();
      } catch (AuraHandledException e) {
        respond(res, 500, false, 'Buyer ID field not configured', null, null);
        return;
      }
      if (
        !Pattern.matches('^[A-Za-z][A-Za-z0-9_]*(__c)?$', buyerIdFieldApiName)
      ) {
        respond(
          res,
          500,
          false,
          'Invalid buyer ID field configuration',
          null,
          null
        );
        return;
      }

      Lead matchedLead = resolveLead(payload.buyer_id, buyerIdFieldApiName);

      if (matchedLead == null) {
        respond(
          res,
          404,
          false,
          'No Lead found for buyer_id: ' + payload.buyer_id,
          null,
          null
        );
        return;
      }

      String leadId = matchedLead.Id;
      PropfocusInboundWritebackService.WritebackResult writebackResult = null;

      if (hasWriteback) {
        writebackResult = PropfocusInboundWritebackService.applyWriteback(
          leadId,
          payloadRoot
        );
      }

      if (!String.isBlank(payload.title) && !String.isBlank(payload.message)) {
        Map<String, Object> notif = new Map<String, Object>{
          'title' => payload.title,
          'message' => payload.message,
          'type' => payload.event_type
        };
        PropfocusLeadTrackingService.notifyLeadOwner(leadId, notif);
      }

      respond(res, 200, true, 'Event processed', leadId, writebackResult);
    } catch (Exception e) {
      respond(res, 500, false, e.getMessage(), null, null);
    }
  }

  @TestVisible
  private static Lead resolveLead(String buyerId, String buyerIdFieldApiName) {
    if (String.isBlank(buyerId)) {
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
  private static Boolean looksLikeSalesforceLeadId(String value) {
    return Pattern.matches('^00Q[a-zA-Z0-9]{12}(?:[a-zA-Z0-9]{3})?$', value);
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

  private static String asString(Object value) {
    return value == null ? null : String.valueOf(value);
  }

  private static void respond(
    RestResponse res,
    Integer statusCode,
    Boolean success,
    String message,
    String leadId,
    PropfocusInboundWritebackService.WritebackResult writeback
  ) {
    res.statusCode = statusCode;
    res.responseBody = Blob.valueOf(
      JSON.serialize(
        new InboundEventResponse(success, message, leadId, writeback)
      )
    );
  }
}
