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

package feathers.messaging;

import openfl.events.EventDispatcher;

/**
	Singleton class that stores the global Id for this Player instance that is 
	server assigned when the client makes its initial connection to the server.
**/
class FlexClient extends EventDispatcher {
	//--------------------------------------------------------------------------
	//
	//  Class constants
	//
	//--------------------------------------------------------------------------

	/**
		This value is passed to the server in an initial client connect to
		indicate that the client needs a server-assigned FlexClient Id.
	**/
	private static final NULL_FLEXCLIENT_ID:String = "nil";

	//--------------------------------------------------------------------------
	//
	//  Class variables
	//
	//--------------------------------------------------------------------------

	/**
		The sole instance of this singleton class.
	**/
	private static var _instance:FlexClient;

	//--------------------------------------------------------------------------
	//
	//  Class methods
	//
	//--------------------------------------------------------------------------

	/**
		Returns the sole instance of this singleton class,
		creating it if it does not already exist.

		@return Returns the sole instance of this singleton class,
		creating it if it does not already exist.
	**/
	public static function getInstance():FlexClient {
		if (_instance == null)
			_instance = new FlexClient();

		return _instance;
	}

	//--------------------------------------------------------------------------
	//
	//  Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructor.
	**/
	public function new() {
		super();
	}

	//--------------------------------------------------------------------------
	//
	//  Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  id
	//----------------------------------

	/**
		Storage for the global FlexClient Id for the Player instance. 
		This value is server assigned and is set as part of the Channel connect process.
	**/
	private var _id:String;

	// [Bindable(event="propertyChange")]

	/**
		The global FlexClient Id for this Player instance.
		This value is server assigned and is set as part of the Channel connect process.
		Once set, it will not change for the duration of the Player instance's lifespan.
		If no Channel has connected to a server this value is null.
	**/
	@:flash.property
	public var id(get, set):String;

	private function get_id():String {
		return _id;
	}

	private function set_id(value:String):String {
		if (_id != value) {
			// var event:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "id", _id, value);
			_id = value;
			// dispatchEvent(event);
		}
		return _id;
	}

	//----------------------------------
	//  waitForFlexClientId
	//----------------------------------
	private var _waitForFlexClientId:Bool = false; // Initialize to false so the first Channel that checks this can attempt to connect.

	// [Bindable(event="propertyChange")]

	/**
		Guard condition that Channel instances use to coordinate their connect attempts during application startup
		when a FlexClient Id has not yet been returned by the server.
		The initial Channel connect process must be serialized.
		Once a FlexClient Id is set further Channel connects and disconnects do not require synchronization.
	**/
	private var waitForFlexClientId(get, set):Bool;

	private function get_waitForFlexClientId():Bool {
		return _waitForFlexClientId;
	}

	private function set_waitForFlexClientId(value:Bool):Bool {
		if (_waitForFlexClientId != value) {
			// var event:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "waitForFlexClientId", _waitForFlexClientId, value);
			_waitForFlexClientId = value;
			// dispatchEvent(event);
		}
		return _waitForFlexClientId;
	}
}
