import feathers.events.FeathersEvent;
import feathers.controls.Alert;
import feathers.messaging.events.MessageFaultEvent;
import feathers.layout.VerticalLayoutData;
import feathers.layout.HorizontalLayoutData;
import feathers.messaging.config.LoaderConfig;
import feathers.controls.Application;
import feathers.controls.Button;
import feathers.controls.LayoutGroup;
import feathers.controls.TextArea;
import feathers.controls.TextInput;
import feathers.events.TriggerEvent;
import feathers.layout.HorizontalLayout;
import feathers.layout.VerticalLayout;
import feathers.messaging.ChannelSet;
import feathers.messaging.Consumer;
import feathers.messaging.Producer;
import feathers.messaging.channels.AMFChannel;
import feathers.messaging.events.MessageEvent;
import feathers.messaging.messages.AsyncMessage;
import feathers.style.IDarkModeTheme;
import feathers.style.Theme;

class Main extends Application {
	public function new() {
		cast(Theme.fallbackTheme, IDarkModeTheme).darkMode = true;
		super();

		LoaderConfig.init(this);

		addEventListener(FeathersEvent.CREATION_COMPLETE, creationCompleteHandler);
	}

	private var _producer:Producer;
	private var _consumer:Consumer;
	private var _chatMessageInput:TextInput;
	private var _sendButton:Button;
	private var _chatHistory:TextArea;

	override private function initialize():Void {
		super.initialize();

		var endpoint = 'http://localhost:8080/blazeds-chat-server/messagebroker/long-polling-amf';

		_producer = new Producer();
		_producer.destination = "chat";
		var producerChannels = new ChannelSet();
		producerChannels.addChannel(new AMFChannel(null, endpoint));
		_producer.channelSet = producerChannels;
		_producer.addEventListener(MessageFaultEvent.FAULT, producer_faultHandler);

		_consumer = new Consumer();
		_consumer.destination = "chat";
		var consumerChannels = new ChannelSet();
		consumerChannels.addChannel(new AMFChannel(null, endpoint));
		_consumer.channelSet = consumerChannels;
		_consumer.addEventListener(MessageEvent.MESSAGE, consumer_messageHandler);

		var appLayout = new VerticalLayout();
		appLayout.horizontalAlign = CENTER;
		appLayout.setPadding(10.0);
		appLayout.gap = 10.0;
		this.layout = appLayout;

		_chatHistory = new TextArea();
		_chatHistory.editable = false;
		_chatHistory.layoutData = VerticalLayoutData.fill();
		addChild(_chatHistory);

		var group = new LayoutGroup();
		var groupLayout = new HorizontalLayout();
		groupLayout.gap = 10.0;
		group.layout = groupLayout;
		group.layoutData = VerticalLayoutData.fillHorizontal();
		addChild(group);

		_chatMessageInput = new TextInput();
		_chatMessageInput.layoutData = HorizontalLayoutData.fillHorizontal();
		group.addChild(_chatMessageInput);

		_sendButton = new Button();
		_sendButton.text = "Send";
		_sendButton.addEventListener(TriggerEvent.TRIGGER, sendButton_triggerHandler);
		group.addChild(_sendButton);
	}

	private function creationCompleteHandler(event:FeathersEvent):Void {
		_consumer.subscribe();
	}

	private function sendButton_triggerHandler(event:TriggerEvent):Void {
		var chatMessage = _chatMessageInput.text;
		if (chatMessage.length == 0) {
			return;
		}
		_chatMessageInput.text = "";

		var message = new AsyncMessage();
		message.body.chatMessage = chatMessage;
		_producer.send(message);
	}

	private function producer_faultHandler(event:MessageFaultEvent):Void {
		var faultMessage = 'faultString: ${event.faultString}\nfaultCode: ${event.faultCode}\nfaultDetail: ${event.faultDetail}';
		Alert.show(faultMessage, "Fault", ["OK"]);
	}

	private function consumer_messageHandler(event:MessageEvent):Void {
		var message = event.message;
		_chatHistory.text += message.body.chatMessage + "\n";
	}
}
