import feathers.controls.Alert;
import feathers.controls.Application;
import feathers.controls.Button;
import feathers.controls.Form;
import feathers.controls.FormItem;
import feathers.controls.Label;
import feathers.controls.TextInput;
import feathers.events.TriggerEvent;
import feathers.layout.VerticalLayout;
import feathers.rpc.events.FaultEvent;
import feathers.rpc.events.ResultEvent;
import feathers.rpc.remoting.RemoteObject;
import feathers.style.IDarkModeTheme;
import feathers.style.Theme;
import openfl.events.Event;

class Main extends Application {
	public function new() {
		cast(Theme.fallbackTheme, IDarkModeTheme).darkMode = true;
		super();
	}

	private var _remoteObject:RemoteObject;
	private var _nameInput:TextInput;

	override private function initialize():Void {
		super.initialize();

		this._remoteObject = new RemoteObject();
		this._remoteObject.destination = "exampleService";
		this._remoteObject.endpoint = "http://localhost:8080/messagebroker/websocket-amf";
		this._remoteObject.addEventListener(ResultEvent.RESULT, handleResult);
		this._remoteObject.addEventListener(FaultEvent.FAULT, handleFault);

		var appLayout = new VerticalLayout();
		appLayout.horizontalAlign = CENTER;
		appLayout.setPadding(30.0);
		appLayout.gap = 20.0;
		this.layout = appLayout;

		var form = new Form();
		this.addChild(form);

		var title = new Label();
		title.variant = Label.VARIANT_HEADING;
		title.text = "BlazeDS Feathers UI RPC Services Example";
		form.addChild(title);

		this._nameInput = new TextInput();
		this._nameInput.addEventListener(Event.CHANGE, nameInput_changeHandler);

		var formItem = new FormItem();
		formItem.text = "What's your name?";
		formItem.content = this._nameInput;
		formItem.textPosition = LEFT;
		formItem.horizontalAlign = JUSTIFY;
		form.addChild(formItem);

		var submitButton = new Button();
		submitButton.text = "Submit";
		submitButton.addEventListener(TriggerEvent.TRIGGER, submitButton_triggerHandler);
		form.submitButton = submitButton;
		form.addChild(submitButton);
	}

	private function validateName():Void {
		var isValid = this._nameInput.text.length > 0;
		if (isValid) {
			this._nameInput.errorString = null;
		} else {
			this._nameInput.errorString = "Please enter your name";
		}
	}

	private function handleResult(event:ResultEvent):Void {
		Alert.show(Std.string(event.result), "Message from BlazeDS", ["OK"]);
	}

	private function handleFault(event:FaultEvent):Void {
		Alert.show(Std.string(event.fault), "Fault", ["OK"]);
	}

	private function nameInput_changeHandler(event:Event):Void {
		this.validateName();
	}

	private function submitButton_triggerHandler(event:TriggerEvent):Void {
		var name = this._nameInput.text;
		if (name.length == 0) {
			this.validateName();
			return;
		}
		_remoteObject.getOperation("echo").send(name);
	}
}
