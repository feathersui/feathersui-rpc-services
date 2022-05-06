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

import feathers.messaging.messages.AbstractMessage;
import feathers.messaging.messages.IMessage;
import openfl.events.Event;
import openfl.events.EventType;

/**
	The event that indicates an RPC operation has successfully returned a result.
**/
class ResultEvent extends AbstractEvent {
	//--------------------------------------------------------------------------
	//
	//  Class constants
	//
	//--------------------------------------------------------------------------

	/**
		The RESULT event type.

		The properties of the event object have the following values:

		<table class="innertable">
		<tr><th>Property</th><th>Value</th></tr>
		<tr><td><code>bubbles</code></td><td>false</td></tr>
		<tr><td><code>cancelable</code></td><td>true, preventDefault() 
		from the associated token's responder.result method will prevent
		the service or operation from dispatching this event</td></tr>
		<tr><td><code>currentTarget</code></td><td>The Object that defines the 
		event listener that handles the event. For example, if you use 
		<code>myButton.addEventListener()</code> to register an event listener, 
		myButton is the value of the <code>currentTarget</code>. </td></tr>
		<tr><td><code>message</code></td><td> The Message associated with this event.</td></tr>
		<tr><td><code>target</code></td><td>The Object that dispatched the event; 
		it is not always the Object listening for the event. 
		Use the <code>currentTarget</code> property to always access the 
		Object listening for the event.</td></tr>
		<tr><td><code>result</code></td><td>Result that the RPC call returns.</td></tr>
		<tr><td><code>token</code></td><td>The token that represents the indiviudal call
		to the method. Used in the asynchronous completion token pattern.</td></tr>
		</table> 
	**/
	public static final RESULT:EventType<ResultEvent> = "result";

	//--------------------------------------------------------------------------
	//
	//  Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Creates a new ResultEvent.

		@param type The event type; indicates the action that triggered the event.
		@param bubbles Specifies whether the event can bubble up the display list hierarchy.
		@param cancelable Specifies whether the behavior associated with the event can be prevented.
		@param result Object that holds the actual result of the call.
		@param token Token that represents the call to the method. Used in the asynchronous completion token pattern.
		@param message Source Message of the result.
	**/
	public function new(type:String, bubbles:Bool = false, cancelable:Bool = true, result:Dynamic = null, token:AsyncToken = null, message:IMessage = null) {
		super(type, bubbles, cancelable, token, message);

		if (message != null && message.headers != null) {
			_statusCode = (Reflect.field(message.headers, AbstractMessage.STATUS_CODE_HEADER) : Int);
		}

		_result = result;
	}

	//--------------------------------------------------------------------------
	//
	//  Properties
	//
	//--------------------------------------------------------------------------

	/**
		In certain circumstances, headers may also be returned with a result to
		provide further context.
	**/
	@:flash.property
	public var headers(get, set):Any;

	private function get_headers():Any {
		return _headers;
	}

	private function set_headers(value:Any):Any {
		_headers = value;
		return _headers;
	}

	/**
		Result that the RPC call returns.
	**/
	@:flash.property
	public var result(get, never):Dynamic;

	private function get_result():Dynamic {
		return _result;
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

	public static function createEvent(result:Dynamic = null, token:AsyncToken = null, message:IMessage = null):ResultEvent {
		return new ResultEvent(ResultEvent.RESULT, false, true, result, token, message);
	}

	/**
		Because this event can be re-dispatched we have to implement clone to
		return the appropriate type, otherwise we will get just the standard
		event type.
	**/
	override public function clone():Event {
		return new ResultEvent(type, bubbles, cancelable, result, token, message);
	}

	/**
		Returns a string representation of the ResultEvent.

		@return String representation of the ResultEvent.
	**/
	override public function toString():String {
		return formatToString("ResultEvent", "messageId", "type", "bubbles", "cancelable", "eventPhase");
	}

	/*
		Have the token apply the result.
	**/
	override private function callTokenResponders():Void {
		if (token != null) {
			token.applyResult(this);
		}
	}

	private function setResult(r:Dynamic):Void {
		_result = r;
	}

	//--------------------------------------------------------------------------
	//
	//  Private Variables
	//
	//--------------------------------------------------------------------------
	private var _result:Dynamic;
	private var _headers:Any;
	private var _statusCode:Int;
}
