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

import feathers.messaging.events.MessageEvent;
import feathers.messaging.messages.IMessage;

/**
 * The base class for events that RPC services dispatch.
 *  
 *  @langversion 3.0
 *  @playerversion Flash 9
 *  @playerversion AIR 1.1
 *  @productversion Flex 3
 */
class AbstractEvent extends MessageEvent {
	private var _token:AsyncToken;

	private function new(type:String, bubbles:Bool = false, cancelable:Bool = true, token:AsyncToken = null, message:IMessage = null) {
		super(type, bubbles, cancelable, message);

		_token = token;
	}

	/**
	 * The token that represents the call to the method. Used in the asynchronous completion token pattern.
	 *  
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion Flex 3
	 */
	public var token(get, never):AsyncToken;

	public function get_token():AsyncToken {
		return _token;
	}

	private function setToken(t:AsyncToken):Void {
		_token = t;
	}

	/**
	 * Does nothing by default.
	 *  
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion Flex 3
	 */
	private function callTokenResponders():Void {}
}
