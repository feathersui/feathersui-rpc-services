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

package feathers.rpc;

import feathers.rpc.events.AbstractEvent;
import openfl.errors.Error;

/**
	The AbstractOperation class represents an individual method on a
	service. An Operation can be called either by invoking the function of the
	same name on the service or by accessing the Operation as a property on the
	service and calling the `send()` method.

	@see mx.rpc.AbstractService
	@see mx.rpc.remoting.RemoteObject
	@see mx.rpc.soap.WebService
**/
@:access(feathers.rpc.events.AbstractEvent)
class AbstractOperation extends AbstractInvoker {
	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Creates a new Operation. This is usually done directly by the MXML
		compiler or automatically by the service when an unknown Operation has
		been accessed. It is not recommended that a developer use this
		constructor directly.

		@param service The service on which the Operation is being invoked.

		@param name The name of the new Operation.
	**/
	public function new(service:AbstractService = null, name:String = null) {
		super();

		_service = service;
		_name = name;
		this.arguments = {};
	}

	//-------------------------------------------------------------------------
	//
	// Variables
	//
	//-------------------------------------------------------------------------

	/**
		The arguments to pass to the Operation when it is invoked. If you call
		the `send()` method with no parameters, an array based on
		this object is sent. If you call the `send()` method with
		parameters (or call the function directly on the service) those
		parameters are used instead of whatever is stored in this property.
		For RemoteObject Operations the associated argumentNames array determines
		the order of the arguments passed.
	**/
	public var arguments:Dynamic;

	/**
		This is a hook primarily for framework developers to register additional user 
		specified properties for your operation.
	**/
	public var properties:Dynamic;

	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------

	/**
		The name of this Operation. This is how the Operation is accessed off the
		service. It can only be set once.
	**/
	@:flash.property
	public var name(get, set):String;

	private function get_name():String {
		return _name;
	}

	private function set_name(n:String):String {
		if (_name == null) {
			_name = n;
		} else {
			throw new Error("Cannot reset the name of an Operation");
		}
		return _name;
	}

	/**
		Provides convenient access to the service on which the Operation
		is being invoked. Note that the service cannot be changed after
		the Operation is constructed.
	**/
	@:flash.property
	public var service(get, never):AbstractService;

	private function get_service():AbstractService {
		return _service;
	}

	private function setService(s:AbstractService):Void {
		if (_service == null) {
			_service = s;
		} else {
			throw new Error("Cannot reset the service of an Operation");
		}
	}

	//-------------------------------------------------------------------------
	//
	//  Methods
	//
	//-------------------------------------------------------------------------

	/**
		Executes the method. Any arguments passed in are passed along as part of
		the method call. If there are no arguments passed, the arguments object
		is used as the source of parameters.

		@param args Optional arguments passed in as part of the method call. If there
		are no arguments passed, the arguments object is used as the source of 
		parameters.

		@return AsyncToken object.
		The same object is available in the `result` and
		`fault` events from the `token` property.
	**/
	/* abstract */
	public function send(#if (haxe_ver >= 4.2)...args:Dynamic #else p1:Dynamic = null, p2:Dynamic = null, p3:Dynamic = null, p4:Dynamic = null,
		p5:Dynamic = null #end):AsyncToken {
		return null;
	}

	//---------------------------------
	// Helper methods
	//---------------------------------

	/*
		This is unless we come up with a way for faceless components to support
		event bubbling; dispatch the event if there's someone listening on us,
		otherwise have the RemoteObject dispatch it in case there's a default
		handler.
	 */
	override private function dispatchRpcEvent(event:AbstractEvent):Void {
		event.callTokenResponders();
		if (!event.isDefaultPrevented()) {
			if (hasEventListener(event.type)) {
				dispatchEvent(event);
			} else {
				if (_service != null)
					_service.dispatchEvent(event);
			}
		}
	}

	//--------------------------------------------------------------------------
	//
	// Private Variables
	//
	//--------------------------------------------------------------------------
	private var _service:AbstractService;
	private var _name:String;
}
