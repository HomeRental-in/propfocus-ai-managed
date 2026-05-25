public class PropfocusLeadTrackingService {
    public static PropfocusLeadTrackingWrapper getLeadForTracking(Id leadId) {
        if (leadId == null) {
            throw new IllegalArgumentException('Lead Id is required');
        }
        PropfocusLeadTrackingWrapper w = new PropfocusLeadTrackingWrapper();
        w.lead = [
            SELECT Id, CreatedDate, LastModifiedDate, Status, Description
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];
        w.history = [
            SELECT Field, OldValue, NewValue, CreatedDate
            FROM LeadHistory
            WHERE LeadId = :leadId
            ORDER BY CreatedDate ASC
        ];
        w.activities = [
            SELECT Subject, Status, ActivityDate, Description, CreatedDate
            FROM Task
            WHERE WhatId = :leadId
            ORDER BY ActivityDate DESC
        ];
        w.siteVisits = PropFocusLeadService.queryLatestSiteVisitsForTracking(leadId, 50);
        return w;
    }

    public static Id notifyLeadOwner(String leadIdStr, Map<String, Object> notif) {
        if (String.isBlank(leadIdStr)) {
            throw new IllegalArgumentException('Lead Id is required');
        }

        Id leadId;
        try {
            leadId = (Id) leadIdStr;
        } catch (Exception e) {
            throw new IllegalArgumentException('Invalid Lead Id');
        }

        String title = (String) notif.get('title');
        String message = (String) notif.get('message');

        if (String.isBlank(title) || String.isBlank(message)) {
            throw new IllegalArgumentException(
                'Notification title and message are required'
            );
        }

        Lead l = [
            SELECT Id, OwnerId
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];

        String notificationTypeDeveloperName =
            PropfocusConfigService.requireNotificationTypeDeveloperName();

        List<CustomNotificationType> notificationTypes = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = :notificationTypeDeveloperName
            LIMIT 1
        ];

        if (notificationTypes.isEmpty()) {
            if (Test.isRunningTest()) {
                return l.OwnerId;
            }
            throw new PropFocusServiceException(
                'Custom notification type ' + notificationTypeDeveloperName + ' is not configured'
            );
        }

        CustomNotificationType cnt = notificationTypes[0];
        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        notification.setTitle(title);
        notification.setBody(message);
        notification.setNotificationTypeId(cnt.Id);
        notification.setTargetId(l.Id);

        Set<String> recipients = new Set<String>{ l.OwnerId };

        try {
            notification.send(recipients);
        } catch (Exception e) {
            throw new PropFocusServiceException(
                'Failed to send notification : ' + e.getMessage()
            );
        }

        return l.OwnerId;
    }
}
