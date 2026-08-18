public inherited sharing class PropfocusOAuthService {
  private static final String DEFAULT_GRANT_TYPE = 'client_credentials';
  private static final String CACHE_KEY = 'PropfocusAccessToken';
  private static final Integer EXPIRY_BUFFER_SECONDS = 60;

  @TestVisible
  private static String cachedToken;
  @TestVisible
  private static Long cachedExpiryEpochSeconds;

  public static void applyAuthorization(HttpRequest req) {
    if (req == null || !isOAuthConfigured()) {
      return;
    }
    req.setHeader('Authorization', 'Bearer ' + getAccessToken());
  }

  public static Boolean isOAuthConfigured() {
    Propfocus_Config__mdt configured = Propfocus_Config__mdt.getInstance(
      'Default'
    );
    if (configured == null) {
      return false;
    }
    return !String.isBlank(configured.OAuth_Token_Url__c) &&
      !String.isBlank(configured.OAuth_Client_Id__c) &&
      !String.isBlank(configured.OAuth_Client_Secret__c);
  }

  public static String getAccessToken() {
    if (hasValidCachedToken()) {
      return cachedToken;
    }
    if (!isOAuthConfigured()) {
      throw new PropFocusServiceException('Propfocus OAuth is not configured');
    }

    Propfocus_Config__mdt configured = Propfocus_Config__mdt.getInstance(
      'Default'
    );
    String tokenUrl = configured.OAuth_Token_Url__c;
    String clientId = configured.OAuth_Client_Id__c;
    String clientSecret = configured.OAuth_Client_Secret__c;
    String grantType = String.isBlank(configured.OAuth_Grant_Type__c)
      ? DEFAULT_GRANT_TYPE
      : configured.OAuth_Grant_Type__c.trim();

    HttpRequest tokenRequest = new HttpRequest();
    tokenRequest.setEndpoint(tokenUrl);
    tokenRequest.setMethod('POST');
    tokenRequest.setHeader('Content-Type', 'application/x-www-form-urlencoded');
    tokenRequest.setHeader('Accept', 'application/json');
    tokenRequest.setBody(
      'grant_type=' +
        EncodingUtil.urlEncode(grantType, 'UTF-8') +
        '&client_id=' +
        EncodingUtil.urlEncode(clientId, 'UTF-8') +
        '&client_secret=' +
        EncodingUtil.urlEncode(clientSecret, 'UTF-8')
    );
    tokenRequest.setTimeout(10000);

    HttpResponse tokenResponse = new Http().send(tokenRequest);
    if (tokenResponse.getStatusCode() != 200) {
      throw new PropFocusServiceException(
        'Propfocus OAuth token request failed with status ' +
        tokenResponse.getStatusCode()
      );
    }

    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      tokenResponse.getBody()
    );
    String accessToken = extractAccessToken(payload);
    if (String.isBlank(accessToken)) {
      throw new PropFocusServiceException(
        'Propfocus OAuth token response missing access_token'
      );
    }

    Integer expiresIn = extractExpiresIn(payload);
    cacheToken(accessToken, expiresIn);
    return accessToken;
  }

  @TestVisible
  private static String extractAccessToken(Map<String, Object> payload) {
    if (payload == null) {
      return null;
    }
    String accessToken = (String) payload.get('access_token');
    if (!String.isBlank(accessToken)) {
      return accessToken;
    }
    Object dataObj = payload.get('data');
    if (dataObj instanceof Map<String, Object>) {
      return (String) ((Map<String, Object>) dataObj).get('access_token');
    }
    return null;
  }

  @TestVisible
  private static Integer extractExpiresIn(Map<String, Object> payload) {
    if (payload == null) {
      return 3600;
    }
    if (payload.containsKey('expires_in')) {
      return Integer.valueOf(String.valueOf(payload.get('expires_in')));
    }
    Object dataObj = payload.get('data');
    if (dataObj instanceof Map<String, Object>) {
      Map<String, Object> data = (Map<String, Object>) dataObj;
      if (data.containsKey('expires_in')) {
        return Integer.valueOf(String.valueOf(data.get('expires_in')));
      }
    }
    return 3600;
  }

  @TestVisible
  static void cacheToken(String accessToken, Integer expiresInSeconds) {
    cachedToken = accessToken;
    Long nowSeconds = System.now().getTime() / 1000;
    Integer safeExpiry = expiresInSeconds == null ? 3600 : expiresInSeconds;
    cachedExpiryEpochSeconds = nowSeconds + safeExpiry - EXPIRY_BUFFER_SECONDS;
  }

  @TestVisible
  static void clearCacheForTests() {
    cachedToken = null;
    cachedExpiryEpochSeconds = null;
  }

  private static Boolean hasValidCachedToken() {
    if (String.isBlank(cachedToken) || cachedExpiryEpochSeconds == null) {
      return false;
    }
    Long nowSeconds = System.now().getTime() / 1000;
    return nowSeconds < cachedExpiryEpochSeconds;
  }
}
