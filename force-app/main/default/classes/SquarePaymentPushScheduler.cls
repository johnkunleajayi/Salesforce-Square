public class SquarePaymentPushScheduler implements Schedulable {

    public void execute(SchedulableContext context) {
        System.enqueueJob(new SquarePaymentPush());
    }
}