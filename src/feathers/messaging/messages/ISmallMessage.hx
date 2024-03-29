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

/**
	A marker interface that is used to indicate that an IMessage has an
	alternative smaller form for serialization.
**/
interface ISmallMessage extends IMessage {
	//--------------------------------------------------------------------------
	//
	// Methods
	//
	//--------------------------------------------------------------------------

	/**
		This method must be implemented by subclasses that have a "small" form,
		typically achieved through the use of
		`flash.utils.IExternalizable`. If a small form is not
		available this method should return null.

		@return Returns An alternative representation of an
		flex.messaging.messages.IMessage so that the serialized form
		is smaller than the regular message.
	**/
	function getSmallMessage():IMessage;
}
