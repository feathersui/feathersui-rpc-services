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

package feathers.messaging;

import feathers.messaging.Channel;
import feathers.messaging.messages.ErrorMessage;
import feathers.messaging.messages.IMessage;
import openfl.events.TimerEvent;
import openfl.utils.Timer;
#if (openfl >= "9.2.0")
import openfl.net.Responder;
#elseif flash
import flash.net.Responder;
#end

/**
 *  The MessageResponder class handles a successful result or fault from a message
 *  destination. For each message that a Channel sends, the Channel creates a
 *  MessageResponder to handle the result. Upon a response, the Channel will
 *  invoke either the <code>result()</code> or <code>status()</code> callback
 *  on the MessageResponder. MessageResponder subclasses should override these
 *  methods to perform any necessary processing. For every response, whether a 
 *  successful result or an error, the MessageResponder should invoke 
 *  <code>acknowledge()</code> on its agent. If the response was a fault, the
 *  MessageResponder should also invoke <code>fault()</code> on its agent.
 */
class MessageResponder #if (flash || openfl >= "9.2.0") extends Responder #end {
	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
	 *  Constructs a MessageResponder to handle the response for the specified
	 *  Message for the specified MessageAgent.
	 *
	 *  @param agent The MessageAgent sending the Message.
	 * 
	 *  @param message The Message being sent.
	 * 
	 *  @param channel The Channel used to send. 
	 *  
	 */
	public function new(agent:MessageAgent, message:IMessage, channel:Channel = null) {
		#if (flash || openfl >= "9.2.0")
		super(result, status);
		#end

		_agent = agent;
		_channel = channel;
		_message = message;
		_requestTimedOut = false;
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 *  Flag indicating whether the request corresponding to this responder
	 *  has timed out. This is used by responders that cannot close
	 *  their underlying connection (NetConnection for instance) so they must 
	 *  instead ignore any response that is returned after the request timeout 
	 *  is reached.
	 */
	private var _requestTimedOut:Bool;

	/**
	 *  @private
	 *  Timer used to trigger a request timeout.
	 */
	private var _requestTimer:Timer;

	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  agent
	//----------------------------------

	/**
	 *  @private
	 */
	private var _agent:MessageAgent;

	/**
	 *  Provides access to the MessageAgent that sent the message.
	 *  
	 */
	public var agent(get, never):MessageAgent;

	private function get_agent():MessageAgent {
		return _agent;
	}

	//----------------------------------
	//  channel
	//----------------------------------

	/**
	 *  @private
	 */
	private var _channel:Channel;

	/**
	 *  Provides access to the Channel used to send the message.
	 *  
	 */
	public var channel(get, never):Channel;

	private function get_channel():Channel {
		return _channel;
	}

	//----------------------------------
	//  message
	//----------------------------------

	/**
	 *  @private
	 */
	private var _message:IMessage;

	/**
	 *  Provides access to the sent Message.
	 *  
	 */
	public var message(get, set):IMessage;

	private function get_message():IMessage {
		return _message;
	}

	private function set_message(value:IMessage):IMessage {
		_message = value;
		return _message;
	}

	//--------------------------------------------------------------------------
	//
	// Methods
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private 
	 *  Starts a timer to monitor a request timeout. If the timer hits the
	 *  specified requestTimeout before a response is returned, 
	 *  <code>requestTimedOut()</code> is invoked and any subsequent 
	 *  response is ignored by this responder.
	 * 
	 *  @param requestTimeout The amount of time in seconds to allow a request
	 *                        to run before timing it out.
	 */
	final public function startRequestTimeout(requestTimeout:Int):Void {
		_requestTimer = new Timer(requestTimeout * 1000, 1);
		_requestTimer.addEventListener(TimerEvent.TIMER, timeoutRequest);
		_requestTimer.start();
	}

	/**
	 *  Called by the channel that created this MessageResponder when a
	 *  response returns from the destination.
	 *  This method performs core result processing and then invokes the
	 *  <code>resultHandler()</code> method that subclasses may override to
	 *  perform any necessary custom processing.
	 *
	 *  @param message The result Message returned by the destination.
	 *  
	 */
	final public function result(message:IMessage):Void {
		// Ignore any response after the request has timed out.
		if (!_requestTimedOut) {
			// Shut down the timeout timer if it's alive.
			if (_requestTimer != null) {
				releaseTimer();
			}
			resultHandler(message);
		}
	}

	/**
	 *  Called by the channel that created this MessageResponder when a fault
	 *  response returns from the destination.
	 *  This method performs core result processing and then invokes the
	 *  <code>statusHandler()</code> method that subclasses may override to
	 *  perform any necessary custom processing.
	 * 
	 *  @param message The fault Message returned by the destination.
	 *  
	 */
	final public function status(message:IMessage):Void {
		// Ignore any response after the request has timed out.
		if (!_requestTimedOut) {
			// Shut down the timeout timer if it's alive.
			if (_requestTimer != null) {
				releaseTimer();
			}
			statusHandler(message);
		}
	}

	//--------------------------------------------------------------------------
	//
	// Protected Members
	//
	//--------------------------------------------------------------------------

	/**
	 *  Constructs an ErrorMessage that can be passed to the associated 
	 *  MessageAgent's callbacks upon a request timeout.
	 *
	 *  @return Returns an ErrorMessage that can be passed to the associated
	 *  MessageAgent's callbacks upon a request timeout.
	 *  
	 */
	private function createRequestTimeoutErrorMessage():ErrorMessage {
		var errorMsg:ErrorMessage = new ErrorMessage();
		errorMsg.correlationId = message.messageId;
		errorMsg.faultCode = "Client.Error.RequestTimeout";
		errorMsg.faultString = "Request timed out";
		errorMsg.faultDetail = "The request timeout for the sent message was reached without receiving a response from the server.";
		return errorMsg;
	}

	/**
	 *  Subclasses must override this method to perform custom processing of
	 *  the result and invoke the proper callbacks on the associated 
	 *  MessageAgent.
	 * 
	 *  @param message The result Message returned by the destination.
	 *  
	 */
	private function resultHandler(message:IMessage):Void {}

	/**
	 *  Subclasses must override this method to handle a request timeout and 
	 *  invoke the proper callbacks on the associated MessageAgent.
	 *  
	 */
	private function requestTimedOut():Void {}

	/**
	 *  Subclasses must override this method to perform custom processing of
	 *  the status and invoke the proper callbacks on the associated 
	 *  MessageAgent.
	 * 
	 *  @param message The fault Message returned by the destination.
	 *  
	 */
	private function statusHandler(message:IMessage):Void {}

	//--------------------------------------------------------------------------
	//
	// Private Members
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 *  Helper callback that flags the request as timed out before delegating
	 *  to custom timeout processing.
	 */
	private function timeoutRequest(event:TimerEvent):Void {
		_requestTimedOut = true;
		releaseTimer();
		requestTimedOut();
	}

	/**
	 *  @private
	 *  Utility method to shutdown the request timeout Timer.
	 */
	private function releaseTimer():Void {
		_requestTimer.stop();
		_requestTimer.removeEventListener(TimerEvent.TIMER, timeoutRequest);
		_requestTimer = null;
	}
}
