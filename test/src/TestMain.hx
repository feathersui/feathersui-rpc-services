import feathers.utils.AMFBinaryDataTest;
import openfl.display.Sprite;
import utest.Runner;
import utest.ui.Report;

class TestMain extends Sprite {
	public function new() {
		super();

		var runner = new Runner();
		runner.addCase(new AMFBinaryDataTest());

		// a report prints the final results after all tests have run
		Report.create(runner);

		// don't forget to start the runner
		runner.run();
	}
}
