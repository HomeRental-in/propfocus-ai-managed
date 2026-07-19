public class PropFocusServiceException extends Exception {
  /**
   * Throw a user-facing error that is safe in Aura/LWC and in Flow / Queueable /
   * anonymous Apex. AuraHandledException can only be thrown from Visualforce or
   * Aura; elsewhere it becomes LimitException and fails the transaction.
   */
  public static void throwUserFacing(String message) {
    String detail = String.isBlank(message) ? 'Unexpected Propfocus error' : message;
    System.Quiddity quiddity = System.Request.getCurrent().getQuiddity();
    if (quiddity == System.Quiddity.AURA || quiddity == System.Quiddity.VF) {
      AuraHandledException auraEx = new AuraHandledException(detail);
      auraEx.setMessage(detail);
      throw auraEx;
    }
    throw new PropFocusServiceException(detail);
  }
}
