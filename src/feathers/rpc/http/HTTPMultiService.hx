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

package feathers.rpc.http;

import feathers.messaging.ChannelSet;
import feathers.messaging.channels.DirectHTTPChannel;
import feathers.messaging.config.LoaderConfig;
import feathers.messaging.messages.HTTPRequestMessage;
import feathers.rpc.utils.RPCURLUtil;
import openfl.errors.ArgumentError;

/**
	You use the `<mx:HTTPMultiService>` tag to represent a
	collection of http operations.  Each one has a URL, method, parameters and
	return type.  

	You can set attributes such as the URL and method on the
	HTTPMultiService tag to act as defaults for values set on each individual
	operation tag.  The URL of the HTTPMultiService serves as the base url (meaning the prefix)
	for any relative urls set on the http operation tags.
	Each http operation has a `send()` method, which makes an HTTP request to the
	specified URL, and an HTTP response is returned.

	You can pass parameters to the specified URL which are used to put data into the HTTP request. 
	The contentType property specifies a mime-type which is used to determine the over-the-wire
	data format (such as HTTP form encoding or XML).

	You can also use a serialization filter to
	implement a custom resultFormat such as JSON.   
	When you do not go through the server-based
	proxy service, you can use only HTTP GET or POST methods. However, when you set
	the `useProxy ` property to true and you use the server-based proxy service, you
	can also use the HTTP HEAD, OPTIONS, TRACE, and DELETE methods.

	**Note:** Unlike the HTTPService class, the HTTPMultiService class does not 
	define a `request` property.

	**Note:** Due to a software limitation, like HTTPService, the HTTPMultiService does 
	not generate user-friendly error messages when using GET and not using a proxy.

	@see mx.rpc.http.HTTPService
**/
@:access(feathers.rpc.http.AbstractOperation)
@:access(feathers.rpc.http.SerializationFilter)
@:meta(DefaultProperty("operationList"))
class HTTPMultiService extends AbstractService {
	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Creates a new HTTPService. If you expect the service to send using relative URLs you may
		wish to specify the `baseURL` that will be the basis for determining the full URL (one example
		would be `Application.application.url`).

		@param baseURL The URL the HTTPService should use when computing relative URLS.
	**/
	public function new(baseURL:String = null, destination:String = null) {
		super();

		makeObjectsBindable = true;

		if (destination == null) {
			if (RPCURLUtil.isHttpsURL(LoaderConfig.url))
				asyncRequest.destination = HTTPService.DEFAULT_DESTINATION_HTTPS;
			else
				asyncRequest.destination = HTTPService.DEFAULT_DESTINATION_HTTP;
		} else
			asyncRequest.destination = destination;

		// _log = Log.getLogger("mx.rpc.http.HTTPMultiService");

		this.baseURL = baseURL;

		concurrency = Concurrency.MULTIPLE;
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/** 
		A shared direct Http channelset used for service instances that do not use the proxy. 
	**/
	private static var _directChannelSet:ChannelSet;

	// private var _log:ILogger;
	private var _showBusyCursor:Bool = false;

	private var _concurrency:String;

	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  contentType
	//----------------------------------
	// [Inspectable(enumeration="application/x-www-form-urlencoded,application/xml", defaultValue="application/x-www-form-urlencoded", category="General")]

	/**
		Type of content for service requests. 
		The default is `application/x-www-form-urlencoded` which sends requests
		like a normal HTTP POST with name-value pairs. `application/xml` send
		requests as XML.
	**/
	public var contentType:String = AbstractOperation.CONTENT_TYPE_FORM;

	//----------------------------------
	//  concurrency
	//----------------------------------
	// [Inspectable(enumeration="multiple,single,last", defaultValue="multiple", category="General")]

	/**
		Value that indicates how to handle multiple calls to the same operation within the service.
		The concurrency setting set here will be used for operations that do not specify concurrecny.
		Individual operations that have the concurrency setting set directly will ignore the value set here.
		The default value is `multiple`. The following values are permitted:

		- `multiple` Existing requests are not cancelled, and the developer is
		responsible for ensuring the consistency of returned data by carefully
		managing the event stream. This is the default value.
		- `single` Only a single request at a time is allowed on the operation;
		multiple requests generate a fault.
		- `last` Making a request cancels any existing request.
	**/
	@:flash.property
	public var concurrency(get, set):String;

	private function get_concurrency():String {
		return _concurrency;
	}

	private function set_concurrency(c:String):String {
		_concurrency = c;
		return _concurrency;
	}

	//----------------------------------
	//  showBusyCursor
	//----------------------------------
	// [Inspectable(defaultValue="false", category="General")]

	/**
		If `true`, a busy cursor is displayed while a service is executing. The default
		value is `false`.
	**/
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
	//  headers
	//----------------------------------
	// [Inspectable(defaultValue="undefined", category="General")]

	/**
		Custom HTTP headers to be sent to the third party endpoint. If multiple headers need to
		be sent with the same name the value should be specified as an Array.  These headers are sent
		to all operations.  You can also set headers at the operation level.
	**/
	public var headers:Dynamic = {};

	//----------------------------------
	//  makeObjectsBindable
	//----------------------------------
	// [Inspectable(defaultValue="true", category="General")]

	/**
		When `true`, the objects returned support data binding to UI controls.
		That means  they send PropertyChangeEvents when their property values are being changed.  
		This is the default value for any operations whose makeObjectsBindable property 
		is not set explicitly.
	**/
	public var makeObjectsBindable:Bool = true;

	//----------------------------------
	//  method
	//----------------------------------
	// [Inspectable(enumeration="GET,get,POST,post,HEAD,head,OPTIONS,options,PUT,put,TRACE,trace,DELETE,delete", defaultValue="GET", category="General")]

	/**
		HTTP method for sending the request if a method is not set explicit on the operation. 
		Permitted values are `GET`, `POST`, `HEAD`,
		`OPTIONS`, `PUT`, `TRACE` and `DELETE`.
		Lowercase letters are converted to uppercase letters. The default value is `GET`.
	**/
	public var method:String = HTTPRequestMessage.GET_METHOD;

	//----------------------------------
	//  resultFormat
	//----------------------------------
	private var _resultFormat:String = AbstractOperation.RESULT_FORMAT_OBJECT;

	// [Inspectable(enumeration="object,array,xml,flashvars,text,e4x", defaultValue="object", category="General")]

	/**
		Value that indicates how you want to deserialize the result
		returned by the HTTP call. The value for this is based on the following:

		- Whether you are returning XML or name/value pairs.
		- How you want to access the results; you can access results as an object,
		text, or XML.

		The default value is `object`. The following values are permitted:

		- `object` The value returned is XML and is parsed as a tree of ActionScript
		objects. This is the default.
		- `array` The value returned is XML and is parsed as a tree of ActionScript
		objects however if the top level object is not an Array, a new Array is created and the result
		set as the first item. If makeObjectsBindable is true then the Array 
		will be wrapped in an ArrayCollection.
		- `xml` The value returned is XML and is returned as literal XML in an
		ActionScript XMLnode object.
		- `flashvars` The value returned is text containing 
		name=value pairs separated by ampersands, which
		is parsed into an ActionScript object.
		- `text` The value returned is text, and is left raw.
		- `e4x` The value returned is XML and is returned as literal XML 
		in an ActionScript XML object, which can be accessed using ECMAScript for 
		XML (E4X) expressions.
	**/
	@:flash.property
	public var resultFormat(get, set):String;

	private function get_resultFormat():String {
		return _resultFormat;
	}

	private function set_resultFormat(value:String):String {
		switch (value) {
			case AbstractOperation.RESULT_FORMAT_OBJECT:
			case AbstractOperation.RESULT_FORMAT_ARRAY:
			case AbstractOperation.RESULT_FORMAT_XML:
			case AbstractOperation.RESULT_FORMAT_E4X:
			case AbstractOperation.RESULT_FORMAT_TEXT:
			case AbstractOperation.RESULT_FORMAT_FLASHVARS:
			case AbstractOperation.RESULT_FORMAT_HAXE_XML:
			case AbstractOperation.RESULT_FORMAT_JSON:
			// these are valid values
			default:
				{
					var sf:SerializationFilter;
					if (value != null && (sf = Reflect.field(SerializationFilter.filterForResultFormatTable, value)) == null) {
						var message:String = 'Invalid resultFormat \'$value\' valid formats are [${AbstractOperation.RESULT_FORMAT_OBJECT}, ${AbstractOperation.RESULT_FORMAT_ARRAY}, ${AbstractOperation.RESULT_FORMAT_XML}, ${AbstractOperation.RESULT_FORMAT_E4X}, ${AbstractOperation.RESULT_FORMAT_TEXT}, ${AbstractOperation.RESULT_FORMAT_FLASHVARS}, ${AbstractOperation.RESULT_FORMAT_HAXE_XML}, ${AbstractOperation.RESULT_FORMAT_JSON}]';
						throw new ArgumentError(message);
					}
				}
		}
		_resultFormat = value;
		return _resultFormat;
	}

	/** Default serializationFilter used by all operations which do not set one explicitly */
	public var serializationFilter:SerializationFilter;

	//----------------------------------
	//  rootURL
	//----------------------------------

	/**
		The URL that the HTTPService object should use when computing relative URLs.
		This contains a prefix which is prepended onto any URLs when it is set.
		It defaults to null in which case the URL for the SWF is used to compute
		relative URLs.
	**/
	public var baseURL:String;

	override public function set_destination(value:String):String {
		useProxy = true;
		super.destination = value;
		return asyncRequest.destination;
	}

	private var _useProxy:Bool = false;

	// [Inspectable(defaultValue="false", category="General")]

	/**
		Specifies whether to use the Flex proxy service. The default value is `false`. If you
		do not specify `true` to proxy requests though the Flex server, you must ensure that the player 
		can reach the target URL. You also cannot use destinations defined in the services-config.xml file if the
		`useProxy` property is set to `false`.

		@default false    
	**/
	@:flash.property
	public var useProxy(get, set):Bool;

	private function get_useProxy():Bool {
		return _useProxy;
	}

	private function set_useProxy(value:Bool):Bool {
		if (value != _useProxy) {
			_useProxy = value;
			var dcs:ChannelSet = getDirectChannelSet();
			if (!useProxy) {
				if (dcs != asyncRequest.channelSet)
					asyncRequest.channelSet = dcs;
			} else {
				if (asyncRequest.channelSet == dcs)
					asyncRequest.channelSet = null;
			}
		}
		return _useProxy;
	}

	/**
		This serves as the default property for this instance so that we can
		define a set of operations as direct children of the HTTPMultiService
		tag in MXML.
	**/
	@:flash.property
	public var operationList(get, set):Array<AbstractOperation>;

	private function get_operationList():Array<AbstractOperation> {
		// Note: does not preserve order of the elements
		if (operations == null)
			return null;
		var ol:Array<AbstractOperation> = [];
		for (i in Reflect.fields(operations)) {
			var op:AbstractOperation = Reflect.field(operations, i);
			ol.push(op);
		}
		return ol;
	}

	private function set_operationList(ol:Array<AbstractOperation>):Array<AbstractOperation> {
		if (ol == null)
			operations = null;
		else {
			var op:AbstractOperation;
			var ops:Dynamic = {};
			for (op in ol) {
				var name:String = op.name;
				if (name == null || name.length == 0)
					throw new ArgumentError("Operations must have a name property value for HTTPMultiService");
				Reflect.setField(ops, name, op);
			}
			operations = ops;
		}
		return ol;
	}

	//--------------------------------------------------------------------------
	//
	// Internal Methods
	//
	//--------------------------------------------------------------------------

	private function getDirectChannelSet():ChannelSet {
		if (_directChannelSet == null) {
			var dcs:ChannelSet = new ChannelSet();
			var dhc:DirectHTTPChannel = new DirectHTTPChannel("direct_http_channel");
			dhc.requestTimeout = requestTimeout;
			dcs.addChannel(dhc);
			_directChannelSet = dcs;
		}
		return _directChannelSet;
	}
}
