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

package feathers.messaging.messages;

import feathers.rpc.utils.RPCObjectUtil;
import feathers.rpc.utils.RPCUIDUtil;
import openfl.Lib;
import openfl.utils.ByteArray;
import openfl.utils.IDataInput;
import openfl.utils.IDataOutput;

/**
 *  Abstract base class for all messages.
 *  Messages have two customizable sections; headers and body.
 *  The <code>headers</code> property provides access to specialized meta
 *  information for a specific message instance.
 *  The <code>headers</code> property is an associative array with the specific
 *  header name as the key.
 *  
 *  The body of a message contains the instance specific data that needs to be
 *  delivered and processed by the remote destination.
 *  The <code>body</code> is an object and is the payload for a message.
 */
class AbstractMessage implements IMessage {
	//--------------------------------------------------------------------------
	//
	// Static Constants
	//
	//--------------------------------------------------------------------------

	/**
	 *  Messages pushed from the server may arrive in a batch, with messages in the
	 *  batch potentially targeted to different Consumer instances. 
	 *  Each message will contain this header identifying the Consumer instance that 
	 *  will receive the message.
	 *  
	 */
	public static final DESTINATION_CLIENT_ID_HEADER:String = "DSDstClientId";

	/**
	 *  Messages are tagged with the endpoint id for the Channel they are sent over.
	 *  Channels set this value automatically when they send a message.
	 *  
	 */
	public static final ENDPOINT_HEADER:String = "DSEndpoint";

	/**
	 *  This header is used to transport the global FlexClient Id value in outbound 
	 *  messages once it has been assigned by the server.
	 *  
	 */
	public static final FLEX_CLIENT_ID_HEADER:String = "DSId";

	/**
	 *  Messages sent by a MessageAgent can have a priority header with a 0-9
	 *  numerical value (0 being lowest) and the server can choose to use this
	 *  numerical value to prioritize messages to clients. 
	 *  
	 */
	public static final PRIORITY_HEADER:String = "DSPriority";

	/**
	 *  Messages that need to set remote credentials for a destination
	 *  carry the Base64 encoded credentials in this header.  
	 *  
	 */
	public static final REMOTE_CREDENTIALS_HEADER:String = "DSRemoteCredentials";

	/**
	 *  Messages that need to set remote credentials for a destination
	 *  may also need to report the character-set encoding that was used to
	 *  create the credentials String using this header.  
	 *  
	 */
	public static final REMOTE_CREDENTIALS_CHARSET_HEADER:String = "DSRemoteCredentialsCharset";

	/**
	 *  Messages sent with a defined request timeout use this header. 
	 *  The request timeout value is set on outbound messages by services or 
	 *  channels and the value controls how long the corresponding MessageResponder 
	 *  will wait for an acknowledgement, result or fault response for the message
	 *  before timing out the request.
	 *  
	 */
	public static final REQUEST_TIMEOUT_HEADER:String = "DSRequestTimeout";

	/**
	 *  A status code can provide context about the nature of a response
	 *  message. For example, messages received from an HTTP based channel may
	 *  need to report the HTTP response status code (if available).
	 *  
	 */
	public static final STATUS_CODE_HEADER:String = "DSStatusCode";

	//--------------------------------------------------------------------------
	//
	// Private Static Constants for Serialization
	//
	//--------------------------------------------------------------------------
	private static final HAS_NEXT_FLAG:UInt = 128;
	private static final BODY_FLAG:UInt = 1;
	private static final CLIENT_ID_FLAG:UInt = 2;
	private static final DESTINATION_FLAG:UInt = 4;
	private static final HEADERS_FLAG:UInt = 8;
	private static final MESSAGE_ID_FLAG:UInt = 16;
	private static final TIMESTAMP_FLAG:UInt = 32;
	private static final TIME_TO_LIVE_FLAG:UInt = 64;
	private static final CLIENT_ID_BYTES_FLAG:UInt = 1;
	private static final MESSAGE_ID_BYTES_FLAG:UInt = 2;

	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
	 *  Constructs an instance of an AbstractMessage with an empty body and header.
	 *  This message type should not be instantiated or used directly.
	 *  
	 */
	public function new() {}

	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  body
	//----------------------------------

	/**
	 *  @private
	 */
	private var _body:Any = {};

	/**
	 *  The body of a message contains the specific data that needs to be 
	 *  delivered to the remote destination.
	 *  
	 */
	public var body(get, set):Any;

	private function get_body():Any {
		return _body;
	}

	/**
	 *  @private
	 */
	private function set_body(value:Any):Any {
		_body = value;
		return _body;
	}

	//----------------------------------
	//  clientId
	//----------------------------------

	/**
	 *  @private
	 */
	private var _clientId:String;

	/**
	 * @private
	 */
	private var clientIdBytes:ByteArray;

	/**
	 *  The clientId indicates which MessageAgent sent the message.
	 *  
	 */
	public var clientId(get, set):String;

	private function get_clientId():String {
		return _clientId;
	}

	/**
	 *  @private
	 */
	private function set_clientId(value:String):String {
		_clientId = value;
		clientIdBytes = null;
		return _clientId;
	}

	//----------------------------------
	//  destination
	//----------------------------------

	/**
	 *  @private
	 */
	private var _destination:String = "";

	/**
	 *  The message destination.
	 *  
	 */
	public var destination(get, set):String;

	private function get_destination():String {
		return _destination;
	}

	/**
	 *  @private
	 */
	private function set_destination(value:String):String {
		_destination = value;
		return _destination;
	}

	//----------------------------------
	//  headers
	//----------------------------------

	/**
	 *  @private
	 */
	private var _headers:Any;

	/**
	 *  The headers of a message are an associative array where the key is the
	 *  header name and the value is the header value.
	 *  This property provides access to the specialized meta information for the 
	 *  specific message instance.
	 *  Core header names begin with a 'DS' prefix. Custom header names should start 
	 *  with a unique prefix to avoid name collisions.
	 *  
	 */
	public var headers(get, set):Any;

	private function get_headers():Any {
		if (_headers == null)
			_headers = {};

		return _headers;
	}

	/**
	 *  @private
	 */
	private function set_headers(value:Any):Any {
		_headers = value;
		return _headers;
	}

	//----------------------------------
	//  messageId
	//----------------------------------

	/**
	 *  @private
	 */
	private var _messageId:String;

	/**
	 * @private
	 */
	private var messageIdBytes:ByteArray;

	/**
	 *  The unique id for the message.
	 *  
	 */
	public var messageId(get, set):String;

	private function get_messageId():String {
		if (_messageId == null)
			_messageId = RPCUIDUtil.createUID();

		return _messageId;
	}

	/**
	 *  @private
	 */
	private function set_messageId(value:String):String {
		_messageId = value;
		messageIdBytes = null;
		return _messageId;
	}

	//----------------------------------
	//  timestamp
	//----------------------------------

	/**
	 *  @private
	 */
	private var _timestamp:Float = 0;

	/**
	 *  Provides access to the time stamp for the message.
	 *  A time stamp is the date and time that the message was sent.
	 *  The time stamp is used for tracking the message through the system,
	 *  ensuring quality of service levels and providing a mechanism for
	 *  message expiration.
	 *
	 *  @see #timeToLive
	 *  
	 */
	public var timestamp(get, set):Float;

	private function get_timestamp():Float {
		return _timestamp;
	}

	/**
	 *  @private
	 */
	private function set_timestamp(value:Float):Float {
		_timestamp = value;
		return _timestamp;
	}

	//----------------------------------
	//  timeToLive
	//----------------------------------

	/**
	 *  @private
	 */
	private var _timeToLive:Float = 0;

	/**
	 *  The time to live value of a message indicates how long the message
	 *  should be considered valid and deliverable.
	 *  This value works in conjunction with the <code>timestamp</code> value.
	 *  Time to live is the number of milliseconds that this message remains
	 *  valid starting from the specified <code>timestamp</code> value.
	 *  For example, if the <code>timestamp</code> value is 04/05/05 1:30:45 PST
	 *  and the <code>timeToLive</code> value is 5000, then this message will
	 *  expire at 04/05/05 1:30:50 PST.
	 *  Once a message expires it will not be delivered to any other clients.
	 *  
	 */
	public var timeToLive(get, set):Float;

	private function get_timeToLive():Float {
		return _timeToLive;
	}

	/**
	 *  @private
	 */
	private function set_timeToLive(value:Float):Float {
		_timeToLive = value;
		return _timeToLive;
	}

	//--------------------------------------------------------------------------
	//
	// Methods
	//
	//--------------------------------------------------------------------------

	/**
	 * @private
	 * 
	 * While this class itself does not implement flash.utils.IExternalizable,
	 * ISmallMessage implementations will typically use IExternalizable to
	 * serialize themselves in a smaller form. This method supports this
	 * functionality by implementing IExternalizable.readExternal(IDataInput) to
	 * deserialize the properties for this abstract base class.
	 */
	public function readExternal(input:IDataInput):Void {
		var flagsArray = readFlags(input);

		for (i in 0...flagsArray.length) {
			var flags = flagsArray[i];
			var reservedPosition:UInt = 0;

			if (i == 0) {
				if ((flags & BODY_FLAG) != 0)
					readExternalBody(input);
				else
					body = null; // default body is {} so need to set it here

				if ((flags & CLIENT_ID_FLAG) != 0)
					clientId = input.readObject();

				if ((flags & DESTINATION_FLAG) != 0)
					destination = (input.readObject() : String);

				if ((flags & HEADERS_FLAG) != 0)
					headers = input.readObject();

				if ((flags & MESSAGE_ID_FLAG) != 0)
					messageId = (input.readObject() : String);

				if ((flags & TIMESTAMP_FLAG) != 0)
					timestamp = (input.readObject() : Float);

				if ((flags & TIME_TO_LIVE_FLAG) != 0)
					timeToLive = (input.readObject() : Float);

				reservedPosition = 7;
			} else if (i == 1) {
				if ((flags & CLIENT_ID_BYTES_FLAG) != 0) {
					clientIdBytes = (input.readObject() : ByteArray);
					clientId = RPCUIDUtil.fromByteArray(clientIdBytes);
				}

				if ((flags & MESSAGE_ID_BYTES_FLAG) != 0) {
					messageIdBytes = (input.readObject() : ByteArray);
					messageId = RPCUIDUtil.fromByteArray(messageIdBytes);
				}

				reservedPosition = 2;
			}

			// For forwards compatibility, read in any other flagged objects to
			// preserve the integrity of the input stream...
			if ((flags >> reservedPosition) != 0) {
				for (j in reservedPosition...6) {
					if (((flags >> j) & 1) != 0) {
						input.readObject();
					}
				}
			}
		}
	}

	/**
	 *  Returns a string representation of the message.
	 *
	 *  @return String representation of the message.
	 *  
	 */
	public function toString():String {
		return RPCObjectUtil.toString(this);
	}

	/**
	 * @private
	 * 
	 * While this class itself does not implement flash.utils.IExternalizable,
	 * ISmallMessage implementations will typically use IExternalizable to
	 * serialize themselves in a smaller form. This method supports this
	 * functionality by implementing IExternalizable.writeExternal(IDataOutput)
	 * to efficiently serialize the properties for this abstract base class.
	 */
	public function writeExternal(output:IDataOutput):Void {
		var flags:UInt = 0;

		// Since we're using custom serialization, we have to invoke the
		// messageId getter to ensure we have a valid id for the message.
		var checkForMessageId:String = messageId;

		if (clientIdBytes == null)
			clientIdBytes = RPCUIDUtil.toByteArray(_clientId);

		if (messageIdBytes == null)
			messageIdBytes = RPCUIDUtil.toByteArray(_messageId);

		if (body != null)
			flags |= BODY_FLAG;

		if (clientId != null && clientIdBytes == null)
			flags |= CLIENT_ID_FLAG;

		if (destination != null)
			flags |= DESTINATION_FLAG;

		if (headers != null)
			flags |= HEADERS_FLAG;

		if (messageId != null && messageIdBytes == null)
			flags |= MESSAGE_ID_FLAG;

		if (timestamp != 0)
			flags |= TIMESTAMP_FLAG;

		if (timeToLive != 0)
			flags |= TIME_TO_LIVE_FLAG;

		if (clientIdBytes != null || messageIdBytes != null)
			flags |= HAS_NEXT_FLAG;

		output.writeByte(flags);

		flags = 0;

		if (clientIdBytes != null)
			flags |= CLIENT_ID_BYTES_FLAG;

		if (messageIdBytes != null)
			flags |= MESSAGE_ID_BYTES_FLAG;

		// This is only read if the previous flag has HAS_NEXT_FLAG set
		if (flags != 0)
			output.writeByte(flags);

		if (body != null)
			writeExternalBody(output);

		if (clientId != null && clientIdBytes == null)
			output.writeObject(clientId);

		if (destination != null)
			output.writeObject(destination);

		if (headers != null)
			output.writeObject(headers);

		if (messageId != null && messageIdBytes == null)
			output.writeObject(messageId);

		if (timestamp != 0)
			output.writeObject(timestamp);

		if (timeToLive != 0)
			output.writeObject(timeToLive);

		if (clientIdBytes != null)
			output.writeObject(clientIdBytes);

		if (messageIdBytes != null)
			output.writeObject(messageIdBytes);
	}

	//--------------------------------------------------------------------------
	//
	// Protected Methods
	//
	//--------------------------------------------------------------------------

	private function addDebugAttributes(attributes:Any):Void {
		Reflect.setField(attributes, "body", body);
		Reflect.setField(attributes, "clientId", clientId);
		Reflect.setField(attributes, "destination", destination);
		Reflect.setField(attributes, "headers", headers);
		Reflect.setField(attributes, "messageId", messageId);
		Reflect.setField(attributes, "timestamp", timestamp);
		Reflect.setField(attributes, "timeToLive", timeToLive);
	}

	final private function getDebugString():String {
		var result:String = "(" + Lib.getQualifiedClassName(this) + ")";

		var attributes:Any = {};
		addDebugAttributes(attributes);

		var propertyNames:Array<String> = [];
		for (propertyName in Reflect.fields(attributes)) {
			propertyNames.push(propertyName);
		}
		// propertyNames.sort();

		var length = propertyNames.length;
		for (i in 0...length) {
			var name:String = propertyNames[i];
			var value:Any = Reflect.field(attributes, name);
			var valueAsString:String = RPCObjectUtil.toString(value);
			result += '\n  $name=$valueAsString';
		}

		return result;
	}

	private function readExternalBody(input:IDataInput):Void {
		body = input.readObject();
	}

	/**
	 * To support efficient serialization for ISmallMessage implementations,
	 * this utility method reads in the property flags from an IDataInput
	 * stream. Flags are read in one byte at a time. Flags make use of
	 * sign-extension so that if the high-bit is set to 1 this indicates that
	 * another set of flags follows.
	 * 
	 * @return The Array of property flags. Each flags byte is stored as a uint
	 * in the Array.
	 */
	private function readFlags(input:IDataInput):Array<UInt> {
		var hasNextFlag:Bool = true;
		var flagsArray:Array<UInt> = [];

		while (hasNextFlag && input.bytesAvailable > 0) {
			var flags = input.readUnsignedByte();
			flagsArray.push(flags);

			if ((flags & HAS_NEXT_FLAG) != 0)
				hasNextFlag = true;
			else
				hasNextFlag = false;
		}

		return flagsArray;
	}

	private function writeExternalBody(output:IDataOutput):Void {
		output.writeObject(body);
	}
}
