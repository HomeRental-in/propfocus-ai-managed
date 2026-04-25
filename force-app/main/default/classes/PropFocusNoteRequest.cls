global class PropFocusNoteRequest {

    public String org_id;
    public String entity_type;
    public Id entity_id;
    public String action_type;
    public NotePayload payload;
    public String source;
    public Datetime timestamp;

    global class NotePayload {
        public String title;
        public String content;
        public String visibility;
    }
}
