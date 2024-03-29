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

package feathers.rpc.events;

import feathers.messaging.messages.IMessage;
import openfl.events.Event;

/**
	The event that indicates an RPC operation has been invoked.
**/
class InvokeEvent extends AbstractEvent {
	/**
		The INVOKE event type.

		The properties of the event object have the following values:

		<table class="innertable">
		<tr><th>Property</th><th>Value</th></tr>
		<tr><td>`bubbles`</td><td>false</td></tr>
		<tr><td>`token`</td><td> The token that represents the indiviudal call
		to the method. Used in the asynchronous completion token pattern.</td></tr>
		<tr><td>`cancelable`</td><td>true</td></tr>
		<tr><td>`currentTarget`</td><td>The Object that defines the 
		event listener that handles the event. For example, if you use 
		`myButton.addEventListener()` to register an event listener, 
		myButton is the value of the `currentTarget`. </td></tr>
		<tr><td>`message`</td><td> The request Message associated with this event.</td></tr>
		<tr><td>`target`</td><td>The Object that dispatched the event; 
		it is not always the Object listening for the event. 
		Use the `currentTarget` property to always access the 
		Object listening for the event.</td></tr>
		</table>
		@eventType invoke 
	**/
	public static final INVOKE:String = "invoke";

	/**
		Create a new InvokeEvent.

		@param type The event type; indicates the action that triggered the event.
		@param bubbles Specifies whether the event can bubble up the display list hierarchy.
		@param cancelable Specifies whether the behavior associated with the event can be prevented.
		@param token Token that represents the call to the method. Used in the asynchronous completion token pattern.
		@param message Source Message of the request.
	**/
	public function new(type:String, bubbles:Bool = false, cancelable:Bool = false, token:AsyncToken = null, message:IMessage = null) {
		super(type, bubbles, cancelable, token, message);
	}

	@:dox(hide)
	public static function createEvent(token:AsyncToken = null, message:IMessage = null):InvokeEvent {
		return new InvokeEvent(InvokeEvent.INVOKE, false, false, token, message);
	}

	/** 
		Because this event can be re-dispatched we have to implement clone to
		return the appropriate type, otherwise we will get just the standard
		event type.
	**/
	@:dox(hide)
	override public function clone():Event {
		return new InvokeEvent(type, bubbles, cancelable, token, message);
	}

	/**
		Returns a string representation of the InvokeEvent.

		@return String representation of the InvokeEvent.
	**/
	override public function toString():String {
		return formatToString("InvokeEvent", "messageId", "type", "bubbles", "cancelable", "eventPhase");
	}
}
