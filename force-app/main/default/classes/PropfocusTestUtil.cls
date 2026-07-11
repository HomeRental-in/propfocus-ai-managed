@IsTest
public class PropfocusTestUtil {
  public static Lead createLead(String label) {
    String token = label.replace(' ', '-').toLowerCase();
    Lead ld = new Lead(
      LastName = label,
      Company = 'Test Co',
      Email = token + '@example.com',
      MobilePhone = '9876543210',
      Status = 'Open - Not Contacted'
    );

    String buyerField = PropfocusConfigService.getConfig().buyerIdField;
    if (
      !String.isBlank(buyerField) &&
      buyerField != 'Email' &&
      Schema.SObjectType.Lead.fields.getMap().containsKey(buyerField)
    ) {
      Schema.DescribeFieldResult buyerFieldDescribe = Schema.SObjectType.Lead.fields.getMap()
        .get(buyerField)
        .getDescribe();
      if (
        buyerFieldDescribe.isCreateable() && !buyerFieldDescribe.isAutoNumber()
      ) {
        ld.put(
          buyerField,
          'BUYER-' + String.valueOf(Math.abs(Crypto.getRandomInteger()))
        );
      }
    }

    insert ld;
    return reloadLead(ld.Id);
  }

  public static Lead reloadLead(Id leadId) {
    String buyerField = PropfocusConfigService.getConfig().buyerIdField;
    String fields = 'Id, Email, OwnerId, LastName, Company, Status, Propfocus_Buyer_Insights_Available__c, Propfocus_Link__c, Propfocus_Site_Visit__c';
    if (
      !String.isBlank(buyerField) &&
      buyerField != 'Email' &&
      Pattern.matches('^[A-Za-z][A-Za-z0-9_]*(__c)?$', buyerField) &&
      Schema.SObjectType.Lead.fields.getMap().containsKey(buyerField)
    ) {
      fields += ', ' + buyerField;
    }
    return (Lead) Database.query(
      'SELECT ' + fields + ' FROM Lead WHERE Id = :leadId LIMIT 1'
    );
  }

  public static String buyerIdFor(Lead ld) {
    Lead refreshed = reloadLead(ld.Id);
    String buyerField = PropfocusConfigService.getConfig().buyerIdField;
    if (
      String.isBlank(buyerField) ||
      buyerField == 'Email' ||
      !Schema.SObjectType.Lead.fields.getMap().containsKey(buyerField)
    ) {
      return refreshed.Email;
    }
    Object value = refreshed.get(buyerField);
    return value == null ? refreshed.Email : String.valueOf(value);
  }

  public static String configuredOrganizationId() {
    return PropfocusConfigService.getConfig().organizationId;
  }
}
