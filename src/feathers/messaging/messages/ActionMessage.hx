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
	The CommandMessage class provides a mechanism for sending commands to the
	server infrastructure, such as commands related to publish/subscribe 
	messaging scenarios, ping operations, and cluster operations.
**/
@:meta(RemoteClass(alias = "flex.messaging.io.amf.ActionMessage"))
class ActionMessage {
	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructs an instance of an ActionMessage with an empty array of bodies
		and headers.
	**/
	public function new() {}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/**
		The version of the ActionMessage.  Probably should not be changed.
	**/
	public var version:Int = 3;

	//--------------------------------------------------------------------------
	//
	// Overridden Methods
	//
	//--------------------------------------------------------------------------
	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  bodies
	//----------------------------------
	private var _bodies:Array<MessageBody> = [];

	/**
		The array of MessageBody instances.
	**/
	@:flash.property
	public var bodies(get, set):Array<MessageBody>;

	private function get_bodies():Array<MessageBody> {
		return _bodies;
	}

	private function set_bodies(value:Array<MessageBody>):Array<MessageBody> {
		_bodies = value;
		return _bodies;
	}

	//----------------------------------
	//  headers
	//----------------------------------
	private var _headers:Array<MessageHeader> = [];

	/**
		The array of MessageHeaders
	**/
	@:flash.property
	public var headers(get, set):Array<MessageHeader>;

	private function get_headers():Array<MessageHeader> {
		return _headers;
	}

	private function set_headers(value:Array<MessageHeader>):Array<MessageHeader> {
		_headers = value;
		return _headers;
	}
}
