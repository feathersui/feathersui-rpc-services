import feathers.controls.Alert;
import feathers.controls.Application;
import feathers.controls.AssetLoader;
import feathers.controls.Button;
import feathers.controls.Label;
import feathers.events.TriggerEvent;
import feathers.layout.VerticalLayout;
import feathers.messaging.config.LoaderConfig;
import feathers.rpc.events.FaultEvent;
import feathers.rpc.events.ResultEvent;
import feathers.rpc.remoting.RemoteObject;
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

		LoaderConfig.init(this);

		this._myConnection = new RemoteObject();
		this._myConnection.destination = "amfphpExamplesGateway";
		#if (html5 && !electron)
		this._myConnection.endpoint = "../../../../../Php";
		#else
		this._myConnection.endpoint = "http://localhost:8080/Examples/Php";
		#end
		this._myConnection.source = "PizzaService";
		this._myConnection.addEventListener(ResultEvent.RESULT, handleResult);
		this._myConnection.addEventListener(FaultEvent.FAULT, handleFault);

		var appLayout = new VerticalLayout();
		appLayout.horizontalAlign = CENTER;
		appLayout.paddingTop = 320.0;
		appLayout.gap = 20.0;
		this.layout = appLayout;

		var background = new AssetLoader();
		background.source = "header-background-pizza";
		background.includeInLayout = false;
		this.addChild(background);

		var title = new Label();
		title.variant = Label.VARIANT_HEADING;
		title.text = "amfPHP Feathers UI Pizza Example";
		this.addChild(title);

		var getAPizzaButton = new Button();
		getAPizzaButton.text = "Get a pizza";
		getAPizzaButton.addEventListener(TriggerEvent.TRIGGER, getAPizzaButton_triggerHandler);
		this.addChild(getAPizzaButton);
	}

	private function handleResult(event:ResultEvent):Void {
		Alert.show(Std.string(event.result), "You got a pizza!", ["OK"]);
	}

	private function handleFault(event:FaultEvent):Void {
		Alert.show(Std.string(event.fault), "Fault", ["OK"]);
	}

	private function getAPizzaButton_triggerHandler(event:TriggerEvent):Void {
		_myConnection.getOperation("getPizza").send();
	}
}
