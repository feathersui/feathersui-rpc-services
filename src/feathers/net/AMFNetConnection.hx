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

	AMF JavaScript library by Emil Malinov https://github.com/emilkm/amfjs
 */

package feathers.net;

import feathers.messaging.messages.ActionMessage;
import feathers.messaging.messages.ErrorMessage;
import feathers.messaging.messages.MessageBody;
import feathers.messaging.messages.MessageHeader;
import feathers.utils.AMFReader;
import feathers.utils.AMFWriter;
import openfl.Lib;
import openfl.events.ErrorEvent;
import openfl.events.Event;
import openfl.events.HTTPStatusEvent;
import openfl.events.IOErrorEvent;
import openfl.events.SecurityErrorEvent;
import openfl.net.Responder;
import openfl.net.URLLoader;
import openfl.net.URLRequest;
import openfl.net.URLRequestMethod;
import openfl.utils.ByteArray;
#if (!flash && !html5)
import openfl.net.URLRequestHeader;
#end

class AMFNetConnection {
	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------
	private static final UNKNOWN_CONTENT_LENGTH:Int = 1;
	private static final AMF0_BOOLEAN:Int = 1;
	private static final NULL_STRING:String = "null";
	private static final AMF0_AMF3:Int = 17;

	/**
	 *  Constructor
	 */
	public function new() {}

	/**
	 *  The class to use to test if success or failure
	 */
	public var errorClass:Class<Dynamic>;

	private var url:String;

	private var callPoolSize:UInt = 6;

	private var callPool:Array<CallPoolItem> = [];

	private var requestQueue:Array<RequestQueueItem> = [];

	private var queueBlocked:Bool;

	//--------------------------------------------------------------------------
	//
	// Methods
	//
	//--------------------------------------------------------------------------
	// support xhr queuing so that the same AMFNetConnection can handle multiple call requests without conflicting calls
	private function _processQueue():Void {
		var call:CallPoolItem;
		if (queueBlocked) {
			return;
		}
		for (i in 0...callPoolSize) {
			if (requestQueue.length == 0) {
				break;
			}
			if (callPool.length == i) {
				call = {
					xhr: new URLLoader(),
					busy: false,
					item: null
				};
				// call.xhr.addEventListener(ProgressEvent.PROGRESS, event -> {
				// 	trace("progress: " + event.bytesLoaded, event.bytesTotal);
				// });
				call.xhr.addEventListener(IOErrorEvent.IO_ERROR, getErrorCallback(call));
				call.xhr.addEventListener(SecurityErrorEvent.SECURITY_ERROR, getErrorCallback(call));
				call.xhr.addEventListener(HTTPStatusEvent.HTTP_STATUS, getStatusCallback(call));
				call.xhr.addEventListener(Event.COMPLETE, getCompleteCallback(call));
				if (callPoolSize > 1) {
					callPool.push(call);
				}
			} else {
				call = callPool[i];
			}
			if (!call.busy) {
				_processCallItem(call);
				if (sequence == 1 || queueBlocked) {
					return;
				}
			}
		}
	}

	private function getCompleteCallback(call:CallPoolItem):(Event) -> Void {
		return function(event:Event):Void {
			handleComplete(call);
		};
	}

	private function getStatusCallback(call:CallPoolItem):(HTTPStatusEvent) -> Void {
		return function(event:HTTPStatusEvent):Void {
			handleStatus(event, call);
		};
	}

	private function getErrorCallback(call:CallPoolItem):(ErrorEvent) -> Void {
		return function(event:ErrorEvent):Void {
			handleError(event, call);
		};
	}

	private function _processCallItem(call:CallPoolItem):Void {
		call.busy = true;
		final requestItem = requestQueue.shift();
		call.item = requestItem;

		var xhr:URLLoader = call.xhr;
		var responder:Responder = call.item.responder;
		var args:Array<Dynamic> = call.item.args;
		var urlRequest:URLRequest = new URLRequest(url);

		#if (!flash && !html5)
		for (name => value in cookies) {
			urlRequest.requestHeaders.push(new URLRequestHeader("Cookie", '$name=$value'));
		}
		#end
		urlRequest.method = URLRequestMethod.POST;
		urlRequest.contentType = "application/x-amf";
		xhr.dataFormat = BINARY;
		var actionMessage:ActionMessage = new ActionMessage();
		var messageBody:MessageBody = new MessageBody();
		sequence++;
		messageBody.targetURI = call.item.targetURI;
		messageBody.responseURI = "/" + Std.string(sequence);
		messageBody.data = args;
		actionMessage.bodies = [messageBody];
		var byteArray = new ByteArray();
		byteArray.endian = BIG_ENDIAN;
		byteArray.objectEncoding = AMF3;
		var writer:AMFWriter = new AMFWriter(byteArray);
		writer.endian = BIG_ENDIAN;
		writer.objectEncoding = AMF3;
		writeMessage(writer, actionMessage);
		urlRequest.data = byteArray;
		xhr.load(urlRequest);
	}

	private function _relinquishCall(call:CallPoolItem):Void {
		call.busy = false;
		call.item = null;
	}

	private function _startQueue():Void {
		Lib.setTimeout(_processQueue, 1);
	}

	/**
	 *  Connect to a server.  Pass in an http URL as the commmand for
	 *  connection to AMF server.
	 */
	public function connect(command:String, ...params):Void {
		// send a ping to the URL in the command param
		url = command;
	}

	/**
	 *  Call a server function.
	 */
	public function call(command:String, responder:Responder, ...params:Dynamic):Void {
		requestQueue.push({
			url: url,
			targetURI: command,
			responder: responder,
			args: params.toArray()
		});
		_startQueue();
	}

	private var sequence:Int = 0;

	private function handleComplete(call:CallPoolItem):Void {
		var xhr:URLLoader = call.xhr;
		var responder:Responder = call.item.responder;
		var args:Array<Dynamic> = call.item.args;
		try {
			var message:ActionMessage;
			var body:MessageBody;
			_relinquishCall(call);
			var bytes = cast(xhr.data, ByteArray);
			bytes.endian = BIG_ENDIAN;
			bytes.objectEncoding = AMF3;
			var reader = new AMFReader(bytes);
			reader.endian = BIG_ENDIAN;
			reader.objectEncoding = AMF3;
			try {
				message = Std.downcast(readMessage(reader), ActionMessage);
			} catch (e) {
				trace(e);
				// trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
				var error = new ErrorMessage();
				error.faultCode = "-1001";
				error.faultString = "Failed decoding the response.";
				error.faultDetail = null;
				error.extendedData = null;
				@:privateAccess responder.__status(error);
				if (requestQueue.length > 0)
					_processQueue();
				return;
			}
			var l = message.bodies.length;
			for (i in 0...l) {
				body = message.bodies[i];
				// todo review this: consider what happens if an error is thrown in the responder callback(s),
				// this should (or should not?) be caught and trigger failure here? maybe not...
				if (!Std.isOfType(body.data, errorClass))
					@:privateAccess responder.__result(body.data);
				else
					@:privateAccess responder.__status(body.data);
			}
		} catch (e) {
			_relinquishCall(call);
			var unknownError = new ErrorMessage();
			unknownError.faultCode = "-1006";
			unknownError.faultString = "Unknown error.";
			unknownError.faultDetail = e.message;
			unknownError.extendedData = null;
			@:privateAccess responder.__status(unknownError);
		}
		if (requestQueue.length > 0)
			_processQueue();
	}

	private var cookies:Map<String, String> = [];

	private function handleStatus(event:HTTPStatusEvent, call:CallPoolItem):Void {
		var xhr:URLLoader = call.xhr;
		var responder:Responder = call.item.responder;
		var args:Array<Dynamic> = call.item.args;
		if (event.status == 0) {
			_relinquishCall(call);
			var error = new ErrorMessage();
			error.faultCode = "-1004";
			error.faultString = "Invalid response type.";
			error.faultDetail = "Invalid XMLHttpRequest response status or type.";
			error.extendedData = null;
			@:privateAccess responder.__status(error);
		}
		#if (!flash && !html5)
		if (event.responseHeaders != null) {
			for (header in event.responseHeaders) {
				if (header.name == "Set-Cookie") {
					var setCookieParts = header.value.split(";");
					var cookieString = setCookieParts[0];
					var cookieStringParts = cookieString.split("=");
					if (cookieStringParts.length == 2) {
						cookies.set(cookieStringParts[0], cookieStringParts[1]);
					}
				}
			}
		}
		#end
	}

	private function handleError(event:ErrorEvent, call:CallPoolItem):Void {
		var xhr:URLLoader = call.xhr;
		var responder:Responder = call.item.responder;
		var args:Array<Dynamic> = call.item.args;

		_relinquishCall(call);
		var error = new ErrorMessage();
		error.faultCode = "-1005";
		error.faultString = "Invalid response.";
		error.faultDetail = "";
		error.extendedData = null;
		@:privateAccess responder.__status(error);
	}

	private function writeMessage(writer:AMFWriter, message:ActionMessage):Void {
		try {
			writer.writeShort(message.version);
			var l = message.headers.length;
			writer.writeShort(l);
			for (i in 0...l) {
				this.writeHeader(writer, message.headers[i]);
			}
			l = message.bodies.length;
			writer.writeShort(l);
			for (i in 0...l) {
				this.writeBody(writer, message.bodies[i]);
			}
		} catch (e) {
			trace(e);
			// trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
		}
	}

	private function writeHeader(writer:AMFWriter, header:MessageHeader):Void {
		writer.writeUTF(header.name);
		writer.writeBoolean(header.mustUnderstand);
		writer.writeInt(UNKNOWN_CONTENT_LENGTH);
		// writer.writeObject(header.data);
		trace('not sending header data:', header.data);
		writer.writeByte(AMF0_BOOLEAN);
		writer.writeBoolean(true);
	}

	private function writeBody(writer:AMFWriter, body:MessageBody):Void {
		if (body.targetURI == null) {
			writer.writeUTF(NULL_STRING);
		} else {
			writer.writeUTF(body.targetURI);
		}
		if (body.responseURI == null) {
			writer.writeUTF(NULL_STRING);
		} else {
			writer.writeUTF(body.responseURI);
		}
		writer.writeInt(UNKNOWN_CONTENT_LENGTH);

		writer.writeByte(AMF0_AMF3);
		writer.writeObject(body.data);
	}

	private function readMessage(reader:AMFReader):ActionMessage {
		var message:ActionMessage = new ActionMessage();
		message.version = reader.readUnsignedShort();
		reader.objectEncoding = message.version;
		var headerCount = reader.readUnsignedShort();
		for (i in 0...headerCount) {
			message.headers.push(this.readHeader(reader));
		}
		var bodyCount = reader.readUnsignedShort();
		for (i in 0...bodyCount) {
			message.bodies.push(this.readBody(reader));
		}
		return message;
	}

	private function readHeader(reader:AMFReader):MessageHeader {
		var header:MessageHeader = new MessageHeader();
		header.name = reader.readUTF();
		header.mustUnderstand = reader.readBoolean();
		// reader.pos += 4; //length
		// reader.reset();
		var len = reader.readUnsignedInt();
		// trace('readHeader len',len);
		var type = reader.readUnsignedByte();
		if (type != 2) { // amf0 string
			throw "Only string header data supported.";
		}
		header.data = reader.readUTF();
		// trace('readHeader data:',header.data);
		return header;
	}

	private function readBody(reader:AMFReader):MessageBody {
		var body:MessageBody = new MessageBody();
		body.targetURI = reader.readUTF();
		body.responseURI = reader.readUTF();
		// reader.pos += 4; //length
		var len = reader.readUnsignedInt();
		// trace('readBody len',len);
		// reader.reset();
		body.data = reader.readObject();
		return body;
	}
}

@:structInit
private class CallPoolItem {
	public function new(xhr:URLLoader, busy:Bool, item:RequestQueueItem) {
		this.xhr = xhr;
		this.busy = busy;
		this.item = item;
	}

	public var xhr:URLLoader;
	public var busy:Bool;
	public var item:RequestQueueItem;
}

@:structInit
private class RequestQueueItem {
	public function new(url:String, targetURI:String, responder:Responder, args:Array<Dynamic>) {
		this.url = url;
		this.targetURI = targetURI;
		this.responder = responder;
		this.args = args;
	}

	public var url:String;
	public var targetURI:String;
	public var responder:Responder;
	public var args:Array<Dynamic>;
}
