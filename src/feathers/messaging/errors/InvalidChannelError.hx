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
	This error is thrown when a Channel can't be accessed
	or is not valid for the current destination.
	This error is thrown by the following methods/properties
	within the framework:

	- <code>ServerConfig.getChannel()</code> if the channel
		can't be found based on channel id.
**/
class InvalidChannelError extends ChannelError {
	//--------------------------------------------------------------------------
	//
	//  Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructs a new instance of an InvalidChannelError with the specified message.

		@param msg String that contains the message that describes this InvalidChannelError.
	**/
	public function new(msg:String) {
		super(msg);
	}
}
