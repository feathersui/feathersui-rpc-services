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

import openfl.errors.Error;

/** 
	The MessagePerformanceUtils utility class is used to retrieve various metrics about
	the sizing and timing of a message sent from a client to the server and its 
	response message, as well as pushed messages from the server to the client.  
	Metrics are gathered when corresponding properties on the channel used are enabled:
	&lt;record-message-times&gt; denotes capturing of timing information,
	&lt;record-message-sizes&gt; denotes capturing of sizing information.

	You can then use methods of this utility class to retrieve various performance information
	about the message that you have just received.

	When these metrics are enabled an instance of this class should be created from 
	a response, acknowledgement, or message handler using code such as below:

	```haxe
	var mpiutil:MessagePerformanceUtils = new MessagePerformanceUtils(event.message);
	```
**/
class MessagePerformanceUtils {
	/**
		Information about the original message sent out by the client
	**/
	@:dox(hide)
	public var mpii:MessagePerformanceInfo;

	/**
		Information about the response message sent back to the client
	**/
	@:dox(hide)
	public var mpio:MessagePerformanceInfo;

	/**
		If this is a pushed message, information about the original message
		that caused the push
	**/
	@:dox(hide)
	public var mpip:MessagePerformanceInfo;

	/**
		Header for MPI of original message sent by client
	**/
	@:dox(hide)
	public static final MPI_HEADER_IN:String = "DSMPII";

	/**
		Header for MPI of response message sent to the client
	**/
	@:dox(hide)
	public static final MPI_HEADER_OUT:String = "DSMPIO";

	/**
		Header for MPI of a message that caused a pushed message             
	**/
	@:dox(hide)
	public static final MPI_HEADER_PUSH:String = "DSMPIP";

	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructor

		Creates an MPUtils instance with information from the MPI headers
		of the passed in message

		@param message The message whose MPI headers will be used in retrieving
		MPI information
	**/
	public function new(message:Dynamic) {
		this.mpii = Std.downcast(Reflect.field(message.headers, MPI_HEADER_IN), MessagePerformanceInfo);
		this.mpio = Std.downcast(Reflect.field(message.headers, MPI_HEADER_OUT), MessagePerformanceInfo);

		// it is possible that if not all participants have mpi enabled we might be missing parts here
		if (mpio == null || (mpii == null && Reflect.field(message.headers, MPI_HEADER_PUSH) == null)) {
			throw new Error("Message is missing MPI headers.  Verify that all participants have it enabled.");
		}

		if (pushedMessageFlag)
			this.mpip = Std.downcast(Reflect.field(message.headers, MPI_HEADER_PUSH), MessagePerformanceInfo);
	}

	//--------------------------------------------------------------------------
	//
	//  Public Methods
	//
	//--------------------------------------------------------------------------

	/**
		Time between this client sending a message and receiving a response
		for it from the server

		@return Total time in milliseconds
	**/
	@:flash.property
	public var totalTime(get, never):Float;

	private function get_totalTime():Float {
		if (mpii == null)
			return 0;
		else
			return mpio.receiveTime - mpii.sendTime;
	}

	/**
		Time between server receiving the client message and either the time
		the server responded to the received message or had the pushed message ready
		to be sent to the receiving client.  

		@return Server processing time in milliseconds
	**/
	@:flash.property
	public var serverProcessingTime(get, never):Float;

	private function get_serverProcessingTime():Float {
		if (pushedMessageFlag) {
			return mpip.serverPrePushTime - mpip.receiveTime;
		} else {
			return mpio.sendTime - mpii.receiveTime;
		}
	}

	/**
		Time between server receiving the client message and the server beginning to push
		messages out to other clients as a result of the original message.  

		@return Server pre-push processing time in milliseconds
	**/
	@:flash.property
	public var serverPrePushTime(get, never):Float;

	private function get_serverPrePushTime():Float {
		if (mpii == null)
			return 0;
		if (mpii.serverPrePushTime == 0)
			return serverProcessingTime;

		return mpii.serverPrePushTime - mpii.receiveTime;
	}

	/**
		Time spent in the adapter associated with the destination for this message before
		either the response to the message was ready or the message had been prepared
		to be pushed to the receiving client.  

		@return Server adapter processing time in milliseconds
	**/
	@:flash.property
	public var serverAdapterTime(get, never):Float;

	private function get_serverAdapterTime():Float {
		if (pushedMessageFlag) {
			if (mpip == null)
				return 0;
			if (mpip.serverPreAdapterTime == 0 || mpip.serverPostAdapterTime == 0)
				return 0;

			return mpip.serverPostAdapterTime - mpip.serverPreAdapterTime;
		} else {
			if (mpii == null)
				return 0;
			if (mpii.serverPreAdapterTime == 0 || mpii.serverPostAdapterTime == 0)
				return 0;

			return mpii.serverPostAdapterTime - mpii.serverPreAdapterTime;
		}
	}

	/**
		Time spent in a module invoked from the adapter associated with the destination for this message 
		but external to it, before either the response to the message was ready or the message had been 
		prepared to be pushed to the receiving client.  

		@return Server adapter-external processing time in milliseconds
	**/
	@:flash.property
	public var serverAdapterExternalTime(get, never):Float;

	private function get_serverAdapterExternalTime():Float {
		if (pushedMessageFlag) {
			if (mpip == null)
				return 0;
			if (mpip.serverPreAdapterExternalTime == 0 || mpip.serverPostAdapterExternalTime == 0)
				return 0;

			return mpip.serverPostAdapterExternalTime - mpip.serverPreAdapterExternalTime;
		} else {
			if (mpii == null)
				return 0;
			if (mpii.serverPreAdapterExternalTime == 0 || mpii.serverPostAdapterExternalTime == 0)
				return 0;

			return mpii.serverPostAdapterExternalTime - mpii.serverPreAdapterExternalTime;
		}
	}

	/**
		Time that the message waited on the server after it was ready to be pushed to the client
		but had not yet been polled for.
	**/
	@:flash.property
	public var serverPollDelay(get, never):Float;

	private function get_serverPollDelay():Float {
		if (mpip == null)
			return 0;
		if (mpip.serverPrePushTime == 0 || mpio.sendTime == 0)
			return 0;

		return mpio.sendTime - mpip.serverPrePushTime;
	}

	/**
		Server processing time spent outside of the adapter associated with the destination of this message.      
	**/
	@:flash.property
	public var serverNonAdapterTime(get, never):Float;

	private function get_serverNonAdapterTime():Float {
		return serverProcessingTime - serverAdapterTime;
	}

	/**
		The network round trip time for a client message and the server response to it,
		calculated by the difference between total time and server processing time.

		@return Network round trip time in milliseconds
	**/
	@:flash.property
	public var networkRTT(get, never):Float;

	private function get_networkRTT():Float {
		if (!pushedMessageFlag)
			return totalTime - serverProcessingTime;
		else
			return 0;
	}

	/**
		Timestamp in milliseconds since epoch of when the server sent a response message back
		to the client.

		@return Timestamp in milliseconds since epoch
	**/
	@:flash.property
	public var serverSendTime(get, never):Float;

	private function get_serverSendTime():Float {
		return mpio.sendTime;
	}

	/**
		Timestamp in milliseconds since epoch of when the client received response message from
		the server.

		@return Timestamp in milliseconds since epoch
	**/
	@:flash.property
	public var clientReceiveTime(get, never):Float;

	private function get_clientReceiveTime():Float {
		return mpio.receiveTime;
	}

	/**
		The size of the original client message as measured during deserialization by the server
		endpoint.

		@return Message size in Bytes
	**/
	@:flash.property
	public var messageSize(get, never):Int;

	private function get_messageSize():Int {
		if (mpii == null)
			return 0;
		else
			return mpii.messageSize;
	}

	/**
		The size of the response message sent to the client by the server as measured during serialization
		at the server endpoint.

		@return Message size in Bytes
	**/
	@:flash.property
	public var responseMessageSize(get, never):Int;

	private function get_responseMessageSize():Int {
		return mpio.messageSize;
	}

	/**
		Returns true if message was pushed to the client and is not a response to a message that
		originated on the client.

		@return true if this message was pushed to the client and is not a response to a message that
		originated on the client
	**/
	@:flash.property
	public var pushedMessageFlag(get, never):Bool;

	private function get_pushedMessageFlag():Bool {
		return mpio.pushedFlag;
	}

	/**
		Only populated in the case of a pushed message, this is the time between the push causing client
		sending its message and the push receving client receiving it.  Note that the two clients'
		clocks must be in sync for this to be meaningful.

		@return Total push time in milliseconds
	**/
	@:flash.property
	public var totalPushTime(get, never):Float;

	private function get_totalPushTime():Float {
		return clientReceiveTime - originatingMessageSentTime - pushedOverheadTime;
	}

	/**
		Only populated in the case of a pushed message, this is the network time between
		the server pushing the message and the client receiving it.  Note that the server
		and client clocks must be in sync for this to be meaningful.

		@return One way server push time in milliseconds       
	**/
	@:flash.property
	public var pushOneWayTime(get, never):Float;

	private function get_pushOneWayTime():Float {
		return clientReceiveTime - serverSendTime;
	}

	/**
		Only populated in the case of a pushed message, timestamp in milliseconds since epoch of 
		when the client that caused a push message sent its message.

		@return Timestamp in milliseconds since epoch
	**/
	@:flash.property
	public var originatingMessageSentTime(get, never):Float;

	private function get_originatingMessageSentTime():Float {
		return mpip.sendTime;
	}

	/**
		Only populated in the case of a pushed message, size in Bytes of the message that originally
		caused this pushed message.

		@return Pushed causer message size in Bytes
	**/
	@:flash.property
	public var originatingMessageSize(get, never):Float;

	private function get_originatingMessageSize():Float {
		return mpip.messageSize;
	}

	/**
		Returns a summary of all information available in MPI.  

		For example:

		```haxe
		var mpiutil:MessagePerformanceUtils = new MessagePerformanceUtils(message);                     
		Alert.show(mpiutil.prettyPrint(), "MPI Output", Alert.NONMODAL);
		```

		@return String containing a summary of all information available in MPI
	**/
	public function prettyPrint():String {
		var alertString:String = new String("");
		if (messageSize != 0)
			alertString += "Original message size(B): " + messageSize + "\n";
		if (responseMessageSize != 0)
			alertString += "Response message size(B): " + responseMessageSize + "\n";
		if (totalTime != 0)
			alertString += "Total time (s): " + (totalTime / 1000) + "\n";
		if (networkRTT != 0)
			alertString += "Network Roundtrip time (s): " + (networkRTT / 1000) + "\n";
		if (serverProcessingTime != 0)
			alertString += "Server processing time (s): " + (serverProcessingTime / 1000) + "\n";
		if (serverAdapterTime != 0)
			alertString += "Server adapter time (s): " + (serverAdapterTime / 1000) + "\n";
		if (serverNonAdapterTime != 0)
			alertString += "Server non-adapter time (s): " + (serverNonAdapterTime / 1000) + "\n";
		if (serverAdapterExternalTime != 0)
			alertString += "Server adapter external time (s): " + (serverAdapterExternalTime / 1000) + "\n";

		if (pushedMessageFlag) {
			alertString += "PUSHED MESSAGE INFORMATION:\n";
			if (totalPushTime != 0)
				alertString += "Total push time (s): " + (totalPushTime / 1000) + "\n";
			if (pushOneWayTime != 0)
				alertString += "Push one way time (s): " + (pushOneWayTime / 1000) + "\n";
			if (originatingMessageSize != 0)
				alertString += "Originating Message size (B): " + originatingMessageSize + "\n";
			if (serverPollDelay != 0)
				alertString += "Server poll delay (s): " + (serverPollDelay / 1000) + "\n";
		}

		return alertString;
	}

	//--------------------------------------------------------------------------
	//
	//  Private Methods
	//
	//--------------------------------------------------------------------------

	/**
		Overhead time in milliseconds for processing of the push causer message
	**/
	private var pushedOverheadTime(get, never):Float;

	private function get_pushedOverheadTime():Float {
		return mpip.overheadTime;
	}
}
