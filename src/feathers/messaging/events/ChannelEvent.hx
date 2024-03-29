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
import openfl.events.Event;

/**
	The ChannelEvent is used to propagate channel events within the messaging system.
**/
class ChannelEvent extends Event {
	//--------------------------------------------------------------------------
	//
	// Static Constants
	//
	//--------------------------------------------------------------------------

	/**
		The CONNECT event type; indicates that the Channel connected to its
		endpoint.

		The value of this constant is `"channelConnect"`.

		The properties of the event object have the following values:

		<table class="innertable">
		<tr><th>Property</th><th>Value</th></tr>
		<tr><td>`bubbles`</td><td>false</td></tr>
		<tr><td>`cancelable`</td><td>false</td></tr>
		<tr><td>`channel`</td><td>The channel that generated this event.</td></tr>   
		<tr><td>`currentTarget`</td><td>The Object that defines the 
		event listener that handles the event. For example, if you use 
		`myButton.addEventListener()` to register an event listener, 
		myButton is the value of the `currentTarget`. </td></tr>
		<tr><td>`target`</td><td>The Object that dispatched the event; 
		it is not always the Object listening for the event. 
		Use the `currentTarget` property to always access the 
		Object listening for the event.</td></tr>
		<tr><td>`reconnecting`</td><td> Indicates whether the channel
		that generated this event is reconnecting.</td></tr>
		<tr><td>`rejected`</td><td> Indicates whether the channel that
		generated this event was rejected. This would be true in the event that
		the channel has been disconnected due to inactivity and should not attempt to
		failover or connect on an alternate channel.</td></tr>   
		</table>
	**/
	public static final CONNECT:String = "channelConnect";

	/**
		The DISCONNECT event type; indicates that the Channel disconnected from its
		endpoint.

		The value of this constant is `"channelDisconnect"`.

		The properties of the event object have the following values:

		<table class="innertable">
		<tr><th>Property</th><th>Value</th></tr>
		<tr><td>`bubbles`</td><td>false</td></tr>
		<tr><td>`cancelable`</td><td>false</td></tr>
		<tr><td>`channel`</td><td>The channel that generated this event.</td></tr>   
		<tr><td>`currentTarget`</td><td>The Object that defines the 
		event listener that handles the event. For example, if you use 
		`myButton.addEventListener()` to register an event listener, 
		myButton is the value of the `currentTarget`. </td></tr>
		<tr><td>`target`</td><td>The Object that dispatched the event; 
		it is not always the Object listening for the event. 
		Use the `currentTarget` property to always access the 
		Object listening for the event.</td></tr>
		<tr><td>`reconnecting`</td><td> Indicates whether the channel
		that generated this event is reconnecting.</td></tr>
		<tr><td>`rejected`</td><td> Indicates whether the channel that
		generated this event was rejected. This would be true in the event that
		the channel has been disconnected due to inactivity and should not attempt to
		failover or connect on an alternate channel.</td></tr>   
		</table>
	**/
	public static final DISCONNECT:String = "channelDisconnect";

	//--------------------------------------------------------------------------
	//
	// Static Methods
	//
	//--------------------------------------------------------------------------

	/**
		Utility method to create a new ChannelEvent that doesn't bubble and
		is not cancelable.

		@param type The ChannelEvent type.

		@param channel The Channel generating the event.

		@param reconnecting Indicates whether the Channel is in the process of
		reconnecting or not.

		@param rejected Indicates whether the Channel's connection has been rejected,
		which suppresses automatic reconnection.

		@param connected Indicates whether the Channel that generated this event 
		is already connected.

		@return New ChannelEvent.
	**/
	public static function createEvent(type:String, channel:Channel = null, reconnecting:Bool = false, rejected:Bool = false,
			connected:Bool = false):ChannelEvent {
		return new ChannelEvent(type, false, false, channel, reconnecting, rejected, connected);
	}

	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructs an instance of this event with the specified type and Channel
		instance.

		@param type The ChannelEvent type.

		@param bubbles Specifies whether the event can bubble up the display 
		list hierarchy.

		@param cancelable Indicates whether the behavior associated with the 
		event can be prevented; used by the RPC subclasses.

		@param channel The Channel generating the event.

		@param reconnecting Indicates whether the Channel is in the process of
		reconnecting or not.

		@param rejected Indicates whether the Channel's connection has been rejected,
		which suppresses automatic reconnection.

		@param connected Indicates whether the Channel that generated this event 
		is already connected.
	**/
	public function new(type:String, bubbles:Bool = false, cancelable:Bool = false, channel:Channel = null, reconnecting:Bool = false, rejected:Bool = false,
			connected:Bool = false) {
		super(type, bubbles, cancelable);

		this.channel = channel;
		this.reconnecting = reconnecting;
		this.rejected = rejected;
		this.connected = connected;
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/**
		The Channel that generated this event.
	**/
	public var channel:Channel;

	/**
		Indicates whether the Channel that generated this event is already connected.
	**/
	public var connected:Bool;

	/**
		Indicates whether the Channel that generated this event is reconnecting.
	**/
	public var reconnecting:Bool;

	/**
		Indicates whether the Channel that generated this event was rejected. 
		This would be true in the event that the channel has been
		disconnected due to inactivity and should not attempt to failover or
		connect on an alternate channel.
	**/
	public var rejected:Bool;

	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  channelId
	//----------------------------------
	@:dox(hide)
	@:flash.property
	public var channelId(get, never):String;

	private function get_channelId():String {
		if (channel != null) {
			return channel.id;
		}
		return null;
	}

	//--------------------------------------------------------------------------
	//
	// Overridden Methods
	//
	//--------------------------------------------------------------------------

	/**
		Clones the ChannelEvent.

		@return Copy of this ChannelEvent.
	**/
	override public function clone():Event {
		return new ChannelEvent(type, bubbles, cancelable, channel, reconnecting, rejected, connected);
	}

	/**
		Returns a string representation of the ChannelEvent.

		@return String representation of the ChannelEvent.
	**/
	override public function toString():String {
		#if flash
		return Reflect.callMethod(this, formatToString, [
			"ChannelEvent",
			"channelId",
			"reconnecting",
			"rejected",
			"type",
			"bubbles",
			"cancelable",
			"eventPhase"
		]);
		#else
		return Reflect.callMethod(this, __formatToString, [
			"ChannelEvent",
			[
				"channelId",
				"reconnecting",
				"rejected",
				"type",
				"bubbles",
				"cancelable",
				"eventPhase"
			]
		]);
		#end
	}
}
