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

package feathers.messaging.channels;

import feathers.messaging.errors.ChannelError;
import feathers.messaging.errors.InvalidChannelError;
import feathers.messaging.errors.MessageSerializationError;
import feathers.messaging.messages.AbstractMessage;
import feathers.messaging.messages.AcknowledgeMessage;
import feathers.messaging.messages.ErrorMessage;
import feathers.messaging.messages.HTTPRequestMessage;
import feathers.messaging.messages.IMessage;
import openfl.events.ErrorEvent;
import openfl.events.Event;
import openfl.events.HTTPStatusEvent;
import openfl.events.IOErrorEvent;
import openfl.events.SecurityErrorEvent;
import openfl.events.TimerEvent;
import openfl.net.URLLoader;
import openfl.net.URLRequest;
import openfl.net.URLRequestHeader;
import openfl.net.URLVariables;

/**
 *  @private
 *  The DirectHTTPChannel class is used to turn an HTTPRequestMessage object into an
 *  HTTP request.
 *  This Channel does not connect to a Flex endpoint.
 */
class DirectHTTPChannel extends Channel {
	/**
	 *  Constructs an instance of a DirectHTTPChannel.
	 *  The parameters are not used.
	 *  
	 */
	public function new(id:String, uri:String = "") {
		super(id, uri);
		if (uri.length > 0) {
			var message:String = "Error for DirectHTTPChannel. No URI can be specified.";
			throw new InvalidChannelError(message);
		}
		clientId = ("DirectHTTPChannel" + clientCounter++);
	}

	/**
	 * @private
	 * Used by DirectHTTPMessageResponder to specify a dummy clientId for AcknowledgeMessages.
	 * Each instance of this channel gets a new clientId.
	 */
	private var clientId:String;

	/**
	 *  Indicates if this channel is connected.
	 *  
	 */
	override public function get_connected():Bool {
		return true;
	}

	/**
	 *  Indicates the protocol used by this channel.
	 *  
	 */
	override public function get_protocol():String {
		return "http";
	}

	//----------------------------------
	//  realtime
	//----------------------------------

	/**
	 *  @private
	 *  Returns true if the channel supports realtime behavior via server push or client poll.
	 */
	override private function get_realtime():Bool {
		return false;
	}

	/**
	 *  @private
	 *  Because this channel is always "connected", we ignore any connect timeout
	 *  that is reported.
	 */
	override private function connectTimeoutHandler(event:TimerEvent):Void {
		// Ignore.
	}

	/**
	 *  Returns the appropriate MessageResponder for the Channel.
	 *
	 *  @param agent The MessageAgent sending the message.
	 * 
	 *  @param message The IMessage to send.
	 * 
	 *  @return The MessageResponder to handle the send result or fault.
	 *  
	 */
	override private function getMessageResponder(agent:MessageAgent, message:IMessage):MessageResponder {
		return new DirectHTTPMessageResponder(agent, message, this, new URLLoader());
	}

	/**
	 *  Because this channel doesn't participate in hunting we will always assume
	 *  that we have connected.
	 *
	 *  @private
	 */
	override private function internalConnect():Void {
		connectSuccess();
	}

	override private function internalSend(msgResp:MessageResponder):Void {
		var httpMsgResp:DirectHTTPMessageResponder = cast(msgResp, DirectHTTPMessageResponder);
		var urlRequest:URLRequest;

		try {
			urlRequest = createURLRequest(httpMsgResp.message);
		} catch (e:MessageSerializationError) {
			httpMsgResp.agent.fault(e.fault, httpMsgResp.message);
			return;
		}

		var urlLoader:URLLoader = httpMsgResp.urlLoader;
		urlLoader.addEventListener(ErrorEvent.ERROR, httpMsgResp.errorHandler);
		urlLoader.addEventListener(IOErrorEvent.IO_ERROR, httpMsgResp.errorHandler);
		urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, httpMsgResp.securityErrorHandler);
		urlLoader.addEventListener(Event.COMPLETE, httpMsgResp.completeHandler);
		urlLoader.addEventListener(HTTPStatusEvent.HTTP_STATUS, httpMsgResp.httpStatusHandler);
		urlLoader.load(urlRequest);
	}

	/**
	 * @private
	 */
	/*override */
	private function createURLRequest(message:IMessage):URLRequest {
		var httpMsg:HTTPRequestMessage = cast(message, HTTPRequestMessage);
		var result:URLRequest = new URLRequest();
		var url:String = httpMsg.url;
		var params:String = null;

		// Propagate our requestTimeout for those platforms
		// supporting the idleTimeout property on URLRequest.
		if (Reflect.hasField(result, "idleTimeout") && requestTimeout > 0)
			Reflect.setField(result, "idleTimeout", requestTimeout * 1000);

		result.contentType = httpMsg.contentType;

		var contentTypeIsXML:Bool = result.contentType == HTTPRequestMessage.CONTENT_TYPE_XML
			|| result.contentType == HTTPRequestMessage.CONTENT_TYPE_SOAP_XML;

		var headers:Dynamic = httpMsg.httpHeaders;
		if (headers) {
			var requestHeaders:Array<URLRequestHeader> = [];
			var header:URLRequestHeader;
			for (h in Reflect.fields(headers)) {
				header = new URLRequestHeader(h, Reflect.field(headers, h));
				requestHeaders.push(header);
			}
			result.requestHeaders = requestHeaders;
		}

		if (!contentTypeIsXML) {
			var urlVariables:URLVariables = new URLVariables();
			var body = httpMsg.body;
			for (p in Reflect.fields(body))
				Reflect.setField(urlVariables, p, Reflect.field(httpMsg.body, p));

			params = Std.string(urlVariables);
		}

		if (httpMsg.method == HTTPRequestMessage.POST_METHOD || contentTypeIsXML) {
			result.method = "POST";
			if (result.contentType == HTTPRequestMessage.CONTENT_TYPE_FORM)
				result.data = params;
			else {
				// For XML content, work around bug 196450 by calling
				// XML.toXMLString() ourselves as URLRequest.data uses
				// XML.toString() hence bug 184950.
				if (httpMsg.body != null && (httpMsg.body is Xml))
					result.data = cast(httpMsg.body, Xml).toString();
				else
					result.data = httpMsg.body;
			}
		} else {
			if (params != null && params != "") {
				url += (url.indexOf("?") > -1) ? '&' : '?';
				url += params;
			}
		}
		result.url = url;

		// if (NetworkMonitor.isMonitoring())
		// {
		//     NetworkMonitor.adjustURLRequest(result, LoaderConfig.url, message.messageId);
		// }

		return result;
	}

	override public function setCredentials(credentials:String, agent:MessageAgent = null, charset:String = null):Void {
		var message:String = "Authentication not supported on DirectHTTPChannel (no proxy).";
		throw new ChannelError(message);
	}

	/**
	 * @private
	 * Incremented per new instance of the channel to create clientIds.
	 */
	private static var clientCounter:UInt = 0;
}

/**
 *  @private
 *  This is an adapter for url loader that is used by the HTTPChannel.
 */
@:access(feathers.messaging.channels.DirectHTTPChannel)
private class DirectHTTPMessageResponder extends MessageResponder {
	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
	 *  Constructs a DirectHTTPMessageResponder.
	 *  
	 */
	public function new(agent:MessageAgent, msg:IMessage, channel:DirectHTTPChannel, urlLoader:URLLoader) {
		super(agent, msg, channel);
		this.urlLoader = urlLoader;
		clientId = channel.clientId;
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/**
	 * @private
	 */
	private var clientId:String;

	/**
	 * @private
	 */
	private var lastStatus:Int;

	/**
	 *  The URLLoader associated with this responder.
	 *  
	 */
	public var urlLoader:URLLoader;

	//--------------------------------------------------------------------------
	//
	// Methods
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 */
	public function errorHandler(event:Event):Void {
		status(null);
		// send the ack
		var ack:AcknowledgeMessage = new AcknowledgeMessage();
		ack.clientId = clientId;
		ack.correlationId = message.messageId;
		Reflect.setField(ack.headers, AcknowledgeMessage.ERROR_HINT_HEADER, true); // hint there was an error
		agent.acknowledge(ack, message);
		// send fault
		var msg:ErrorMessage = new ErrorMessage();
		msg.clientId = clientId;
		msg.correlationId = message.messageId;
		msg.faultCode = "Server.Error.Request";
		msg.faultString = "HTTP request error";
		var details:String = Std.string(event);
		if ((message is HTTPRequestMessage)) {
			details += ". URL: ";
			details += cast(message, HTTPRequestMessage).url;
		}
		msg.faultDetail = 'Error: $details';
		msg.rootCause = event;
		msg.body = cast(event.target, URLLoader).data;
		Reflect.setField(msg.headers, AbstractMessage.STATUS_CODE_HEADER, lastStatus);
		agent.fault(msg, message);
	}

	/**
	 *  @private
	 */
	public function securityErrorHandler(event:Event):Void {
		status(null);
		// send the ack
		var ack:AcknowledgeMessage = new AcknowledgeMessage();
		ack.clientId = clientId;
		ack.correlationId = message.messageId;
		Reflect.setField(ack.headers, AcknowledgeMessage.ERROR_HINT_HEADER, true); // hint there was an error
		agent.acknowledge(ack, message);
		// send fault
		var msg:ErrorMessage = new ErrorMessage();
		msg.clientId = clientId;
		msg.correlationId = message.messageId;
		msg.faultCode = "Channel.Security.Error";
		msg.faultString = "Security error accessing URL";
		msg.faultDetail = 'Destination: ${message.destination}';
		msg.rootCause = event;
		msg.body = cast(event.target, URLLoader).data;
		Reflect.setField(msg.headers, AbstractMessage.STATUS_CODE_HEADER, lastStatus);
		agent.fault(msg, message);
	}

	/**
	 *  @private
	 */
	public function completeHandler(event:Event):Void {
		result(null);
		var ack:AcknowledgeMessage = new AcknowledgeMessage();
		ack.clientId = clientId;
		ack.correlationId = message.messageId;
		ack.body = cast(event.target, URLLoader).data;
		Reflect.setField(ack.headers, AbstractMessage.STATUS_CODE_HEADER, lastStatus);
		agent.acknowledge(ack, message);
	}

	/**
	 *  @private
	 */
	public function httpStatusHandler(event:HTTPStatusEvent):Void {
		lastStatus = event.status;
	}

	/**
	 *  Handle a request timeout by closing our associated URLLoader and
	 *  faulting the message to the agent.
	 *  
	 */
	override private function requestTimedOut():Void {
		urlLoader.removeEventListener(ErrorEvent.ERROR, errorHandler);
		urlLoader.removeEventListener(IOErrorEvent.IO_ERROR, errorHandler);
		urlLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
		urlLoader.removeEventListener(Event.COMPLETE, completeHandler);
		urlLoader.removeEventListener(HTTPStatusEvent.HTTP_STATUS, httpStatusHandler);
		urlLoader.close();

		status(null);
		// send the ack
		var ack:AcknowledgeMessage = new AcknowledgeMessage();
		ack.clientId = clientId;
		ack.correlationId = message.messageId;
		Reflect.setField(ack.headers, AcknowledgeMessage.ERROR_HINT_HEADER, true); // hint there was an error
		agent.acknowledge(ack, message);
		// send the fault
		agent.fault(createRequestTimeoutErrorMessage(), message);
	}
}
