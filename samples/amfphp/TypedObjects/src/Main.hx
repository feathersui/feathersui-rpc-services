import feathers.controls.Alert;
import feathers.controls.Application;
import feathers.controls.Button;
import feathers.controls.Label;
import feathers.events.TriggerEvent;
import feathers.layout.VerticalLayout;
import feathers.messaging.config.LoaderConfig;
import feathers.rpc.events.FaultEvent;
import feathers.rpc.events.ResultEvent;
import feathers.rpc.remoting.RemoteObject;
import feathers.skins.RectangleSkin;
import feathers.style.IDarkModeTheme;
import feathers.style.Theme;

class Main extends Application {
	public function new() {
		cast(Theme.fallbackTheme, IDarkModeTheme).darkMode = true;
		super();
	}

	private var _myConnection:RemoteObject;

	override private function initialize():Void {
		super.initialize();

		#if (openfl >= "9.2.0")
		openfl.Lib.registerClassAlias("UserVo1", UserVo1);
		openfl.Lib.registerClassAlias("UserVo2", UserVo2);
		#else
		untyped __global__["flash.net.registerClassAlias"]("UserVo1", UserVo1);
		untyped __global__["flash.net.registerClassAlias"]("UserVo2", UserVo2);
		#end

		LoaderConfig.init(this);

		this._myConnection = new RemoteObject();
		this._myConnection.destination = "amfphpExamplesGateway";
		#if (html5 && !electron)
		this._myConnection.endpoint = "../../../../../Php";
		#else
		this._myConnection.endpoint = "http://localhost:8080/Examples/Php";
		#end
		this._myConnection.source = "VoService";
		this._myConnection.addEventListener(ResultEvent.RESULT, handleResult);
		this._myConnection.addEventListener(FaultEvent.FAULT, handleFault);

		this.backgroundSkin = new RectangleSkin(SolidColor(0x001116));

		var appLayout = new VerticalLayout();
		appLayout.horizontalAlign = CENTER;
		appLayout.setPadding(30.0);
		appLayout.gap = 20.0;
		this.layout = appLayout;

		var title = new Label();
		title.variant = Label.VARIANT_HEADING;
		title.text = "amfPHP Feathers UI Typed Object Example";
		this.addChild(title);

		var description1 = new Label();
		description1.text = "This example shows the two ways amfPHP can handle typed objects.";
		this.addChild(description1);
		var description2 = new Label();
		description2.text = "UserVo1 has a matching PHP type, UserVo2 doesn't.";
		this.addChild(description2);
		var description3 = new Label();
		description3.text = "See the VoService Methods for details.";
		this.addChild(description3);

		var sendUserVo1Btn = new Button();
		sendUserVo1Btn.text = "Send and receive a UserVo1 Typed Object";
		sendUserVo1Btn.addEventListener(TriggerEvent.TRIGGER, sendUserVo1Btn_triggerHandler);
		this.addChild(sendUserVo1Btn);

		var sendUserVo2Btn = new Button();
		sendUserVo2Btn.text = "Send and receive a UserVo2 Typed Object";
		sendUserVo2Btn.addEventListener(TriggerEvent.TRIGGER, sendUserVo2Btn_triggerHandler);
		this.addChild(sendUserVo2Btn);
	}

	private function handleResult(event:ResultEvent):Void {
		Alert.show(Std.string(event.result.status), "User VO Status", ["OK"]);
	}

	private function handleFault(event:FaultEvent):Void {
		Alert.show(Std.string(event.fault), "Fault", ["OK"]);
	}

	private function sendUserVo1Btn_triggerHandler(event:TriggerEvent):Void {
		_myConnection.getOperation("receiveAndReturnUserVo1").send(new UserVo1());
	}

	private function sendUserVo2Btn_triggerHandler(event:TriggerEvent):Void {
		_myConnection.getOperation("receiveAndReturnUserVo2").send(new UserVo2());
	}
}
