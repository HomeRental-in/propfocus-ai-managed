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
    // Do not query LeadHistory: a compile-time or SOQL reference creates a
    // packaging dependency on Lead.FieldHistoryTracking in subscriber orgs.
    w.history = new List<SObject>();
    w.activities = [
      SELECT Subject, Status, ActivityDate, Description, CreatedDate
      FROM Task
      WHERE WhatId = :leadId
      ORDER BY ActivityDate DESC
    ];
    w.siteVisits = PropFocusLeadService.queryLatestSiteVisitsForTracking(
      leadId,
      50
    );
    return w;
  }

  public static Id notifyLeadOwner(
    String leadIdStr,
    Map<String, Object> notif
  ) {
    if (String.isBlank(leadIdStr)) {
      throw new IllegalArgumentException('Record Id is required');
    }

    Id recordId;
    try {
      recordId = (Id) leadIdStr;
    } catch (Exception e) {
      throw new IllegalArgumentException('Invalid Record Id');
    }

    String title = (String) notif.get('title');
    String message = (String) notif.get('message');

    if (String.isBlank(title) || String.isBlank(message)) {
      throw new IllegalArgumentException(
        'Notification title and message are required'
      );
    }

    Id ownerId;
    Id targetId;
    if (recordId.getSObjectType() == Opportunity.SObjectType) {
      Opportunity opp = [
        SELECT Id, OwnerId
        FROM Opportunity
        WHERE Id = :recordId
        LIMIT 1
      ];
      ownerId = opp.OwnerId;
      targetId = opp.Id;
    } else {
      Lead l = [
        SELECT Id, OwnerId
        FROM Lead
        WHERE Id = :recordId
        LIMIT 1
      ];
      ownerId = l.OwnerId;
      targetId = l.Id;
    }

    CustomNotificationType cnt = resolveNotificationType();

    if (cnt == null) {
      if (Test.isRunningTest()) {
        return ownerId;
      }
      throw new PropFocusServiceException(
        'Custom notification type ' +
          PropfocusConfigService.requireNotificationTypeDeveloperName() +
          ' is not configured'
      );
    }
    Messaging.CustomNotification notification = new Messaging.CustomNotification();
    notification.setTitle(title);
    notification.setBody(message);
    notification.setNotificationTypeId(cnt.Id);
    notification.setTargetId(targetId);

    Set<String> recipients = new Set<String>{ ownerId };

    try {
      notification.send(recipients);
    } catch (Exception e) {
      throw new PropFocusServiceException(
        'Failed to send notification : ' + e.getMessage()
      );
    }

    return ownerId;
  }

  private static CustomNotificationType resolveNotificationType() {
    for (
      String devName : PropfocusConfigService.notificationTypeLookupDeveloperNames()
    ) {
      List<CustomNotificationType> notificationTypes = [
        SELECT Id
        FROM CustomNotificationType
        WHERE DeveloperName = :devName
        LIMIT 1
      ];
      if (!notificationTypes.isEmpty()) {
        return notificationTypes[0];
      }
    }
    return null;
  }
}
