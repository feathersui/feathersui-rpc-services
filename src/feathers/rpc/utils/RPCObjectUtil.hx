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

import openfl.Lib;
#if flash
import flash.utils.QName;
import flash.errors.Error;
import haxe.Exception;
#end

/**
	The RPCObjectUtil class is a subset of ObjectUtil, removing methods
	that create dependency issues when RPC messages are in a bootstrap loader.
**/
class RPCObjectUtil {
	/**
		Array of properties to exclude from debugging output.
	**/
	private static var defaultToStringExcludes:Array<String> = ["password", "credentials"];

	//--------------------------------------------------------------------------
	//
	//  Class methods
	//
	//--------------------------------------------------------------------------

	/**
		Change default set of strings to exclude.

		@param excludes The array of strings to exclude.
	**/
	public static function setToStringExcludes(excludes:Array<String>):Void {
		defaultToStringExcludes = excludes;
	}

	private static var _externalToString:(Any, Array<String>, Array<String>) -> String = null;

	/**
		Assign an static external toString method rather than use the internal one.

		The function passed in needs to have the same signature as `toString`.

		```haxe
		public static function externalToString(value:Any, namespaceURIs:Array = null, exclude:Array = null):String
		```

		@param externalToString The function to call instead of internalToString.
	**/
	public static function externalToString(value:(Any, Array<String>, Array<String>) -> String):Void {
		_externalToString = value;
	}

	/**
		Pretty-prints the specified Object into a String.
		All properties will be in alpha ordering.
		Each object will be assigned an id during printing;
		this value will be displayed next to the object type token
		preceded by a '#', for example:

		<pre>
		(mx.messaging.messages::AsyncMessage)#2.</pre>

		This id is used to indicate when a circular reference occurs.
		Properties of an object that are of the `Class` type will
		appear only as the assigned type.
		For example a custom definition like the following:

		<pre>
		public class MyCustomClass {
		public var clazz:Class;
		}</pre>

		With the `clazz` property assigned to `Date`
		will display as shown below:

		<pre>
		(somepackage::MyCustomClass)#0
		clazz = (Date)</pre>

		@param obj Object to be pretty printed.

		@param namespaceURIs Array of namespace URIs for properties 
		that should be included in the output.
		By default only properties in the public namespace will be included in
		the output.
		To get all properties regardless of namespace pass an array with a 
		single element of "*".

		@param exclude Array of the property names that should be 
		excluded from the output.
		Use this to remove data from the formatted string.

		@return String containing the formatted version
		of the specified object.

		```haxe
		// example 1
		var obj = new AsyncMessage();
		obj.body = [];
		obj.body.push(new AsyncMessage());
		obj.headers["1"] = { name: "myName", num: 15.3};
		obj.headers["2"] = { name: "myName", num: 15.3};
		obj.headers["10"] = { name: "myName", num: 15.3};
		obj.headers["11"] = { name: "myName", num: 15.3};
		trace(ObjectUtil.toString(obj));
		```

		```
		// will output to flashlog.txt
		(mx.messaging.messages::AsyncMessage)#0
		  body = (Array)#1
			[0] (mx.messaging.messages::AsyncMessage)#2
			  body = (Object)#3
			  clientId = (Null)
			  correlationId = ""
			  destination = ""
			  headers = (Object)#4
			  messageId = "378CE96A-68DB-BC1B-BCF7FFFFFFFFB525"
			  sequenceId = (Null)
			  sequencePosition = 0
			  sequenceSize = 0
			  timeToLive = 0
			  timestamp = 0
		  clientId = (Null)
		  correlationId = ""
		  destination = ""
		  headers = (Object)#5
			1 = (Object)#6
			  name = "myName"
			  num = 15.3
			10 = (Object)#7
			  name = "myName"
			  num = 15.3
			11 = (Object)#8
			  name = "myName"
			  num = 15.3
			2 = (Object)#9
			  name = "myName"
			  num = 15.3
		  messageId = "1D3E6E96-AC2D-BD11-6A39FFFFFFFF517E"
		  sequenceId = (Null)
		  sequencePosition = 0
		  sequenceSize = 0
		  timeToLive = 0
		  timestamp = 0
		```

		```haxe
		// example 2 with circular references
		obj = {};
		obj.prop1 = new Date();
		obj.prop2 = [];
		obj.prop2.push(15.2);
		obj.prop2.push("testing");
		obj.prop2.push(true);
		obj.prop3 = {};
		obj.prop3.circular = obj;
		obj.prop3.deeper = new ErrorMessage();
		obj.prop3.deeper.rootCause = obj.prop3.deeper;
		obj.prop3.deeper2 = {};
		obj.prop3.deeper2.deeperStill = {};
		obj.prop3.deeper2.deeperStill.yetDeeper = obj;
		trace(ObjectUtil.toString(obj));
		```

		```
		// will output to flashlog.txt
		(Object)#0
		  prop1 = Tue Apr 26 13:59:17 GMT-0700 2005
		  prop2 = (Array)#1
			[0] 15.2
			[1] "testing"
			[2] true
		  prop3 = (Object)#2
			circular = (Object)#0
			deeper = (mx.messaging.messages::ErrorMessage)#3
			  body = (Object)#4
			  clientId = (Null)
			  code = (Null)
			  correlationId = ""
			  destination = ""
			  details = (Null)
			  headers = (Object)#5
			  level = (Null)
			  message = (Null)
			  messageId = "14039376-2BBA-0D0E-22A3FFFFFFFF140A"
			  rootCause = (mx.messaging.messages::ErrorMessage)#3
			  sequenceId = (Null)
			  sequencePosition = 0
			  sequenceSize = 0
			  timeToLive = 0
			  timestamp = 0
			deeper2 = (Object)#6
			  deeperStill = (Object)#7
				yetDeeper = (Object)#0
		```
	**/
	public static function toString(value:Any, namespaceURIs:Array<String> = null, exclude:Array<String> = null):String {
		if (exclude == null) {
			exclude = defaultToStringExcludes;
		}

		refCount = 0;

		if (_externalToString != null)
			return _externalToString(value, namespaceURIs, exclude);
		else
			return internalToString(value, 0, null, namespaceURIs, exclude);
	}

	// This method cleans up all of the additional parameters that show up in AsDoc
	// code hinting tools that developers shouldn't ever see.
	private static function internalToString(value:Any, indent:Int = 0, refs:Any = null, namespaceURIs:Array<String> = null,
			exclude:Array<String> = null):String {
		if (value == null) {
			return "(null)";
		}
		if ((value is String)) {
			return '"$value"';
		}
		if ((value is Bool) || (value is Float) || (value is Date) || (value is Class) || (value is Xml)) {
			return Std.string(value);
		}
		var valueClass = Type.getClass(value);
		if (valueClass != null) {
			return '(${Type.getClassName(valueClass)})';
		}
		return "(unknown)";
	}

	// This method will append a newline and the specified number of spaces
	// to the given string.
	private static function newline(str:String, length:Int = 0):String {
		var result:String = str + "\n";
		for (i in 0...length) {
			result += " ";
		}
		return result;
	}

	/**
		Returns information about the class, and properties of the class, for
		the specified Object.

		@param obj The Object to inspect.

		@param exclude Array of Strings specifying the property names that should be 
		excluded from the returned result. For example, you could specify 
		`["currentTarget", "target"]` for an Event object since these properties 
		can cause the returned result to become large.

		@param options An Object containing one or more properties 
		that control the information returned by this method. 
		The properties include the following:

		- `includeReadOnly`: If `false`, 
		exclude Object properties that are read-only. 
		The default value is `true`.
		- `includeTransient`: If `false`, 
		exclude Object properties and variables that have `[Transient]` metadata.
		The default value is `true`.
		- `uris`: Array of Strings of all namespaces that should be included in the output.
		It does allow for a wildcard of "~~". 
		By default, it is null, meaning no namespaces should be included. 
		For example, you could specify `["mx_internal", "mx_object"]` 
		or `["~~"]`.

		@return An Object containing the following properties:
		- `name`: String containing the name of the class;
		- `properties`: Sorted list of the property names of the specified object.
	**/
	public static function getClassInfo(obj:Dynamic, excludes:Array<String> = null, options:Dynamic = null):Dynamic {
		var length:Int = 0;
		var i:Int = 0;

		// this version doesn't handle ObjectProxy

		if (options == null)
			options = {includeReadOnly: true, uris: null, includeTransient: true};

		var result:Dynamic;
		var propertyNames:Array<Dynamic> = [];
		var cacheKey:String;

		var className:String = null;
		var classAlias:String = null;
		#if flash
		var properties:flash.xml.XMLList;
		var prop:flash.xml.XML;
		#end
		var isDynamic:Bool = false;
		var metadataInfo:Dynamic;
		var numericIndex:Bool = false;

		#if flash
		if ((obj is flash.xml.XML)) {
			className = "XML";
			properties = obj.text();
			if (properties.length() != 0)
				propertyNames.push("*");
			properties = obj.attributes();
		} else {
			// don't cache describe type.  Makes it slower, but fewer dependencies
			var classInfo:flash.xml.XML = flash.Lib.describeType(obj);
			className = Std.string(classInfo.attribute("name"));
			classAlias = Std.string(classInfo.attribute("alias"));
			isDynamic = (Std.string(classInfo.attribute("isDynamic")) == "true");

			properties = new flash.xml.XMLList();
			var accessors = classInfo.descendants("accessor");
			for (i in 0...accessors.length()) {
				var accessor = accessors[i];
				if (options.includeReadOnly && Std.string(accessor.attribute("access")) != "writeonly") {
					properties.appendChild(accessor);
				} else if (!options.includeReadOnly && Std.string(accessor.attribute("access")) == "readwrite") {
					properties.appendChild(accessor);
				}
			}
			var variables = classInfo.descendants("variable");
			for (i in 0...variables.length()) {
				var variable = variables[i];
				properties.appendChild(variable);
			}
		}
		#else
		var detectedClass = Type.getClass(obj);
		if (detectedClass == null) {
			isDynamic = true;
		}
		#end

		// If type is not dynamic, check our cache for class info...
		if (!isDynamic) {
			cacheKey = getCacheKey(obj, excludes, options);
			result = Reflect.field(CLASS_INFO_CACHE, cacheKey);
			if (result != null)
				return result;
		}
		result = {};
		Reflect.setField(result, "name", className);
		Reflect.setField(result, "alias", classAlias);
		Reflect.setField(result, "properties", propertyNames);
		Reflect.setField(result, "dynamic", isDynamic);
		metadataInfo = #if flash recordMetadata(properties) #else null #end;
		Reflect.setField(result, "metadata", metadataInfo);
		var excludeObject:Dynamic = {};
		if (excludes != null) {
			length = excludes.length;
			for (i in 0...length) {
				Reflect.setField(excludeObject, excludes[i], 1);
			}
		}
		var isArray:Bool = className == "Array";
		if (isDynamic) {
			for (p in Reflect.fields(obj)) {
				if (Reflect.field(excludeObject, p) != 1) {
					if (isArray) {
						var pi:Float = Std.parseInt(p);

						if (Math.isNaN(pi)) {
							propertyNames.push(p);
							numericIndex = true;
						} else
							propertyNames.push(pi);
					} else {
						propertyNames.push(p);
					}
				}
			}
		}
		#if flash
		if (className == "Object" || isArray) {
			// Do nothing since we've already got the dynamic members
		} else if (className == "XML") {
			length = properties.length();
			for (i in 0...length) {
				var p = properties[i].name();
				if (Reflect.field(excludeObject, p) != 1)
					propertyNames.push(new QName("", "@" + p));
			}
		} else {
			length = properties.length();
			var uris:Array<Dynamic> = options.uris;
			var uri:String;
			var qName:QName;
			var includeTransients:Bool;

			includeTransients = options.hasOwnProperty("includeTransient") && options.includeTransient;
			for (i in 0...length) {
				prop = properties[i];
				var p = Std.string(prop.attribute("name"));
				uri = Std.string(prop.attribute("uri"));
				if (Reflect.field(excludeObject, p) == 1)
					continue;
				if (!includeTransients && internalHasMetadata(metadataInfo, p, "Transient"))
					continue;
				if (uris != null) {
					if (uris.length == 1 && uris[0] == "*") {
						qName = new QName(uri, p);
						try {
							Reflect.field(obj, qName.localName); // access the property to ensure it is supported
							// propertyNames.push();
						} catch (e:Dynamic) {
							// don't keep property name
						}
					} else {
						for (j in 0...uris.length) {
							uri = uris[j];
							if (Std.string(prop.attribute("uri")) == uri) {
								qName = new QName(uri, p);
								try {
									Reflect.field(obj, qName.localName);
									propertyNames.push(qName);
								} catch (e:Dynamic) {
									// don't keep property name
								}
							}
						}
					}
				} else if (uri.length == 0) {
					qName = new QName(uri, p);
					try {
						Reflect.field(obj, qName.localName);
						propertyNames.push(qName);
					} catch (e:Dynamic) {
						// don't keep property name
					}
				}
			}
		}
		#end
		propertyNames.sort((a, b) -> {
			if (numericIndex) {
				var aNum:Float = a;
				var bNum:Float = b;
				if (aNum < bNum) {
					return -1;
				}
				if (aNum > bNum) {
					return 1;
				}
				return 0;
			}
			var aString = Std.string(a).toLowerCase();
			var bString = Std.string(b).toLowerCase();
			if (aString < bString) {
				return -1;
			}
			if (aString > bString) {
				return 1;
			}
			return 0;
		});
		// remove any duplicates, i.e. any items that can't be distingushed by toString()
		length = propertyNames.length;
		var i = 0;
		while (i < (length - 1)) {
			// the list is sorted so any duplicates should be adjacent
			// two properties are only equal if both the uri and local name are identical
			if (Std.string(propertyNames[i]) == Std.string(propertyNames[i + 1])) {
				propertyNames.splice(i, 1);
				i--; // back up
			}
			i++;
		}
		// For normal, non-dynamic classes we cache the class info
		if (!isDynamic) {
			cacheKey = getCacheKey(obj, excludes, options);
			Reflect.setField(CLASS_INFO_CACHE, cacheKey, result);
		}
		return result;
	}

	private static function internalHasMetadata(metadataInfo:Dynamic, propName:String, metadataName:String):Bool {
		if (metadataInfo != null) {
			var metadata:Dynamic = Reflect.field(metadataInfo, propName);
			if (metadata != null) {
				if (Reflect.field(metadata, metadataName) != null)
					return true;
			}
		}
		return false;
	}

	#if flash
	private static function recordMetadata(properties:flash.xml.XMLList):Dynamic {
		var result:Dynamic = null;

		try {
			var propertiesList = properties.elements();
			for (i in 0...propertiesList.length()) {
				var prop = propertiesList[i];
				var propName:String = Std.string(prop.attribute("name"));
				var metadataList:flash.xml.XMLList = prop.metadata;

				if (metadataList.length() > 0) {
					if (result == null)
						result = {};

					var metadata:Dynamic = {};
					Reflect.setField(result, propName, metadata);

					var mdList = metadataList.elements();
					for (j in 0...mdList.length()) {
						var md = mdList[j];
						var mdName:String = Std.string(md.attribute("name"));

						var argsList:flash.xml.XMLList = md.arg;
						var value:Dynamic = {};

						for (k in 0...argsList.length()) {
							var arg = argsList[k];
							var argKey:String = Std.string(arg.attribute("key"));
							if (argKey != null) {
								var argValue:String = Std.string(arg.attribute("value"));
								Reflect.setField(value, argKey, argValue);
							}
						}

						var existing:Dynamic = Reflect.field(metadata, mdName);
						if (existing != null) {
							var existingArray:Array<Dynamic>;
							if ((existing is Array))
								existingArray = cast(existing, Array<Dynamic>);
							else
								existingArray = [];
							existingArray.push(value);
							existing = existingArray;
						} else {
							existing = value;
						}
						Reflect.setField(metadata, mdName, existing);
					}
				}
			}
		} catch (e:Dynamic) {}

		return result;
	}
	#end

	private static function getCacheKey(o:Dynamic, excludes:Array<String> = null, options:Dynamic = null):String {
		var key:String = Lib.getQualifiedClassName(o);

		if (excludes != null) {
			var length:Int = excludes.length;
			for (i in 0...length) {
				var excl:String = excludes[i];
				if (excl != null)
					key += excl;
			}
		}

		if (options != null) {
			for (flag in Reflect.fields(options)) {
				key += flag;
				var value:Dynamic = Reflect.field(options, flag);
				if (value != null) {
					key += Std.string(value);
				}
			}
		}
		return key;
	}

	private static var refCount:Int = 0;

	private static var CLASS_INFO_CACHE:Dynamic = {};
}
