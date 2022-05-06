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

package feathers.messaging.config;

#if flash
/**
	The ConfigMap class provides a mechanism to store the properties returned 
	by the server with the ordering of the properties maintained. 
**/
@:meta(RemoteClass(alias = "flex.messaging.config.ConfigMap"))
class ConfigMap extends flash.utils.Proxy {
	//--------------------------------------------------------------------------
	//
	//  Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructor.

		@param item An Object containing name/value pairs.
	**/
	public function new(item:Dynamic = null) {
		super();

		if (!item)
			item = {};
		_item = item;

		propertyList = [];
	}

	//--------------------------------------------------------------------------
	//
	//  Variables
	//
	//--------------------------------------------------------------------------

	/**
		Contains a list of all of the property names for the proxied object.
	**/
	private var propertyList:Array<String>;

	//--------------------------------------------------------------------------
	//
	//  Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  object
	//----------------------------------

	/**
		Storage for the object property.
	**/
	private var _item:Dynamic;

	//--------------------------------------------------------------------------
	//
	//  Overridden methods
	//
	//--------------------------------------------------------------------------

	/**
		Returns the specified property value of the proxied object.

		@param name Typically a string containing the name of the property,
		or possibly a QName where the property name is found by 
		inspecting the <code>localName</code> property.

		@return The value of the property.
	**/
	@:ns("http://www.adobe.com/2006/actionscript/flash/proxy") override function getProperty(name:Dynamic):Dynamic {
		// if we have a data proxy for this then
		var result:Dynamic = null;
		result = _item[name];
		return result;
	}

	#if (haxe_ver >= 4.2)
	/**
		Returns the value of the proxied object's method with the specified name.

		@param name The name of the method being invoked.

		@param rest An array specifying the arguments to the
		called method.

		@return The return value of the called method.
	**/
	@:ns("http://www.adobe.com/2006/actionscript/flash/proxy") override function callProperty(name:Dynamic, ...rest:Dynamic):Dynamic {
		return Reflect.callMethod(_item, Reflect.field(_item, name), rest.toArray());
	}
	#end

	/**
		Deletes the specified property on the proxied object and
		sends notification of the delete to the handler.

		@param name Typically a string containing the name of the property,
		or possibly a QName where the property name is found by 
		inspecting the <code>localName</code> property.

		@return A Boolean indicating if the property was deleted.
	**/
	@:ns("http://www.adobe.com/2006/actionscript/flash/proxy") override function deleteProperty(name:Dynamic):Bool {
		var oldVal:Dynamic = Reflect.field(_item, name);
		var deleted:Bool = Reflect.deleteField(_item, name);
		var deleteIndex:Int = -1;
		for (i in 0...propertyList.length) {
			if (propertyList[i] == name) {
				deleteIndex = i;
				break;
			}
		}
		if (deleteIndex > -1) {
			propertyList.splice(deleteIndex, 1);
		}
		return deleted;
	}

	/**
		This is an internal function that must be implemented by 
		a subclass of flash.utils.Proxy.

		@param name The property name that should be tested 
		for existence.

		@return If the property exists, <code>true</code>; 
		otherwise <code>false</code>.

		@see flash.utils.Proxy#hasProperty()
	**/
	@:ns("http://www.adobe.com/2006/actionscript/flash/proxy") override function hasProperty(name:Dynamic):Bool {
		return Reflect.hasField(_item, name);
	}

	/**
		This is an internal function that must be implemented by 
		a subclass of flash.utils.Proxy.

		@param index The zero-based index of the object's
		property.

		@return The property's name.

		@see flash.utils.Proxy#nextName()
	**/
	@:ns("http://www.adobe.com/2006/actionscript/flash/proxy") override function nextName(index:Int):String {
		return propertyList[index - 1];
	}

	/**
		This is an internal function that must be implemented by 
		a subclass of flash.utils.Proxy.

		@param index The zero-based index of the object's
		property.

		@return The zero-based index of the next proprety.

		@see flash.utils.Proxy#nextNameIndex()
	**/
	@:ns("http://www.adobe.com/2006/actionscript/flash/proxy") override function nextNameIndex(index:Int):Int {
		if (index < propertyList.length) {
			return index + 1;
		} else {
			return 0;
		}
	}

	/**
		This is an internal function that must be implemented by 
		a subclass of flash.utils.Proxy.

		@param index The zero-based index value of the object's
		property.

		@return The property's value.

		@see flash.utils.Proxy#nextValue()
	**/
	@:ns("http://www.adobe.com/2006/actionscript/flash/proxy") override function nextValue(index:Int):Dynamic {
		return Reflect.field(_item, propertyList[index - 1]);
	}

	/**
		Updates the specified property on the proxied object
		and sends notification of the update to the handler.

		@param name Object containing the name of the property that
		should be updated on the proxied object.

		@param value Value that should be set on the proxied object.
	**/
	@:ns("http://www.adobe.com/2006/actionscript/flash/proxy") override function setProperty(name:Dynamic, value:Dynamic):Void {
		var oldVal:Dynamic = Reflect.field(_item, name);
		if (oldVal != value) {
			// Update item.
			Reflect.setField(_item, name, value);
			for (i in 0...propertyList.length) {
				if (propertyList[i] == name) {
					return;
				}
			}
			propertyList.push(name);
		}
	}
}
#end
