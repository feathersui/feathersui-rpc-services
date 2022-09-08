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
	The ErrorMessage class is used to report errors within the messaging system.
	An error message only occurs in response to a message sent within the
	system.
**/
@:meta(RemoteClass(alias = "flex.messaging.messages.ErrorMessage"))
class ErrorMessage extends AcknowledgeMessage {
	//--------------------------------------------------------------------------
	//
	// Static Constants
	//
	//--------------------------------------------------------------------------

	/**
		If a message may not have been delivered, the `faultCode` will
		contain this constant. 
	**/
	public static final MESSAGE_DELIVERY_IN_DOUBT:String = "Client.Error.DeliveryInDoubt";

	/**
		Header name for the retryable hint header.
		This is used to indicate that the operation that generated the error
		may be retryable rather than fatal.
	**/
	public static final RETRYABLE_HINT_HEADER:String = "DSRetryableErrorHint";

	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructs an ErrorMessage instance.
	**/
	public function new() {
		super();
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/**
		The fault code for the error.
		This value typically follows the convention of
		"[outer_context].[inner_context].[issue]".
		For example: "Channel.Connect.Failed", "Server.Call.Failed", etc.
	**/
	public var faultCode:String;

	/**
		A simple description of the error.
	**/
	public var faultString:String;

	/**
		Detailed description of what caused the error.
		This is typically a stack trace from the remote destination.
	**/
	public var faultDetail:String;

	/**
		Should a root cause exist for the error, this property contains those details.
		This may be an ErrorMessage, a NetStatusEvent info Object, or an underlying
		Flash error event: ErrorEvent, IOErrorEvent, or SecurityErrorEvent.
	**/
	public var rootCause:Any;

	/**
		Extended data that the remote destination has chosen to associate
		with this error to facilitate custom error processing on the client.
	**/
	public var extendedData:Any;

	//--------------------------------------------------------------------------
	//
	// Overridden Methods
	//
	//--------------------------------------------------------------------------

	override public function getSmallMessage():IMessage {
		return null;
	}
}
