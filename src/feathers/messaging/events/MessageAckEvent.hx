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

import feathers.messaging.messages.AcknowledgeMessage;
import feathers.messaging.messages.IMessage;
import openfl.events.Event;

/**
	The MessageAckEvent class is used to propagate acknowledge messages within the messaging system.
**/
class MessageAckEvent extends MessageEvent {
	//--------------------------------------------------------------------------
	//
	// Static Constants
	//
	//--------------------------------------------------------------------------

	/**
		The ACKNOWLEDGE event type; dispatched upon receipt of an acknowledgement.

		The value of this constant is `"acknowledge"`.

		The properties of the event object have the following values:

		<table class="innertable">
		<tr><th>Property</th><th>Value</th></tr>
		<tr><td>`acknowledgeMessage`</td><td> Utility property to get
		the message property from MessageEvent as an AcknowledgeMessage.</td></tr> 
		<tr><td>`bubbles`</td><td>false</td></tr>
		<tr><td>`cancelable`</td><td>false</td></tr>
		<tr><td>`currentTarget`</td><td>The Object that defines the 
		event listener that handles the event. For example, if you use 
		`myButton.addEventListener()` to register an event listener, 
		myButton is the value of the `currentTarget`.</td></tr>
		<tr><td>`correlate`</td><td> The original Message correlated with
		this acknowledgement.</td></tr>
		<tr><td>`message`</td><td>The Message associated with this event.</td></tr>
		<tr><td>`target`</td><td>The Object that dispatched the event; 
		it is not always the Object listening for the event. 
		Use the `currentTarget` property to always access the 
		Object listening for the event.</td></tr>
		</table>
	**/
	public static final ACKNOWLEDGE:String = "acknowledge";

	//--------------------------------------------------------------------------
	//
	// Static Methods
	//
	//--------------------------------------------------------------------------

	/**
		Utility method to create a new MessageAckEvent that doesn't bubble and
		is not cancelable.

		@param ack The AcknowledgeMessage this event should dispatch.

		@param correlation The Message correlated with this acknowledgement.

		@return New MessageAckEvent.
	**/
	public static function createEvent(ack:AcknowledgeMessage = null, correlation:IMessage = null):MessageAckEvent {
		return new MessageAckEvent(MessageAckEvent.ACKNOWLEDGE, false, false, ack, correlation);
	}

	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructs an instance of this event with the specified acknowledge
		message and original correlated message.

		@param type The type for the MessageAckEvent.

		@param bubbles Specifies whether the event can bubble up the display 
		list hierarchy.

		@param cancelable Indicates whether the behavior associated with the 
		event can be prevented.

		@param ack The AcknowledgeMessage this event should dispatch.

		@param correlation The message correlated with this acknowledgement.
	**/
	public function new(type:String, bubbles:Bool = false, cancelable:Bool = false, ack:AcknowledgeMessage = null, correlation:IMessage = null) {
		super(type, bubbles, cancelable, ack);

		this.correlation = correlation;
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/**
		The original Message correlated with this acknowledgement.
	**/
	public var correlation:IMessage;

	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  acknowledgeMessage
	//----------------------------------

	/**
		Utility property to get the message property from the MessageEvent as an AcknowledgeMessage.  
	**/
	@:flash.property
	public var acknowledgeMessage(get, never):AcknowledgeMessage;

	private function get_acknowledgeMessage():AcknowledgeMessage {
		return Std.downcast(message, AcknowledgeMessage);
	}

	//----------------------------------
	//  correlationId
	//----------------------------------
	@:dox(hide)
	@:flash.property
	public var correlationId(get, never):String;

	private function get_correlationId():String {
		if (correlation != null) {
			return correlation.messageId;
		}
		return null;
	}

	//--------------------------------------------------------------------------
	//
	// Overridden Methods
	//
	//--------------------------------------------------------------------------

	/**
		Clones the MessageAckEvent.

		@return Copy of this MessageAckEvent.
	**/
	override public function clone():Event {
		return new MessageAckEvent(type, bubbles, cancelable, Std.downcast(message, AcknowledgeMessage), correlation);
	}

	/**
		Returns a string representation of the MessageAckEvent.

		@return String representation of the MessageAckEvent.
	**/
	override public function toString():String {
		#if flash
		return Reflect.callMethod(this, formatToString, [
			"MessageAckEvent",
			"messageId",
			"correlationId",
			"type",
			"bubbles",
			"cancelable",
			"eventPhase"
		]);
		#else
		return Reflect.callMethod(this, __formatToString, [
			"MessageAckEvent",
			["messageId", "correlationId", "type", "bubbles", "cancelable", "eventPhase"]
		]);
		#end
	}
}
