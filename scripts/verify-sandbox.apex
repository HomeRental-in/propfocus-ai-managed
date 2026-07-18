// Verify Propfocus sandbox config and components
PropfocusConfigService.Config cfg = PropfocusConfigService.getUiConfiguration();
System.debug('ORG_ID=' + cfg.organizationId);
System.debug('BUYER_ID_FIELD=' + cfg.buyerIdField);
System.debug('API_NAMED_CREDENTIAL=' + cfg.apiNamedCredential);
System.debug('EMBED_URL=' + cfg.embedBaseUrl);
System.debug('INBOUND=' + PropfocusConfigService.getInboundEndpoint());

List<PermissionSet> ps = [
    SELECT Name FROM PermissionSet
    WHERE Name IN ('Propfocus_User', 'Propfocus_AI_Admin', 'Propfocus_Integration')
];
System.debug('PERMSETS=' + ps.size());

List<ApexClass> classes = [
    SELECT Name FROM ApexClass WHERE Name LIKE 'Propfocus%' OR Name LIKE 'PropFocus%'
];
System.debug('APEX_CLASSES=' + classes.size());
