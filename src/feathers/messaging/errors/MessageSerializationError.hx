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

import feathers.messaging.messages.ErrorMessage;

/**
	This error indicates a problem serializing a message within a channel.
	It provides a fault property which corresponds to an ErrorMessage generated
	when this error is thrown.
**/
class MessageSerializationError extends MessagingError {
	//--------------------------------------------------------------------------
	//
	//  Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructs a new instance of the MessageSerializationError
		with the specified message.

		@param msg String that contains the message that describes the error.
		@param fault Provides specific information about the fault that occured
		and for which message.
	**/
	public function new(msg:String, fault:ErrorMessage) {
		super(msg);
		this.fault = fault;
	}

	//--------------------------------------------------------------------------
	//
	//  Variables
	//
	//--------------------------------------------------------------------------

	/**
		Provides specific information about the fault that occurred and for
		which message.
	**/
	public var fault:ErrorMessage;
}
