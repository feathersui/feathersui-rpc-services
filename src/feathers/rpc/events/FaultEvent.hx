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

import feathers.messaging.events.MessageFaultEvent;
import feathers.messaging.messages.AbstractMessage;
import feathers.messaging.messages.IMessage;
import openfl.events.Event;
import openfl.events.EventType;

/**
	This event is dispatched when an RPC call has a fault.
**/
class FaultEvent extends AbstractEvent {
	//--------------------------------------------------------------------------
	//
	//  Class constants
	//
	//--------------------------------------------------------------------------

	/**
		The FAULT event type.

		The properties of the event object have the following values:

		<table class="innertable">
		<tr><th>Property</th><th>Value</th></tr>
		<tr><td>`bubbles`</td><td>false</td></tr>
		<tr><td>`cancelable`</td><td>true, calling preventDefault() 
		from the associated token's responder.fault method will prevent
		the service or operation from dispatching this event</td></tr>
		<tr><td>`currentTarget`</td><td>The Object that defines the 
		event listener that handles the event. For example, if you use 
		`myButton.addEventListener()` to register an event listener, 
		myButton is the value of the `currentTarget`. </td></tr>
		<tr><td>`fault`</td><td>The Fault object that contains the
		details of what caused this event.</td></tr>   
		<tr><td>`message`</td><td>The Message associated with this event.</td></tr>
		<tr><td>`target`</td><td>The Object that dispatched the event; 
		it is not always the Object listening for the event. 
		Use the `currentTarget` property to always access the 
		Object listening for the event.</td></tr>
		<tr><td>`token`</td><td>The token that represents the call
		to the method. Used in the asynchronous completion token pattern.</td></tr>   
		</table>
	**/
	public static final FAULT:EventType<FaultEvent> = "fault";

	//--------------------------------------------------------------------------
	//
	//  Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Creates a new FaultEvent. The fault is a required parameter while the call and message are optional.

		@param type The event type; indicates the action that triggered the event.
		@param bubbles Specifies whether the event can bubble up the display list hierarchy.
		@param cancelable Specifies whether the behavior associated with the event can be prevented.
		@param fault Object that holds details of the fault, including a faultCode and faultString.
		@param token Token representing the call to the method. Used in the asynchronous completion token pattern.
		@param message Source Message of the fault.
	**/
	public function new(type:String, bubbles:Bool = false, cancelable:Bool = true, fault:Fault = null, token:AsyncToken = null, message:IMessage = null) {
		super(type, bubbles, cancelable, token, message);

		if (message != null && message.headers != null) {
			_statusCode = (Reflect.field(message.headers, AbstractMessage.STATUS_CODE_HEADER) : Int);
		}

		_fault = fault;
	}

	//--------------------------------------------------------------------------
	//
	//  Properties
	//
	//--------------------------------------------------------------------------

	/**
		The Fault object that contains the details of what caused this event.
	**/
	@:flash.property
	public var fault(get, never):Fault;

	private function get_fault():Fault {
		return _fault;
	}

	/**
		In certain circumstances, headers may also be returned with a fault to
		provide further context to the failure.
	**/
	@:flash.property
	public var headers(get, set):Dynamic;

	private function get_headers():Dynamic {
		return _headers;
	}

	private function set_headers(value:Dynamic):Dynamic {
		_headers = value;
		return _headers;
	}

	/**
		If the source message was sent via HTTP, this property provides access
		to the HTTP response status code (if available), otherwise the value is
		0.
	**/
	@:flash.property
	public var statusCode(get, never):Int;

	private function get_statusCode():Int {
		return _statusCode;
	}

	//--------------------------------------------------------------------------
	//
	//  Methods
	//
	//--------------------------------------------------------------------------

	/** 
		Because this event can be redispatched we have to implement clone to
		return the appropriate type, otherwise we will get just the standard
		event type.
	**/
	override public function clone():Event {
		return new FaultEvent(type, bubbles, cancelable, fault, token, message);
	}

	/**
		Returns a string representation of the FaultEvent.

		@return String representation of the FaultEvent.
	**/
	override public function toString():String {
		#if flash
		return Reflect.callMethod(this, formatToString, [
			"FaultEvent",
			"fault",
			"messageId",
			"type",
			"bubbles",
			"cancelable",
			"eventPhase"
		]);
		#else
		return Reflect.callMethod(this, __formatToString, [
			"FaultEvent",
			["fault", "messageId", "type", "bubbles", "cancelable", "eventPhase"]
		]);
		#end
	}

	/**
		Have the token apply the fault.
	**/
	override private function callTokenResponders():Void {
		if (token != null) {
			token.applyFault(this);
		}
	}

	/**
		Given a MessageFaultEvent, this method constructs and
		returns a FaultEvent.

		@param value MessageFaultEvent reference to extract the appropriate
		fault information from.
		@param token AsyncToken [optional] associated with this fault.
		@return Returns a FaultEvent.
	**/
	public static function createEventFromMessageFault(value:MessageFaultEvent, token:AsyncToken = null):FaultEvent {
		var fault:Fault = new Fault(value.faultCode, value.faultString, value.faultDetail);
		fault.rootCause = value.rootCause;
		return new FaultEvent(FaultEvent.FAULT, false, true, fault, token, value.message);
	}

	/**
		Given a Fault, this method constructs and
		returns a FaultEvent.

		@param fault Fault that contains the details of the FaultEvent.
		@param token AsyncToken [optional] associated with this fault.
		@param msg Message [optional] associated with this fault.
		@return Returns a FaultEvent.
	**/
	public static function createEvent(fault:Fault, token:AsyncToken = null, msg:IMessage = null):FaultEvent {
		return new FaultEvent(FaultEvent.FAULT, false, true, fault, token, msg);
	}

	//--------------------------------------------------------------------------
	//
	//  Private Variables
	//
	//--------------------------------------------------------------------------
	private var _fault:Fault;
	private var _headers:Any;
	private var _statusCode:Int;
}
