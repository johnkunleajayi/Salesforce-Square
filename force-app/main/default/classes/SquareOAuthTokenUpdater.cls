public class SquareOAuthTokenUpdater implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext context) {
        String accessToken = getAccessToken();
        if (accessToken != null) {
            System.debug('Square Access Token: ' + accessToken);
        } else {
            System.debug('Failed to retrieve Square Access Token');
        }
    }

    public static String getAccessToken() {
        try {
            Square_Config__mdt config = getConfig();

            if (String.isEmpty(config.Refresh_Token__c)) {
                System.debug('Missing refresh token in metadata.');
                return null;
            }

            String body = 'client_id=' + config.Client_ID__c +
                          '&client_secret=' + config.Client_Secret__c +
                          '&grant_type=refresh_token' +
                          '&refresh_token=' + config.Refresh_Token__c;

            HttpRequest req = new HttpRequest();
            req.setEndpoint(config.Token_Endpoint__c);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(body);

            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                String accessToken = (String) result.get('access_token');
                String newRefreshToken = (String) result.get('refresh_token');

                // Debug: Log the token details before updating metadata
                System.debug('Access Token: ' + accessToken);
                System.debug('Refresh Token: ' + newRefreshToken);

                updateCustomMetadata(accessToken, newRefreshToken);
                return accessToken;
            } else {
                System.debug('Token endpoint error: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception ex) {
            System.debug('Token fetch error: ' + ex.getMessage());
        }
        return null;
    }

    private static Square_Config__mdt getConfig() {
        // Retrieve the custom metadata record
        Square_Config__mdt config = [
            SELECT Client_ID__c, Client_Secret__c, Redirect_URI__c, Token_Endpoint__c, Refresh_Token__c
            FROM Square_Config__mdt
            WHERE DeveloperName = 'Square_Default'
            LIMIT 1
        ];

        if (config == null) {
            System.debug('No custom metadata record found for Square_Default');
        }
        return config;
    }

    private static void updateCustomMetadata(String accessToken, String refreshToken) {
        try {
            // Ensure none of the values are null
            if (String.isEmpty(accessToken) || String.isEmpty(refreshToken)) {
                System.debug('One or more values are missing: Access Token, Refresh Token, or Expires In.');
                return;
            }

            // Retrieve the existing metadata record
            Metadata.CustomMetadata md = new Metadata.CustomMetadata();
            md.fullName = 'Square_Config.Square_Default';
            md.label = 'Square_Default';

            // Set the new values for the custom metadata fields
            Metadata.CustomMetadataValue tokenField = new Metadata.CustomMetadataValue();
            tokenField.field = 'Access_Token__c';
            tokenField.value = accessToken;

            Metadata.CustomMetadataValue refreshField = new Metadata.CustomMetadataValue();
            refreshField.field = 'Refresh_Token__c';
            refreshField.value = refreshToken;


            // Add the fields to the metadata record
            md.values.add(tokenField);
            md.values.add(refreshField);

            // Create the deployment container and enqueue the metadata update
            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(md);

            Id jobId = Metadata.Operations.enqueueDeployment(container, null);
            System.debug('Metadata update enqueued. Job ID: ' + jobId);
        } catch (Exception e) {
            System.debug('Failed to update metadata: ' + e.getMessage());
        }
    }
}