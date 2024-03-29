/*
	Licensed to the Apache Software Foundation (ASF) under one or more
	contributor license agreements.  See the NOTICE file distributed with
	this work for additional information regarding copyright ownership.
	The ASF licenses this file to You under the Apache License, Version 2.0
	(the "License"); you may not use this file except in compliance with
	the License.  You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.
 */

package feathers.messaging;

import feathers.messaging.utils.RpcClassAliasInitializer;
import feathers.messaging.messages.AbstractMessage;
import feathers.messaging.messages.AsyncMessage;
import feathers.messaging.messages.IMessage;

/**
	A Producer sends messages to a destination.
	Producers dispatch a MessageAckEvent or MessageFaultEvent 
	for each message they send depending upon whether the outbound message
	was sent and processed successfully or not.
**/
class Producer extends AbstractProducer {
	//--------------------------------------------------------------------------
	//
	// Static Constants
	//
	//--------------------------------------------------------------------------

	/**
		The default message priority.
	**/
	public static final DEFAULT_PRIORITY:Int = 4;

	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructor.

		```haxe
		function sendMessage():Void
		{
			var producer:Producer = new Producer();
			producer.destination = "NASDAQ";
			var msg:AsyncMessage = new AsyncMessage();
			msg.headers.operation = "UPDATE";
			msg.body = {"SYMBOL":50.00};
			producer.send(msg);
		}
		```
	**/
	public function new() {
		super();
		RpcClassAliasInitializer.registerClassAliases();
		// _log = Log.getLogger("mx.messaging.Producer");
		_agentType = "producer";
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------
	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  subtopic
	//----------------------------------
	private var _subtopic:String = "";

	// [Bindable(event = "propertyChange")]

	/**
		Provides access to the subtopic for the remote destination that the MessageAgent uses.
	**/
	@:flash.property
	public var subtopic(get, set):String;

	private function get_subtopic():String {
		return _subtopic;
	}

	private function set_subtopic(value:String):String {
		if (_subtopic != value) {
			// var event:PropertyChangeEvent;
			if (value == null)
				value = "";

			// event = PropertyChangeEvent.createUpdateEvent(this, "subtopic", _subtopic, value);
			_subtopic = value;

			// dispatchEvent(event);
		}
		return _subtopic;
	}

	//--------------------------------------------------------------------------
	//
	// Protected Methods
	//
	//--------------------------------------------------------------------------

	override private function internalSend(message:IMessage, waitForClientId:Bool = true):Void {
		if (subtopic.length > 0)
			Reflect.setField(message.headers, AsyncMessage.SUBTOPIC_HEADER, subtopic);

		handlePriority(message);

		super.internalSend(message, waitForClientId);
	}

	//--------------------------------------------------------------------------
	//
	// Private Methods
	//
	//--------------------------------------------------------------------------

	/**
		If the priority header has been set on the message, makes sure that the
		priority value is within the valid range (0-9). If no priority header
		has been set, tries to use Producer's priority level if one exists.
	**/
	private function handlePriority(message:IMessage):Void {
		// If message priority is already set, make sure it's within range.
		if (Reflect.field(message.headers, AbstractMessage.PRIORITY_HEADER) != null) {
			var messagePriority:Int = Reflect.field(message.headers, AbstractMessage.PRIORITY_HEADER);
			if (messagePriority < 0)
				Reflect.setField(message.headers, AbstractMessage.PRIORITY_HEADER, 0);
			else if (messagePriority > 9)
				Reflect.setField(message.headers, AbstractMessage.PRIORITY_HEADER, 9);
		}
		// Otherwise, see if there's the default priority property is set.
		else if (priority > -1) {
			Reflect.setField(message.headers, AbstractMessage.PRIORITY_HEADER, priority);
		}
	}
}
