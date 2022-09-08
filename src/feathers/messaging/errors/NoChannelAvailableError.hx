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

package feathers.messaging.errors;

/**
	This error is thrown when no Channel is available to send messages.

	This error is thrown by the following methods within the framework:

	- `ChannelSet.send()` if the ChannelSet has no channels.
**/
class NoChannelAvailableError extends MessagingError {
	//--------------------------------------------------------------------------
	//
	//  Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructs a new instance of the NoChannelAvailableError with the specified message.

		@param msg String that contains the message that describes this NoChannelAvailableError.
	**/
	public function new(msg:String) {
		super(msg);
	}
}
