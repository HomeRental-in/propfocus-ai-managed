Id leadId = '00QdL00000bmlulUAA';
String url = PropfocusAI.PropFocusLeadService.generateMicrositeLink(
    leadId,
    'lastname',
    new List<String>{ 'All Projects' },
    'new',
    ''
);
PropfocusAI.PropFocusLeadService.BuyerInsightsEmbedContext ctx =
    PropfocusAI.PropFocusLeadService.getBuyerInsightsEmbedContext(leadId);
System.debug('MICROSITE_URL=' + url);
System.debug('EMBED_URL=' + ctx.embedUrl);
System.debug('EMBED_KEY=' + ctx.embedKey);
System.debug('USES_LEAD_ID=' + ctx.usesSalesforceLeadId);
