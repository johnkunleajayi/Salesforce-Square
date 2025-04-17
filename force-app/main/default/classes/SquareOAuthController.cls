public class SquareOAuthController {

    @RemoteAction
    public static String doOAuthCallback(String code) {
        if (String.isEmpty(code)) {
            return 'Error: Authorization code is missing.';
        }

        Square_Config__mdt config = getConfig();

        String clientId = config.Client_ID__c;
        String clientSecret = config.Client_Secret__c;
        String redirectUri = config.Redirect_URI__c;
        String tokenEndpoint = config.Token_Endpoint__c;

        String body = 'client_id=' + clientId +
                      '&client_secret=' + clientSecret +
                      '&code=' + code +
                      '&grant_type=authorization_code' +
                      '&redirect_uri=' + EncodingUtil.urlEncode(redirectUri, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint(tokenEndpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(body);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String accessToken = (String) responseMap.get('access_token');
            String refreshToken = (String) responseMap.get('refresh_token');
            return 'Access Token: ' + accessToken + '\nRefresh Token: ' + refreshToken;
        } else {
            return 'Failed to get token. Status: ' + res.getStatusCode() + '\nResponse: ' + res.getBody();
        }
    }

    private static Square_Config__mdt getConfig() {
        return [
            SELECT Client_ID__c, Client_Secret__c, Redirect_URI__c, Token_Endpoint__c
            FROM Square_Config__mdt
            WHERE DeveloperName = 'Square_Default'
            LIMIT 1
        ];
    }
}