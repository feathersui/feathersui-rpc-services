package feathers.utils;

import openfl.errors.Error;
import openfl.net.ObjectEncoding;
import openfl.utils.ByteArray;
import openfl.utils.Endian;
import openfl.utils.IDataInput;
import openfl.utils.IExternalizable;

class AMF3Reader implements IDataInput {
	private static final AMF0_AMF3:Int = 0x11;
	private static final AMF3_OBJECT_ENCODING:Int = 0x03;
	private static final AMF3_UNDEFINED:Int = 0x00;
	private static final AMF3_NULL:Int = 0x01;
	private static final AMF3_BOOLEAN_FALSE:Int = 0x02;
	private static final AMF3_BOOLEAN_TRUE:Int = 0x03;
	private static final AMF3_INTEGER:Int = 0x04;
	private static final AMF3_DOUBLE:Int = 0x05;
	private static final AMF3_STRING:Int = 0x06;
	private static final AMF3_XMLDOCUMENT:Int = 0x07;
	private static final AMF3_DATE:Int = 0x08;
	private static final AMF3_ARRAY:Int = 0x09;
	private static final AMF3_OBJECT:Int = 0x0A;
	private static final AMF3_XML:Int = 0x0B;
	private static final AMF3_BYTEARRAY:Int = 0x0C;
	private static final AMF3_VECTOR_INT:Int = 0x0D;
	private static final AMF3_VECTOR_UINT:Int = 0x0E;
	private static final AMF3_VECTOR_DOUBLE:Int = 0x0F;
	private static final AMF3_VECTOR_OBJECT:Int = 0x10;
	private static final AMF3_DICTIONARY:Int = 0x11;
	private static final UINT29_MASK:Int = 0x1FFFFFFF;
	private static final INT28_MAX_VALUE:Int = 268435455;
	private static final INT28_MIN_VALUE:Int = -268435456;
	private static final EMPTY_STRING:String = "";

	private static function getAliasByClass(theClass:Dynamic):String {
		var registeredClassAliases = @:privateAccess openfl.Lib.__registeredClassAliases;
		for (key => value in registeredClassAliases) {
			if (value == theClass) {
				return key;
			}
		}
		return null;
	}

	public function new(targetReference:ByteArray) {
		target = targetReference;
		reset();
	}

	private var objects:Array<Dynamic>;
	private var traits:Array<Dynamic>;
	private var strings:Array<Dynamic>;

	private var target:ByteArray;

	public var endian(get, set):Endian;

	private function get_endian():Endian {
		return target.endian;
	}

	private function set_endian(value:Endian):Endian {
		target.endian = value;
		return target.endian;
	}

	public var objectEncoding:ObjectEncoding;

	public var bytesAvailable(get, never):Int;

	private function get_bytesAvailable():Int {
		return target.bytesAvailable;
	}

	public function reset():Void {
		objects = [];
		traits = [];
		strings = [];
	}

	public function readByte():Int {
		return target.readByte();
	}

	public function readUnsignedByte():UInt {
		return target.readUnsignedByte();
	}

	public function readBoolean():Bool {
		return target.readBoolean();
	}

	public function readShort():Int {
		return target.readShort();
	}

	public function readUnsignedShort():UInt {
		return target.readUnsignedShort();
	}

	public function readInt():Int {
		return target.readInt();
	}

	public function readUnsignedInt():Int {
		return target.readUnsignedInt();
	}

	public function readFloat():Float {
		return target.readFloat();
	}

	public function readDouble():Float {
		return target.readDouble();
	}

	public function readUInt29():Int {
		final read = readUnsignedByte;
		var b:UInt = read() & 255;
		if (b < 128) {
			return b;
		}
		var value:UInt = (b & 127) << 7;
		b = read() & 255;
		if (b < 128)
			return (value | b);
		value = (value | (b & 127)) << 7;
		b = read() & 255;
		if (b < 128)
			return (value | b);
		value = (value | (b & 127)) << 8;
		b = read() & 255;
		return (value | b);
	}

	public function readObject():Dynamic {
		target.objectEncoding = objectEncoding;
		if (objectEncoding == AMF0)
			return readAmf0Object();
		else
			return readAmf3Object();
	}

	public function readUTF():String {
		return target.readUTF();
	}

	public function readUTFBytes(length:UInt):String {
		return target.readUTFBytes(length);
	}

	public function readMultiByte(length:UInt, charSet:String):String {
		throw new Error("readMultiByte not supported");
	}

	public function readBytes(bytes:ByteArray, offset:UInt = 0, length:UInt = 0):Void {
		target.readBytes(bytes, offset, length);
	}

	public function readAmf0Object():Dynamic {
		throw new Error("AMF0 support not supported");
	}

	public function readAmf3Object():Dynamic {
		var amfType:UInt = readUnsignedByte();
		return readAmf3ObjectValue(amfType);
	}

	public function readAmf3XML():Dynamic {
		var ref:UInt = readUInt29();
		if ((ref & 1) == 0)
			return getObject(ref >> 1);
		else {
			var len:UInt = (ref >> 1);
			var stringSource:String = readUTFBytes(len);
			// if (!_xmlClass) {
			throw new Error("XML class is not linked in, as required for deserialization");
			// }
			// var xml:Dynamic = Type.createInstance(_xmlClass, stringSource);
			// rememberObject(xml);
			// return xml;
		}
	}

	public function readAmf3String():String {
		var ref:UInt = readUInt29();
		if ((ref & 1) == 0) {
			return getString(ref >> 1);
		} else {
			var len:UInt = (ref >> 1);
			if (len == 0) {
				return EMPTY_STRING;
			}
			var str:String = readUTFBytes(len);
			rememberString(str);
			return str;
		}
	}

	private function rememberString(v:String):Void {
		strings.push(v);
	}

	private function getString(v:UInt):String {
		return strings[v];
	}

	private function getObject(v:UInt):Dynamic {
		return objects[v];
	}

	private function getTraits(v:UInt):AMFTraits {
		return traits[v];
	}

	private function rememberTraits(v:AMFTraits):Void {
		traits.push(v);
	}

	private function rememberObject(v:Dynamic):Void {
		objects.push(v);
	}

	private function readTraits(ref:UInt):AMFTraits {
		var ti:AMFTraits;
		if ((ref & 3) == 1) {
			ti = getTraits(ref >> 2);
			return ti;
		} else {
			ti = new AMFTraits();
			ti.externalizable = ((ref & 4) == 4);
			ti.isDynamic = ((ref & 8) == 8);
			ti.count = (ref >> 4);
			var className:String = readAmf3String();
			if (className != null && className != "") {
				ti.alias = className;
			}

			for (i in 0...ti.count) {
				ti.props.push(readAmf3String());
			}

			rememberTraits(ti);
			return ti;
		}
	}

	private function readScriptObject():Dynamic {
		var ref:UInt = readUInt29();
		if ((ref & 1) == 0) {
			// retrieve object from object reference table
			return getObject(ref >> 1);
		} else {
			var decodedTraits:AMFTraits = readTraits(ref);
			var obj:Dynamic;
			var localTraits:AMFTraits = null;
			if (decodedTraits.alias != null && decodedTraits.alias.length > 0) {
				var c:Class<Dynamic> = openfl.Lib.getClassByAlias(decodedTraits.alias);
				if (c != null) {
					obj = Type.createInstance(c, []);
					localTraits = getLocalTraitsInfo(obj);
				} else {
					obj = {};
				}
			} else {
				obj = {};
			}
			rememberObject(obj);
			if (decodedTraits.externalizable) {
				obj.readExternal(this);
			} else {
				final l:UInt = decodedTraits.props.length;
				var hasProp:Bool;
				for (i in 0...l) {
					var fieldValue:Dynamic = readObject();
					var prop:String = decodedTraits.props[i];
					hasProp = localTraits != null && (localTraits.hasProp(prop) || localTraits.isDynamic || localTraits.isTransient(prop));
					if (hasProp) {
						Reflect.field(localTraits.getterSetters, prop).setValue(obj, fieldValue);
					} else {
						if (localTraits == null) {
							Reflect.setField(obj, prop, fieldValue);
						} else {
							// @todo add debug-only logging for error checks (e.g. ReferenceError: Error #1074: Illegal write to read-only property)
							#if debug
							trace('ReferenceError: Error #1056: Cannot create property ' + prop + ' on ' + localTraits.qName);
							#end
						}
					}
				}
				if (decodedTraits.isDynamic) {
					while (true) {
						var name:String = readAmf3String();
						if (name == null || name.length == 0) {
							break;
						}
						Reflect.setField(obj, name, readObject());
					}
				}
			}
			return obj;
		}
	}

	private function getLocalTraitsInfo(instance:Dynamic):AMFTraits {
		// var classInfo:Dynamic = instance.ROYALE_CLASS_INFO;
		// var originalClassInfo:Dynamic;
		var localTraits:AMFTraits;
		var instanceClass = Type.getClass(instance);

		if (instanceClass != null) {
			localTraits = new AMFTraits();
			var alias:String = getAliasByClass(instanceClass);
			if (alias != null)
				localTraits.alias = alias;
			else
				localTraits.alias = '';
			localTraits.qName = Type.getClassName(instanceClass);
			localTraits.isDynamic = false;
			localTraits.externalizable = (instance is IExternalizable);

			if (localTraits.externalizable) {
				localTraits.count = 0;
			} else {
				var props:Array<Dynamic> = [];
				for (instanceField in Type.getInstanceFields(instanceClass)) {
					if (Type.typeof(Reflect.field(instance, instanceField)) == TFunction) {
						if (StringTools.startsWith(instanceField, "get_")) {
							var propName = instanceField.substr(4);
							props.push(propName);
							Reflect.setField(localTraits.getterSetters, propName, AMFTraits.createInstanceAccessorGetterSetter(propName));
						}
						continue;
					}
					Reflect.setField(localTraits.getterSetters, instanceField, AMFTraits.createInstanceAccessorGetterSetter(instanceField));
					props.push(instanceField);
				}
				localTraits.props = props;
				// var accessChecks:Dynamic = {};
				// var c:Dynamic = instance;
				// while (classInfo) {
				// 	var reflectionInfo:Dynamic = c.ROYALE_REFLECTION_INFO();
				// 	populateSerializableMembers(reflectionInfo, accessChecks, localTraits);
				// 	if (!c.constructor.superClass_ || !c.constructor.superClass_.ROYALE_CLASS_INFO)
				// 		break;
				// 	classInfo = c.constructor.superClass_.ROYALE_CLASS_INFO;
				// 	c = c.constructor.superClass_;
				// }
				// sometimes flash native seriazliation double-counts props and outputs some props data twice.
				// this can happen with overrides (it was noticed with Transient overrides)
				// it may mean that js amf output can sometimes be more compact, but should always deserialize to the same result.
				localTraits.count = localTraits.props.length;
				// not required, but useful when testing:
				// localTraits.props.sort();
			}
			// cache in the classInfo for faster lookups next time
			// originalClassInfo.localTraits = localTraits;
		} else {
			// assume dynamic, anon object
			if (Type.typeof(instance) == TObject) {
				localTraits = AMFTraits.getBaseObjectTraits();
			} else {
				// could be a class object
				var anonFields:Array<String> = [];
				for (key in Reflect.fields(instance)) {
					if (key != "") {
						anonFields.push(key);
					}
				}
				localTraits = AMFTraits.getDynObjectTraits(anonFields);
			}
			// not required, but useful when testing:
			// localTraits.props.sort();
		}
		return localTraits;
	}

	public function readAmf3Array():Array<Dynamic> {
		var ref:UInt = readUInt29();
		if ((ref & 1) == 0)
			return getObject(ref >> 1);
		var denseLength:UInt = (ref >> 1);
		var array:Array<Dynamic> = [];
		rememberObject(array);
		while (true) {
			var name:String = readAmf3String();
			if (name == null || name.length == 0)
				break;
			// associative keys first
			Reflect.setField(array, name, readObject());
		}
		// then dense array keys
		for (i in 0...denseLength) {
			array[i] = readObject();
		}
		return array;
	}

	public function readAmf3Date():Date {
		var ref:UInt = readUInt29();
		if ((ref & 1) == 0)
			return getObject(ref >> 1);
		var time:Float = readDouble();
		var date:Date = Date.fromTime(time);
		rememberObject(date);
		return date;
	}

	public function readByteArray():ByteArray {
		var ref:UInt = readUInt29();
		if ((ref & 1) == 0)
			return getObject(ref >> 1);
		else {
			var len:UInt = (ref >> 1);
			var bytes = new ByteArray(len);
			target.readBytes(bytes, 0, len);
			rememberObject(bytes);
			return bytes;
		}
	}

	private function readAmf3Vector(amfType:UInt):Dynamic {
		var ref:UInt = readUInt29();
		if ((ref & 1) == 0)
			return getObject(ref >> 1);
		var len:UInt = (ref >> 1);
		var fixed:Bool = readBoolean();
		/*var vector:Array = toVector(amfType, [], readBoolean());*/
		var vector:openfl.Vector<Dynamic> = null;
		var i:UInt;
		if (amfType == AMF3_VECTOR_OBJECT) {
			var className:String = readAmf3String(); // className
			if (className == '') {
				className = 'Object';
			} else {
				try {
					className = openfl.Lib.getQualifiedClassName(openfl.Lib.getClassByAlias(className));
				} catch (e:Error) {
					className = 'Object';
				}
			}
			vector = new openfl.Vector<Dynamic>(len, fixed);
			for (i in 0...len)
				vector[i] = readObject();
		} else if (amfType == AMF3_VECTOR_INT) {
			vector = new openfl.Vector<Dynamic>(len, fixed);
			for (i in 0...len)
				vector[i] = readInt();
		} else if (amfType == AMF3_VECTOR_UINT) {
			vector = new openfl.Vector<Dynamic>(len, fixed);
			for (i in 0...len)
				vector[i] = readUnsignedInt();
		} else if (amfType == AMF3_VECTOR_DOUBLE) {
			vector = new openfl.Vector<Dynamic>(len, fixed);
			for (i in 0...len)
				vector[i] = readDouble();
		} else {
			throw new Error("Unknown vector type: " + amfType);
		}
		rememberObject(vector);
		return vector;
	}

	private function readAmf3ObjectValue(amfType:UInt):Dynamic {
		var value:Dynamic = null;
		var u:UInt;

		switch (amfType) {
			case AMF3_STRING:
				value = readAmf3String();
			case AMF3_OBJECT:
				try {
					value = readScriptObject();
				} catch (e) {
					trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
					throw new Error("Failed to deserialize: " + e);
				}
			case AMF3_ARRAY:
				value = readAmf3Array();
			case AMF3_BOOLEAN_FALSE:
				value = false;
			case AMF3_BOOLEAN_TRUE:
				value = true;
			case AMF3_INTEGER:
				u = readUInt29();
				// Symmetric with writing an integer to fix sign bits for
				// negative values...
				value = (u << 3) >> 3;
			case AMF3_DOUBLE:
				value = readDouble();
			case AMF3_UNDEFINED:
				#if html5
				value = js.Lib.undefined;
				#else
				value = null;
				#end
			case AMF3_NULL:
			// null is already assigned by default
			case AMF3_DATE:
				value = readAmf3Date();
			case AMF3_BYTEARRAY:
				value = readByteArray();
			case AMF3_XML:
				value = readAmf3XML();
			case AMF3_VECTOR_INT:
			case AMF3_VECTOR_UINT:
			case AMF3_VECTOR_DOUBLE:
			case AMF3_VECTOR_OBJECT:
				value = readAmf3Vector(amfType);
			case AMF0_AMF3:
				value = readObject();
			default:
				throw new Error("Unsupported AMF type: " + amfType);
		}
		return value;
	}
}
