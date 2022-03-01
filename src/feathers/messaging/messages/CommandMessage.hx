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

import openfl.utils.IDataInput;
import openfl.utils.IDataOutput;

/**
 *  The CommandMessage class provides a mechanism for sending commands to the
 *  server infrastructure, such as commands related to publish/subscribe 
 *  messaging scenarios, ping operations, and cluster operations.
 */
@:meta(RemoteClass(alias = "flex.messaging.messages.CommandMessage"))
class CommandMessage extends AsyncMessage {
	//--------------------------------------------------------------------------
	//
	// Static Constants
	//
	//--------------------------------------------------------------------------

	/**
	 *  This operation is used to subscribe to a remote destination.
	 *  
	 */
	public static final SUBSCRIBE_OPERATION:UInt = 0;

	/**
	 *  This operation is used to unsubscribe from a remote destination.
	 *  
	 */
	public static final UNSUBSCRIBE_OPERATION:UInt = 1;

	/**
	 *  This operation is used to poll a remote destination for pending,
	 *  undelivered messages.
	 *  
	 */
	public static final POLL_OPERATION:UInt = 2;

	/**
	 *  This operation is used by a remote destination to sync missed or cached messages 
	 *  back to a client as a result of a client issued poll command.
	 *  
	 */
	public static final CLIENT_SYNC_OPERATION:UInt = 4;

	/**
	 *  This operation is used to test connectivity over the current channel to
	 *  the remote endpoint.
	 *  
	 */
	public static final CLIENT_PING_OPERATION:UInt = 5;

	/**
	 *  This operation is used to request a list of failover endpoint URIs
	 *  for the remote destination based on cluster membership.
	 *  
	 */
	public static final CLUSTER_REQUEST_OPERATION:UInt = 7;

	/**
	 * This operation is used to send credentials to the endpoint so that
	 * the user can be logged in over the current channel.  
	 * The credentials need to be Base64 encoded and stored in the <code>body</code>
	 * of the message.
	 *  
	 */
	public static final LOGIN_OPERATION:UInt = 8;

	/**
	 * This operation is used to log the user out of the current channel, and 
	 * will invalidate the server session if the channel is HTTP based.
	 *  
	 */
	public static final LOGOUT_OPERATION:UInt = 9;

	/**
	 * Endpoints can imply what features they support by reporting the
	 * latest version of messaging they are capable of during the handshake of
	 * the initial ping CommandMessage.
	 *  
	 */
	public static final MESSAGING_VERSION:String = "DSMessagingVersion";

	/**
	 * This operation is used to indicate that the client's subscription with a
	 * remote destination has timed out.
	 *  
	 */
	public static final SUBSCRIPTION_INVALIDATE_OPERATION:UInt = 10;

	/**
	 * Used by the MultiTopicConsumer to subscribe/unsubscribe for more
	 * than one topic in the same message.
	 *  
	 */
	public static final MULTI_SUBSCRIBE_OPERATION:UInt = 11;

	/**
	 *  This operation is used to indicate that a channel has disconnected.
	 *  
	 */
	public static final DISCONNECT_OPERATION:UInt = 12;

	/**
	 *  This operation is used to trigger a ChannelSet to connect.
	 *  
	 */
	public static final TRIGGER_CONNECT_OPERATION:UInt = 13;

	/**
	 *  This is the default operation for new CommandMessage instances.
	 *  
	 */
	public static final UNKNOWN_OPERATION:UInt = 10000;

	/**
	 *  The server message type for authentication commands.
	 *  
	 */
	public static final AUTHENTICATION_MESSAGE_REF_TYPE:String = "flex.messaging.messages.AuthenticationMessage";

	/**
	 *  Subscribe commands issued by a Consumer pass the Consumer's <code>selector</code>
	 *  expression in this header.
	 *  
	 */
	public static final SELECTOR_HEADER:String = "DSSelector";

	/**
	 *  Durable JMS subscriptions are preserved when an unsubscribe message
	 *  has this parameter set to true in its header.
	 *  
	 */
	public static final PRESERVE_DURABLE_HEADER:String = "DSPreserveDurable";

	/**
	 * Header to indicate that the Channel needs the configuration from the
	 * server.
	 *  
	 */
	public static final NEEDS_CONFIG_HEADER:String = "DSNeedsConfig";

	/** 
	 * Header used in a MULTI_SUBSCRIBE message to specify an Array of subtopic/selector
	 * pairs to add to the existing set of subscriptions.
	 *  
	 */
	public static final ADD_SUBSCRIPTIONS:String = "DSAddSub";

	/**
	 * Like the above, but specifies the subtopic/selector array of to remove
	 *  
	 */
	public static final REMOVE_SUBSCRIPTIONS:String = "DSRemSub";

	/**
	 * The separator string used for separating subtopic and selectors in the 
	 * add and remove subscription headers.
	 *  
	 */
	public static final SUBTOPIC_SEPARATOR:String = "_;_";

	/**
	 * Header to drive an idle wait time before the next client poll request.
	 *  
	 */
	public static final POLL_WAIT_HEADER:String = "DSPollWait";

	/**
	 * Header to suppress poll response processing. If a client has a long-poll 
	 * parked on the server and issues another poll, the response to this subsequent poll 
	 * should be tagged with this header in which case the response is treated as a
	 * no-op and the next poll will not be scheduled. Without this, a subsequent poll 
	 * will put the channel and endpoint into a busy polling cycle.
	 *  
	 */
	public static final NO_OP_POLL_HEADER:String = "DSNoOpPoll";

	/**
	 * Header to specify which character set encoding was used while encoding
	 * login credentials. 
	 *  
	 */
	public static final CREDENTIALS_CHARSET_HEADER:String = "DSCredentialsCharset";

	/**
	 * Header to indicate the maximum number of messages a Consumer wants to 
	 * receive per second.
	 *  
	 */
	public static final MAX_FREQUENCY_HEADER:String = "DSMaxFrequency";

	/**
	 * Header that indicates the message is a heartbeat.
	 */
	public static final HEARTBEAT_HEADER:String = "DS<3";

	//--------------------------------------------------------------------------
	//
	// Private Static Constants for Serialization
	//
	//--------------------------------------------------------------------------
	private static final OPERATION_FLAG:UInt = 1;

	//--------------------------------------------------------------------------
	//
	// Static Variables
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private 
	 *  Map of operations to semi-descriptive operation text strings.
	 */
	private static var operationTexts:Dynamic = null;

	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
	 *  Constructs an instance of a CommandMessage with an empty body and header
	 *  and a default <code>operation</code> of <code>UNKNOWN_OPERATION</code>.
	 *  
	 */
	public function new() {
		super();
		operation = UNKNOWN_OPERATION;
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/**
	 *  Provides access to the operation/command for the CommandMessage.
	 *  Operations indicate how this message should be processed by the remote
	 *  destination.
	 *  
	 */
	public var operation:UInt;

	//--------------------------------------------------------------------------
	//
	// Overridden Methods
	//
	//--------------------------------------------------------------------------

	/**
	 * @private
	 */
	override public function getSmallMessage():IMessage {
		// We shouldn't use small messages for PING or LOGIN operations as the
		// messaging version handshake would not yet be complete... for now just
		// optimize POLL operations.
		if (operation == POLL_OPERATION) {
			return new CommandMessageExt(this);
		}

		return null;
	}

	/**
	 *  @private
	 */
	override private function addDebugAttributes(attributes:Dynamic):Void {
		super.addDebugAttributes(attributes);
		Reflect.setField(attributes, "operation", getOperationAsString(operation));
	}

	/**
	 *  Returns a string representation of the message.
	 *
	 *  @return String representation of the message.
	 *  
	 */
	override public function toString():String {
		return getDebugString();
	}

	//--------------------------------------------------------------------------
	//
	// Methods
	//
	//--------------------------------------------------------------------------

	/**
		Provides a description of the operation specified.
		This method is used in <code>toString()</code> operations on this 
		message.

		@param op One of the CommandMessage operation constants.

		@return Short name for the operation.

		```haxe
		var msg = cast(event.message, CommandMessage);
		trace("Current operation -'" +
			CommandMessage.getOperationAsString(msg.operation)+ "'.");
		```
	**/
	public static function getOperationAsString(op:UInt):String {
		if (operationTexts == null) {
			operationTexts = {};
			Reflect.setField(operationTexts, Std.string(SUBSCRIBE_OPERATION), "subscribe");
			Reflect.setField(operationTexts, Std.string(UNSUBSCRIBE_OPERATION), "unsubscribe");
			Reflect.setField(operationTexts, Std.string(POLL_OPERATION), "poll");
			Reflect.setField(operationTexts, Std.string(CLIENT_SYNC_OPERATION), "client sync");
			Reflect.setField(operationTexts, Std.string(CLIENT_PING_OPERATION), "client ping");
			Reflect.setField(operationTexts, Std.string(CLUSTER_REQUEST_OPERATION), "cluster request");
			Reflect.setField(operationTexts, Std.string(LOGIN_OPERATION), "login");
			Reflect.setField(operationTexts, Std.string(LOGOUT_OPERATION), "logout");
			Reflect.setField(operationTexts, Std.string(SUBSCRIPTION_INVALIDATE_OPERATION), "subscription invalidate");
			Reflect.setField(operationTexts, Std.string(MULTI_SUBSCRIBE_OPERATION), "multi-subscribe");
			Reflect.setField(operationTexts, Std.string(DISCONNECT_OPERATION), "disconnect");
			Reflect.setField(operationTexts, Std.string(TRIGGER_CONNECT_OPERATION), "trigger connect");
			Reflect.setField(operationTexts, Std.string(UNKNOWN_OPERATION), "unknown");
		}
		var result = Reflect.field(operationTexts, Std.string(op));
		return Std.string(result);
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
				if ((flags & OPERATION_FLAG) != 0)
					operation = cast(input.readObject(), UInt);

				reservedPosition = 1;
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

		var flags:UInt = 0;

		if (operation != 0)
			flags |= OPERATION_FLAG;

		output.writeByte(flags);

		if (operation != 0)
			output.writeObject(operation);
	}
}
