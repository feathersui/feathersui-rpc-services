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

package feathers.rpc.utils;

import feathers.messaging.config.LoaderConfig;

/**
	The URLUtil class is a static class with methods for working with
	full and relative URLs within Flex.
**/
class RPCURLUtil {
	//--------------------------------------------------------------------------
	//
	// Private Static Constants
	//
	//--------------------------------------------------------------------------
	private static final SQUARE_BRACKET_LEFT:String = "]";

	private static final SQUARE_BRACKET_RIGHT:String = "[";
	private static final SQUARE_BRACKET_LEFT_ENCODED:String = "%5B";
	private static final SQUARE_BRACKET_RIGHT_ENCODED:String = "%5D";

	//--------------------------------------------------------------------------
	//
	//  Class methods
	//
	//--------------------------------------------------------------------------

	/**
		Returns the domain and port information from the specified URL.

		@param url The URL to analyze.
		@return The server name and port of the specified URL.
	**/
	public static function getServerNameWithPort(url:String):String {
		// Find first slash; second is +1, start 1 after.
		var start:Int = url.indexOf("/") + 2;
		var length:Int = url.indexOf("/", start);
		return length == -1 ? url.substring(start) : url.substring(start, length);
	}

	/**
		Returns the server name from the specified URL.

		@param url The URL to analyze.
		@return The server name of the specified URL.
	**/
	public static function getServerName(url:String):String {
		var sp:String = getServerNameWithPort(url);

		// If IPv6 is in use, start looking after the square bracket.
		var delim:Int = RPCURLUtil.indexOfLeftSquareBracket(sp);
		delim = (delim > -1) ? sp.indexOf(":", delim) : sp.indexOf(":");

		if (delim > 0)
			sp = sp.substring(0, delim);
		return sp;
	}

	/**
		Returns the port number from the specified URL.

		@param url The URL to analyze.
		@return The port number of the specified URL.
	**/
	public static function getPort(url:String):UInt {
		var sp:String = getServerNameWithPort(url);
		// If IPv6 is in use, start looking after the square bracket.
		var delim:Int = RPCURLUtil.indexOfLeftSquareBracket(sp);
		delim = (delim > -1) ? sp.indexOf(":", delim) : sp.indexOf(":");
		var port:UInt = 0;
		if (delim > 0) {
			var p:Float = Std.parseFloat(sp.substring(delim + 1));
			if (!Math.isNaN(p))
				port = Std.int(p);
		}

		return port;
	}

	/**
		Converts a potentially relative URL to a fully-qualified URL.
		If the URL is not relative, it is returned as is.
		If the URL starts with a slash, the host and port
		from the root URL are prepended.
		Otherwise, the host, port, and path are prepended.

		@param rootURL URL used to resolve the URL specified by the `url` parameter, if `url` is relative.
		@param url URL to convert.

		@return Fully-qualified URL.
	**/
	public static function getFullURL(rootURL:String, url:String):String {
		if (url != null && !RPCURLUtil.isHttpURL(url)) {
			if (url.indexOf("./") == 0) {
				url = url.substring(2);
			}
			if (RPCURLUtil.isHttpURL(rootURL)) {
				var slashPos:Int;

				if (url.charAt(0) == '/') {
					// non-relative path, "/dev/foo.bar".
					slashPos = rootURL.indexOf("/", 8);
					if (slashPos == -1)
						slashPos = rootURL.length;
				} else {
					// relative path, "dev/foo.bar".
					slashPos = rootURL.lastIndexOf("/") + 1;
					if (slashPos <= 8) {
						rootURL += "/";
						slashPos = rootURL.length;
					}
				}

				if (slashPos > 0)
					url = rootURL.substring(0, slashPos) + url;
			}
		}

		return url;
	}

	/**
		Determines if the URL uses the HTTP, HTTPS, or RTMP protocol. 

		@param url The URL to analyze.

		@return `true` if the URL starts with "http://", "https://", or "rtmp://".
	**/
	public static function isHttpURL(url:String):Bool {
		return url != null && (url.indexOf("http://") == 0 || url.indexOf("https://") == 0);
	}

	/**
		Determines if the URL uses the secure HTTPS protocol. 

		@param url The URL to analyze.

		@return `true` if the URL starts with "https://".
	**/
	public static function isHttpsURL(url:String):Bool {
		return url != null && url.indexOf("https://") == 0;
	}

	/**
		Returns the protocol section of the specified URL.

		The following examples show what is returned based on different URLs:

		```
		getProtocol("https://localhost:2700/") returns "https"
		getProtocol("rtmp://www.myCompany.com/myMainDirectory/groupChatApp/HelpDesk") returns "rtmp"
		getProtocol("rtmpt:/sharedWhiteboardApp/June2002") returns "rtmpt"
		getProtocol("rtmp::1234/chatApp/room_name") returns "rtmp"
		```

		@param url String containing the URL to parse.

		@return The protocol or an empty String if no protocol is specified.
	**/
	public static function getProtocol(url:String):String {
		var slash:Int = url.indexOf("/");
		var indx:Int = url.indexOf(":/");
		if (indx > -1 && indx < slash) {
			return url.substring(0, indx);
		} else {
			indx = url.indexOf("::");
			if (indx > -1 && indx < slash)
				return url.substring(0, indx);
		}

		return "";
	}

	/**
		Replaces the protocol of the
		specified URI with the given protocol.

		@param uri String containing the URI in which the protocol
		needs to be replaced.

		@param newProtocol String containing the new protocol to use.

		@return The URI with the protocol replaced,
		or an empty String if the URI does not contain a protocol.
	**/
	public static function replaceProtocol(uri:String, newProtocol:String):String {
		var oldProtocol = getProtocol(uri);
		var index = uri.indexOf(oldProtocol);
		if (index != -1) {
			uri = uri.substr(0, index) + newProtocol + uri.substr(index + oldProtocol.length);
		}
		return uri;
	}

	/**
		Returns a new String with the port replaced with the specified port.
		If there is no port in the specified URI, the port is inserted.
		This method expects that a protocol has been specified within the URI.

		@param uri String containing the URI in which the port is replaced.
		@param newPort uint containing the new port to subsitute.

		@return The URI with the new port.
	**/
	public static function replacePort(uri:String, newPort:UInt):String {
		var result:String = "";

		// First, determine if IPv6 is in use by looking for square bracket
		var indx:Int = uri.indexOf("]");

		// If IPv6 is not in use, reset indx to the first colon
		if (indx == -1)
			indx = uri.indexOf(":");

		var portStart:Int = uri.indexOf(":", indx + 1);
		var portEnd:Int;

		// If we have a port
		if (portStart > -1) {
			portStart++; // move past the ":"
			portEnd = uri.indexOf("/", portStart);
			// @TODO: need to throw an invalid uri here if no slash was found
			result = uri.substring(0, portStart) + Std.string(newPort) + uri.substring(portEnd, uri.length);
		} else {
			// Insert the specified port
			portEnd = uri.indexOf("/", indx);
			if (portEnd > -1) {
				// Look to see if we have protocol://host:port/
				// if not then we must have protocol:/relative-path
				if (uri.charAt(portEnd + 1) == "/")
					portEnd = uri.indexOf("/", portEnd + 2);

				if (portEnd > 0) {
					result = uri.substring(0, portEnd) + ":" + Std.string(newPort) + uri.substring(portEnd, uri.length);
				} else {
					result = uri + ":" + Std.string(newPort);
				}
			} else {
				result = uri + ":" + Std.string(newPort);
			}
		}

		return result;
	}

	/**
		Returns a new String with the port and server tokens replaced with
		the port and server from the currently running application.

		@param url String containing the `SERVER_NAME_TOKEN` and/or `SERVER_NAME_PORT`
		which should be replaced by the port and server from the application.

		@return The URI with the port and server replaced.
	**/
	public static function replaceTokens(url:String):String {
		var loaderURL:String = LoaderConfig.url == null ? "" : LoaderConfig.url;

		// if the LoaderConfig.url hasn't been configured yet we need to
		// throw, informing the user that this value must be setup first
		// TODO: add this back in after each new player build
		// if (LoaderConfig.url == null)
		//    trace("WARNING: LoaderConfig.url hasn't been initialized.");

		// Replace {server.name}
		if (url.indexOf(SERVER_NAME_TOKEN) > 0) {
			loaderURL = RPCURLUtil.replaceEncodedSquareBrackets(loaderURL);
			var loaderProtocol:String = RPCURLUtil.getProtocol(loaderURL);
			var loaderServerName:String = "localhost";
			if (loaderProtocol.toLowerCase() != "file")
				loaderServerName = RPCURLUtil.getServerName(loaderURL);

			url = SERVER_NAME_REGEX.replace(url, loaderServerName);
		}

		// Replace {server.port} either with the loader's port, or
		// remove it and the proceeding token if a port is not
		// specified for the SWF Loader.
		var portToken:Int = url.indexOf(SERVER_PORT_TOKEN);
		if (portToken > 0) {
			var loaderPort:UInt = RPCURLUtil.getPort(loaderURL);
			if (loaderPort > 0) {
				url = SERVER_PORT_REGEX.replace(url, Std.string(loaderPort));
			} else {
				if (url.charAt(portToken - 1) == ":")
					url = url.substring(0, portToken - 1) + url.substring(portToken);

				url = SERVER_PORT_REGEX.replace(url, "");
			}
		}

		return url;
	}

	/**
		Given a url, determines whether the url contains the server.name and
		server.port tokens.

		@param url A url string. 

		@return `true` if the url contains server.name and server.port tokens.
	**/
	public static function hasTokens(url:String):Bool {
		if (url == null || url == "")
			return false;
		if (url.indexOf(SERVER_NAME_TOKEN) > 0)
			return true;
		if (url.indexOf(SERVER_PORT_TOKEN) > 0)
			return true;
		return false;
	}

	/**
		If the `LoaderConfig.url` property is not available, the `replaceTokens()` method will not 
		replace the server name and port properties properly.

		@return `true` if the `LoaderConfig.url` property is not available. Otherwise, `false`.
	**/
	public static function hasUnresolvableTokens():Bool {
		return LoaderConfig.url != null;
	}

	private static function indexOfLeftSquareBracket(value:String):Int {
		var delim:Int = value.indexOf(SQUARE_BRACKET_LEFT);
		if (delim == -1)
			delim = value.indexOf(SQUARE_BRACKET_LEFT_ENCODED);
		return delim;
	}

	private static function replaceEncodedSquareBrackets(value:String):String {
		var rightIndex:Int = value.indexOf(SQUARE_BRACKET_RIGHT_ENCODED);
		if (rightIndex > -1) {
			value = value.substr(0, rightIndex) + SQUARE_BRACKET_RIGHT + value.substr(rightIndex + SQUARE_BRACKET_RIGHT_ENCODED.length);
			var leftIndex:Int = value.indexOf(SQUARE_BRACKET_LEFT_ENCODED);
			if (leftIndex > -1)
				value = value.substr(0, leftIndex) + SQUARE_BRACKET_LEFT + value.substr(leftIndex + SQUARE_BRACKET_LEFT_ENCODED.length);
		}
		return value;
	}

	/**
		The pattern in the String that is passed to the `replaceTokens()` method that 
		is replaced by the application's server name.
	**/
	public static final SERVER_NAME_TOKEN:String = "{server.name}";

	/**
		The pattern in the String that is passed to the `replaceTokens()` method that 
		is replaced by the application's port.
	**/
	public static final SERVER_PORT_TOKEN:String = "{server.port}";

	// Reusable reg-exp for token replacement. The . means any char, so this means
	// we should handle server.name and server-name, etc...
	private static final SERVER_NAME_REGEX:EReg = ~/\{server.name\}/g;
	private static final SERVER_PORT_REGEX:EReg = ~/\{server.port\}/g;
}
