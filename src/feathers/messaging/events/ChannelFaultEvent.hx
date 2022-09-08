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

import feathers.messaging.Channel;
import feathers.messaging.messages.ErrorMessage;
import openfl.events.Event;

/**
	The ChannelFaultEvent class is used to propagate channel fault events within the messaging system.
**/
class ChannelFaultEvent extends ChannelEvent {
	//--------------------------------------------------------------------------
	//
	// Static Constants
	//
	//--------------------------------------------------------------------------

	/**
		The FAULT event type; indicates that the Channel faulted.

		The value of this constant is `"channelFault"`.

		The properties of the event object have the following values:

		<table class="innertable">
		<tr><th>Property</th><th>Value</th></tr>
		<tr><td>`bubbles`</td><td>false</td></tr>
		<tr><td>`cancelable`</td><td>false</td></tr>
		<tr><td>`channel`</td><td>The Channel that generated this event.</td></tr>   
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
		<tr><td>`reconnecting`</td><td> Indicates whether the channel
		that generated this event is reconnecting.</td></tr> 
		<tr><td>`rootCause`</td><td> Provides access to the underlying reason
		for the failure if the channel did not raise the failure itself.</td></tr>         
		<tr><td>`target`</td><td>The Object that dispatched the event; 
		it is not always the Object listening for the event. 
		Use the `currentTarget` property to always access the 
		Object listening for the event.</td></tr>
		</table>
	**/
	public static final FAULT:String = "channelFault";

	//--------------------------------------------------------------------------
	//
	// Static Methods
	//
	//--------------------------------------------------------------------------

	/**
		Utility method to create a new ChannelFaultEvent that doesn't bubble and
		is not cancelable.

		@param channel The Channel generating the event.

		@param reconnecting Indicates whether the Channel is in the process of
		reconnecting or not.

		@param code The fault code.

		@param level The fault level.

		@param description The fault description.

		@param rejected Indicates whether the Channel's connection has been rejected,
		which suppresses automatic reconnection.

		@param connected Indicates whether the Channel that generated this event 
		is already connected.

		@return New ChannelFaultEvent.
	**/
	public static function createEvent(channel:Channel, reconnecting:Bool = false, code:String = null, level:String = null, description:String = null,
			rejected:Bool = false, connected:Bool = false):ChannelFaultEvent {
		return new ChannelFaultEvent(ChannelFaultEvent.FAULT, false, false, channel, reconnecting, code, level, description, rejected, connected);
	}

	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructs an instance of this event with the specified type.
		Note that the `rejected` and `connected` arguments that correspond to properties
		defined by the super-class `ChannelEvent` were not originally included in this method signature and have been 
		added at the end of the argument list to preserve backward compatibility even though this signature differs from 
		`ChannelEvent`'s constructor.

		@param type The type of the event.

		@param bubbles Indicates whether the event can bubble up the display list hierarchy.

		@param cancelable Indicates whether the behavior associated with the event can be prevented.

		@param channel The Channel generating the event.

		@param reconnecting Indicates whether the Channel is in the process of
		reconnecting or not.

		@param code The fault code.

		@param level The fault level.

		@param description The fault description.

		@param rejected Indicates whether the Channel's connection has been rejected,
		which suppresses automatic reconnection.

		@param connected Indicates whether the Channel that generated this event 
		is already connected.
	**/
	public function new(type:String, bubbles:Bool = false, cancelable:Bool = false, channel:Channel = null, reconnecting:Bool = false, code:String = null,
			level:String = null, description:String = null, rejected:Bool = false, connected:Bool = false) {
		super(type, bubbles, cancelable, channel, reconnecting, rejected, connected);

		faultCode = code;
		faultString = level;
		faultDetail = description;
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/**
		Provides access to the destination-specific failure code. For more 
		specific details see the `faultString` and 
		`faultDetails` properties.

		The format of the fault codes are provided by the remote destination, 
		but will typically have the following form: `host.operation.error`
		or `Channel.operation.error`.
		For example, `"Server.Connect.Failed"` and `Channel.Connect.Failed`.

		Channel.Connect.Failed is issued by the Channel class and its subclasses
		(RTMPChannel, AMFChannel, HTTPChannel, and so forth) whenever there is an issue
		in a Channel's connect attempts to the remote destination. Channel.Call.Failed is
		issued by the AMFChannel when the channel is already connected but it gets a
		Call.Failed code from its underlying NetConnection.
		Only the AMFChannel class listens for NetConnection.Call.Failed, which gets
		converted to Channel.Call.Failed.

		@see #faultString
		@see #faultDetail
	**/
	public var faultCode:String;

	/**
		Provides destination-specific details of the failure.

		Typically fault details are a stack trace of an exception thrown at 
		the remote destination.

		@see #faultString
		@see #faultCode
	**/
	public var faultDetail:String;

	/**
		Provides access to the destination-specific reason for the failure.

		@see #faultCode
		@see #faultDetail
	**/
	public var faultString:String;

	/**
		Provides access to the underlying reason for the failure if the channel did
		not raise the failure itself.
	**/
	public var rootCause:Dynamic;

	//--------------------------------------------------------------------------
	//
	// Overridden Methods
	//
	//--------------------------------------------------------------------------

	/**
		Clones the ChannelFaultEvent.

		@return Copy of this ChannelFaultEvent.
	**/
	override public function clone():Event {
		var faultEvent:ChannelFaultEvent = new ChannelFaultEvent(type, bubbles, cancelable, channel, reconnecting, faultCode, faultString, faultDetail,
			rejected, connected);
		faultEvent.rootCause = rootCause;
		return faultEvent;
	}

	/**
		Returns a string representation of the ChannelFaultEvent.

		@return String representation of the ChannelFaultEvent.
	**/
	override public function toString():String {
		#if flash
		return Reflect.callMethod(this, formatToString, [
			"ChannelFaultEvent",
			"faultCode",
			"faultString",
			"faultDetail",
			"channelId",
			"type",
			"bubbles",
			"cancelable",
			"eventPhase"
		]);
		#else
		return Reflect.callMethod(this, __formatToString, [
			"ChannelFaultEvent",
			[
				"faultCode",
				"faultString",
				"faultDetail",
				"channelId",
				"type",
				"bubbles",
				"cancelable",
				"eventPhase"
			]
		]);
		#end
	}

	//--------------------------------------------------------------------------
	//
	// Methods
	//
	//--------------------------------------------------------------------------

	/**
		Creates an ErrorMessage based on the ChannelFaultEvent by copying over
		the faultCode, faultString, faultDetail and rootCause to the new ErrorMessage.

		@return The ErrorMessage.
	**/
	public function createErrorMessage():ErrorMessage {
		var result:ErrorMessage = new ErrorMessage();
		result.faultCode = faultCode;
		result.faultString = faultString;
		result.faultDetail = faultDetail;
		result.rootCause = rootCause;
		return result;
	}
}
