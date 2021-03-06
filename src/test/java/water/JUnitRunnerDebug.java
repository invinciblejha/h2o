package water;

import java.util.ArrayList;
import java.util.List;

import org.junit.internal.TextListener;
import org.junit.runner.*;
import org.junit.runner.notification.Failure;

import water.deploy.NodeCL;
import water.util.Log;
import water.util.Utils;

public class JUnitRunnerDebug {
  public static void main(String[] args) throws Exception {
    String flat = "";
    boolean multi = true;
    flat += "127.0.0.1:54321\n";
    if( multi ) {
      flat += "127.0.0.1:54323\n";
      flat += "127.0.0.1:54325\n";
    }
    flat = Utils.writeFile(flat).getAbsolutePath();

    new NodeCL(UserCode.class, ("-ip 127.0.0.1 -port 54321 -flatfile " + flat + " " + multi).split(" ")).start();
    if( multi ) {
      new NodeCL(H2O.class, ("-ip 127.0.0.1 -port 54323 -flatfile " + flat).split(" ")).start();
      new NodeCL(H2O.class, ("-ip 127.0.0.1 -port 54325 -flatfile " + flat).split(" ")).start();
    }
  }

  public static class UserCode {
    public static void userMain(String[] args) {
      H2O.main(args);
      boolean multi = Boolean.parseBoolean(args[6]);
      if( multi )
        TestUtil.stall_till_cloudsize(3);

      List<Class> tests = new ArrayList<Class>();

      // Classes to test:
      // tests = JUnitRunner.all();
      tests.add(hex.NeuralNetIrisTest.class);

      JUnitCore junit = new JUnitCore();
      junit.addListener(new LogListener());
      Result result = junit.run(tests.toArray(new Class[0]));
      if( result.getFailures().size() == 0 )
        Log.info("Success!");
    }
  }

  static class LogListener extends TextListener {
    LogListener() {
      super(System.out);
    }

    @Override public void testRunFinished(Result result) {
      printHeader(result.getRunTime());
      printFailures(result);
      printFooter(result);
    }

    @Override public void testStarted(Description description) {
      Log.info("");
      Log.info("Starting test " + description);
    }

    @Override public void testFailure(Failure failure) {
      Log.info("Test failed " + failure);
    }

    @Override public void testIgnored(Description description) {
      Log.info("Ignoring test " + description);
    }
  }
}
