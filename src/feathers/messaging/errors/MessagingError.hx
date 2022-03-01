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

import openfl.errors.Error;

/**
 *  This is the base class for any messaging related error.
 *  It allows for less granular catch code.
 */
class MessagingError extends Error {
	//--------------------------------------------------------------------------
	//
	//  Constructor
	//
	//--------------------------------------------------------------------------

	/**
	 *  Constructs a new instance of a MessagingError with the
	 *  specified message.
	 *
	 *  @param msg String that contains the message that describes the error.
	 *  
	 */
	public function new(msg:String) {
		super(msg);
	}

	//--------------------------------------------------------------------------
	//
	//  Methods
	//
	//--------------------------------------------------------------------------

	/**
	 *  Returns the string "[MessagingError]" by default, and includes the message property if defined.
	 * 
	 *  @return String representation of the MessagingError.
	 *  
	 */
	#if !flash override #end public function toString():String {
		var value:String = "[MessagingError";
		if (message != null)
			value += " message='" + message + "']";
		else
			value += "]";
		return value;
	}
}
