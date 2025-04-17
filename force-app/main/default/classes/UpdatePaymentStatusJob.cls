public class UpdatePaymentStatusJob implements Queueable {

    private List<Transaction__c> paymentsToUpdate;

    public UpdatePaymentStatusJob(List<Transaction__c> paymentsToUpdate) {
        this.paymentsToUpdate = paymentsToUpdate;
    }

    public void execute(QueueableContext context) {
        // Update payment status in Salesforce
        for (Transaction__c payment : paymentsToUpdate) {
            payment.Status__c = 'Completed';
        }

        try {
            update paymentsToUpdate;
            System.debug('Payments successfully updated in Salesforce.');
        } catch (Exception e) {
            System.debug('Error updating payments: ' + e.getMessage());
        }
    }
}