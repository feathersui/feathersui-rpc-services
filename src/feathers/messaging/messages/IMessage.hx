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
	This interface defines the contract for message objects.
**/
interface IMessage {
	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  body
	//----------------------------------

	/**
		The body of a message contains the specific data that needs to be 
		delivered to the remote destination.
	**/
	@:flash.property
	var body(get, set):Any;

	//----------------------------------
	//  clientId
	//----------------------------------

	/**
		The clientId indicates which client sent the message.
	**/
	@:flash.property
	var clientId(get, set):String;

	//----------------------------------
	//  destination
	//----------------------------------

	/**
		The message destination.
	**/
	@:flash.property
	var destination(get, set):String;

	//----------------------------------
	//  headers
	//----------------------------------

	/**
		Provides access to the headers of the message.
		The headers of a message are an associative array where the key is the
		header name.
		This property provides access to specialized meta information for the 
		specific message instance.
	**/
	@:flash.property
	var headers(get, set):Any;

	//----------------------------------
	//  messageId
	//----------------------------------

	/**
		The unique id for the message.
		The message id can be used to correlate a response to the original
		request message in request-response messaging scenarios.
	**/
	@:flash.property
	var messageId(get, set):String;

	//----------------------------------
	//  timestamp
	//----------------------------------

	/**
		Provides access to the time stamp for the message.
		A time stamp is the date and time that the message was sent.
		The time stamp is used for tracking the message through the system,
		ensuring quality of service levels and providing a mechanism for
		expiration.

		@see `IMessage.timeToLive`
	**/
	@:flash.property
	var timestamp(get, set):Float;

	//----------------------------------
	//  timeToLive
	//----------------------------------

	/**
		The time to live value of a message indicates how long the message
		should be considered valid and deliverable.
		This value works in conjunction with the `timestamp` value.
		Time to live is the number of milliseconds that this message remains
		valid starting from the specified `timestamp` value.
		For example, if the `timestamp` value is 04/05/05 1:30:45 PST
		and the `timeToLive` value is 5000, then this message will
		expire at 04/05/05 1:30:50 PST.
		Once a message expires it will not be delivered to any other clients.
	**/
	@:flash.property
	var timeToLive(get, set):Float;

	//--------------------------------------------------------------------------
	//
	// Methods
	//
	//--------------------------------------------------------------------------

	/**
		This method will return a string representation of the message.

		@return String representation of the message.
	**/
	function toString():String;
}
