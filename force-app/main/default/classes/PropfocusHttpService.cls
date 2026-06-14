public class PropfocusHttpService {
  public static HttpResponse send(HttpRequest req) {
    PropfocusOAuthService.applyAuthorization(req);
    return new Http().send(req);
  }
}
