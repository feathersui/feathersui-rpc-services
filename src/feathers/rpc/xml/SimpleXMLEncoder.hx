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

import feathers.rpc.utils.RPCObjectUtil;
#if flash
import flash.utils.QName;
import flash.xml.XMLDocument;
import flash.xml.XMLNode;
#end

/**
 * The SimpleXMLEncoder class takes ActionScript Objects and encodes them to XML
 * using default serialization.
 */
class SimpleXMLEncoder {
	//--------------------------------------------------------------------------
	//
	//  Class Methods
	//
	//--------------------------------------------------------------------------

	/**
	 * @private
	 */
	private static function encodeDate(rawDate:Date, dateType:String):String {
		var s:String = "";
		var n:Float;

		if (dateType == "dateTime" || dateType == "date") {
			s += rawDate.getUTCFullYear() + "-";

			n = rawDate.getUTCMonth() + 1;
			if (n < 10)
				s += "0";
			s += n + "-";

			n = rawDate.getUTCDate();
			if (n < 10)
				s += "0";
			s += n;
		}

		if (dateType == "dateTime") {
			s += "T";
		}

		if (dateType == "dateTime" || dateType == "time") {
			n = rawDate.getUTCHours();
			if (n < 10)
				s += "0";
			s += n + ":";

			n = rawDate.getUTCMinutes();
			if (n < 10)
				s += "0";
			s += n + ":";

			n = rawDate.getUTCSeconds();
			if (n < 10)
				s += "0";
			s += n + ".";

			s += "000";
			/*n = rawDate.getUTCMilliseconds();
				if (n < 10)
					s += "00";
				else if (n < 100)
					s += "0";
				s += n; */
		}

		s += "Z";

		return s;
	}

	//--------------------------------------------------------------------------
	//
	//  Constructor
	//
	//--------------------------------------------------------------------------

	/**
	 *  Constructor.
	 *
	 *  @param myXML The XML object.
	 */
	public function new(myXML:#if flash XMLDocument #else Xml #end) {
		this.myXMLDoc = myXML != null ? myXML : #if flash new XMLDocument() #else Xml.createDocument() #end;
	}

	//--------------------------------------------------------------------------
	//
	//  Variables
	//
	//--------------------------------------------------------------------------
	private var myXMLDoc:#if flash XMLDocument #else Xml #end;

	//--------------------------------------------------------------------------
	//
	//  Methods
	//
	//--------------------------------------------------------------------------

	/**
	 *  Encodes an ActionScript object to XML using default serialization.
	 *  
	 *  @param obj The ActionScript object to encode.
	 *  
	 *  @param qname The qualified name of the child node.
	 *  
	 *  @param parentNode An XMLNode under which to put the encoded
	 *  value.
	 *
	 *
	 *  @return The XMLNode object. 
	 */
	public function encodeValue(obj:Dynamic, qname:#if flash QName #else String #end,
			parentNode:#if flash XMLNode #else Xml #end):#if flash XMLNode #else Xml #end {
		var myElement:#if flash XMLNode #else Xml #end;

		if (obj == null)
			return null;

		// Skip properties that are functions
		var typeType:UInt = getDataTypeFromObject(obj);
		if (typeType == SimpleXMLEncoder.FUNCTION_TYPE)
			return null;

		if (typeType == SimpleXMLEncoder.XML_TYPE) {
			myElement = obj.cloneNode(true);
			#if flash
			parentNode.appendChild(myElement);
			#else
			parentNode.addChild(myElement);
			#end
			return myElement;
		}

		#if flash
		myElement = myXMLDoc.createElement("foo");
		myElement.nodeName = qname.localName;
		parentNode.appendChild(myElement);
		#else
		myElement = Xml.createElement("foo");
		myElement.nodeName = qname;
		parentNode.addChild(myElement);
		#end

		if (typeType == SimpleXMLEncoder.OBJECT_TYPE) {
			var classInfo:Dynamic = RPCObjectUtil.getClassInfo(obj, null, CLASS_INFO_OPTIONS);
			var properties:Array<String> = classInfo.properties;
			for (fieldName in properties) {
				var propQName = #if flash new QName("", fieldName) #else fieldName #end;
				encodeValue(Reflect.field(obj, fieldName), propQName, myElement);
			}
		} else if (typeType == SimpleXMLEncoder.ARRAY_TYPE) {
			var numMembers:UInt = obj.length;
			var itemQName = #if flash new QName("", "item") #else "item" #end;

			for (i in 0...numMembers) {
				encodeValue(obj[i], itemQName, myElement);
			}
		} else {
			// Simple types fall through to here
			var valueString:String;

			if (typeType == SimpleXMLEncoder.DATE_TYPE) {
				valueString = encodeDate(Std.downcast(obj, Date), "dateTime");
			} else if (typeType == SimpleXMLEncoder.NUMBER_TYPE) {
				if (obj == Math.POSITIVE_INFINITY)
					valueString = "INF";
				else if (obj == Math.NEGATIVE_INFINITY)
					valueString = "-INF";
				else {
					var rep:String = Std.string(obj);
					// see if its hex
					var start:String = rep.substr(0, 2);
					if (start == "0X" || start == "0x") {
						valueString = Std.string(Std.parseInt(rep));
					} else {
						valueString = rep;
					}
				}
			} else {
				valueString = Std.string(obj);
			}

			#if flash
			var valueNode:XMLNode = myXMLDoc.createTextNode(valueString);
			myElement.appendChild(valueNode);
			#else
			var valueNode = Xml.createPCData(valueString);
			myElement.addChild(valueNode);
			#end
		}

		return myElement;
	}

	/**
	 *  @private
	 */
	private function getDataTypeFromObject(obj:Dynamic):UInt {
		if ((obj is Float))
			return SimpleXMLEncoder.NUMBER_TYPE;
		else if ((obj is Bool))
			return SimpleXMLEncoder.BOOLEAN_TYPE;
		else if ((obj is String))
			return SimpleXMLEncoder.STRING_TYPE;
		else if ((obj is #if flash XMLDocument #else Xml #end))
			return SimpleXMLEncoder.XML_TYPE;
		else if ((obj is Date))
			return SimpleXMLEncoder.DATE_TYPE;
		else if ((obj is Array))
			return SimpleXMLEncoder.ARRAY_TYPE;
		else if (Reflect.isFunction(obj))
			return SimpleXMLEncoder.FUNCTION_TYPE;
		else if (obj != null)
			return SimpleXMLEncoder.OBJECT_TYPE;
		else if (Reflect.isObject(obj))
			return SimpleXMLEncoder.OBJECT_TYPE;
		// Otherwise force it to string
		return SimpleXMLEncoder.STRING_TYPE;
	}

	private static final NUMBER_TYPE:UInt = 0;
	private static final STRING_TYPE:UInt = 1;
	private static final OBJECT_TYPE:UInt = 2;
	private static final DATE_TYPE:UInt = 3;
	private static final BOOLEAN_TYPE:UInt = 4;
	private static final XML_TYPE:UInt = 5;
	private static final ARRAY_TYPE:UInt = 6; // An array with a wrapper element
	private static final MAP_TYPE:UInt = 7;
	private static final ANY_TYPE:UInt = 8;
	// We don't appear to use this type anywhere, commenting out
	// private static final COLL_TYPE:UInt     = 10; // A collection (no wrapper element, just maxOccurs)
	private static final ROWSET_TYPE:UInt = 11;
	private static final QBEAN_TYPE:UInt = 12; // CF QueryBean
	private static final DOC_TYPE:UInt = 13;
	private static final SCHEMA_TYPE:UInt = 14;
	private static final FUNCTION_TYPE:UInt = 15; // We currently do not serialize properties of type function
	private static final ELEMENT_TYPE:UInt = 16;
	private static final BASE64_BINARY_TYPE:UInt = 17;
	private static final HEX_BINARY_TYPE:UInt = 18;

	/**
	 * @private
	 */
	private static final CLASS_INFO_OPTIONS:Dynamic = {includeReadOnly: false, includeTransient: false};
}
