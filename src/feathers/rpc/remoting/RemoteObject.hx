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

#if flash
import feathers.messaging.utils.RpcClassAliasInitializer;
import feathers.messaging.channels.AMFChannel;
import feathers.messaging.channels.SecureAMFChannel;
import feathers.messaging.ChannelSet;
import feathers.messaging.Channel;
import haxe.Constraints.Function;

/**
 * The RemoteObject class gives you access to classes on a remote application server.
 *  
 *  @langversion 3.0
 *  @playerversion Flash 9
 *  @playerversion AIR 1.1
 *  @productversion Flex 3
 */
@:access(feathers.rpc.AbstractOperation)
class RemoteObject extends AbstractService {
	//-------------------------------------------------------------------------
	//
	//              Constructor
	//
	//-------------------------------------------------------------------------

	/**
	 * Creates a new RemoteObject.
	 * @param destination [optional] Destination of the RemoteObject; should match a destination name in the services-config.xml file.
	 *  
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion Flex 3
	 */
	public function new(destination:String = null) {
		super(destination);

		RpcClassAliasInitializer.registerClassAliases();

		concurrency = Concurrency.MULTIPLE;
		makeObjectsBindable = true;
		showBusyCursor = false;
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------
	private var _concurrency:String;

	private var _endpoint:String;

	private var _source:String;

	private var _makeObjectsBindable:Bool;

	private var _showBusyCursor:Bool;

	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------
	// [Inspectable(enumeration="multiple,single,last", defaultValue="multiple", category="General")]

	/**
	 * Value that indicates how to handle multiple calls to the same service. The default
	 * value is multiple. The following values are permitted:
	 * <ul>
	 * <li>multiple - Existing requests are not cancelled, and the developer is
	 * responsible for ensuring the consistency of returned data by carefully
	 * managing the event stream. This is the default.</li>
	 * <li>single - Making only one request at a time is allowed on the method; additional requests made 
	 * while a request is outstanding are immediately faulted on the client and are not sent to the server.</li>
	 * <li>last - Making a request causes the client to ignore a result or fault for any current outstanding request. 
	 * Only the result or fault for the most recent request will be dispatched on the client. 
	 * This may simplify event handling in the client application, but care should be taken to only use 
	 * this mode when results or faults for requests may be safely ignored.</li>
	 * </ul>
	 *  
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion Flex 3
	 */
	@:flash.property
	public var concurrency(get, set):String;

	private function get_concurrency():String {
		return _concurrency;
	}

	/**
	 *  @private
	 */
	private function set_concurrency(c:String):String {
		_concurrency = c;
		return _concurrency;
	}

	//----------------------------------
	//  endpoint
	//----------------------------------
	// [Inspectable(category="General")]

	/**
	 * This property allows the developer to quickly specify an endpoint for a RemoteObject
	 * destination without referring to a services configuration file at compile time or programmatically creating 
	 * a ChannelSet. It also overrides an existing ChannelSet if one has been set for the RemoteObject service.
	 *
	 * <p>If the endpoint url starts with "https" a SecureAMFChannel will be used, otherwise an AMFChannel will 
	 * be used. Two special tokens, {server.name} and {server.port}, can be used in the endpoint url to specify
	 * that the channel should use the server name and port that was used to load the SWF. </p>
	 *
	 * <p><b>Note:</b> This property is required when creating AIR applications.</p>
	 *  
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion Flex 3
	 */
	@:flash.property
	public var endpoint(get, set):String;

	private function get_endpoint():String {
		return _endpoint;
	}

	private function set_endpoint(url:String):String {
		// If endpoint has changed, null out channelSet to force it
		// to be re-initialized on the next Operation send
		if (_endpoint != url || url == null) {
			_endpoint = url;
			channelSet = null;
		}
		return _endpoint;
	}

	//----------------------------------
	//  makeObjectsBindable
	//----------------------------------
	// [Inspectable(category="General", defaultValue="true")]

	/**
	 * When this value is true, anonymous objects returned are forced to bindable objects.
	 *  
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion Flex 3
	 */
	@:flash.property
	public var makeObjectsBindable(get, set):Bool;

	private function get_makeObjectsBindable():Bool {
		return _makeObjectsBindable;
	}

	private function set_makeObjectsBindable(b:Bool):Bool {
		_makeObjectsBindable = b;
		return _makeObjectsBindable;
	}

	//----------------------------------
	//  showBusyCursor
	//----------------------------------
	// [Inspectable(defaultValue="false", category="General")]

	/**
	 * If <code>true</code>, a busy cursor is displayed while a service is executing. The default
	 * value is <code>false</code>.
	 *  
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion Flex 3
	 */
	@:flash.property
	public var showBusyCursor(get, set):Bool;

	private function get_showBusyCursor():Bool {
		return _showBusyCursor;
	}

	private function set_showBusyCursor(sbc:Bool):Bool {
		_showBusyCursor = sbc;
		return _showBusyCursor;
	}

	//----------------------------------
	//  source
	//----------------------------------
	// [Inspectable(category="General")]

	/**
	 * Lets you specify a source value on the client; not supported for destinations that use the JavaAdapter. This allows you to provide more than one source
	 * that can be accessed from a single destination on the server. 
	 *     
	 *  
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion Flex 3
	 */
	@:flash.property
	public var source(get, set):String;

	private function get_source():String {
		return _source;
	}

	private function set_source(s:String):String {
		_source = s;
		return _source;
	}

	/**
	 * An optional function, primarily intended for framework developers who need to install
	 * a function to get called with the parameters passed to each remote object invocation.
	 * The function takes an array of parameters and returns the potentially altered array.
	 *
	 * The function definition should look like:
	 * <code>
	 *   function myParametersFunction(parameters:Array):Array
	 * </code>
	 *  
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion Flex 3
	 */
	public var convertParametersHandler:Function;

	/**
	 * An optional function, primarily intended for framework developers who need to install
	 * a hook to process the results of an operation before notifying the result handlers.
	 *
	 * The function definition should look like:
	 * <code>
	 *   function myConvertResultsFunction(result:*, operation:AbstractOperation):*
	 * </code>
	 * 
	 * It is passed the result just after the makeObjectsBindable conversion has been done
	 * but before the result event is created.
	 *  
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion Flex 3
	 */
	public var convertResultHandler:Function;

	//-------------------------------------------------------------------------
	//
	// Internal Methods
	//
	//-------------------------------------------------------------------------

	/**
		*@private
	 */
	private function initEndpoint():Void {
		if (endpoint != null) {
			var chan:Channel;
			if (endpoint.indexOf("https") == 0) {
				chan = new SecureAMFChannel(null, endpoint);
			} else {
				chan = new AMFChannel(null, endpoint);
			}

			// Propagate requestTimeout.
			chan.requestTimeout = requestTimeout;

			channelSet = new ChannelSet();
			channelSet.addChannel(chan);
		}
	}

	//--------------------------------------------------------------------------
	//
	// Methods
	//
	//--------------------------------------------------------------------------

	/**
	 * Returns an Operation of the given name. If the Operation wasn't
	 * created beforehand, a new <code>mx.rpc.remoting.Operation</code> is
	 * created during this call. Operations are usually accessible by simply
	 * naming them after the service variable
	 * (<code>myService.someOperation</code>), but if your Operation name
	 * happens to match a defined method on the service
	 * (like <code>setCredentials</code>), you can use this method to get the
	 * Operation instead.
	 * @param name Name of the Operation.
	 * @return Operation that executes for this name.
	 *  
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion Flex 3
	 */
	override public function getOperation(name:String):AbstractOperation {
		var op:AbstractOperation = super.getOperation(name);
		if (op == null) {
			op = new Operation(this, name);
			Reflect.setField(_operations, name, op);
			op.asyncRequest = asyncRequest;
			op.setKeepLastResultIfNotSet(_keepLastResult);
		}
		return op;
	}

	/**
	 * If a remote object is managed by an external service, such a ColdFusion Component (CFC),
	 * a username and password can be set for the authentication mechanism of that remote service.
	 *
	 * @param remoteUsername the username to pass to the remote endpoint
	 * @param remotePassword the password to pass to the remote endpoint
	 * @param charset The character set encoding to use while encoding the
	 * remote credentials. The default is null, which implies the legacy charset
	 * of ISO-Latin-1. The only other supported charset is &quot;UTF-8&quot;.
	 *  
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion Flex 3
	 */
	override public function setRemoteCredentials(remoteUsername:String, remotePassword:String, charset:String = null):Void {
		super.setRemoteCredentials(remoteUsername, remotePassword, charset);
	}

	/**
	 * Represents an instance of RemoteObject as a String, describing
	 * important properties such as the destination id and the set of
	 * channels assigned.
	 *
	 * @return Returns a String representing an instance of a RemoteObject.
	 *  
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion Flex 3
	 */
	public function toString():String {
		var s:String = "[RemoteObject ";
		s += " destination=\"" + destination + "\"";
		if (source != null && source.length > 0)
			s += " source=\"" + source + "\"";
		s += " channelSet=\"" + channelSet + "\"]";
		return s;
	}
}
#end
