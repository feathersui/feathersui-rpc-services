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

package feathers.rpc;

import feathers.messaging.messages.IMessage;
import feathers.rpc.events.FaultEvent;
import feathers.rpc.events.ResultEvent;
import openfl.events.EventDispatcher;

/**
	This class provides a place to set additional or token-level data for 
	asynchronous RPC operations.  It also allows an IResponder to be attached
	for an individual call.
	The AsyncToken can be referenced in `ResultEvent` and 
	`FaultEvent` from the `token` property.
**/
class AsyncToken extends EventDispatcher {
	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructs an instance of the token with the specified message.

		@param message The message with which the token is associated.
	**/
	public function new(message:IMessage = null) {
		super();
		_message = message;
	}

	//--------------------------------------------------------------------------
	//
	// Public properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	// message
	//----------------------------------
	private var _message:IMessage;

	/**
		Provides access to the associated message.
	**/
	@:flash.property
	public var message(get, never):IMessage;

	private function get_message():IMessage {
		return _message;
	}

	private function setMessage(message:IMessage):Void {
		_message = message;
	}

	//----------------------------------
	// responder
	//----------------------------------
	private var _responders:Array<IResponder>;

	/**
		An array of IResponder handlers that will be called when
		the asynchronous request completes.

		Each responder assigned to the token will have its  `result`
		or `fault` function called passing in the
		matching event _before_ the operation or service dispatches the 
		event itself.

		A developer can prevent the service from subsequently dispatching the 
		event by calling `event.preventDefault()`.

		Note that this will not prevent the service or operation's 
		`result` property from being assigned.
	**/
	@:flash.property
	public var responders(get, never):Array<IResponder>;

	private function get_responders():Array<IResponder> {
		return _responders;
	}

	private var _resultEvent:ResultEvent;
	private var _faultEvent:FaultEvent;

	//----------------------------------
	// result
	//----------------------------------
	private var _result:Dynamic;

	// [Bindable(event="propertyChange")]

	/**
		The result that was returned by the associated RPC call.
		Once the result property on the token has been assigned
		it will be strictly equal to the result property on the associated
		ResultEvent.
	**/
	@:flash.property
	public var result(get, never):Dynamic;

	private function get_result():Dynamic {
		return _result;
	}

	//--------------------------------------------------------------------------
	//
	// Methods
	//
	//--------------------------------------------------------------------------

	/**
		Adds a responder to an Array of responders. 
		The object assigned to the responder parameter must implement
		`mx.rpc.IResponder`.

		@param responder A handler which will be called when the asynchronous request completes.

		@see mx.rpc.IResponder
	**/
	public function addResponder(responder:IResponder):Void {
		if (_responders == null)
			_responders = [];

		_responders.push(responder);

		// if a responder is added after the token has applied a result/fault,
		// we should tell the responder about what already happened.
		// in Flash, this can't happen because results of async http/file loads
		// are queued until after all code has run for the current frame.
		// however, OpenFL doesn't queue anything, and local file loads can
		// complete while other code is still running. OpenFL should probably
		// cache the result until the next frame too, but even if that is
		// eventually changed, we need to deal with how it works today.
		if (_resultEvent != null) {
			responder.result(_resultEvent);
		}
		if (_faultEvent != null) {
			responder.fault(_faultEvent);
		}
	}

	/**
		Determines if this token has at least one `mx.rpc.IResponder` registered.

		@return true if at least one responder has been added to this token. 
	**/
	public function hasResponder():Bool {
		return (_responders != null && _responders.length > 0);
	}

	public function applyFault(event:FaultEvent):Void {
		_faultEvent = event;
		if (_responders != null) {
			for (i in 0..._responders.length) {
				var responder = _responders[i];
				if (responder != null) {
					responder.fault(event);
				}
			}
		}
	}

	public function applyResult(event:ResultEvent):Void {
		_resultEvent = event;
		setResult(event.result);

		if (_responders != null) {
			for (i in 0..._responders.length) {
				var responder = _responders[i];
				if (responder != null) {
					responder.result(event);
				}
			}
		}
	}

	private function setResult(newResult:Dynamic):Void {
		if (_result != newResult) {
			// var event:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "result", _result, newResult);
			_result = newResult;
			// dispatchEvent(event);
		}
	}
}
