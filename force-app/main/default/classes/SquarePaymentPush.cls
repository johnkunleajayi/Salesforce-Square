public class SquarePaymentPush implements Queueable, Database.AllowsCallouts {
    
    public void execute(QueueableContext context) {
        Square_Config__mdt config = getConfig();
        String accessToken = config.Access_Token__c;
        String paymentsUrl = config.PaymentCreationURL__c;

        if (String.isEmpty(accessToken) || String.isEmpty(paymentsUrl)) {
            System.debug('Missing config: access token or endpoint.');
            return;
        }

        // Query unpaid transactions
        List<Transaction__c> paymentsToPush = [
            SELECT Id, Name, Transaction_Amount__c, CurrencyCode__c, Customer__c, Customer_Email__c
            FROM Transaction__c
            WHERE Status__c = 'Pending'
            LIMIT 50
        ];

        List<Transaction__c> paymentsToUpdate = new List<Transaction__c>();

        for (Transaction__c payment : paymentsToPush) {
            try {
                if (payment.Transaction_Amount__c == null || String.isEmpty(payment.CurrencyCode__c)) {
                    System.debug('Skipping payment ' + payment.Id + ' due to missing amount or currency.');
                    continue;
                }

                HttpRequest req = new HttpRequest();
                req.setEndpoint(paymentsUrl);
                req.setMethod('POST');
                req.setHeader('Authorization', 'Bearer ' + accessToken);
                req.setHeader('Content-Type', 'application/json');

                // Generate unique idempotency key
                String idempotencyKey = String.valueOf(System.currentTimeMillis()) + Math.random();

                // Convert amount to cents and validate
                Integer amountInCents = (payment.Transaction_Amount__c * 100).intValue();
                String currencys = String.valueOf(payment.CurrencyCode__c).trim();

                // Build request body
                Map<String, Object> amountMoney = new Map<String, Object>();
                amountMoney.put('amount', amountInCents);
                amountMoney.put('currency', currencys);

                Map<String, Object> buyerSuppliedMoney = new Map<String, Object>();
                buyerSuppliedMoney.put('amount', amountInCents);
                buyerSuppliedMoney.put('currency', currencys);

                Map<String, Object> cashDetails = new Map<String, Object>();
                cashDetails.put('buyer_supplied_money', buyerSuppliedMoney);

                Map<String, Object> bodyMap = new Map<String, Object>();
                bodyMap.put('idempotency_key', idempotencyKey);
                bodyMap.put('source_id', 'CASH');
                bodyMap.put('autocomplete', true);
                bodyMap.put('amount_money', amountMoney);
                bodyMap.put('cash_details', cashDetails);
                bodyMap.put('note', 'Payment from Salesforce');

                req.setBody(JSON.serialize(bodyMap));

                // Send request
                Http http = new Http();
                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                    paymentsToUpdate.add(payment);
                    System.debug('Payment ' + payment.Id + ' successfully processed in Square.');
                } else {
                    System.debug('Failed to process payment ' + payment.Id + '. Status: ' + res.getStatusCode() + ' | Body: ' + res.getBody());
                }

            } catch (Exception ex) {
                System.debug('Exception for payment ' + payment.Id + ': ' + ex.getMessage());
            }
        }

        // Enqueue update job if needed
        if (!paymentsToUpdate.isEmpty()) {
            System.enqueueJob(new UpdatePaymentStatusJob(paymentsToUpdate));
        }
    }

    private static Square_Config__mdt getConfig() {
        return [
            SELECT Access_Token__c, PaymentCreationURL__c
            FROM Square_Config__mdt
            WHERE DeveloperName = 'Square_Default'
            LIMIT 1
        ];
    }
}