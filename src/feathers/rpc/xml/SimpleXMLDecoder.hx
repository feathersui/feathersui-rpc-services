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

package feathers.rpc.xml;

import Xml.XmlType;
import feathers.data.ArrayCollection;
#if flash
import flash.xml.XMLNode;
import flash.xml.XMLNodeType;
#end

/**
 *  The SimpleXMLDecoder class deserialize XML into a graph of ActionScript objects.
 * Use  this class when no schema information is available.
 */
class SimpleXMLDecoder {
	//--------------------------------------------------------------------------
	//
	//  Class Methods
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 */
	public static function simpleType(val:Dynamic):Dynamic {
		var result:Dynamic = val;

		if (val != null) {
			// return the value as a string, a boolean or a number.
			// numbers that start with 0 are left as strings
			// bForceObject removed since we'll take care of converting to a String or Number object later
			if ((val is String) && cast(val, String) == "") {
				result = Std.string(val);
			} else if (Math.isNaN(Std.parseFloat(Std.string(val)))
				|| (val.charAt(0) == '0')
				|| ((val.charAt(0) == '-') && (val.charAt(1) == '0'))
				|| val.charAt(val.length - 1) == 'E') {
				var valStr:String = Std.string(val);

				// Bug 101205: Also check for boolean
				var valStrLC:String = valStr.toLowerCase();
				if (valStrLC == "true")
					result = true;
				else if (valStrLC == "false")
					result = false;
				else
					result = valStr;
			} else {
				result = Std.parseFloat(Std.string(val));
			}
		}

		return result;
	}

	//--------------------------------------------------------------------------
	//
	//  Constructor
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 *  Constructor.
	 */
	public function new(makeObjectsBindable:Bool = false) {
		this.makeObjectsBindable = makeObjectsBindable;
	}

	//--------------------------------------------------------------------------
	//
	//  Methods
	//
	//--------------------------------------------------------------------------

	/**
	 *  Converts a tree of XMLNodes into a tree of ActionScript Objects.
	 *
	 *  @param dataNode An XMLNode to be converted into a tree of ActionScript Objects.
	 *
	 *  @return A tree of ActionScript Objects.
	 */
	public function decodeXML(dataNode:#if flash XMLNode #else Xml #end):Dynamic {
		var result:Dynamic = null;
		var isSimpleType = false;

		if (dataNode == null)
			return null;

		// Cycle through the subnodes
		var children = #if flash dataNode.childNodes #else getXmlChildNodes(dataNode) #end;
		if (children.length == 1 && children[0].nodeType == #if flash XMLNodeType.TEXT_NODE #else XmlType.PCData #end) {
			// If exactly one text node subtype, we must want a simple
			// value.
			isSimpleType = true;
			result = SimpleXMLDecoder.simpleType(children[0].nodeValue);
		} else if (children.length > 0) {
			result = {};
			// if (makeObjectsBindable)
			// 	result = new ObjectProxy(result);

			for (i in 0...children.length) {
				var partNode:#if flash XMLNode #else Xml #end = children[i];

				// skip text nodes, which are part of mixed content
				if (partNode.nodeType != #if flash XMLNodeType.ELEMENT_NODE #else XmlType.Element #end) {
					continue;
				}

				var partName:String = getLocalName(partNode);
				var partObj = decodeXML(partNode);

				// Enable processing multiple copies of the same element (sequences)
				var existing = Reflect.field(result, partName);
				if (existing != null) {
					if ((existing is Array)) {
						cast(existing, Array<Dynamic>).push(partObj);
					} else if ((existing is ArrayCollection)) {
						cast(existing, ArrayCollection<Dynamic>).array.push(partObj);
					} else {
						var wrapperArray = [existing];
						wrapperArray.push(partObj);

						if (makeObjectsBindable)
							Reflect.setField(result, partName, new ArrayCollection(wrapperArray));
						else
							Reflect.setField(result, partName, wrapperArray);
					}
				} else {
					Reflect.setField(result, partName, partObj);
				}
			}
		}

		// Cycle through the attributes
		var isComplexString = false;
		var attributes = #if flash dataNode.attributes #else getXmlAttributes(dataNode) #end;
		for (attribute in Reflect.fields(attributes)) {
			if (attribute == "xmlns" || attribute.indexOf("xmlns:") != -1)
				continue;

			// result can be null if it contains no children.
			if (result == null) {
				result = {};
				// if (makeObjectsBindable)
				// 	result = new ObjectProxy(result);
			}

			// If result is not currently an Object (it is a Number, Boolean,
			// or String), then convert it to be a ComplexString so that we
			// can attach attributes to it.  (See comment in ComplexString.as)
			if (isSimpleType && !isComplexString) {
				result = toComplexString(result);
				isSimpleType = false;
				isComplexString = true;
			}

			Reflect.setField(result, attribute, SimpleXMLDecoder.simpleType(Reflect.field(attributes, attribute)));
		}

		return result;
	}

	private function getXmlChildNodes(xml:Xml):Array<Xml> {
		var result:Array<Xml> = [];
		for (element in xml.iterator()) {
			result.push(element);
		}
		return result;
	}

	private function getXmlAttributes(xml:Xml):Dynamic {
		var result:Dynamic = {};
		if (xml.nodeType != XmlType.Element) {
			return result;
		}
		for (attribute in xml.attributes()) {
			var value = xml.get(attribute);
			Reflect.setField(result, attribute, value);
		}
		return result;
	}

	private function toComplexString(value:Dynamic) {
		return {
			value: Std.string(value),
			valueOf: () -> {
				return SimpleXMLDecoder.simpleType(value);
			}
		};
	}

	/**
	 * Returns the local name of an XMLNode.
	 *
	 *  @param xmlNode The XMLNode. 
	 *
	 * @return The local name of an XMLNode.
	 */
	public static function getLocalName(xmlNode:#if flash XMLNode #else Xml #end):String {
		var name:String = xmlNode.nodeName;
		var myPrefixIndex = name.indexOf(":");
		if (myPrefixIndex != -1) {
			name = name.substring(myPrefixIndex + 1);
		}
		return name;
	}

	private var makeObjectsBindable:Bool;
}
