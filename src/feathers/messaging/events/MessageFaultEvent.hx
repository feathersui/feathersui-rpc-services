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

import feathers.messaging.messages.ErrorMessage;
import openfl.events.Event;

/**
	The MessageFaultEvent class is used to propagate fault messages within the messaging system.
**/
class MessageFaultEvent extends Event {
	//--------------------------------------------------------------------------
	//
	// Static Constants
	//
	//--------------------------------------------------------------------------

	/**
		The FAULT event type; dispatched for a message fault.

		The value of this constant is `"fault"`.

		The properties of the event object have the following values:

		<table class="innertable">
		<tr><th>Property</th><th>Value</th></tr>
		<tr><td>`bubbles`</td><td>false</td></tr>
		<tr><td>`cancelable`</td><td>false</td></tr>   
		<tr><td>`currentTarget`</td><td>The Object that defines the 
		event listener that handles the event. For example, if you use 
		`myButton.addEventListener()` to register an event listener, 
		myButton is the value of the `currentTarget`. </td></tr>
		<tr><td>`faultCode`</td><td>Provides destination-specific
		details of the failure.</td></tr>
		<tr><td>`faultDetail`</td><td>Provides access to the
		destination-specific reason for the failure.</td></tr>
		<tr><td>`faultString`</td><td>Provides access to the underlying
		reason for the failure if the channel did not raise the failure itself.</td></tr>
		<tr><td>`message`</td><td>The ErrorMessage for this event.</td></tr>    
		<tr><td>`rootCause`</td><td> Provides access to the underlying reason
		for the failure, if one exists.</td></tr>         
		<tr><td>`target`</td><td>The Object that dispatched the event; 
		it is not always the Object listening for the event. 
		Use the `currentTarget` property to always access the 
		Object listening for the event.</td></tr>
		</table>
	**/
	public static final FAULT:String = "fault";

	//--------------------------------------------------------------------------
	//
	// Static Methods
	//
	//--------------------------------------------------------------------------

	/**
		Utility method to create a new MessageFaultEvent that doesn't bubble and
		is not cancelable.

		@param message The ErrorMessage associated with the fault.

		@return New MessageFaultEvent.
	**/
	public static function createEvent(msg:ErrorMessage):MessageFaultEvent {
		return new MessageFaultEvent(MessageFaultEvent.FAULT, false, false, msg);
	}

	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructs an instance of a fault message event for the specified message
		and fault information.

		@param type The type for the MessageAckEvent.

		@param bubbles Specifies whether the event can bubble up the display 
		list hierarchy.

		@param cancelable Indicates whether the behavior associated with the 
		event can be prevented.

		@param message The ErrorMessage associated with the fault.
	**/
	public function new(type:String, bubbles:Bool = false, cancelable:Bool = false, message:ErrorMessage = null) {
		super(type, bubbles, cancelable);

		this.message = message;
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/**
		The ErrorMessage for this event.
	**/
	public var message:ErrorMessage;

	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  faultCode
	//----------------------------------

	/**
		Provides access to the destination specific failure code.
		For more specific details see `faultString` and
		`faultDetails` properties.

		The format of the fault codes are provided by the remote destination,
		but, will typically have the following form: _host.operation.error_
		For example, `"Server.Connect.Failed"`

		@see #faultString
		@see #faultDetail
	**/
	@:flash.property
	public var faultCode(get, never):String;

	private function get_faultCode():String {
		return message.faultCode;
	}

	//----------------------------------
	//  faultDetail
	//----------------------------------

	/**
		Provides destination specific details of the failure.

		Typically fault details are a stack trace of an exception thrown at
		the remote destination.

		@see #faultString
		@see #faultCode
	**/
	@:flash.property
	public var faultDetail(get, never):String;

	private function get_faultDetail():String {
		return message.faultDetail;
	}

	//----------------------------------
	//  faultString
	//----------------------------------

	/**
		Provides access to the destination specific reason for the failure.

		@see #faultCode
		@see #faultDetail
	**/
	@:flash.property
	public var faultString(get, never):String;

	private function get_faultString():String {
		return message.faultString;
	}

	//----------------------------------
	//  rootCause
	//----------------------------------

	/**
		Provides access to the root cause of the failure, if one exists.

		In the case of custom exceptions thrown by a destination, the root cause
		represents the top level failure that is merely transported by the
		ErrorMessage.

		@see MessageFaultEvent#rootCause
	**/
	@:flash.property
	public var rootCause(get, never):Dynamic;

	private function get_rootCause():Dynamic {
		return message.rootCause;
	}

	//--------------------------------------------------------------------------
	//
	// Overridden Methods
	//
	//--------------------------------------------------------------------------

	/**
		Clones the MessageFaultEvent.

		@return Copy of this MessageFaultEvent.
	**/
	override public function clone():Event {
		return new MessageFaultEvent(type, bubbles, cancelable, message);
	}

	/**
		Returns a string representation of the MessageFaultEvent.

		@return String representation of the MessageFaultEvent.
	**/
	override public function toString():String {
		#if flash
		return Reflect.callMethod(this, formatToString, [
			"MessageFaultEvent",
			"faultCode",
			"faultDetail",
			"faultString",
			"rootCause",
			"type",
			"bubbles",
			"cancelable",
			"eventPhase"
		]);
		#else
		return Reflect.callMethod(this, __formatToString, [
			"MessageFaultEvent",
			[
				"faultCode",
				"faultDetail",
				"faultString",
				"rootCause",
				"type",
				"bubbles",
				"cancelable",
				"eventPhase"
			]
		]);
		#end
	}
}
