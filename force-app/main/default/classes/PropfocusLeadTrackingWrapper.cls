public with sharing class PropfocusLeadTrackingWrapper {

  public Boolean success;
  public String message;
  public Lead lead;
  /** Lead field-history rows when available; typed as SObject to avoid a packaging dependency on LeadHistory. */
  public List<SObject> history;
  public List<Task> activities;
  public List<SObject> siteVisits;

  public PropfocusLeadTrackingWrapper() {
    success = true;
    history = new List<SObject>();
    activities = new List<Task>();
    siteVisits = new List<SObject>();
  }

  public static PropfocusLeadTrackingWrapper error(String message) {
    PropfocusLeadTrackingWrapper w = new PropfocusLeadTrackingWrapper();
    w.success = false;
    w.message = message;
    return w;
  }
}
