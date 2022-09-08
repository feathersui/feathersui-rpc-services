import feathers.controls.Alert;
import feathers.controls.Application;
import feathers.controls.Button;
import feathers.controls.Label;
import feathers.controls.TextInput;
import feathers.events.TriggerEvent;
import feathers.layout.VerticalLayout;
import feathers.rpc.events.FaultEvent;
import feathers.rpc.events.ResultEvent;
import feathers.rpc.http.HTTPService;
import feathers.style.IDarkModeTheme;
import feathers.style.Theme;

class Main extends Application {
	private static final ROOT_URL = "https://feathersui.com/samples/haxe-openfl/http-service-result-formats";

	// private static final ROOT_URL = "http://localhost:8080";

	public function new() {
		cast(Theme.fallbackTheme, IDarkModeTheme).darkMode = true;
		super();
	}

	private var _jsonService:HTTPService;
	private var _xmlService:HTTPService;
	private var _urlVarsService:HTTPService;
	private var _textService:HTTPService;
	private var _objectService:HTTPService;

	private var _nameInput:TextInput;

	override private function initialize():Void {
		super.initialize();

		this._jsonService = new HTTPService();
		this._jsonService.resultFormat = HTTPService.RESULT_FORMAT_JSON;
		this._jsonService.addEventListener(ResultEvent.RESULT, handleJSONResult);
		this._jsonService.addEventListener(FaultEvent.FAULT, handleFault);
		this._jsonService.url = '${ROOT_URL}/json.php';

		this._xmlService = new HTTPService();
		this._xmlService.resultFormat = HTTPService.RESULT_FORMAT_HAXE_XML;
		this._xmlService.addEventListener(ResultEvent.RESULT, handleXMLResult);
		this._xmlService.addEventListener(FaultEvent.FAULT, handleFault);
		this._xmlService.url = '${ROOT_URL}/xml.php';

		this._urlVarsService = new HTTPService();
		this._urlVarsService.resultFormat = HTTPService.RESULT_FORMAT_FLASHVARS;
		this._urlVarsService.addEventListener(ResultEvent.RESULT, handleURLVarsResult);
		this._urlVarsService.addEventListener(FaultEvent.FAULT, handleFault);
		this._urlVarsService.url = '${ROOT_URL}/urlvars.php';

		this._textService = new HTTPService();
		this._textService.resultFormat = HTTPService.RESULT_FORMAT_TEXT;
		this._textService.addEventListener(ResultEvent.RESULT, handleTextResult);
		this._textService.addEventListener(FaultEvent.FAULT, handleTextFault);
		this._textService.url = '${ROOT_URL}/text.php';

		this._objectService = new HTTPService();
		this._objectService.resultFormat = HTTPService.RESULT_FORMAT_OBJECT;
		this._objectService.addEventListener(ResultEvent.RESULT, handleObjectResult);
		this._objectService.addEventListener(FaultEvent.FAULT, handleFault);
		this._objectService.url = '${ROOT_URL}/xml.php';

		var appLayout = new VerticalLayout();
		appLayout.horizontalAlign = CENTER;
		appLayout.gap = 10.0;
		appLayout.setPadding(10.0);
		this.layout = appLayout;

		var title = new Label();
		title.variant = Label.VARIANT_HEADING;
		title.text = "What is your name?";
		this.addChild(title);

		this._nameInput = new TextInput();
		this.addChild(this._nameInput);

		var loadJSONButton = new Button();
		loadJSONButton.text = "Load JSON result";
		loadJSONButton.addEventListener(TriggerEvent.TRIGGER, loadJSONButton_triggerHandler);
		this.addChild(loadJSONButton);

		var loadXMLButton = new Button();
		loadXMLButton.text = "Load XML result";
		loadXMLButton.addEventListener(TriggerEvent.TRIGGER, loadXMLButton_triggerHandler);
		this.addChild(loadXMLButton);

		var loadURLVarsButton = new Button();
		loadURLVarsButton.text = "Load URL variables result";
		loadURLVarsButton.addEventListener(TriggerEvent.TRIGGER, loadURLVarsButton_triggerHandler);
		this.addChild(loadURLVarsButton);

		var loadTextButton = new Button();
		loadTextButton.text = "Load text result";
		loadTextButton.addEventListener(TriggerEvent.TRIGGER, loadTextButton_triggerHandler);
		this.addChild(loadTextButton);

		var loadObjectButton = new Button();
		loadObjectButton.text = "Load XML as Object result";
		loadObjectButton.addEventListener(TriggerEvent.TRIGGER, loadObjectButton_triggerHandler);
		this.addChild(loadObjectButton);
	}

	private function validateName():Bool {
		if (this._nameInput.text.length > 0) {
			this._nameInput.errorString = null;
			return true;
		}
		this._nameInput.errorString = "Name is required";
		return false;
	}

	private function handleFault(event:FaultEvent):Void {
		Alert.show(Std.string(event.fault), "Fault", ["OK"]);
	}

	private function handleJSONResult(event:ResultEvent):Void {
		var json:{?message:String, ?error:String} = event.result;
		if (json.error != null) {
			Alert.show(Std.string(json.error), "Fault", ["OK"]);
			return;
		}
		var text = Std.string(json.message);
		Alert.show(text, "Message", ["OK"]);
	}

	private function handleXMLResult(event:ResultEvent):Void {
		var xml:Xml = event.result;
		var rootElement = xml.firstElement();
		if (rootElement.elementsNamed("error").hasNext()) {
			var error = rootElement.elementsNamed("error").next().firstChild().nodeValue;
			Alert.show(error, "Fault", ["OK"]);
			return;
		}
		var text = rootElement.elementsNamed("message").next().firstChild().nodeValue;
		Alert.show(text, "Message", ["OK"]);
	}

	private function handleURLVarsResult(event:ResultEvent):Void {
		var urlVars:Dynamic = event.result;
		if (urlVars.error != null) {
			Alert.show(urlVars.error, "Fault", ["OK"]);
			return;
		}
		var text = urlVars.message;
		Alert.show(text, "Message", ["OK"]);
	}

	private function handleTextResult(event:ResultEvent):Void {
		var text = Std.string(event.result);
		Alert.show(text, "Message", ["OK"]);
	}

	private function handleObjectResult(event:ResultEvent):Void {
		var response = event.result.response;
		if (response.error != null) {
			Alert.show(response.error, "Fault", ["OK"]);
			return;
		}
		var text = response.message;
		Alert.show(text, "Message", ["OK"]);
	}

	private function handleTextFault(event:FaultEvent):Void {
		Alert.show("Error loading text result", "Fault", ["OK"]);
	}

	private function loadJSONButton_triggerHandler(event:TriggerEvent):Void {
		if (!this.validateName()) {
			return;
		}
		this._jsonService.send({
			name: this._nameInput.text
		});
	}

	private function loadXMLButton_triggerHandler(event:TriggerEvent):Void {
		if (!this.validateName()) {
			return;
		}
		this._xmlService.send({
			name: this._nameInput.text
		});
	}

	private function loadURLVarsButton_triggerHandler(event:TriggerEvent):Void {
		if (!this.validateName()) {
			return;
		}
		this._urlVarsService.send({
			name: this._nameInput.text
		});
	}

	private function loadTextButton_triggerHandler(event:TriggerEvent):Void {
		if (!this.validateName()) {
			return;
		}
		this._textService.send({
			name: this._nameInput.text
		});
	}

	private function loadObjectButton_triggerHandler(event:TriggerEvent):Void {
		if (!this.validateName()) {
			return;
		}
		this._objectService.send({
			name: this._nameInput.text
		});
	}
}
