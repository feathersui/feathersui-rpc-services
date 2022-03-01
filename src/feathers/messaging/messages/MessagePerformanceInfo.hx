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
 * @private
 * 
 * The MessagePerformanceInfo class is used to capture various metrics about
 * the sizing and timing of a message sent from a client to the server and its 
 * response message, as well as pushed messages from the server to the client.	
 * A response message should have two instances of this class among its headers,
 * headers[MPII] - info for the client to server message,
 * headers[MPIO] - info for the response message from server to client.
 * A pushed message will have an extra headers and its headers will represent,
 * headers[MPII] - info for the client to server message poll message (non RTMP)
 * headers[MPIO] - info for the pushed message from server to client,
 * headers[MPIP] - info for the message from the client that caused the push message
 */
@:meta(RemoteClass(alias = "flex.messaging.messages.MessagePerformanceInfo"))
class MessagePerformanceInfo {
	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------
	public function new() {}

	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------

	/**
	 * Size of message in Bytes (message types depends on what header this MPI is in)
	 *  
	 */
	public var messageSize:Int;

	/**
	 * Millisecond timestamp of when this message was sent
	 * (origin depends on on what header this MPI is in)
	 *  
	 */
	public var sendTime:Float = 0;

	/**
	 * Millisecond timestamp of when this message was received
	 * (destination depends on on what header this MPI is in)
	 *  
	 */
	private var _receiveTime:Float;

	/**
	 * Amount of time in milliseconds that this message was being processed on the server
	 * in order to calculate and populate MPI metrics
	 *  
	 */
	public var overheadTime:Float;

	/**
	 * "OUT" when this message originated on the server
	 *  
	 */
	private var _infoType:String;

	/**
	 * True if this is info for a message that was pushed from server to client
	 *  
	 */
	public var pushedFlag:Bool;

	/**
	 * Millisecond timestamp of when the server became ready to push this message out 
	 * to clients
	 *  
	 */
	public var serverPrePushTime:Float;

	/**
	 * Millisecond timestamp of when the server called into the adapter associated with the
	 * destination of this message
	 *  
	 */
	public var serverPreAdapterTime:Float;

	/**
	 * Millisecond timestamp of when server processing returned from the adapater associated 
	 * with the destination of this message
	 *  
	 */
	public var serverPostAdapterTime:Float;

	/**
	 * Millisecond timestamp of when the adapter associated with the destination of this message
	 * made a call to an external component (for example a JMS server)
	 *  
	 */
	public var serverPreAdapterExternalTime:Float;

	/**
	 * Millisecond timestamp of when processing came back to the adapter associated with the destination 
	 * of this message from a call to an external component (for example a JMS server)
	 *  
	 */
	public var serverPostAdapterExternalTime:Float;

	/**
	 * Flag is true when record-message-times is enabled for the communication channel
	 *  
	 */
	public var recordMessageTimes:Bool;

	/**
	 * Flag is true when record-message-sizes is enabled for the communication channel
	 *  
	 */
	public var recordMessageSizes:Bool;

	//--------------------------------------------------------------------------
	//
	// Public Methods
	//
	//--------------------------------------------------------------------------

	/**
	 *  Sets the info type of this message (IN or OUT).  Used to mark the MPI with the 
	 *  client receive time when this MPI is of type OUT (IN, OUT are from the perspective of the
	 *  server)
	 * 
	 * @param type - "IN" or "OUT" info type
	 *  
	 */
	public var infoType(get, set):String;

	private function set_infoType(type:String):String {
		_infoType = type;
		if (_infoType == "OUT") {
			var curDate:Date = Date.now();
			this._receiveTime = curDate.getTime();
		}
		return this._infoType;
	}

	/**
	 *  Get the info type of this message (IN or OUT).
	 * 
	 * @return "IN" or "OUT" (from the perspective of the server)
	 *  
	 */
	private function get_infoType():String {
		return this._infoType;
	}

	/**
	 *  Sets reveive time of this message.  
	 *  When the infoType is "OUT", we should skip override the receive time
	 *  See the set infoType for details
	 * 
	 * @param time - the receive time to set
	 */
	public var receiveTime(get, set):Float;

	private function set_receiveTime(time:Float):Float {
		// Check whether infoType is out and receiveTime would already set
		// If it is the case, we should skip the reset the receive time of the message
		if (_infoType == null || _infoType != "OUT") {
			// var curDate:Date = new Date();
			this._receiveTime = time;
		}
		return this._receiveTime;
	}

	/**
	 *  Get the receive time of this message (IN or OUT).
	 * 
	 * @return Number the receive time that the client receives the message
	 */
	private function get_receiveTime():Float {
		return this._receiveTime;
	}
}
