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
	HTTP requests are sent to the HTTP endpoint using this message type.
	An HTTPRequestMessage encapsulates content and header information normally
	found in HTTP requests made by a browser.
**/
@:meta(RemoteClass(alias = "flex.messaging.messages.HTTPMessage"))
class HTTPRequestMessage extends AbstractMessage {
	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructs an uninitialized HTTP request.
	**/
	public function new() {
		super();
		_method = GET_METHOD;
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/**
		Indicates the content type of this message.
		This value must be understood by the destination this request is sent to.

		The following example sets the `contentType` property:

		```haxe
		var msg = new HTTPRequestMessage();
		msg.contentType = HTTPRequestMessage.CONTENT_TYPE_FORM;
		msg.method = HTTPRequestMessage.POST_METHOD;
		msg.url = "http://my.company.com/login";
		```
	**/
	public var contentType:String;

	/**
		Contains specific HTTP headers that should be placed on the request made
		to the destination.
	**/
	public var httpHeaders:Any;

	/**
		Only used when going through the proxy, should the proxy 
		send back the request and response headers it used.  Defaults to false.
		Currently only set when using the NetworkMonitor.
	**/
	public var recordHeaders:Bool;

	// [Inspectable(defaultValue="undefined", category="General")]

	/**
		Contains the final destination for this request.
		This is the URL that the content of this message, found in the
		`body` property, will be sent to, using the method specified.

		The following example sets the `url` property:

		```haxe
		var msg = new HTTPRequestMessage();
		msg.contentType = HTTPRequestMessage.CONTENT_TYPE_FORM;
		msg.method = HTTPRequestMessage.POST_METHOD;
		msg.url = "http://my.company.com/login";
		```
	**/
	public var url:String;

	// private var resourceManager:IResourceManager = ResourceManager.getInstance();
	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  method
	//----------------------------------
	private var _method:String;

	// [Inspectable(category="General")]

	/**
		Indicates what method should be used for the request.
		The only values allowed are:

		- `HTTPRequestMessage.DELETE_METHOD`
		- `HTTPRequestMessage.GET_METHOD`
		- `HTTPRequestMessage.HEAD_METHOD`
		- `HTTPRequestMessage.POST_METHOD`
		- `HTTPRequestMessage.OPTIONS_METHOD`
		- `HTTPRequestMessage.PUT_METHOD`
		- `HTTPRequestMessage.TRACE_METHOD`

		The following example sets the `method` property:

		```haxe
		var msg = new HTTPRequestMessage();
		msg.contentType = HTTPRequestMessage.CONTENT_TYPE_FORM;
		msg.method = HTTPRequestMessage.POST_METHOD;
		msg.url = "http://my.company.com/login";
		```
	**/
	@:flash.property
	public var method(get, set):String;

	private function get_method():String {
		return _method;
	}

	private function set_method(value:String):String {
		/*
			if (VALID_METHODS.indexOf(value) == -1)
			{
				var message:String = resourceManager.getString(
					"messaging", "invalidRequestMethod");
				throw new ArgumentError(message);
			}
		 */

		_method = value;
		return _method;
	}

	//--------------------------------------------------------------------------
	//
	// Static Constants
	//
	//--------------------------------------------------------------------------

	/**
		Indicates that the content of this message is XML.

		The following example uses this constant:

		```haxe
		var msg = new HTTPRequestMessage();
		msg.contentType = HTTPRequestMessage.CONTENT_TYPE_XML;
		msg.method = HTTPRequestMessage.POST_METHOD;
		msg.url = "http://my.company.com/login";
		```
	**/
	public static final CONTENT_TYPE_XML:String = "application/xml";

	/**
		Indicates that the content of this message is a form.

		The following example uses this constant:

		```haxe
		var msg = new HTTPRequestMessage();
		msg.contentType = HTTPRequestMessage.CONTENT_TYPE_FORM;
		msg.method = HTTPRequestMessage.POST_METHOD;
		msg.url = "http://my.company.com/login";
		```
	**/
	public static final CONTENT_TYPE_FORM:String = "application/x-www-form-urlencoded";

	/**
		Indicates that the content of this message is XML meant for a SOAP
		request.

		The following example uses this constant:

		```haxe
		var msg = new HTTPRequestMessage();
		msg.contentType = HTTPRequestMessage.CONTENT_TYPE_SOAP_XML;
		msg.method = HTTPRequestMessage.POST_METHOD;
		msg.url = "http://my.company.com/login";
		```
	**/
	public static final CONTENT_TYPE_SOAP_XML:String = "text/xml; charset=utf-8";

	/**
		Indicates that the method used for this request should be "post".

		The following example uses this constant:

		```haxe
		var msg = new HTTPRequestMessage();
		msg.contentType = HTTPRequestMessage.CONTENT_TYPE_FORM;
		msg.method = HTTPRequestMessage.POST_METHOD;
		msg.url = "http://my.company.com/login";
		```
	**/
	public static final POST_METHOD:String = "POST";

	/**
		Indicates that the method used for this request should be "get".

		The following example uses this constant:

		```haxe
		var msg = new HTTPRequestMessage();
		msg.contentType = HTTPRequestMessage.CONTENT_TYPE_FORM;
		msg.method = HTTPRequestMessage.GET_METHOD;
		msg.url = "http://my.company.com/login";
		```
	**/
	public static final GET_METHOD:String = "GET";

	/**
		Indicates that the method used for this request should be "put".

		The following example uses this constant:

		```haxe
		var msg = new HTTPRequestMessage();
		msg.contentType = HTTPRequestMessage.CONTENT_TYPE_FORM;
		msg.method = HTTPRequestMessage.PUT_METHOD;
		msg.url = "http://my.company.com/login";
		```
	**/
	public static final PUT_METHOD:String = "PUT";

	/**
		Indicates that the method used for this request should be "head".

		The following example uses this constant:

		```haxe
		var msg = new HTTPRequestMessage();
		msg.contentType = HTTPRequestMessage.CONTENT_TYPE_FORM;
		msg.method = HTTPRequestMessage.HEAD_METHOD;
		msg.url = "http://my.company.com/login";
		```
	**/
	public static final HEAD_METHOD:String = "HEAD";

	/**
		Indicates that the method used for this request should be "delete".

		The following example uses this constant:

		```haxe
		var msg = new HTTPRequestMessage();
		msg.contentType = HTTPRequestMessage.CONTENT_TYPE_FORM;
		msg.method = HTTPRequestMessage.DELETE_METHOD;
		msg.url = "http://my.company.com/login";
		```
	**/
	public static final DELETE_METHOD:String = "DELETE";

	/**
		Indicates that the method used for this request should be "options".

		The following example uses this constant:

		```haxe
		var msg = new HTTPRequestMessage();
		msg.contentType = HTTPRequestMessage.CONTENT_TYPE_FORM;
		msg.method = HTTPRequestMessage.OPTIONS_METHOD;
		msg.url = "http://my.company.com/login";
		```
	**/
	public static final OPTIONS_METHOD:String = "OPTIONS";

	/**
		Indicates that the method used for this request should be "trace".

		The following example uses this constant:

		```haxe
		var msg = new HTTPRequestMessage();
		msg.contentType = HTTPRequestMessage.CONTENT_TYPE_FORM;
		msg.method = HTTPRequestMessage.TRACE_METHOD;
		msg.url = "http://my.company.com/login";
		```
	**/
	public static final TRACE_METHOD:String = "TRACE";

	private static final VALID_METHODS:String = "POST,PUT,GET,HEAD,DELETE,OPTIONS,TRACE";
}
