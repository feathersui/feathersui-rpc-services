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

package feathers.messaging.events;

import feathers.messaging.messages.IMessage;
import openfl.events.Event;

/**
	The MessageEvent class is used to propagate messages within the messaging system.
**/
class MessageEvent extends Event {
	//--------------------------------------------------------------------------
	//
	// Static Constants
	//
	//--------------------------------------------------------------------------

	/**
		The MESSAGE event type; dispatched upon receipt of a message.

		The value of this constant is `"message"`.

		The properties of the event object have the following values:

		<table class="innertable">
		<tr><th>Property</th><th>Value</th></tr>
		<tr><td>`bubbles`</td><td>false</td></tr>
		<tr><td>`cancelable`</td><td>false</td></tr>
		<tr><td>`currentTarget`</td><td>The Object that defines the 
		event listener that handles the event. For example, if you use 
		`myButton.addEventListener()` to register an event listener, 
		myButton is the value of the `currentTarget`. </td></tr>
		<tr><td>`message`</td><td>The message associated with this event.</td></tr>
		<tr><td>`target`</td><td>The Object that dispatched the event; 
		it is not always the Object listening for the event. 
		Use the `currentTarget` property to always access the 
		Object listening for the event.</td></tr>
		</table>
	**/
	public static final MESSAGE:String = "message";

	/**
		The RESULT event type; dispatched when an RPC agent receives a result from
		a remote service destination.

		The value of this constant is `"result"`.

		The properties of the event object have the following values:

		<table class="innertable">
		<tr><th>Property</th><th>Value</th></tr>
		<tr><td>`bubbles`</td><td>false</td></tr>
		<tr><td>`cancelable`</td><td>false</td></tr>
		<tr><td>`currentTarget`</td><td>The Object that defines the 
		event listener that handles the event. For example, if you use 
		`myButton.addEventListener()` to register an event listener, 
		myButton is the value of the `currentTarget`. </td></tr>
		<tr><td>`message`</td><td>The message associated with this event.</td></tr>
		<tr><td>`target`</td><td>The Object that dispatched the event; 
		it is not always the Object listening for the event. 
		Use the `currentTarget` property to always access the 
		Object listening for the event.</td></tr>
		</table>
	**/
	public static final RESULT:String = "result";

	//--------------------------------------------------------------------------
	//
	// Static Methods
	//
	//--------------------------------------------------------------------------

	/**
		Utility method to create a new MessageEvent that doesn't bubble and
		is not cancelable.

		@param type The type for the MessageEvent.

		@param message The associated message.

		@return New MessageEvent.
	**/
	public static function createEvent(type:String, msg:IMessage):MessageEvent {
		return new MessageEvent(type, false, false, msg);
	}

	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructs an instance of this event with the specified type and 
		message.

		@param type The type for the MessageEvent.

		@param bubbles Specifies whether the event can bubble up the display 
		list hierarchy.

		@param cancelable Indicates whether the behavior associated with the 
		event can be prevented; used by the RPC subclasses.

		@param message The associated message.
	**/
	public function new(type:String, bubbles:Bool = false, cancelable:Bool = false, message:IMessage = null) {
		super(type, bubbles, cancelable);

		this.message = message;
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/**
		The Message associated with this event.
	**/
	public var message:IMessage;

	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  messageId
	//----------------------------------
	@:flash.property
	public var messageId(get, never):String;

	private function get_messageId():String {
		if (message != null) {
			return message.messageId;
		}
		return null;
	}

	//--------------------------------------------------------------------------
	//
	// Overridden Methods
	//
	//--------------------------------------------------------------------------

	/**
		Clones the MessageEvent.

		@return Copy of this MessageEvent.
	**/
	override public function clone():Event {
		return new MessageEvent(type, bubbles, cancelable, message);
	}

	/**
		Returns a string representation of the MessageEvent.

		@return String representation of the MessageEvent.
	**/
	override public function toString():String {
		return formatToString("MessageEvent", "messageId", "type", "bubbles", "cancelable", "eventPhase");
	}
}
