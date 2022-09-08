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

package feathers.rpc.remoting;

import feathers.messaging.messages.RemotingMessage;
import feathers.messaging.messages.AsyncMessage;
import feathers.messaging.events.MessageEvent;
import feathers.messaging.messages.IMessage;
import feathers.rpc.events.FaultEvent;

/**
	An Operation used specifically by RemoteObjects. An Operation is an individual method on a service.
	An Operation can be called either by invoking the
	function of the same name on the service or by accessing the Operation as a property on the service and
	calling the `send()` method.
**/
@:access(feathers.rpc.remoting.RemoteObject)
class Operation extends AbstractOperation {
	//---------------------------------
	// Constructor
	//---------------------------------

	/**
		Creates a new Operation. This is usually done directly automatically by the RemoteObject
		when an unknown operation has been accessed. It is not recommended that a developer use this constructor
		directly.

		@param service The RemoteObject object defining the service.
		@param name The name of the service.
	**/
	public function new(remoteObject:AbstractService = null, name:String = null) {
		super(remoteObject, name);

		argumentNames = [];

		this.remoteObject = cast(remoteObject, RemoteObject);
	}

	//---------------------------------
	// Properties
	//---------------------------------
	// [Inspectable(enumeration="multiple,single,last", defaultValue="multiple", category="General")]

	/**
		The concurrency for this Operation.  If it has not been explicitly set the setting from the RemoteObject
		will be used.
	**/
	@:flash.property
	public var concurrency(get, set):String;

	private function get_concurrency():String {
		if (_concurrencySet) {
			return _concurrency;
		}
		// else
		return remoteObject.concurrency;
	}

	private function set_concurrency(c:String):String {
		_concurrency = c;
		_concurrencySet = true;
		return get_concurrency();
	}

	// [Inspectable(defaultValue="true", category="General")]

	override private function get_makeObjectsBindable():Bool {
		if (_makeObjectsBindableSet) {
			return _makeObjectsBindable;
		}

		return cast(service, RemoteObject).makeObjectsBindable;
	}

	override private function set_makeObjectsBindable(b:Bool):Bool {
		_makeObjectsBindable = b;
		_makeObjectsBindableSet = true;
		return get_makeObjectsBindable();
	}

	/**
		Whether this operation should show the busy cursor while it is executing.
		If it has not been explicitly set the setting from the RemoteObject
		will be used.
	**/
	@:flash.property
	public var showBusyCursor(get, set):Bool;

	private function get_showBusyCursor():Bool {
		if (_showBusyCursorSet) {
			return _showBusyCursor;
		}
		// else
		return remoteObject.showBusyCursor;
	}

	private function set_showBusyCursor(sbc:Bool):Bool {
		_showBusyCursor = sbc;
		_showBusyCursorSet = true;
		return get_showBusyCursor();
	}

	/**
		An ordered list of the names of the arguments to pass to a method invocation.  Since the arguments object is
		a hashmap with no guaranteed ordering, this array helps put everything together correctly.
		It will be set automatically by the MXML compiler, if necessary, when the Operation is used in tag form.
	**/
	public var argumentNames:Array<String>;

	//--------------------------------------------------------------------------
	//
	// Private Variables
	//
	//--------------------------------------------------------------------------
	private var _concurrency:String;

	private var _concurrencySet:Bool;

	private var _makeObjectsBindableSet:Bool;

	private var _showBusyCursor:Bool;

	private var _showBusyCursorSet:Bool;

	//---------------------------------
	// Methods
	//---------------------------------

	override public function send(#if (haxe_ver >= 4.2)...rest:Dynamic #else p1:Dynamic = null, p2:Dynamic = null, p3:Dynamic = null, p4:Dynamic = null,
		p5:Dynamic = null #end):AsyncToken {
		#if (haxe_ver >= 4.2)
		var args = rest.toArray();
		#else
		var args:Array<Dynamic> = [];
		if (p1 != null) {
			args.push(p1);
		}
		if (p2 != null) {
			args.push(p2);
		}
		if (p3 != null) {
			args.push(p3);
		}
		if (p4 != null) {
			args.push(p4);
		}
		if (p5 != null) {
			args.push(p5);
		}
		#end

		if (service != null)
			service.initialize();

		if (remoteObject.convertParametersHandler != null)
			args = remoteObject.convertParametersHandler(args);

		if (operationManager != null)
			return operationManager(args);

		if (Concurrency.SINGLE == concurrency && activeCalls.hasActiveCalls()) {
			var token:AsyncToken = new AsyncToken(null);
			var m:String = "Attempt to invoke while another call is pending.  Either change concurrency options or avoid multiple calls.";
			var fault:Fault = new Fault("ConcurrencyError", m);
			var faultEvent:FaultEvent = FaultEvent.createEvent(fault, token);
			new AsyncDispatcher(dispatchRpcEvent, [faultEvent], 10);
			return token;
		}

		// We delay endpoint initialization until now because MXML codegen may set
		// the destination attribute after the endpoint and will clear out the
		// channelSet.
		if (asyncRequest.channelSet == null && remoteObject.endpoint != null) {
			remoteObject.initEndpoint();
		}

		if (args == null || (args.length == 0 && this.arguments != null)) {
			if ((this.arguments is Array)) {
				args = Std.downcast(this.arguments, Array);
			} else {
				args = [];
				for (i in 0...argumentNames.length) {
					args[i] = Reflect.field(this.arguments, argumentNames[i]);
				}
			}
		}

		var message:RemotingMessage = new RemotingMessage();
		message.operation = name;
		message.body = args;
		message.source = cast(service, RemoteObject).source;

		return invoke(message);
	}

	override public function cancel(id:String = null):AsyncToken {
		// if (showBusyCursor) {
		// 	CursorManager.removeBusyCursor();
		// }
		return super.cancel(id);
	}

	override private function setService(ro:AbstractService):Void {
		super.setService(ro);
		remoteObject = cast(ro, RemoteObject);
	}

	override private function invoke(message:IMessage, token:AsyncToken = null):AsyncToken {
		// if (showBusyCursor) {
		// 	CursorManager.setBusyCursor();
		// }

		return super.invoke(message, token);
	}

	/*
		Kill the busy cursor, find the matching call object and pass it back
	 */
	override private function preHandle(event:MessageEvent):AsyncToken {
		// if (showBusyCursor) {
		// 	CursorManager.removeBusyCursor();
		// }

		var wasLastCall:Bool = activeCalls.wasLastCall(cast(event.message, AsyncMessage).correlationId);
		var token:AsyncToken = super.preHandle(event);

		if (Concurrency.LAST == concurrency && !wasLastCall) {
			return null;
		}
		// else
		return token;
	}

	override private function processResult(message:IMessage, token:AsyncToken):Bool {
		if (super.processResult(message, token)) {
			if (remoteObject.convertResultHandler != null)
				_result = remoteObject.convertResultHandler(_result, this);
			return true;
		}
		return false;
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------
	private var remoteObject:RemoteObject;
}
