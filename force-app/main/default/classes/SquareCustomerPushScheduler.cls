public class SquareCustomerPushScheduler implements Schedulable {

    public void execute(SchedulableContext context) {
        System.enqueueJob(new SquareCustomerPush());
    }
}