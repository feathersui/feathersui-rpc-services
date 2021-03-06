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
	The MessageBody for an ActionMessage
**/
@:meta(RemoteClass(alias = "flex.messaging.io.amf.MessageBody"))
class MessageBody {
	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructs an instance of a MessageBody
	**/
	public function new() {}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/**
		The target URI.
	**/
	public var targetURI:String = "null";

	/**
		The response URI.
	**/
	public var responseURI:String = "/1";

	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  data
	//----------------------------------
	private var _data:Dynamic;

	/**
		The data to be sent.
	**/
	@:flash.property
	public var data(get, set):Dynamic;

	private function get_data():Dynamic {
		return _data;
	}

	private function set_data(value:Dynamic):Dynamic {
		_data = value;
		return _data;
	}
}
