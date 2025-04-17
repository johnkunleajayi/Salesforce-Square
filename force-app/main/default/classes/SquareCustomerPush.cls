public class SquareCustomerPush implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext context) {
        Square_Config__mdt config = getConfig();
        String accessToken = config.Access_Token__c;
        String endpoint = config.CustomerCreationURL__c;

        if (String.isEmpty(accessToken) || String.isEmpty(endpoint)) {
            System.debug('Missing Access Token or Endpoint in metadata.');
            return;
        }

        List<Customer__c> customersToSync = [
            SELECT Id, First_Name__c, Last_Name__c, Email__c, Phone_Number__c
            FROM Customer__c
            WHERE Square_Customer_ID__c = NULL
            LIMIT 50
        ];

        if (customersToSync.isEmpty()) {
            System.debug('No customers to sync.');
            return;
        }

        List<Customer__c> customersToUpdate = new List<Customer__c>();

        for (Customer__c customer : customersToSync) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Content-Type', 'application/json');

            Map<String, Object> bodyMap = new Map<String, Object>{
                'given_name' => customer.First_Name__c,
                'family_name' => customer.Last_Name__c,
                'email_address' => customer.Email__c,
                'phone_number' => customer.Phone_Number__c
            };

            req.setBody(JSON.serialize(bodyMap));

            try {
                Http http = new Http();
                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                    Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    Map<String, Object> customerData = (Map<String, Object>) result.get('customer');
                    String squareId = (String) customerData.get('id');

                    customer.Square_Customer_ID__c = squareId;
                    customersToUpdate.add(customer);
                    System.debug('Synced: ' + customer.Email__c + ' -> Square ID: ' + squareId);
                } else {
                    System.debug('Failed for ' + customer.Email__c + ' | Status: ' + res.getStatusCode() + ' | Body: ' + res.getBody());
                }

            } catch (Exception ex) {
                System.debug('Exception for ' + customer.Email__c + ': ' + ex.getMessage());
            }
        }

        if (!customersToUpdate.isEmpty()) {
            update customersToUpdate;
            System.debug('Updated ' + customersToUpdate.size() + ' customers.');
        }
    }

    private static Square_Config__mdt getConfig() {
        return [
            SELECT Access_Token__c, CustomerCreationURL__c
            FROM Square_Config__mdt
            WHERE DeveloperName = 'Square_Default'
            LIMIT 1
        ];
    }
}