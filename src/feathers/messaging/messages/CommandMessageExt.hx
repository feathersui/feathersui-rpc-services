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

import openfl.utils.IDataOutput;
import openfl.utils.IExternalizable;

/**
	A special serialization wrapper for CommandMessage. This wrapper is used to
	enable the externalizable form of an CommandMessage for serialization. The
	wrapper must be applied just before the message is serialized as it does not
	proxy any information to the wrapped message.
**/
@:dox(hide)
@:meta(RemoteClass(alias = "DSC"))
class CommandMessageExt extends CommandMessage implements IExternalizable {
	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------
	public function new(message:CommandMessage = null) {
		super();
		_message = message;
	}

	override public function writeExternal(output:IDataOutput):Void {
		if (_message != null)
			_message.writeExternal(output);
		else
			super.writeExternal(output);
	}

	/**
		The unique id for the message.
	**/
	override private function get_messageId():String {
		/* If we are wrapping another message, use its messageId */
		if (_message != null)
			return _message.messageId;

		return super.messageId;
	}

	private var _message:CommandMessage;
}
