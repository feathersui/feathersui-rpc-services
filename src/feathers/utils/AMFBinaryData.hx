package feathers.utils;

import openfl.errors.Error;
#if html5
import js.lib.ArrayBuffer;
import openfl.net.IDynamicPropertyWriter;
import openfl.net.ObjectEncoding;

/**
 *  A version of BinaryData specific to AMF.
 *
 *  @langversion 3.0
 *  @playerversion Flash 9
 *  @playerversion AIR 1.1
 *  @productversion BlazeDS 4
 *  @productversion LCDS 3
 *
 *  @royalesuppresspublicvarwarning
 */
class AMFBinaryData extends BinaryData {
	private static var _propertyWriter:IDynamicPropertyWriter;
	private static var _amfContextClass:Class<AMFContext>;

	private static function installAlternateContext(clazz:Class<AMFContext>):Void {
		// this should always be a valid subclass of AMFContext (only AMF0 support)
		_amfContextClass = clazz;
	}

	private static function hasAMF0Support():Bool {
		// this should always be a valid subclass of AMFContext (only AMF0 support)
		return _amfContextClass != null && _amfContextClass != AMFContext;
	}

	private static var _defaultEncoding:ObjectEncoding = AMF3;
	@:flash.property
	public static var defaultObjectEncoding(get, set):ObjectEncoding;

	private static function get_defaultObjectEncoding():ObjectEncoding {
		return _defaultEncoding;
	}

	private static function set_defaultObjectEncoding(value:ObjectEncoding):ObjectEncoding {
		_defaultEncoding = value;
		return _defaultEncoding;
	}

	/**
	 *
	 * @royaleignorecoercion org.apache.royale.net.remoting.amf.AMFContext
	 */
	private static function createSerializationContext(forInstance:AMFBinaryData):AMFContext {
		var clazz:Class<AMFContext> = _amfContextClass;
		if (clazz == null)
			clazz = _amfContextClass = AMFContext;
		return cast(Type.createInstance(clazz, [forInstance]), AMFContext);
	}

	/**
	 * Allows greater control over the serialization of dynamic properties of dynamic objects.
	 * When this property is set to null, the default value, dynamic properties are serialized using native code,
	 * which writes all dynamic properties excluding those whose value is a function.
	 * This value is called only for properties of a dynamic object (objects declared within a dynamic class) or
	 * for objects declared using the new operator.
	 * You can use this property to exclude properties of dynamic objects from serialization; to write values
	 * to properties of dynamic objects; or to create new properties for dynamic objects. To do so,
	 * set this property to an object that implements the IDynamicPropertyWriter interface. For more information,
	 * see the IDynamicPropertyWriter interface.
	 */
	public static var dynamicPropertyWriter(get, set):IDynamicPropertyWriter;

	private static function get_dynamicPropertyWriter():IDynamicPropertyWriter {
		return _propertyWriter;
	}

	private static function set_dynamicPropertyWriter(value:IDynamicPropertyWriter):IDynamicPropertyWriter {
		_propertyWriter = value;
		return _propertyWriter;
	}

	public function new(bytes:ArrayBuffer = null) {
		super(bytes);
		if (_objectEncoding != _defaultEncoding)
			_objectEncoding = _defaultEncoding;
	}

	private var _objectEncoding:ObjectEncoding = AMF3;

	public var objectEncoding(get, set):ObjectEncoding;

	private function get_objectEncoding():ObjectEncoding {
		return _objectEncoding;
	}

	private function set_objectEncoding(value:ObjectEncoding):ObjectEncoding {
		if (([0, 3]).indexOf(value) == -1) {
			throw new Error('ArgumentError: Error #2008: Parameter objectEncoding must be one of the accepted values.');
		} else {
			_objectEncoding = value;
		}
		return _objectEncoding;
	}

	private var _serializationContext:AMFContext;

	public function writeObject(v:Dynamic):Void {
		if (_serializationContext == null)
			_serializationContext = createSerializationContext(this);
		_serializationContext.dynamicPropertyWriter = _propertyWriter;
		_position = _serializationContext.writeObjectExternal(v, _position, mergeInToArrayBuffer);
		var err:Error = _serializationContext.getError();
		if (err != null) {
			throw new Error(err.message);
		}
	}

	public function readObject():Dynamic {
		if (_serializationContext == null)
			_serializationContext = createSerializationContext(this);
		var value:Dynamic = _serializationContext.readObjectExternal();
		var err:Error = _serializationContext.getError();
		if (err != null) {
			throw new Error(err.message);
		}
		return value;
	}
}
#end
