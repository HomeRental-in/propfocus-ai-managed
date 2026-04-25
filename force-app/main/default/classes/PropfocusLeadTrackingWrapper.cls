global class PropfocusLeadTrackingWrapper {

    public Boolean success;
    public String message;
    public Lead lead;
    public List<LeadHistory> history;
    public List<Task> activities;
    public List<SObject> siteVisits;

    public PropfocusLeadTrackingWrapper() {
        success = true;
        history = new List<LeadHistory>();
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
