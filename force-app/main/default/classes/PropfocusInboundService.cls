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

        public InboundEventResponse(Boolean success, String message, String leadId) {
            this.success = success;
            this.message = message;
            this.lead_id = leadId;
        }
    }

    @HttpPost
    global static void handleEvent() {
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        try {
            String body = RestContext.request.requestBody?.toString();
            if (String.isBlank(body)) {
                respond(res, 400, false, 'Request body is required', null);
                return;
            }

            InboundEventPayload payload;
            try {
                payload = (InboundEventPayload) JSON.deserialize(body, InboundEventPayload.class);
            } catch (Exception e) {
                respond(res, 400, false, 'Invalid JSON payload', null);
                return;
            }

            if (String.isBlank(payload.buyer_id)) {
                respond(res, 400, false, 'buyer_id is required', null);
                return;
            }
            if (String.isBlank(payload.event_type)) {
                respond(res, 400, false, 'event_type is required', null);
                return;
            }
            if (String.isBlank(payload.title) || String.isBlank(payload.message)) {
                respond(res, 400, false, 'title and message are required', null);
                return;
            }

            // Validate the organization_id matches this org's configured value
            // Prevents cross-tenant event injection
            String configuredOrgId;
            try {
                configuredOrgId = PropfocusConfigService.requireOrganizationId();
            } catch (AuraHandledException e) {
                respond(res, 500, false, 'PropFocus not configured on this org', null);
                return;
            }
            if (!configuredOrgId.equals(payload.organization_id)) {
                respond(res, 403, false, 'Organization ID mismatch', null);
                return;
            }

            // Resolve the buyer ID field from config
            String buyerIdFieldApiName;
            try {
                buyerIdFieldApiName = PropfocusConfigService.requireBuyerIdField();
            } catch (AuraHandledException e) {
                respond(res, 500, false, 'Buyer ID field not configured', null);
                return;
            }
            if (!Pattern.matches('^[A-Za-z][A-Za-z0-9_]*(__c)?$', buyerIdFieldApiName)) {
                respond(res, 500, false, 'Invalid buyer ID field configuration', null);
                return;
            }

            // Find Lead by buyer ID — unconverted only
            String buyerId = payload.buyer_id;
            String soql =
                'SELECT Id FROM Lead' +
                ' WHERE ' + buyerIdFieldApiName + ' = :buyerId' +
                ' AND IsConverted = false' +
                ' LIMIT 1';
            List<Lead> leads = Database.query(soql);

            if (leads.isEmpty()) {
                respond(res, 404, false, 'No Lead found for buyer_id: ' + payload.buyer_id, null);
                return;
            }

            String leadId = leads[0].Id;

            // Send notification to Lead owner
            Map<String, Object> notif = new Map<String, Object>{
                'title'   => payload.title,
                'message' => payload.message,
                'type'    => payload.event_type
            };
            PropfocusLeadTrackingService.notifyLeadOwner(leadId, notif);

            respond(res, 200, true, 'Event processed', leadId);

        } catch (Exception e) {
            respond(res, 500, false, e.getMessage(), null);
        }
    }

    private static void respond(
        RestResponse res,
        Integer statusCode,
        Boolean success,
        String message,
        String leadId
    ) {
        res.statusCode = statusCode;
        res.responseBody = Blob.valueOf(
            JSON.serialize(new InboundEventResponse(success, message, leadId))
        );
    }
}
