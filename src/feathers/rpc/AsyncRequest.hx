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

import feathers.messaging.Producer;
import feathers.messaging.events.MessageEvent;
import feathers.messaging.events.MessageFaultEvent;
import feathers.messaging.messages.AcknowledgeMessage;
import feathers.messaging.messages.ErrorMessage;
import feathers.messaging.messages.IMessage;

/**
	The AsyncRequest class provides an abstraction of messaging for RPC call invocation.
	An AsyncRequest allows multiple requests to be made on a remote destination
	and will call back to the responder specified within the request when
	the remote request is completed.
**/
class AsyncRequest extends Producer {
	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructs a new asynchronous request.
	**/
	public function new() {
		super();
	}

	//--------------------------------------------------------------------------
	//
	// Public Methods
	//
	//--------------------------------------------------------------------------

	/**
		Delegates to the results to responder
		@param    ack Message acknowlegdement of message previously sent
		@param    msg Message that was recieved the acknowledgement
	**/
	@:dox(hide)
	override public function acknowledge(ack:AcknowledgeMessage, msg:IMessage):Void {
		var error:Bool = Reflect.field(ack.headers, AcknowledgeMessage.ERROR_HINT_HEADER);
		// super will clean the error hint from the message
		super.acknowledge(ack, msg);
		// if acknowledge is *not* for a message that caused an error
		// dispatch a result event
		if (!error) {
			var act:String = ack.correlationId;
			var resp:IResponder = _pendingRequests.get(act);
			if (resp != null) {
				_pendingRequests.remove(act);
				resp.result(MessageEvent.createEvent(MessageEvent.RESULT, ack));
			}
		}
	}

	/**
		Delegates to the fault to responder
		@param    error message. The error codes and information are contained in the `headers` property
		@param    msg Message original message that caused the fault.
	**/
	@:dox(hide)
	override public function fault(errMsg:ErrorMessage, msg:IMessage):Void {
		super.fault(errMsg, msg);

		if (_ignoreFault)
			return;

		// This used to use the errMsg.correlationId here but
		// if the server fails to deserialize the message (like if
		// the body references a non-existent server class)
		// it cannot supply a correlationId to the error message.
		var act:String = msg.messageId;
		var resp:IResponder = _pendingRequests.get(act);
		if (resp != null) {
			_pendingRequests.remove(act);
			resp.fault(MessageFaultEvent.createEvent(errMsg));
		}
	}

	/**
		Returns `true` if there are any pending requests for the passed in message.

		@param msg The message for which the existence of pending requests is checked.

		@return Returns `true` if there are any pending requests for the 
		passed in message; otherwise, returns `false`.
	**/
	override public function hasPendingRequestForMessage(msg:IMessage):Bool {
		var act:String = msg.messageId;
		return _pendingRequests.exists(act) && _pendingRequests.get(act) != null;
	}

	/**
		Dispatches the asynchronous request and stores the responder to call
		later.

		@param msg The message to be sent asynchronously.

		@param responder The responder to be called later.
	**/
	public function invoke(msg:IMessage, responder:IResponder):Void {
		_pendingRequests.set(msg.messageId, responder);
		send(msg);
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/**
		manages a list of all pending requests.  each request must implement
		IResponder
	**/
	private var _pendingRequests:Map<String, IResponder> = [];
}
