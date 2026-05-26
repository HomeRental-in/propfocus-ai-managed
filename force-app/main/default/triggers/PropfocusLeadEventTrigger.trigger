trigger PropfocusLeadEventTrigger on Lead (after insert, after update) {
    PropfocusLeadEventService.handleLeadChanges(Trigger.new, Trigger.oldMap);
}
