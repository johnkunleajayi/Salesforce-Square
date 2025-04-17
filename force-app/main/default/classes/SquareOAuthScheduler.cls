public class SquareOAuthScheduler implements Schedulable {

    public void execute(SchedulableContext context){
        
        System.enqueueJob(new SquareOAuthTokenUpdater());
    }
}