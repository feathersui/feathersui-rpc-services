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
import openfl.events.EventDispatcher;
import openfl.events.IEventDispatcher;
import openfl.events.Event;
import openfl.events.EventType;
import feathers.messaging.ChannelSet;
#if flash
import flash.utils.QName;
#end

/**
	The AbstractService class is the base class for the HTTPMultiService, WebService, 
	and RemoteObject classes. This class does the work of creating Operations
	which do the actual execution of remote procedure calls.
**/
@:access(feathers.rpc.AbstractOperation)
class AbstractService implements IEventDispatcher {
	//-------------------------------------------------------------------------
	//
	// Constructor
	//
	//-------------------------------------------------------------------------

	/**
		Constructor.

		@param destination The destination of the service.
	**/
	public function new(destination:String = null) {
		eventDispatcher = new EventDispatcher(this);
		asyncRequest = new AsyncRequest();

		if (destination != null && destination.length > 0) {
			this.destination = destination;
			asyncRequest.destination = destination;
		}

		_operations = {};
	}

	//-------------------------------------------------------------------------
	//
	// Variables
	//
	//-------------------------------------------------------------------------
	//-------------------------------------------------------------------------
	//
	//              Properties
	//
	//-------------------------------------------------------------------------
	//----------------------------------
	//  channelSet
	//----------------------------------

	/**
		Provides access to the ChannelSet used by the service. The
		ChannelSet can be manually constructed and assigned, or it will be 
		dynamically created to use the configured Channels for the
		<code>destination</code> for this service.
	**/
	@:flash.property
	public var channelSet(get, set):ChannelSet;

	private function get_channelSet():ChannelSet {
		return asyncRequest.channelSet;
	}

	private function set_channelSet(value:ChannelSet):ChannelSet {
		if (channelSet != value) {
			asyncRequest.channelSet = value;
		}
		return asyncRequest.channelSet;
	}

	//----------------------------------
	//  destination
	//----------------------------------
	// [Inspectable(category="General")]

	/**
		The destination of the service. This value should match a destination
		entry in the services-config.xml file.
	**/
	@:flash.property
	public var destination(get, set):String;

	private function get_destination():String {
		return asyncRequest.destination;
	}

	private function set_destination(name:String):String {
		asyncRequest.destination = name;
		return asyncRequest.destination;
	}

	//----------------------------------
	//  managers
	//----------------------------------
	private var _managers:Array<Dynamic>;

	/**
		The managers property stores a list of data managers which modify the
		behavior of this service.  You can use this hook to define one or more
		manager components associated with this service.  When this property is set,
		if the managers have a property called "service" that property is set to 
		the value of this service.  When this service is initialized, we also call
		the initialize method on any manager components.
	**/
	@:flash.property
	public var managers(get, set):Array<Dynamic>;

	private function get_managers():Array<Dynamic> {
		return _managers;
	}

	private function set_managers(mgrs:Array<Dynamic>):Array<Dynamic> {
		if (_managers != null) {
			for (i in 0..._managers.length) {
				var mgr:Dynamic = _managers[i];
				if (Reflect.hasField(mgr, "service"))
					mgr.service = null;
			}
		}
		_managers = mgrs;
		for (i in 0...mgrs.length) {
			var mgr:Dynamic = _managers[i];
			if (Reflect.hasField(mgr, "service"))
				Reflect.setField(mgr, "service", this);
			if (_initialized && Reflect.hasField(mgr, "initialize"))
				Reflect.callMethod(mgr, Reflect.field(mgr, "initialize"), []);
		}
		return _managers;
	}

	//----------------------------------
	//  operations
	//----------------------------------
	private var _operations:Dynamic;

	/**
		This is required by data binding.
	**/
	@:dox(hide)
	@:flash.property
	public var operations(get, set):Dynamic;

	private function get_operations():Dynamic {
		return _operations;
	}

	/**
		The Operations array is usually only set by the MXML compiler if you
		create a service using an MXML tag.
	**/
	private function set_operations(ops:Dynamic):Dynamic {
		var op:AbstractOperation;
		for (i in Reflect.fields(ops)) {
			op = cast(Reflect.field(ops, i), AbstractOperation);
			op.setService(this); // service is a write only property.
			if (op.name == null || op.name.length == 0)
				op.name = i;
			op.asyncRequest = asyncRequest;
			op.setKeepLastResultIfNotSet(_keepLastResult);
		}
		_operations = ops;
		dispatchEvent(new Event("operationsChange"));
		return _operations;
	}

	//----------------------------------
	//  requestTimeout
	//----------------------------------
	// [Inspectable(category="General")]

	/**
		Provides access to the request timeout in seconds for sent messages. 
		A value less than or equal to zero prevents request timeout.
	**/
	@:flash.property
	public var requestTimeout(get, set):Int;

	private function get_requestTimeout():Int {
		return asyncRequest.requestTimeout;
	}

	private function set_requestTimeout(value:Int):Int {
		if (requestTimeout != value) {
			asyncRequest.requestTimeout = value;
		}
		return asyncRequest.requestTimeout;
	}

	//----------------------------------
	//  keepLastResult
	//----------------------------------
	private var _keepLastResult:Bool = true;

	// [Inspectable(defaultValue="true", category="General")]

	/**
		Flag indicating whether the service's operations should keep their last call result for later access.

		Setting this flag at the service level will set <code>keepLastResult</code> for each operation, unless explicitly  set in the operation.

		If set to true or not set, each operation's last call result will be accessible through its <code>lastResult</code> bindable property.

		If set to false, each operation's last call result will be cleared after the call,
		and must be processed in the operation's result handler.
		This will allow the result object to be garbage collected,
		which is especially useful if the operation is only called a few times and returns a large result.

		@see mx.rpc.AbstractInvoker#keepLastResult
		@default true
	**/
	@:flash.property
	public var keepLastResult(get, set):Bool;

	private function get_keepLastResult():Bool {
		return _keepLastResult;
	}

	private function set_keepLastResult(value:Bool):Bool {
		_keepLastResult = value;
		return _keepLastResult;
	}

	//-------------------------------------------------------------------------
	//
	//              Methods
	//
	//-------------------------------------------------------------------------
	//---------------------------------
	//   EventDispatcher methods
	//---------------------------------

	@:dox(hide)
	public function addEventListener<T>(type:EventType<T>, listener:T->Void, useCapture:Bool = false, priority:Int = 0, useWeakReference:Bool = false):Void {
		eventDispatcher.addEventListener(type, listener, useCapture, priority, useWeakReference);
	}

	@:dox(hide)
	public function dispatchEvent(event:Event):Bool {
		return eventDispatcher.dispatchEvent(event);
	}

	@:dox(hide)
	public function removeEventListener<T>(type:EventType<T>, listener:T->Void, useCapture:Bool = false):Void {
		eventDispatcher.removeEventListener(type, listener, useCapture);
	}

	@:dox(hide)
	public function hasEventListener(type:String):Bool {
		return eventDispatcher.hasEventListener(type);
	}

	@:dox(hide)
	public function willTrigger(type:String):Bool {
		return eventDispatcher.willTrigger(type);
	}

	/**
		Called to initialize the service.
	**/
	public function initialize():Void {
		if (!_initialized && _managers != null) {
			for (i in 0..._managers.length) {
				var mgr:Dynamic = _managers[i];
				if (Reflect.hasField(mgr, "initialize"))
					mgr.initialize();
			}
			_initialized = true;
		}
	}

	//---------------------------------
	//   Proxy methods
	//---------------------------------
	// override flash_proxy function getProperty(name:*):*
	// {
	// 	return getOperation(getLocalName(name));
	// }
	// override flash_proxy function setProperty(name:*, value:*):Void
	// {
	// 	var message:String = resourceManager.getString(
	// 		"rpc", "operationsNotAllowedInService", [ getLocalName(name) ]);
	// 	throw new Error(message);
	// }
	// override flash_proxy function callProperty(name:*, ... args:Array):*
	// {
	// 	return getOperation(getLocalName(name)).send.apply(null, args);
	// }
	// used to store the nextName values
	// private var nextNameArray:Array;
	// override flash_proxy function nextNameIndex(index:Int):Int
	// {
	// 	if (index == 0)
	// 	{
	// 		nextNameArray = [];
	// 		for (var op:String in _operations)
	// 		{
	// 			nextNameArray.push(op);
	// 		}
	// 	}
	// 	return index < nextNameArray.length ? index + 1 : 0;
	// }
	// override flash_proxy function nextName(index:Int):String
	// {
	// 	return nextNameArray[index-1];
	// }
	// override flash_proxy function nextValue(index:Int):*
	// {
	// 	return _operations[nextNameArray[index-1]];
	// }

	private function getLocalName(name:Dynamic):String {
		#if flash
		if ((name is QName)) {
			return cast(name, QName).localName;
		} else {
			return Std.string(name);
		}
		#end
		return Std.string(name);
	}

	//---------------------------------
	//   Public methods
	//---------------------------------

	/**
		Returns an Operation of the given name. If the Operation wasn't
		created beforehand, subclasses are responsible for creating it during
		this call. Operations are usually accessible by simply naming them after
		the service variable (<code>myService.someOperation</code>), but if your
		Operation name happens to match a defined method on the service (like
		<code>setCredentials</code>), you can use this method to get the
		Operation instead.
		@param name Name of the Operation.
		@return Operation that executes for this name.
	**/
	public function getOperation(name:String):AbstractOperation {
		var o:Dynamic = Reflect.field(_operations, name);
		var op:AbstractOperation = (o is AbstractOperation) ? cast(o, AbstractOperation) : null;
		return op;
	}

	/**
		Disconnects the service's network connection and removes any pending
		request responders.
		This method does not wait for outstanding network operations to complete.
	**/
	public function disconnect():Void {
		asyncRequest.disconnect();
	}

	/**
		Sets the credentials for the destination accessed by the service when using Data Services on the server side.
		The credentials are applied to all services connected over the same
		ChannelSet. Note that services that use a proxy or a third-party adapter
		to a remote endpoint will need to setRemoteCredentials instead.

		@param username The username for the destination.
		@param password The password for the destination.
		@param charset The character set encoding to use while encoding the
		credentials. The default is null, which implies the legacy charset of
		ISO-Latin-1. The only other supported charset is &quot;UTF-8&quot;.
	**/
	public function setCredentials(username:String, password:String, charset:String = null):Void {
		asyncRequest.setCredentials(username, password, charset);
	}

	/**
		Logs the user out of the destination. 
		Logging out of a destination applies to everything connected using the
		same ChannelSet as specified in the server configuration. For example,
		if you're connected over the my-rtmp channel and you log out using one
		of your RPC components, anything that was connected over the same
		ChannelSet is logged out.

		**Note:** Adobe recommends that you use the mx.messaging.ChannelSet.logout() method
		rather than this method.

		@see mx.messaging.ChannelSet#logout()   
	**/
	public function logout():Void {
		asyncRequest.logout();
	}

	/**
		The username and password to be used to authenticate a user when
		accessing a remote, third-party endpoint such as a web service through a
		proxy or a remote object through a custom adapter when using Data Services on the server side.

		@param remoteUsername The username to pass to the remote endpoint
		@param remotePassword The password to pass to the remote endpoint
		@param charset The character set encoding to use while encoding the
		remote credentials. The default is null, which implies the legacy charset
		of ISO-Latin-1. The only other supported charset is &quot;UTF-8&quot;.
	**/
	public function setRemoteCredentials(remoteUsername:String, remotePassword:String, charset:String = null):Void {
		asyncRequest.setRemoteCredentials(remoteUsername, remotePassword, charset);
	}

	//--------------------------------------------------------------
	//   Public methods from Object prototype not inherited by Proxy
	//--------------------------------------------------------------

	/**
		Returns this service.
	**/
	@:dox(hide)
	public function valueOf():Dynamic {
		return this;
	}

	//--------------------------------------------------------------
	//   mx_internal for package methods
	//--------------------------------------------------------------

	private function hasTokenResponders(event:Event):Bool {
		if ((event is AbstractEvent)) {
			var rpcEvent:AbstractEvent = cast(event, AbstractEvent);
			if (rpcEvent.token != null && rpcEvent.token.hasResponder()) {
				return true;
			}
		}

		return false;
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------
	private var _availableChannelIds:Array<String>;
	private var asyncRequest:AsyncRequest;
	private var eventDispatcher:EventDispatcher;
	private var _initialized:Bool = false;
}
