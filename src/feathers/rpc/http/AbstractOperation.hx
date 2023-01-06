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

import feathers.data.ArrayCollection;
import feathers.messaging.ChannelSet;
import feathers.messaging.channels.DirectHTTPChannel;
import feathers.messaging.config.LoaderConfig;
import feathers.messaging.events.MessageEvent;
import feathers.messaging.messages.AsyncMessage;
import feathers.messaging.messages.HTTPRequestMessage;
import feathers.messaging.messages.IMessage;
import feathers.rpc.events.FaultEvent;
import feathers.rpc.utils.RPCObjectUtil;
import feathers.rpc.utils.RPCURLUtil;
import feathers.rpc.xml.SimpleXMLDecoder;
import feathers.rpc.xml.SimpleXMLEncoder;
import haxe.Exception;
import haxe.Json;
import openfl.errors.ArgumentError;
import openfl.errors.Error;
#if flash
import flash.utils.QName;
import flash.xml.XMLDocument;
import flash.xml.XMLNode;
import flash.xml.XMLNodeType;
#end

/**
	An Operation used specifically by HTTPService or HTTPMultiService.  An Operation is an 
	individual operation on a service usually corresponding to a single operation on the server
	side.  An Operation can be called either by invoking the
	function of the same name on the service or by accessing the Operation as a property on the service and
	calling the `send(param1, param2)` method.  HTTP services also support a sendBody
	method which allows you to directly specify the body of the HTTP response.  If you use the
	send(param1, param2) method, the body is typically formed by combining the argumentNames
	property of the operation with the parameters sent.  An Object is created which uses the
	argumentNames[i] as the key and the corresponding parameter as the value.

	The exact way in which the HTTP operation arguments is put into the HTTP body is determined
	by the serializationFilter used.
**/
@:access(feathers.rpc.http.SerializationFilter)
class AbstractOperation extends feathers.rpc.AbstractOperation {
	//---------------------------------
	// Constructor
	//---------------------------------

	/**
		Creates a new Operation. 

		@param service The object defining the type of service, such as 
		HTTPMultiService, WebService, or RemoteObject.

		@param name The name of the service.

		@param service The object defining the type of service, such as 
		HTTPMultiService, WebService, or RemoteObject.

		@param name The name of the service.
	**/
	public function new(service:AbstractService = null, name:String = null) {
		super(service, name);

		// _log = Log.getLogger("mx.rpc.http.HTTPService");

		concurrency = Concurrency.MULTIPLE;
	}

	/**
		The result format "e4x" specifies that the value returned is an XML instance, which can be accessed using ECMAScript for XML (E4X) expressions.
	**/
	private static final RESULT_FORMAT_E4X:String = "e4x";

	/**
		The result format "flashvars" specifies that the value returned is text containing name=value pairs
		separated by ampersands, which is parsed into an ActionScript object.
	**/
	private static final RESULT_FORMAT_FLASHVARS:String = "flashvars";

	/**
		The result format "object" specifies that the value returned is XML but is parsed as a tree of ActionScript objects. This is the default.
	**/
	private static final RESULT_FORMAT_OBJECT:String = "object";

	/**
		The result format "array" is similar to "object" however the value returned is always an Array such
		that if the result returned from result format "object" is not an Array already the item will be
		added as the first item to a new Array.
	**/
	private static final RESULT_FORMAT_ARRAY:String = "array";

	/**
		The result format "text" specifies that the HTTPService result text should be an unprocessed String.
	**/
	private static final RESULT_FORMAT_TEXT:String = "text";

	/**
		The result format "xml" specifies that results should be returned as an flash.xml.XMLNode instance pointing to
		the first child of the parent flash.xml.XMLDocument.
	**/
	private static final RESULT_FORMAT_XML:String = "xml";

	/**
		The result format "haxexml" specifies that results should be returned as a Haxe language Xml instance.

		@see https://api.haxe.org/Xml.html
	**/
	private static final RESULT_FORMAT_HAXE_XML:String = "haxexml";

	/**
		The result format "json" specifies that results should be parsed as JSON.
	**/
	private static final RESULT_FORMAT_JSON:String = "json";

	/**
		Indicates that the data being sent by the HTTP service is encoded as application/xml.
	**/
	private static final CONTENT_TYPE_XML:String = "application/xml";

	/**
		Indicates that the data being sent by the HTTP service is encoded as application/x-www-form-urlencoded.
	**/
	private static final CONTENT_TYPE_FORM:String = "application/x-www-form-urlencoded";

	// Constants for error codes

	/**
		Indicates that the useProxy property was set to false but a url was not provided.
	**/
	private static final ERROR_URL_REQUIRED:String = "Client.URLRequired";

	/**
		Indicates that an XML formatted result could not be parsed into an XML instance
		or decoded into an Object.
	**/
	private static final ERROR_DECODING:String = "Client.CouldNotDecode";

	/**
		Indicates that an input parameter could not be encoded as XML.
	**/
	private static final ERROR_ENCODING:String = "Client.CouldNotEncode";

	//---------------------------------
	// Properties
	//---------------------------------

	/**
		An ordered list of the names of the arguments to pass to a method invocation.  Since the arguments object is
		a hashmap with no guaranteed ordering, this array helps put everything together correctly.
		It will be set automatically by the MXML compiler, if necessary, when the Operation is used in tag form.
	**/
	public var argumentNames:Array<String>;

	//----------------------------------
	//  method
	//----------------------------------
	// [Inspectable(enumeration="GET,get,POST,post,HEAD,head,OPTIONS,options,PUT,put,TRACE,trace,DELETE,delete", defaultValue="GET", category="General")]

	/**
		HTTP method for sending the request. Permitted values are `GET`, `POST`, `HEAD`,
		`OPTIONS`, `PUT`, `TRACE` and `DELETE`.
		Lowercase letters are converted to uppercase letters. The default value is `GET`.
	**/
	@:flash.property
	public var method(get, set):String;

	private function get_method():String {
		return _method;
	}

	private function set_method(m:String):String {
		_method = m;
		return _method;
	}

	// [Inspectable(enumeration="multiple,single,last", defaultValue="multiple", category="General")]

	/**
		Value that indicates how to handle multiple calls to the same service. The default
		value is `multiple`. The following values are permitted:

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
	//  requestTimeout
	//----------------------------------
	private var _requestTimeout:Int = -1;

	/**
		Provides access to the request timeout in seconds for sent messages.
		If an acknowledgement, response or fault is not received from the
		remote destination before the timeout is reached the message is faulted
		on the client. A value less than or equal to zero prevents request timeout.
	**/
	@:flash.property
	public var requestTimeout(get, set):Int;

	private function get_requestTimeout():Int {
		return _requestTimeout;
	}

	private function set_requestTimeout(value:Int):Int {
		if (_requestTimeout != value)
			_requestTimeout = value;
		return _requestTimeout;
	}

	private var _resultFormat:String = RESULT_FORMAT_OBJECT;

	// [Inspectable(enumeration="object,array,xml,flashvars,text,e4x", category="General")]

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
		will be wrapped in an ArrayCollection.<
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
			case RESULT_FORMAT_OBJECT:
			case RESULT_FORMAT_ARRAY:
			case RESULT_FORMAT_XML:
			case RESULT_FORMAT_E4X:
			case RESULT_FORMAT_TEXT:
			case RESULT_FORMAT_FLASHVARS:
			case RESULT_FORMAT_HAXE_XML:
			case RESULT_FORMAT_JSON:
			// these are valid values
			default:
				{
					var sf:SerializationFilter;
					if (value != null && (sf = Reflect.field(SerializationFilter.filterForResultFormatTable, value)) == null) {
						// TODO: share this code with HTTPService, HTTPMultiService?  Also
						// improve the error/asdoc to include discussion of the SerializationFilter
						// and in the error display the contents of the SerializationFilter.filterForResultFormatTable
						// to make it clear which SerializationFormats are available in the current
						// context.
						var message:String = 'Invalid resultFormat \'$value\' valid formats are [$RESULT_FORMAT_OBJECT, $RESULT_FORMAT_ARRAY, $RESULT_FORMAT_XML, $RESULT_FORMAT_E4X, $RESULT_FORMAT_TEXT, $RESULT_FORMAT_FLASHVARS, $RESULT_FORMAT_HAXE_XML, $RESULT_FORMAT_JSON]';
						throw new ArgumentError(message);
					}
					serializationFilter = sf;
				}
		}
		_resultFormat = value;
		return _resultFormat;
	}

	/**
		A SerializationFilter can control how the arguments are formatted to form the content
		of the HTTP request.  It also controls how the results are converted into ActionScript
		objects.  It can be set either explicitly using this property or indirectly using the
		resultFormat property.
	**/
	public var serializationFilter:SerializationFilter;

	/** 
		Returns the serialization filter.
		Subclasses can override this method to control 
		the retrieval of the HTTP request headers. 

		@return The serialization filter.
	**/
	private function getSerializationFilter():SerializationFilter {
		return serializationFilter;
	}

	//----------------------------------
	//  request
	//----------------------------------
	// [Inspectable(defaultValue="undefined", category="General")]

	/**
		Object of name-value pairs used as parameters to the URL. If
		the `contentType` property is set to `application/xml`, it should be an XML document.
	**/
	public var request:Dynamic = {};

	//----------------------------------
	//  url
	//----------------------------------
	private var _url:String;

	// [Inspectable(defaultValue="undefined", category="General")]

	/**
		Location of the service. If you specify the `url` and a non-default destination,
		your destination in the services-config.xml file must allow the specified URL.
	**/
	@:flash.property
	public var url(get, set):String;

	private function get_url():String {
		return _url;
	}

	private function set_url(value:String):String {
		_url = value;
		return _url;
	}

	//----------------------------------
	//  useProxy
	//----------------------------------
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

	//----------------------------------
	//  xmlDecode
	//----------------------------------
	// [Inspectable(defaultValue="undefined", category="General")]

	/**
		ActionScript function used to decode a service result from XML.
		When the `resultFormat` is an object and the `xmlDecode` property is set,
		Flex uses the XML that the HTTPService returns to create an
		Object. If it is not defined the default XMLDecoder is used
		to do the work.

		The function referenced by the `xmlDecode` property must
		take a flash.xml.XMLNode object as a parameter and should return
		an Object. It can return any type of object, but it must return
		something. Returning `null` or `undefined` causes a fault.

		The following example shows an `<mx:HTTPService>` tag that specifies an xmlDecode function:

		```xml
		<mx:HTTPService id="hs" xmlDecode="xmlDecoder" url="myURL" resultFormat="object" contentType="application/xml">
			<mx:request><source/>
				<obj>{RequestObject}</obj>
			</mx:request>
		</mx:HTTPService>
		```

		The following example shows an xmlDecoder function:

		```haxe
		function xmlDecoder(myXML) {
			// Simplified decoding logic.
			var myObj = {};
			myObj.name = myXML.firstChild.nodeValue;
			myObj.honorific = myXML.firstChild.attributes.honorific;
			return myObj;
		}
		```
	**/
	public var xmlDecode:(#if flash XMLNode #else Dynamic #end) -> Dynamic;

	//----------------------------------
	//  xmlEncode
	//----------------------------------
	// [Inspectable(defaultValue="undefined", category="General")]

	/**
		ActionScript function used to encode a service request as XML.
		When the `contentType` of a request is `application/xml` and the
		request object passed in is an Object, Flex attempts to use
		the function specified in the `xmlEncode` property to turn it
		into a flash.xml.XMLNode object If the `xmlEncode` property is not set, 
		Flex uses the default
		XMLEncoder to turn the object graph into a flash.xml.XMLNode object.

		The `xmlEncode` property takes an Object and should return
		a flash.xml.XMLNode object. In this case, the XMLNode object can be a flash.xml.XML object,
		which is a subclass of XMLNode, or the first child of the
		flash.xml.XML object, which is what you get from an `<mx:XML>` tag.
		Returning the wrong type of object causes a fault.
		The following example shows an `<mx:HTTPService>` tag that specifies an xmlEncode function:

		```xml
		<mx:HTTPService id="hs" xmlEncode="xmlEncoder" url="myURL" resultFormat="object" contentType="application/xml">
			<mx:request><source/>
				<obj>{RequestObject}</obj>
			</mx:request>
		</mx:HTTPService>
		```

		The following example shows an xmlEncoder function:

		```haxe
		function xmlEncoder(myObj) {
			return new XML("<userencoded><attrib0>MyObj.test</attrib0><attrib1>MyObj.anotherTest</attrib1></userencoded>");
		}
		```
	**/
	public var xmlEncode:(Dynamic) -> #if flash XMLNode #else Dynamic #end;

	//----------------------------------
	//  headers
	//----------------------------------
	// [Inspectable(defaultValue="undefined", category="General")]

	/**
		Custom HTTP headers to be sent to the third party endpoint. If multiple headers need to
		be sent with the same name the value should be specified as an Array.
	**/
	public var headers:Dynamic = {};

	//----------------------------------
	//  contentType
	//----------------------------------
	// These are not all of the allowed values and mxmlc is now enforcing the value is in this list.  We could add this back if
	// there was wildcard support.
	// [Inspectable(enumeration="application/x-www-form-urlencoded,application/xml", defaultValue="application/x-www-form-urlencoded", category="General")]
	private var _contentType:String = CONTENT_TYPE_FORM;

	/**
		Type of content for service requests. 
		The default is `application/x-www-form-urlencoded` which sends requests
		like a normal HTTP POST with name-value pairs. `application/xml` send
		requests as XML.
	**/
	@:flash.property
	public var contentType(get, set):String;

	private function get_contentType():String {
		return _contentType;
	}

	private function set_contentType(ct:String):String {
		_contentType = ct;
		return _contentType;
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
	//  rootURL
	//----------------------------------
	private var _rootURL:String;

	/**
		The URL that the HTTPService object should use when computing relative URLs.
		This property is only used when going through the proxy.
		When the `useProxy` property is set to `false`, the relative URL is computed automatically
		based on the location of the SWF running this application.
		If not set explicitly `rootURL` is automatically set to the URL of
		mx.messaging.config.LoaderConfig.url.
	**/
	@:flash.property
	public var rootURL(get, set):String;

	private function get_rootURL():String {
		if (_rootURL == null) {
			_rootURL = LoaderConfig.url;
		}
		return _rootURL;
	}

	private function set_rootURL(value:String):String {
		_rootURL = value;
		return _rootURL;
	}

	//---------------------------------
	// Methods
	//---------------------------------

	override public function cancel(id:String = null):AsyncToken {
		if (showBusyCursor) {
			// CursorManager.removeBusyCursor();
		}
		return super.cancel(id);
	}

	public function sendBody(parameters:Dynamic):AsyncToken {
		var filter:SerializationFilter = getSerializationFilter();

		var paramsToSend:Dynamic;
		var token:AsyncToken;
		var fault:Fault;
		var faultEvent:FaultEvent;
		var msg:String;

		// concurrency check
		if (Concurrency.SINGLE == concurrency && activeCalls.hasActiveCalls()) {
			token = new AsyncToken(null);
			var m:String = "Attempt to invoke while another call is pending.  Either change concurrency options or avoid multiple calls.";
			fault = new Fault("ConcurrencyError", m);
			faultEvent = FaultEvent.createEvent(fault, token);
			new AsyncDispatcher(dispatchRpcEvent, [faultEvent], 10);
			return token;
		}

		var ctype:String = contentType;
		var urlToUse:String = url;

		if (urlToUse != null && urlToUse != '') {
			urlToUse = RPCURLUtil.getFullURL(rootURL, urlToUse);
		}

		if (filter != null) {
			// TODO: does this need to run on the array version of the parameters
			ctype = filter.getRequestContentType(this, parameters, ctype);
			urlToUse = filter.serializeURL(this, parameters, urlToUse);
			parameters = filter.serializeBody(this, parameters);
		}

		if (ctype == CONTENT_TYPE_XML) {
			if ((parameters is String) && xmlEncode == null) {
				paramsToSend = cast(parameters, String);
			} else if (#if flash !(parameters is XMLNode) && !(parameters is flash.xml.XML) && #end!(parameters is Xml)) {
				if (xmlEncode != null) {
					#if flash
					var funcEncoded:Dynamic = xmlEncode(parameters);
					if (null == funcEncoded) {
						token = new AsyncToken(null);
						msg = "xmlEncode returned null";
						fault = new Fault(ERROR_ENCODING, msg);
						faultEvent = FaultEvent.createEvent(fault, token);
						new AsyncDispatcher(dispatchRpcEvent, [faultEvent], 10);
						return token;
					} else if (!(funcEncoded is XMLNode)) {
						token = new AsyncToken(null);
						msg = "xmlEncode did not return XMLNode";
						fault = new Fault(ERROR_ENCODING, msg);
						faultEvent = FaultEvent.createEvent(fault, token);
						new AsyncDispatcher(dispatchRpcEvent, [faultEvent], 10);
						return token;
					} else {
						paramsToSend = cast(funcEncoded, XMLNode).toString();
					}
					#else
					throw new Error("xmlEncode is not available on this target");
					#end
				} else {
					var encoder:SimpleXMLEncoder = new SimpleXMLEncoder(null);
					var xmlDoc = #if flash new XMLDocument() #else Xml.createDocument() #end;

					// right now there is a wasted <encoded> wrapper tag
					// call.appendChild(encoder.encodeValue(parameters));
					#if flash
					var childNodes = encoder.encodeValue(parameters, new QName(null, "encoded"), new XMLNode(XMLNodeType.ELEMENT_NODE, "top"))
						.childNodes.copy();
					#else
					var childNodes = getXmlChildNodes(encoder.encodeValue(parameters, "encoded", Xml.createElement("top")));
					#end
					for (i in 0...childNodes.length) {
						#if flash
						xmlDoc.appendChild(childNodes[i]);
						#else
						xmlDoc.addChild(childNodes[i]);
						#end
					}

					paramsToSend = xmlDoc.toString();
				}
			} else {
				paramsToSend = Xml.parse(Std.string(parameters)).toString();
			}
		} else if (ctype == CONTENT_TYPE_FORM) {
			paramsToSend = {};
			var val:Dynamic;

			if (Reflect.isObject(parameters)) {
				// get all dynamic and all concrete properties from the parameters object
				var classInfo:Dynamic = RPCObjectUtil.getClassInfo(parameters);
				var properties:Array<String> = classInfo.properties;
				for (p in properties) {
					val = Reflect.field(parameters, p);
					if (val != null) {
						if ((val is Array))
							Reflect.setField(paramsToSend, p, val);
						else
							Reflect.setField(paramsToSend, p, Std.string(val));
					}
				}
			} else {
				paramsToSend = parameters;
			}
		} else {
			paramsToSend = parameters;
		}

		var message:HTTPRequestMessage = new HTTPRequestMessage();
		if (useProxy) {
			if (urlToUse != null && urlToUse != '') {
				message.url = urlToUse;
			}

			// if (NetworkMonitor.isMonitoring()) {
			// 	message.recordHeaders = true;
			// }
		} else {
			if (urlToUse == null || urlToUse == "") {
				token = new AsyncToken(null);
				msg = "A URL must be specified with useProxy set to false.";
				fault = new Fault(ERROR_URL_REQUIRED, msg);
				faultEvent = FaultEvent.createEvent(fault, token);
				new AsyncDispatcher(dispatchRpcEvent, [faultEvent], 10);
				return token;
			}

			if (!useProxy) {
				var dcs:ChannelSet = getDirectChannelSet();
				if (dcs != asyncRequest.channelSet)
					asyncRequest.channelSet = dcs;
			}

			// if (NetworkMonitor.isMonitoring()) {
			// 	message.recordHeaders = true;
			// }

			message.url = urlToUse;
		}

		message.contentType = ctype;
		message.method = method.toUpperCase();
		if (ctype == CONTENT_TYPE_XML && message.method == HTTPRequestMessage.GET_METHOD)
			message.method = HTTPRequestMessage.POST_METHOD;
		message.body = paramsToSend;
		message.httpHeaders = getHeaders();
		return invoke(message);
	}

	/**
		Returns the HTTP request headers.
		Subclasses can override this method to control 
		the retrieval of the HTTP request headers. 

		@return The HTTP request headers.
	**/
	private function getHeaders():Dynamic {
		return headers;
	}

	private function getXmlChildNodes(xml:Xml):Array<Xml> {
		var result:Array<Xml> = [];
		for (element in xml.iterator()) {
			result.push(element);
		}
		return result;
	}

	override private function processResult(message:IMessage, token:AsyncToken):Bool {
		var body:Dynamic = message.body;

		// _log.info("Decoding HTTPService response");
		// _log.debug("Processing HTTPService response message:\n{0}", message);

		var filter:SerializationFilter = getSerializationFilter();

		if (filter != null)
			body = filter.deserializeResult(this, body);

		if ((body == null) || ((body != null) && (body is String) && (StringTools.trim(Std.string(body)) == ""))) {
			_result = body;
			return true;
		} else if ((body is String)) {
			if (resultFormat == RESULT_FORMAT_XML || resultFormat == RESULT_FORMAT_OBJECT || resultFormat == RESULT_FORMAT_ARRAY) {
				#if flash
				// old XML style
				var tmp:Dynamic = new XMLDocument();
				cast(tmp, XMLDocument).ignoreWhite = true;
				try {
					cast(tmp, XMLDocument).parseXML((body : String));
				} catch (parseError:Exception) {
					var fault:Fault = new Fault(ERROR_DECODING, parseError.message);
					dispatchRpcEvent(FaultEvent.createEvent(fault, token, message));
					return false;
				}
				#else
				var tmp:Xml = null;
				try {
					tmp = Xml.parse((body : String));
				} catch (parseError:Dynamic) {
					var fault:Fault = new Fault(ERROR_DECODING, parseError.message);
					dispatchRpcEvent(FaultEvent.createEvent(fault, token, message));
					return false;
				}
				#end
				if (resultFormat == RESULT_FORMAT_OBJECT || resultFormat == RESULT_FORMAT_ARRAY) {
					var decoded:Dynamic;
					var msg:String;
					if (xmlDecode != null) {
						#if flash
						decoded = xmlDecode(tmp);
						if (decoded == null) {
							msg = "xmlDecode returned null";
							var fault:Fault = new Fault(ERROR_DECODING, msg);
							dispatchRpcEvent(FaultEvent.createEvent(fault, token, message));
						}
						#else
						throw new Error("xmlDecode is not available on this target");
						#end
					} else {
						var decoder:SimpleXMLDecoder = new SimpleXMLDecoder(makeObjectsBindable);

						decoded = decoder.decodeXML(cast(tmp, #if flash XMLNode #else Xml #end));

						if (decoded == null) {
							msg = "Default decoder could not decode result";
							var fault:Fault = new Fault(ERROR_DECODING, msg);
							dispatchRpcEvent(FaultEvent.createEvent(fault, token, message));
						}
					}

					if (decoded == null) {
						return false;
					}

					// if (makeObjectsBindable && (Lib.getQualifiedClassName(decoded) == "Object")) {
					// 	decoded = new ObjectProxy(decoded);
					// } else {
					// 	decoded = decoded;
					// }

					if (resultFormat == RESULT_FORMAT_ARRAY) {
						decoded = decodeArray(decoded);
					}

					_result = decoded;
				} else {
					#if flash
					if (tmp.childNodes.length == 1) {
						tmp = tmp.firstChild;
					}
					_result = tmp;
					#else
					throw new Error('RESULT_FORMAT_XML is not available on this target. RESULT_FORMAT_HAXE_XML is recommended instead.');
					#end
				}
			} else if (resultFormat == RESULT_FORMAT_E4X) {
				#if flash
				try {
					_result = new flash.xml.XML((body : String));
				} catch (error:Exception) {
					var fault:Fault = new Fault(ERROR_DECODING, error.message);
					dispatchRpcEvent(FaultEvent.createEvent(fault, token, message));
					return false;
				}
				#else
				throw new Error('RESULT_FORMAT_E4X is not available on this target. RESULT_FORMAT_HAXE_XML is recommended instead.');
				#end
			} else if (resultFormat == RESULT_FORMAT_HAXE_XML) {
				try {
					_result = Xml.parse((body : String));
				} catch (error:Exception) {
					var fault:Fault = new Fault(ERROR_DECODING, error.message);
					dispatchRpcEvent(FaultEvent.createEvent(fault, token, message));
					return false;
				}
			} else if (resultFormat == RESULT_FORMAT_JSON) {
				try {
					_result = Json.parse((body : String));
				} catch (error:Dynamic) {
					var fault:Fault = new Fault(ERROR_DECODING, error.message);
					dispatchRpcEvent(FaultEvent.createEvent(fault, token, message));
					return false;
				}
			} else if (resultFormat == RESULT_FORMAT_FLASHVARS) {
				_result = decodeParameterString((body : String));
			} else // if only we could assert(theService.resultFormat == "text")
			{
				_result = body;
			}
		} else {
			if (resultFormat == RESULT_FORMAT_ARRAY) {
				body = decodeArray(body);
			}

			_result = body;
		}

		return true;
	}

	override private function invoke(message:IMessage, token:AsyncToken = null):AsyncToken {
		if (showBusyCursor) {
			// CursorManager.setBusyCursor();
		}

		return super.invoke(message, token);
	}

	/*
		Kill the busy cursor, find the matching call object and pass it back
	 */
	override private function preHandle(event:MessageEvent):AsyncToken {
		if (showBusyCursor) {
			// CursorManager.removeBusyCursor();
		}

		var wasLastCall:Bool = activeCalls.wasLastCall(cast(event.message, AsyncMessage).correlationId);
		var token:AsyncToken = super.preHandle(event);

		if (Concurrency.LAST == concurrency && !wasLastCall) {
			return null;
		}
		// else
		return token;
	}

	//--------------------------------------------------------------------------
	//
	// Private Methods
	//
	//--------------------------------------------------------------------------

	private function decodeArray(o:Dynamic):Dynamic {
		var a:Array<Dynamic>;

		if ((o is Array)) {
			a = cast(o, Array<Dynamic>);
		} else if ((o is ArrayCollection)) {
			return o;
		} else {
			a = [];
			a.push(o);
		}

		if (makeObjectsBindable) {
			return new ArrayCollection(a);
		} else {
			return a;
		}
	}

	private function decodeParameterString(source:String):Dynamic {
		var trimmed:String = StringTools.trim(source);
		var params = trimmed.split('&');
		var decoded:Dynamic = {};
		for (i in 0...params.length) {
			var param:String = params[i];
			var equalsIndex:Int = param.indexOf('=');
			if (equalsIndex != -1) {
				var name:String = param.substr(0, equalsIndex);
				name = name.split('+').join(' ');
				name = StringTools.urlDecode(name);
				var value:String = param.substr(equalsIndex + 1);
				value = value.split('+').join(' ');
				value = StringTools.urlDecode(value);
				Reflect.setField(decoded, name, value);
			}
		}
		return decoded;
	}

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

	// private var _log:ILogger;

	/** 
		A shared direct Http channelset used for service instances that do not use the proxy. 
	**/
	private static var _directChannelSet:ChannelSet;

	private var _concurrency:String;

	private var _method:String = HTTPRequestMessage.GET_METHOD;

	private var _showBusyCursor:Bool = false;
}
