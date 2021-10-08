package feathers.utils;

import lime.utils.Bytes;
#if html5
import Type.ValueType;
import openfl.utils.ByteArray;
import openfl.utils.IExternalizable;
import openfl.net.IDynamicPropertyWriter;
import openfl.net.IDynamicPropertyOutput;
import haxe.Constraints.Function;
import js.lib.ArrayBuffer;
import js.lib.DataView;
import js.lib.Uint8Array;
import openfl.errors.Error;

class AMFContext extends BinaryData implements IDynamicPropertyOutput {
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

	private var owner:AMFBinaryData;

	public var dynamicPropertyWriter:IDynamicPropertyWriter;

	private var writeBuffer:Array<Dynamic>;
	private var objects:Array<Dynamic>;
	private var traits:Dynamic;
	private var strings:Dynamic;
	private var stringCount:UInt;
	private var traitCount:UInt;
	private var writeMode:Bool = false;
	private var _numbers:ArrayBuffer;
	private var _numberView:DataView;
	private var _numberBytes:Uint8Array;

	private static var _xmlClass:Class<Dynamic> = null;
	private static var _xmlChecked:Bool;

	private var _error:Error;

	public function getError():Error {
		var _err:Error = _error;
		_error = null;
		return _err;
	}

	/**
	 * @royaleignorecoercion Class
	 */
	public function new(ownerReference:AMFBinaryData) {
		owner = ownerReference;
		reset();
		if (!_xmlChecked) {
			_xmlChecked = true;
		}
		super();
	}

	public function reset():Void {
		writeBuffer = [];
		objects = [];
		traits = {};
		strings = {};
		stringCount = 0;
		traitCount = 0;
	}

	public function supportsAMFEncoding(type:UInt):Bool {
		return type == 3;
	}

	/**
	 * used internally as an override to return the writeBuffer Array for use to mimic Uint8Array during writing.
	 * Array is used because it is not usually known what the byte allocation should be in advance,
	 * and length is not mutable with javascript typed arrays, so 'growing' the buffer with each write is not
	 * a good strategy for performance.
	 * The assumption is that, while write access is slower for individual elements, increasing the length of
	 * the 'buffer' is not, and that using Array will be more performant.
	 * @royaleignorecoercion Uint8Array
	 */
	override private function getTypedArray():Uint8Array {
		return writeMode ? (writeBuffer : Dynamic) : super.getTypedArray();
	}

	override private function getDataView():DataView {
		if (!writeMode)
			return super.getDataView();
		// in write mode, return a utility version
		if (_numberView == null) {
			_numbers = new ArrayBuffer(8);
			_numberView = new DataView(_numbers);
			_numberBytes = new Uint8Array(_numbers);
		}
		return _numberView;
	}

	override private function setBufferSize(newSize:UInt):Void {
		// writing variation: in this subclass, writing  is always using 'Array' so length is not fixed
		_len = newSize;
	}

	override public function writeByte(byte:Int):Void {
		writeBuffer[_position++] = byte & 255;
	}

	override public function writeByteAt(idx:UInt, byte:Int):Void {
		while (idx > _len) {
			writeBuffer[_len++] = 0;
		}
		writeBuffer[idx] = byte & 255;
	}

	public function writeUInt29(v:UInt):Void {
		if (v < 128) {
			writeByte(v);
		} else if (v < 16384) {
			writeByte(((v >> 7) & 127) | 128);
			writeByte(v & 127);
		} else if (v < 2097152) {
			writeByte(((v >> 14) & 127) | 128);
			writeByte(((v >> 7) & 127) | 128);
			writeByte(v & 127);
		} else if (v < 0x40000000) {
			writeByte(((v >> 22) & 127) | 128);
			writeByte(((v >> 15) & 127) | 128);
			writeByte(((v >> 8) & 127) | 128);
			writeByte(v & 255);
		} else {
			throw "Integer out of range: " + v;
		}
	}

	private function addByteSequence(array:Array<Dynamic>):Void {
		var length:UInt = array.length;
		if (_position == _len) {
			writeBuffer = writeBuffer.concat(array);
			_len = _len + length;
			/*if (_len != writeBuffer.length) {
				throw new Error('code review')
			}*/
		} else {
			if (_position + length > _len) {
				// overwrite beyond
				// first truncate to _position
				writeBuffer.resize(_position);
				// then append the new content
				writeBuffer = writeBuffer.concat(array);
				_len = _position + length;
				if (_len != writeBuffer.length) {
					throw new Error('code review');
				}
			} else {
				// overwrite within - concatenate left and right slices with the new content between
				writeBuffer = writeBuffer.slice(0, _position).concat(array).concat(writeBuffer.slice(_position + length));

				if (_len != writeBuffer.length) {
					throw new Error('code review');
				}
			}
		}
		_position += length;
	}

	override public function writeBytes(bytes:ArrayBuffer, offset:UInt = 0, length:UInt = 0):Void {
		if (length == 0) {
			length = bytes.byteLength - offset;
		}
		if (length == 0) {
			return;
		}
		var src:Uint8Array = new Uint8Array(bytes, offset, offset + length);
		var srcArray:Array<Dynamic> = Reflect.callMethod(src, Reflect.field([], "slice"), []);
		addByteSequence(srcArray);
	}

	override public function writeUTF(str:String):Void {
		var utcBytes:Uint8Array = getUTFBytes(str, true);
		var srcArray:Array<Dynamic> = Reflect.callMethod(utcBytes, Reflect.field([], "slice"), []);
		addByteSequence(srcArray);
	}

	override public function writeUTFBytes(str:String):Void {
		var utcBytes:Uint8Array = getUTFBytes(str, false);
		var srcArray:Array<Dynamic> = Reflect.callMethod(utcBytes, Reflect.field([], "slice"), []);
		addByteSequence(srcArray);
	}

	private function copyNumericBytes(byteCount:UInt):Void {
		// arr here is actually an Array, not Uint8Array
		var arr:Uint8Array = getTypedArray();
		var numbers:Uint8Array = _numberBytes;
		var idx:UInt = 0;
		while ((byteCount--) > 0) {
			arr[_position++] = numbers[idx++];
		}
	}

	override public function writeFloat(val:Float):Void {
		// always big endian
		getDataView().setFloat32(0, val, false);
		copyNumericBytes(4);
	}

	override public function writeDouble(val:Float):Void {
		// always big endian
		getDataView().setFloat64(0, val, false);
		copyNumericBytes(8);
	}

	private function writeAMF3_UTF(string:String):Void {
		var utcBytes:Uint8Array = getUTFBytes(string, false);
		var srcArray:Array<Dynamic> = Reflect.callMethod(utcBytes, Reflect.field([], "slice"), []);
		writeUInt29((srcArray.length << 1) | 1);
		addByteSequence(srcArray);
	}

	private function writeAMF3StringWithoutType(v:String):Void {
		if (v.length == 0) {
			writeUInt29(1);
		} else {
			if (!this.amf3StringByReference(v)) {
				writeAMF3_UTF(v);
			}
		}
	}

	private function amf3StringByReference(v:String):Bool {
		final strIndex:Dynamic = Reflect.field(strings, v);
		final found:Bool = strIndex != null;
		if (found) {
			final ref:UInt = strIndex;
			writeUInt29(ref << 1);
		} else {
			Reflect.setField(strings, v, stringCount++);
		}
		return found;
	}

	public function amf3ObjectByReference(v:Dynamic):Bool {
		final ref:Int = objects.indexOf(v);
		final found:Bool = ref != -1;
		if (found) {
			writeUInt29(ref << 1);
		} else {
			objects.push(v);
		}
		return found;
	}

	private function traitsByReference(props:Array<Dynamic>, alias:String):Bool {
		// @todo review this. Don't think it is necessary to do the long joins with the props
		// maybe alias alone is enough...?
		final s:String = alias + "|" + props.join("|");
		final traitsIndex:Dynamic = Reflect.field(traits, s);
		final found:Bool = traitsIndex != null;
		if (found) {
			final ref:UInt = traitsIndex;
			writeUInt29((ref << 2) | 1);
		} else {
			Reflect.setField(traits, s, traitCount++);
		}
		return found;
	}

	private function writeAmf3Int(v:Int):Void {
		if (v >= INT28_MIN_VALUE && v <= INT28_MAX_VALUE) {
			v = v & UINT29_MASK;
			writeByte(AMF3_INTEGER);
			writeUInt29(v);
		} else {
			writeByte(AMF3_DOUBLE);
			writeDouble(v);
		}
	}

	private function writeAmf3Date(v:Date):Void {
		writeByte(AMF3_DATE);
		if (!amf3ObjectByReference(v)) {
			writeUInt29(1);
			writeDouble(v.getTime());
		}
	}

	private function filterSerializableMembers(fieldSet:Dynamic, accessChecks:Dynamic, localTraits:AMFTraits, asAccessors:Bool = false,
			excludeTransient:Bool = true):Array<Dynamic> {
		var l:UInt;
		var metas:Array<Dynamic>;
		var exclude:Bool;
		var transient:Bool;
		var fieldName:String;
		final into:Array<Dynamic> = localTraits.props;

		for (fieldName in Reflect.fields(fieldSet)) {
			// exclude all static props
			if (fieldName.charAt(0) == '|')
				continue;
			// exclude all non-public namespaces (identified by '::' between uri and name)
			if (fieldName.indexOf('::') != -1)
				continue;
			var field:Dynamic = Reflect.field(fieldSet, fieldName);
			exclude = false;
			transient = false;
			var alreadyPresent:Bool = into.indexOf(fieldName) != -1;
			if (asAccessors) {
				exclude = field.access != 'readwrite';
				if (exclude && !alreadyPresent) { // <-- if at some level we already have read-write access, then that wins
					// check: does it combine to provide 'readwrite' permissions via accessChecks through inheritance chain
					if (Reflect.field(accessChecks, fieldName) != null && Reflect.field(accessChecks, fieldName) != field.access) {
						// readonly or writeonly overridde at one level and different at another == readwrite
						exclude = false;
					} else {
						if (Reflect.field(accessChecks, fieldName) == null) {
							// cache for subsequent cross-checks as above
							Reflect.setField(accessChecks, fieldName, field.access);
						}
					}
				}
			}
			// if a subclass override does not redeclare the field as transient, then it is already considered explicitly 'non-transient'
			if (!exclude && !alreadyPresent && excludeTransient && field.metadata != null) {
				// we need to mark Transient fields as special case
				metas = field.metadata();
				l = metas.length;
				while ((l--) > 0) {
					if (metas[l].name == 'Transient') {
						transient = true;
						AMFTraits.markTransient(fieldName, localTraits);
						break;
					}
				}
			}
			if (!exclude) {
				// set up null/undefined value lookups for undefined field values (when encoding)
				var nullValues:Dynamic = localTraits.nullValues;
				if (field.type == 'Number') {
					Reflect.setField(nullValues, fieldName, Math.NaN);
				} else if (field.type == 'Boolean') {
					Reflect.setField(nullValues, fieldName, false);
				} else if (field.type == 'int' || field.type == 'uint') {
					Reflect.setField(nullValues, fieldName, 0);
				} else if (field.type == '*') {
					Reflect.setField(nullValues, fieldName, null /* undefined */);
				} else {
					Reflect.setField(nullValues, fieldName, null);
				}
				if (alreadyPresent) {
					into.splice(into.indexOf(fieldName), 1);
				}
				if (!transient)
					into.push(fieldName);
				if (asAccessors) {
					Reflect.setField(localTraits.getterSetters, fieldName, AMFTraits.createInstanceAccessorGetterSetter(fieldName));
				} else {
					// variable
					Reflect.setField(localTraits.getterSetters, fieldName, AMFTraits.createInstanceVariableGetterSetter(field.get_set, field.type));
				}
			}
		}
		return into;
	}

	private final nothing:Dynamic = {};

	private function populateSerializableMembers(reflectionInfo:Dynamic, accessChecks:Dynamic, localTraits:AMFTraits):Array<Dynamic> {
		if (reflectionInfo == null) {
			return localTraits.props;
		}
		var fields:Dynamic = reflectionInfo.variables ? reflectionInfo.variables() : nothing;
		filterSerializableMembers(fields, accessChecks, localTraits, false, true);
		fields = reflectionInfo.accessors ? reflectionInfo.accessors() : nothing;
		filterSerializableMembers(fields, accessChecks, localTraits, true, true);
		return localTraits.props;
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

	public function writeObjectExternal(v:Dynamic, position:UInt, mergeIntoOwner:Function):UInt {
		writeMode = true;
		_position = 0;
		_len = 0;
		try {
			if (owner.objectEncoding == AMF0)
				writeAmf0Object(v);
			else
				writeAmf3Object(v);
		} catch (e:Error) {
			_error = e;
		}
		var output:Uint8Array = new Uint8Array(writeBuffer);
		reset();
		writeMode = false;
		return mergeIntoOwner(position, output);
	}

	public function writeObject(v:Dynamic):Void {
		writeAmf3Object(v);
	}

	public function writeAmf0Object(v:Dynamic):Void {
		throw new Error('AMF0 support is unimplemented by default, supported via bead');
	}

	/**
	 * @royaleignorecoercion Class
	 * @royaleignorecoercion String
	 * @royaleignorecoercion Number
	 * @royaleignorecoercion Array
	 */
	public function writeAmf3Object(v:Dynamic):Void {
		if (v == null) {
			#if html5
			if (v == js.Lib.undefined) {
				writeByte(AMF3_UNDEFINED);
			} else {
				writeByte(AMF3_NULL);
			}
			#else
			writeByte(AMF3_NULL);
			#end
			return;
		}
		if (isFunctionValue(v)) {
			// output function value as undefined
			writeByte(AMF3_UNDEFINED);
			return;
		}
		if ((v is String)) {
			writeByte(AMF3_STRING);
			writeAMF3StringWithoutType(Std.string(v));
		} else if ((v is Float)) {
			var n:Float = v;
			if (n == Math.abs(n) && n == Std.int(n)) {
				writeAmf3Int(Std.int(n));
			} else {
				writeByte(AMF3_DOUBLE);
				writeDouble(n);
			}
		} else if ((v is Bool)) {
			writeByte((v ? AMF3_BOOLEAN_TRUE : AMF3_BOOLEAN_FALSE));
		} else if (v is Date) {
			writeAmf3Date(cast(v, Date));
			// } else if (_xmlClass && Std.isOfType(v, _xmlClass)) {
			// 	writeXML(v);
		} else {
			if ((v is Array)) {
				writeAmf3Array(cast(v, Array<Dynamic>));
			} else {
				writeAmf3ObjectVariant(v);
			}
		}
	}

	private function writeXML(v:Dynamic):Void {
		writeByte(AMF3_XML);
		if (!this.amf3ObjectByReference(v)) {
			var source:String = v.toXMLString();
			// don't use the regular string writing... it is not added to the String reference table (it seems)
			// this.writeAMF3StringWithoutType(source);
			writeAMF3_UTF(source);
		}
	}

	/**
	 *
	 * @royaleignorecoercion BinaryData
	 * @royaleignorecoercion ArrayBuffer
	 */
	private function writeAmf3ObjectVariant(v:Dynamic):Void {
		if ((v is AMFBinaryData) || (v is BinaryData)) {
			writeByte(AMF3_BYTEARRAY);
			if (!this.amf3ObjectByReference(v)) {
				var binaryData:BinaryData = cast(v, BinaryData);
				var len:UInt = binaryData.length;
				this.writeUInt29((len << 1) | 1);
				var arrayBuffer:ArrayBuffer = binaryData.data;
				writeBytes(arrayBuffer);
			}
			return;
		} else if (v is ByteArrayData) {
			writeByte(AMF3_BYTEARRAY);
			if (!this.amf3ObjectByReference(v)) {
				var byteArray:ByteArray = cast(v, ByteArray);
				var len:UInt = byteArray.length;
				this.writeUInt29((len << 1) | 1);
				var arrayBuffer:ArrayBuffer = byteArray;
				writeBytes(arrayBuffer, 0, len);
			}
			return;
		}

		writeByte(AMF3_OBJECT);
		if (!this.amf3ObjectByReference(v)) {
			final localTraits:AMFTraits = getLocalTraitsInfo(v);
			if (localTraits.externalizable && (localTraits.alias == null || localTraits.alias.length == 0)) {
				// in flash player if you try to write an object with no alias that is externalizable it does this:
				throw new Error("ArgumentError: Error #2004: One of the parameters is invalid.");
			}
			writeTypedObject(v, localTraits);
		}
	}

	/**
	 * This serialization context is passed as the 2nd parameter to an IDynamicPropertyWriter
	 * implementation's writeDynamicProperties method call. The resolved properties are written here
	 * @param name property name
	 * @param value property value
	 */
	public function writeDynamicProperty(name:String, value:Dynamic):Void {
		this.writeAMF3StringWithoutType(name);
		this.writeAmf3Object(value);
	}

	private function writeTypedObject(v:Dynamic, localTraits:AMFTraits):Void {
		var encodedName:String = (localTraits.alias != null && localTraits.alias.length > 0) ? localTraits.alias : ']:' + localTraits.qName + ":[";

		if (!traitsByReference(localTraits.props, encodedName)) {
			this.writeUInt29(3 | (localTraits.externalizable ? 4 : 0) | (localTraits.isDynamic ? 8 : 0) | (localTraits.count << 4));
			this.writeAMF3StringWithoutType(localTraits.alias);

			if (!localTraits.externalizable) {
				var l:UInt = localTraits.count;
				for (i in 0...l) {
					this.writeAMF3StringWithoutType(localTraits.props[i]);
				}
			}
		}

		if (localTraits.externalizable) {
			v.writeExternal(this);
		} else {
			var l:UInt = localTraits.count;
			for (i in 0...l) {
				// sealed props
				var val:Dynamic = localTraits.getterSetters[localTraits.props[i]].getValue(v);
				if (val == null) {
					// coerce null values to the 'correct' types
					val = localTraits.nullValues[localTraits.props[i]];

					// handle '*' type which can be undefined or explicitly null
					if (val == null && localTraits.getterSetters[localTraits.props[i]].getValue(v) == null) {
						val = null;
					}
				}
				this.writeAmf3Object(val);
			}

			if (localTraits.isDynamic) {
				if (dynamicPropertyWriter != null) {
					dynamicPropertyWriter.writeDynamicProperties(v, this);
				} else {
					// default implementation
					var dynFields:Array<String> = Reflect.fields(v);
					var l:UInt = dynFields.length;
					for (i in 0...l) {
						var val = Reflect.field(v, dynFields[i]);
						if (isFunctionValue(val)) {
							// skip this name-value pair, don't even write it out as undefined (match flash)
							continue;
						}
						this.writeAMF3StringWithoutType(dynFields[i]);
						this.writeAmf3Object(val);
					}
				}
				// end of dynamic properties marker
				this.writeAMF3StringWithoutType(EMPTY_STRING);
			}
		}
	}

	private var _comparator:String;

	/**
	 * javascript does not differentiate between 'Class' and 'Function'
	 * So in javascript : Object instanceof Function is true, in flash it is not (Object instanceof Class *is* true).
	 * The function below is an attempt to discriminate between a pure function and a 'constructor' function
	 * @param value the value to inspect
	 * @return true if considered to be a 'pure' function value (not a constructor)
	 */
	private function isFunctionValue(value:Dynamic):Bool {
		if (Type.typeof(value) == TFunction) {
			var comparator:String = _comparator;
			var checkBase:Array<Dynamic>;
			if (comparator == null) {
				// var ff:Function = function f():Void {};
				checkBase = Reflect.fields(function():Void {});
				if (checkBase.indexOf('name') != -1) {
					checkBase.splice(checkBase.indexOf('name'), 1);
				}
				_comparator = comparator = checkBase.join(",");
			}
			checkBase = Reflect.fields(value);
			if (checkBase.indexOf('name') != -1) {
				checkBase.splice(checkBase.indexOf('name'), 1);
			}
			var check:String = checkBase.join(",");
			return check == comparator;
		}
		return false;
	}

	/**
	 *
	 * @royaleignorecoercion String
	 */
	private function writeAmf3Array(v:Array<Dynamic>):Void {
		writeByte(AMF3_ARRAY);
		var len:UInt = v.length;
		var i:UInt = 0;
		var akl:UInt = 0; // associative keys length
		if (!this.amf3ObjectByReference(v)) {
			var denseLength:UInt = len;
			var keys:Array<Dynamic> = [];
			for (key => value in v.keyValueIterator()) {
				keys.push(key);
			}
			// profile the array
			// es6 specifies a generalized traversal order we can rely upon going forward
			// testing in IE11 shows the same order applies in that es5 Array implementation, so we assume it here:
			/*
				Property keys are traversed in the following order:
				First, the keys that are integer indices, in ascending numeric order.
				note non-integers: '02' round-tripping results in the different string '2'.
					'3.141' is not an integer index, because 3.141 is not an integer.
				Then, all other string keys, in the order in which they were added to the object.
				Lastly, all symbol keys, in the order in which they were added to the object.
				We don't need to worry about Symbols here
			 */
			var kl:UInt = keys.length;
			// Assumption - based on the above,
			// if the last key in the keys is an integer index, and length matches the array.length then it is a pure strict array
			// if not, it is non-strict
			if (kl != len || (Std.string((keys[kl - 1]) >> 0) != keys[kl - 1]) || Lambda.exists(v, isFunctionValue)) {
				// Array is not strict
				if (len > 0) {
					// the array has at least some integer keys

					// find denseLength
					for (i in 0...len) {
						if (keys[i] != "" + i)
							break;
						// also seems to be true in avm:
						if (isFunctionValue(v[i]))
							break;
					}
					denseLength = i;
					// remove dense keys,
					// leaving only associative keys (which may include valid integer keys outside the dense part)
					keys.splice(0, denseLength);
				} // else all keys are associative keys, and denseLength is zero
				akl = keys.length;
			}
			this.writeUInt29((denseLength << 1) | 1);

			if (akl > 0) {
				// name-value pairs of associative keys
				for (i in 0...akl) {
					var val:Dynamic = Reflect.field(v, keys[i]);
					if (isFunctionValue(val)) {
						continue;
					}
					this.writeAMF3StringWithoutType(Std.string(keys[i]));
					this.writeAmf3Object(val);
				}
			}
			// empty string 'terminates' associative keys block - no more associative keys (if there were any)
			writeAMF3StringWithoutType(EMPTY_STRING);
			if (denseLength > 0) {
				for (i in 0...denseLength) {
					writeAmf3Object(v[i]);
				}
			}
		}
	}

	/**
	 *
	 * @royaleignorecoercion Array
	 * @royaleignorecoercion String
	 * @royaleignorecoercion Boolean
	 * @royaleignorecoercion Number
	 * @royaleignorecoercion uint
	 * @royaleignorecoercion int
	 */
	private function writeAmf3Vector(v:Dynamic):Void {
		// v is a Vector synthType instance
		var className:String = Type.getClassName(Type.getClass(v));
		var content:Array<Dynamic> = cast(Reflect.field(v, 'value'), Array<Dynamic>);
		var amfType:UInt;
		if (className == 'openfl.Vector<Int>')
			amfType = AMF3_VECTOR_INT;
		else if (className == 'openfl.Vector<UInt>')
			amfType = AMF3_VECTOR_UINT;
		else if (className == 'openfl.Vector<Float>')
			amfType = AMF3_VECTOR_DOUBLE;
		else
			amfType = AMF3_VECTOR_OBJECT;
		writeByte(amfType);

		var i:UInt;
		var len:UInt = v.length;
		if (!this.amf3ObjectByReference(v)) {
			this.writeUInt29((len << 1) | 1);
			this.writeBoolean(Reflect.field(v, 'fixed') == true);
			if (amfType == AMF3_VECTOR_OBJECT) {
				// note this is available as a specific field, but not yet readily accessible in terms of field name
				className = className.substring(8, className.length - 1); // strip leading 'Vector.<' and trailing '>'
				if (className == '*') {
					className = '';
				} else {
					try {
						className = getAliasByClass(openfl.Lib.getDefinitionByName(className));
						if (className == null) {
							className = '';
						}
					} catch (e:Error) {
						className = '';
					}
				}

				/*if (className == 'Boolean' || className == 'String' || className == 'Class' || className == 'Array' || className=='Object' || className=='*') {
						className = ''; // this will be a Vector.<Object> on read (even for '*' it seems, contrary to spec)
					} else {
				}*/
				this.writeAMF3StringWithoutType(className);
				for (i in 0...len) {
					writeAmf3Object(content[i]);
				}
			} else if (amfType == AMF3_VECTOR_INT) {
				for (i in 0...len) {
					writeInt(content[i]);
				}
			} else if (v.type == AMF3_VECTOR_UINT) {
				for (i in 0...len) {
					writeUnsignedInt(content[i]);
				}
			} else if (v.type == AMF3_VECTOR_DOUBLE) {
				for (i in 0...len) {
					writeDouble(content[i]);
				}
			}
		}
	}

	private function getAliasByClass(theClass:Dynamic):String {
		var registeredClassAliases = @:privateAccess openfl.Lib.__registeredClassAliases;
		for (key => value in registeredClassAliases) {
			if (value == theClass) {
				return key;
			}
		}
		return null;
	}

	public function readUInt29():Int {
		final read:Function = readUnsignedByte;
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

	/**
	 *
	 * @royaleignorecoercion ArrayBuffer
	 */
	public function readObjectExternal():Dynamic {
		if (ba != owner.data) {
			ba = cast(owner.data, ArrayBuffer);
			_typedArray = new Uint8Array(ba);
			_dataView = null;
		}
		_position = owner.position;
		_len = owner.length;
		var result:Dynamic = null;
		try {
			if (owner.objectEncoding == AMF0)
				result = readAmf0Object();
			else
				result = readAmf3Object();
		} catch (e:Error) {
			_error = e;
		}
		reset();
		owner.position = _position;
		return result;
	}

	public function readObject():Dynamic {
		return readAmf3Object();
	}

	public function readAmf0Object():Dynamic {
		throw new Error('AMF0 support is unimplemented by default, supported via bead');
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
		strings[stringCount++] = v;
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
		traits[traitCount++] = v;
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

	/**
	 * @royaleignorecoercion Array
	 */
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

	/**
	 * @royaleignorecoercion Array
	 */
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
			var bytes:Uint8Array = new Uint8Array(len);
			bytes.set(new Uint8Array(this.ba, _position, len));
			_position += len;
			var binaryData:AMFBinaryData = new AMFBinaryData(bytes.buffer);
			var ba = binaryData.toByteArray();
			rememberObject(ba);
			return ba;
		}
	}

	/**
	 *
	 * @royaleignorecoercion Array
	 */
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
				} catch (e:Error) {
					// if (goog.DEBUG) {
					// 	var err:Error = (e.message.indexOf("Failed to deserialize") == -1) ? new Error("Failed to deserialize: " + e.message + ' '
					// 		+ e.stack.split('\n')[1]) : e;
					// 	throw err;
					// } else
					throw new Error("Failed to deserialize: " + e.message);
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
#end
