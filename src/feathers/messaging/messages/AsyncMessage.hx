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

import feathers.rpc.utils.RPCUIDUtil;
import openfl.utils.ByteArray;
import openfl.utils.IDataInput;
import openfl.utils.IDataOutput;

/**
 *  AsyncMessage is the base class for all asynchronous messages.
 */
@:meta(RemoteClass(alias = "flex.messaging.messages.AsyncMessage"))
class AsyncMessage extends AbstractMessage implements ISmallMessage {
	//--------------------------------------------------------------------------
	//
	// Static Constants
	//
	//--------------------------------------------------------------------------

	/**
	 *  Messages sent by a MessageAgent with a defined <code>subtopic</code>
	 *  property indicate their target subtopic in this header.
	 *  
	 */
	public static final SUBTOPIC_HEADER:String = "DSSubtopic";

	//--------------------------------------------------------------------------
	//
	// Private Static Constants for Serialization
	//
	//--------------------------------------------------------------------------
	private static final CORRELATION_ID_FLAG:UInt = 1;
	private static final CORRELATION_ID_BYTES_FLAG:UInt = 2;

	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
	 *  Constructs an instance of an AsyncMessage with an empty body and header.
	 *  In addition to this default behavior, the body and the headers for the
	 *  message may also be passed to the constructor as a convenience.
	 *  An example of this invocation approach for the body is:
	 *  <code>var msg:AsyncMessage = new AsyncMessage("Body text");</code>
	 *  An example that provides both the body and headers is:
	 *  <code>var msg:AsyncMessage = new AsyncMessage("Body text", {"customerHeader":"customValue"});</code>
	 * 
	 *  @param body The optional body to assign to the message.
	 * 
	 *  @param headers The optional headers to assign to the message.
	 *  
	 */
	public function new(body:Any = null, headers:Any = null) {
		super();

		correlationId = "";
		if (body != null)
			this.body = body;

		if (headers != null)
			this.headers = headers;
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  correlationId
	//----------------------------------

	/**
	 * @private
	 */
	private var _correlationId:String;

	/**
	 * @private
	 */
	private var correlationIdBytes:ByteArray;

	/**
	 *  Provides access to the correlation id of the message.
	 *  Used for acknowledgement and for segmentation of messages.
	 *  The <code>correlationId</code> contains the <code>messageId</code> of the
	 *  previous message that this message refers to.
	 *
	 *  @see mx.messaging.messages.AbstractMessage#messageId
	 *  
	 */
	@:flash.property
	public var correlationId(get, set):String;

	private function get_correlationId():String {
		return _correlationId;
	}

	/**
	 * @private
	 */
	private function set_correlationId(value:String):String {
		_correlationId = value;
		correlationIdBytes = null;
		return _correlationId;
	}

	//--------------------------------------------------------------------------
	//
	// Overridden Methods
	//
	//--------------------------------------------------------------------------

	/**
	 * @private
	 */
	public function getSmallMessage():IMessage {
		// If it is a subclass, it will need to override this itself if it wants to use
		// small messages.
		if (Type.getClass(this) == AsyncMessage)
			return new AsyncMessageExt(this);
		return null;
	}

	/**
	 * @private
	 */
	override public function readExternal(input:IDataInput):Void {
		super.readExternal(input);

		var flagsArray = readFlags(input);
		for (i in 0...flagsArray.length) {
			var flags = flagsArray[i];
			var reservedPosition:UInt = 0;

			if (i == 0) {
				if ((flags & CORRELATION_ID_FLAG) != 0)
					correlationId = (input.readObject() : String);

				if ((flags & CORRELATION_ID_BYTES_FLAG) != 0) {
					correlationIdBytes = (input.readObject() : ByteArray);
					correlationId = RPCUIDUtil.fromByteArray(correlationIdBytes);
				}

				reservedPosition = 2;
			}

			// For forwards compatibility, read in any other flagged objects
			// to preserve the integrity of the input stream...
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
	 * @private
	 */
	override public function writeExternal(output:IDataOutput):Void {
		super.writeExternal(output);

		if (correlationIdBytes == null)
			correlationIdBytes = RPCUIDUtil.toByteArray(_correlationId);

		var flags:UInt = 0;

		if (correlationId != null && correlationIdBytes == null)
			flags |= CORRELATION_ID_FLAG;

		if (correlationIdBytes != null)
			flags |= CORRELATION_ID_BYTES_FLAG;

		output.writeByte(flags);

		if (correlationId != null && correlationIdBytes == null)
			output.writeObject(correlationId);

		if (correlationIdBytes != null)
			output.writeObject(correlationIdBytes);
	}

	/**
	 *  @private
	 */
	override private function addDebugAttributes(attributes:Any):Void {
		super.addDebugAttributes(attributes);
		Reflect.setField(attributes, "correlationId", correlationId);
	}
}
