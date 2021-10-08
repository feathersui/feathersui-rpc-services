package feathers.utils;

import lime.utils.Bytes;
import openfl.utils.ByteArray;
import openfl.errors.Error;
import openfl.errors.RangeError;
import openfl.errors.TypeError;
#if html5
import js.html.TextDecoder;
import js.html.TextEncoder;
import js.lib.ArrayBuffer;
import js.lib.DataView;
import js.lib.Uint16Array;
import js.lib.Uint32Array;
import js.lib.Uint8Array;
import openfl.utils.Endian;

/**
 *  The BinaryData class is a class that represents binary data.  The way
 *  browsers handle binary data varies.  This class abstracts those
 *  differences..
 *
 *  @langversion 3.0
 *  @playerversion Flash 10.2
 *  @playerversion AIR 2.6
 *  @productversion Royale 0.0
 */
class BinaryData {
	public function new(bytes:ArrayBuffer = null) {
		ba = bytes != null ? bytes : new ArrayBuffer(0);
		_len = ba.byteLength;
	}

	/**
	 *  Utility method to create a BinaryData object from a string.
	 *
	 *  @param {String} str The string to convert to BinaryData as UTF-8 bytes.
	 *  @return {BinaryData} The BinaryData instance from the UTF-8 bytes of the string.     *
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.7.0
	 */
	public static function fromString(str:String):BinaryData {
		var bd:BinaryData = new BinaryData();
		bd.writeUTFBytes(str);
		return bd;
	}

	/**
	 *  Gets a reference to the internal array of bytes.
	 *  On the Flash side, this is  a ByteArray.
	 *  On the JS side, it's a Uint8Array.
	 *  This is primarily used for indexed (Array) access to the bytes, particularly
	 *  where platform-specific performance optimization is required.
	 *  To maintain cross-target consistency, you should not alter the length
	 *  of the ByteArray in any swf specific code, assume its length is fixed
	 *  (even though it is not).
	 *
	 *  @return {Uint8Array} The BinaryData backing array as Uint8Array in javascript.
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.7.0
	 */
	@:flash.property
	public var array(get, never):Uint8Array;

	private function get_array():Uint8Array {
		return getTypedArray();
	}

	private var _endian:Endian = Endian.BIG_ENDIAN;

	private var _sysEndian:Bool = Endian.BIG_ENDIAN == SYSTEM_ENDIAN;

	private static var SYSTEM_ENDIAN:Endian = getSystemEndian();

	private static function getSystemEndian():Endian {
		var tester:Uint8Array = new Uint8Array([102, 108, 101, 120]);
		var checker:Uint32Array = new Uint32Array(tester.buffer);
		var check:UInt = checker[0];
		return (check == 1718379896) ? BIG_ENDIAN : LITTLE_ENDIAN;
	}

	/**
	 *  Indicates the byte order for the data.
	 *  The default is Endian BIG_ENDIAN.
	 *  It is possible to check the default system Endianness of the target platform at runtime with
	 *  <code>org.apache.royale.utils.Endian.systemEndian</code>.
	 *  Setting to values other than Endian.BIG_ENDIAN or Endian.LITTLE_ENDIAN is ignored.
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.7.0
	 */
	@:flash.property
	public var endian(get, set):Endian;

	private function get_endian():Endian {
		return _endian;
	}

	private function set_endian(value:Endian):Endian {
		_endian = value;
		_sysEndian = value == SYSTEM_ENDIAN;
		return _endian;
	}

	private var ba:ArrayBuffer;

	private var _position:Int = 0;

	/**
	 * Get the platform-specific data for sending.
	 * Generally only used by the network services.
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	public var data(get, never):Dynamic;

	private function get_data():Dynamic {
		return ba;
	}

	/**
	 *  create a string representation of the binary data
	 */
	public function toString():String {
		_position = 0;
		return readUTFBytes(length);
	}

	/**
	 *  Write a Boolean value (as a single byte) at the current position
	 *
	 *  @param {Boolean} value The boolean value to write into the BinaryData at the current position
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	public function writeBoolean(value:Bool):Void {
		writeByte(value ? 1 : 0);
	}

	/**
	 *  Write a byte of binary data at the current position
	 *
	 *  @param {int} byte The value to write into the BinaryData at the current position
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	public function writeByte(byte:Int):Void {
		if (_position + 1 > _len) {
			setBufferSize(_position + 1);
		}
		getTypedArray()[_position++] = byte;
	}

	/**
	 *  Writes a sequence of <code>length</code> bytes from the <code>source</code> BinaryData, starting
	 *  at <code>offset</code> (zero-based index) bytes into the source BinaryData. If length
	 *  is omitted or is zero, it will represent the entire length of the source
	 *  starting from offset. If offset is omitted also, it defaults to zero.
	 *
	 *  @param {BinaryData} source The source BinaryData to write from at the current position
	 *  @param {uint} offset The optional offset value of the starting bytes to write inside source
	 *  @param {uint} length The optional length value of the bytes to write from offset in source
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 *
	 *  @royaleignorecoercion ArrayBuffer
	 */
	public function writeBinaryData(bytes:BinaryData, offset:UInt = 0, length:UInt = 0):Void {
		if (bytes == null)
			throw new TypeError('Error #2007: Parameter bytes must be non-null.');
		if (bytes == this)
			throw new Error('Parameter bytes must be another instance.');
		writeBytes(cast(bytes.ba, ArrayBuffer), offset, length);
	}

	public function writeBytes(bytes:ArrayBuffer, offset:UInt = 0, length:UInt = 0):Void {
		if (bytes == null)
			throw new TypeError('Error #2007: Parameter bytes must be non-null.');
		if (offset > bytes.byteLength) {
			// offset exceeds source length
			throw new RangeError('Error #2006: The supplied index is out of bounds.');
		}
		if (length == 0)
			length = bytes.byteLength - offset;
		else if (length > bytes.byteLength - offset) {
			// length exceeds source length
			throw new RangeError('Error #2006: The supplied index is out of bounds.');
		}

		if (_position + length > _len) {
			setBufferSize(_position + length);
		}
		var dest:Uint8Array = new Uint8Array(ba, _position, length);
		var src:Uint8Array = new Uint8Array(bytes, offset, length);
		dest.set(src);
		_position += length;
	}

	/**
	 *  Write a short integer (16 bits, typically represented by a 32 bit int parameter between -32768 and 65535)
	 *  of binary data at the current position
	 *
	 *  @param {int} short The value to write into the BinaryData at the current position
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	public function writeShort(short:Int):Void {
		if (_position + 2 > _len) {
			setBufferSize(_position + 2);
		}
		var arr:Uint8Array = getTypedArray();
		if (endian == Endian.BIG_ENDIAN) {
			arr[_position++] = (short & 0x0000ff00) >> 8;
			arr[_position++] = (short & 0x000000ff);
		} else {
			arr[_position++] = (short & 0x000000ff);
			arr[_position++] = (short & 0x0000ff00) >> 8;
		}
	}

	/**
	 *  Write an unsigned int (32 bits) of binary data at the current position
	 *
	 *  @param {uint} val The value to write into the BinaryData at the current position
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	public function writeUnsignedInt(val:UInt):Void {
		writeInt(val);
	}

	/**
	 *  Write a signed int (32 bits) of binary data at the current position
	 *
	 *  @param {int} val The value to write into the BinaryData at the current position
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	public function writeInt(val:Int):Void {
		if (_position + 4 > _len) {
			setBufferSize(_position + 4);
		}
		var arr:Uint8Array = getTypedArray();
		if (endian == Endian.BIG_ENDIAN) {
			arr[_position++] = (val & 0xff000000) >> 24;
			arr[_position++] = (val & 0x00ff0000) >> 16;
			arr[_position++] = (val & 0x0000ff00) >> 8;
			arr[_position++] = (val & 0x000000ff);
		} else {
			arr[_position++] = (val & 0x000000ff);
			arr[_position++] = (val & 0x0000ff00) >> 8;
			arr[_position++] = (val & 0x00ff0000) >> 16;
			arr[_position++] = (val & 0xff000000) >> 24;
		}
	}

	/**
	 *  Writes an IEEE 754 single-precision (32-bit) floating-point number to the
	 *  BinaryData at the current position
	 *
	 *  @param {Number} val The value to write into the BinaryData at the current position
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	public function writeFloat(val:Float):Void {
		if (_position + 4 > _len) {
			setBufferSize(_position + 4);
		}

		getDataView().setFloat32(_position, val, _endian == Endian.LITTLE_ENDIAN);
		_position += 4;
	}

	/**
	 *  Writes an IEEE 754 double-precision (64-bit) floating-point number to the
	 *  BinaryData at the current position
	 *
	 *  @param {Number} val The value to write into the BinaryData at the current position
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	public function writeDouble(val:Float):Void {
		if (_position + 8 > _len) {
			setBufferSize(_position + 8);
		}
		getDataView().setFloat64(_position, val, _endian == Endian.LITTLE_ENDIAN);
		_position += 8;
	}

	/**
	 *  Reads a Boolean value (as a single byte) at the current position.
	 *  returns true if the byte was non-zero, false otherwise
	 *
	 *  @return {Boolean} The boolean value read from the current position
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	public function readBoolean():Bool {
		return getTypedArray()[_position++] == 1;
	}

	/**
	 *  Read a signed byte of binary data at the current position
	 *
	 *  @return {int} An int value in the range -128 to 127, read from the current position
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	public function readByte():Int {
		return readUnsignedByte() << 24 >> 24;
	}

	/**
	 *  Read an unsigned byte of binary data at the current position
	 *
	 *  @return {uint} An uint value in the range 0 to 255, read from the current position
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	public function readUnsignedByte():UInt {
		return getTypedArray()[_position++];
	}

	/**
	 *  Reads the number of data bytes, specified by the length parameter, from the BinaryData.
	 *  The bytes are read into the BinaryData object specified by the destination parameter,
	 *  and the bytes are written into the destination BinaryData starting at the position specified by offset.
	 *  If length is omitted or is zero, all bytes are read following the current position to the end
	 *  of this BinaryData. If offset is also omitted, it defaults to zero.
	 *
	 *  @param {BinaryData} bytes The destination BinaryData to write bytes into from the current position
	 *  @param {uint} offset The optional offset value of the starting bytes to write inside destination
	 *  @param {uint} length The optional length value of the bytes to read
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	public function readBinaryData(bytes:BinaryData, offset:UInt = 0, length:UInt = 0):Void {
		if (bytes == null)
			throw new TypeError('Error #2007: Parameter bytes must be non-null.');
		if (bytes == this)
			throw new Error('Parameter bytes must be another instance.');
		if (length == 0)
			length = _len - _position;
		bytes.mergeInToArrayBuffer(offset, new Uint8Array(ba, _position, length));
		_position += length;
	}

	public function readBytes(bytes:ArrayBuffer, offset:UInt = 0, length:UInt = 0):Void {
		if (bytes == null)
			throw new TypeError('Error #2007: Parameter bytes must be non-null.');
		if (bytes == ba)
			throw new Error('cannot read into internal ArrayBuffer as both destination and source');
		if (length == 0)
			length = _len - _position;
		// extend the destination length if necessary
		var extra:Int = offset + length - bytes.byteLength;
		if (extra > 0)
			throw new Error('cannot read into destination ArrayBuffer, insufficient fixed length');
		var src:Uint8Array = new Uint8Array(ba, _position, length);
		var dest:Uint8Array = new Uint8Array(bytes, offset, length);

		dest.set(src);
		_position += length;
	}

	public function toByteArray():ByteArray {
		var src:Uint8Array = new Uint8Array(ba, _position, _len);
		var dest:Uint8Array = new Uint8Array(new ArrayBuffer(_len), 0, _len);

		dest.set(src);

		var byteArray:ByteArray = dest.buffer;
		byteArray.objectEncoding = AMF3;
		byteArray.endian = BIG_ENDIAN;
		return byteArray;
	}

	/**
	 *  Read a byte of binary data at the specified index. Does not change the <code>position</code> property.
	 *  If an index is out of range (beyond the current length) this will return zero.
	 *
	 *  @return {uint} A byte value in the range 0-255 from the index
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	public function readByteAt(idx:UInt):UInt {
		return getTypedArray()[idx] >> 0;
	}

	private var _typedArray:Uint8Array;

	private function getTypedArray():Uint8Array {
		if (_typedArray == null)
			_typedArray = new Uint8Array(ba);
		return _typedArray;
	}

	private var _dataView:DataView;

	private function getDataView():DataView {
		if (_dataView == null)
			_dataView = new DataView(ba);
		return _dataView;
	}

	/**
	 *  Writes a byte of binary data at the specified index. Does not change the <code>position</code> property.
	 *  This is a method for optimzed writes with no range checking.
	 *  If the specified index is out of range, it can throw an error.
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	public function writeByteAt(idx:UInt, byte:Int):Void {
		if (idx >= _len) {
			setBufferSize(idx + 1);
		}
		getTypedArray()[idx] = byte;
	}

	/**
	 *  Read a short int of binary data at the current position
	 *
	 *  @return {int} An int value in the range -32768 to 32767, read from the current position
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	public function readShort():Int {
		return readUnsignedShort() << 16 >> 16;
	}

	/**
	 *  Read an unsigned int (32bit) of binary data at the current position
	 *
	 *  @return {uint} A uint value, read from the current position
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	public function readUnsignedInt():UInt {
		var arr:Uint8Array = getTypedArray();
		if (endian == Endian.BIG_ENDIAN) {
			return ((arr[_position++] << 24) >>> 0) + (arr[_position++] << 16) + (arr[_position++] << 8) + arr[_position++];
		} else {
			return arr[_position++] + (arr[_position++] << 8) + (arr[_position++] << 16) + ((arr[_position++] << 24) >>> 0);
		}
	}

	/**
	 *  Read an unsigned short (16bit) of binary data at the current position
	 *
	 *  @return {uint} A uint value in the range 0 to 65535, read from the current position
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	public function readUnsignedShort():UInt {
		var arr:Uint8Array = getTypedArray();
		if (endian == Endian.BIG_ENDIAN) {
			return (arr[_position++] << 8) + arr[_position++];
		} else {
			return arr[_position++] + (arr[_position++] << 8);
		}
	}

	/**
	 *  Read a signed int (32bit) of binary data at the current position
	 *
	 *  @return {int} An int value, read from the current position
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	public function readInt():Int {
		return readUnsignedInt() << 32 >> 32;
	}

	/**
	 *  Reads an IEEE 754 single-precision (32-bit) floating-point number from the BinaryData.
	 *
	 *  @return {Number} A Number value, read from the current position
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	public function readFloat():Float {
		var ret:Float = getDataView().getFloat32(_position, _endian == Endian.LITTLE_ENDIAN);
		_position += 4;
		return ret;
	}

	/**
	 *  Reads an IEEE 754 double-precision (64-bit) floating-point number from the BinaryData.
	 *
	 *  @return {Number} A Number value, read from the current position
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	public function readDouble():Float {
		var ret:Float = getDataView().getFloat64(_position, _endian == Endian.LITTLE_ENDIAN);
		_position += 8;
		return ret;
	}

	private var _len:UInt;

	/**
	 *  The length of this BinaryData, in bytes.
	 *  If the length is set to a value that is larger than the current length, the right side
	 *  of the BinaryData is filled with zeros.
	 *  If the length is set to a value that is smaller than the current length, the BinaryData is truncated.
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.7.0
	 */
	@:flash.property
	public var length(get, set):Int;

	private function get_length():Int {
		return _len;
	}

	private function set_length(value:Int):Int {
		setBufferSize(value);
		return _len;
	}

	private function setBufferSize(newSize:UInt):Void {
		var n:UInt = _len;
		if (n != newSize) {
			// note: ArrayBuffer.slice could be better for buffer size reduction
			// looks like it is only IE11+, so not using it here

			var newView:Uint8Array = new Uint8Array(newSize);
			var oldView:Uint8Array = new Uint8Array(ba, 0, Std.int(Math.min(newSize, n)));
			newView.set(oldView);
			ba = newView.buffer;
			if (_position > newSize)
				_position = newSize;
			_typedArray = newView;
			_dataView = null;
			_len = newSize;
		}
	}

	/**
	 *  The total number of bytes available to read from the current position.
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	@:flash.property
	public var bytesAvailable(get, never):UInt;

	private function get_bytesAvailable():UInt {
		return _position < _len ? _len - _position : 0;
	}

	/**
	 *  Moves, or returns the current position, in bytes, of the pointer into the BinaryData object.
	 *  This is the point at which the next call to a read method starts reading or a write method starts writing.
	 *
	 *  Setting the position beyond the end of the current length value is possible and will increase the length
	 *  during write operations, but will throw an error during read operations.
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	@:flash.property
	public var position(get, set):UInt;

	private function get_position():UInt {
		return _position;
	}

	/**
	 *  @private
	 */
	private function set_position(value:UInt):UInt {
		_position = value;
		return _position;
	}

	/**
	 *  A convenience method to extend the length of the BinaryData
	 *  so you can efficiently write more bytes to it. Not all
	 *  browsers have a way to auto-resize a binary
	 *  data as you write data to the binary data buffer
	 *  and resizing in large chunks is generally more
	 *  efficient anyway. Preallocating bytes to write into
	 *  is also more efficient on the swf target.
	 *
	 *  @param extra The number of additional bytes.
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.0
	 */
	public function growBuffer(extra:UInt):Void {
		setBufferSize(_len + extra);
	}

	/**
	 *  Reads a UTF-8 string from the BinaryData.
	 *  The string is assumed to be prefixed with an unsigned short indicating the length in bytes.
	 *  The <code>position</code> is advanced to the first byte following the string's bytes.
	 *
	 *  @return {String} The utf-8 decoded string
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.7.0
	 */
	public function readUTF():String {
		var bytes:UInt = readUnsignedShort();
		return this.readUTFBytes(bytes);
	}

	/**
	 *  Reads a sequence of UTF-8 bytes specified by the length parameter
	 *  from the BinaryData and returns a string.
	 *  The <code>position</code> is advanced to the first byte following the string's bytes.
	 *
	 *  @param {uint} length An unsigned integer indicating the length of the UTF-8 bytes.
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.7.0
	 */
	public function readUTFBytes(length:UInt):String {
		// Code taken from GC
		// Use native implementations if/when available
		if (_position + length > _len) {
			throw new Error('Error #2030: End of file was encountered.');
		}
		var bytes:Uint8Array = new Uint8Array(ba, _position, length);
		// if ('TextDecoder' in window) {
		var decoder:TextDecoder = new TextDecoder('utf-8');
		_position += length;
		return decoder.decode(bytes);
		// }

		// var out:Array = [];
		// var pos:Int = 0;
		// var c:Int = 0;
		// var c1:Int;
		// var c2:Int;
		// var c3:Int;
		// var c4:Int;
		// while (pos < bytes.length) {
		// 	c1 = bytes[pos++];
		// 	if (c1 < 128) {
		// 		out[c++] = String.fromCharCode(c1);
		// 	} else if (c1 > 191 && c1 < 224) {
		// 		c2 = bytes[pos++];
		// 		out[c++] = String.fromCharCode((c1 & 31) << 6 | c2 & 63);
		// 	} else if (c1 > 239 && c1 < 365) {
		// 		// Surrogate Pair
		// 		c2 = bytes[pos++];
		// 		c3 = bytes[pos++];
		// 		c4 = bytes[pos++];
		// 		var u:Int = ((c1 & 7) << 18 | (c2 & 63) << 12 | (c3 & 63) << 6 | c4 & 63) - 0x10000;
		// 		out[c++] = String.fromCharCode(0xD800 + (u >> 10));
		// 		out[c++] = String.fromCharCode(0xDC00 + (u & 1023));
		// 	} else {
		// 		c2 = bytes[pos++];
		// 		c3 = bytes[pos++];
		// 		out[c++] = String.fromCharCode((c1 & 15) << 12 | (c2 & 63) << 6 | c3 & 63);
		// 	}
		// }
		// _position += length;
		// return out.join('');
	}

	/**
	 *  Writes a UTF-8 string to the byte stream.
	 *  The length of the UTF-8 string in bytes is written first, as a 16-bit unsigned integer,
	 *  followed by the bytes representing the characters of the string.
	 *  If the byte length of the string is larger than 65535 this will throw a RangeError
	 *  The <code>position</code> is advanced to the first byte following the string's bytes.
	 *
	 *  @param {String} str The string value to be written.
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.7.0
	 */
	public function writeUTF(str:String):Void {
		var utcBytes:Uint8Array = getUTFBytes(str, true);
		_position = mergeInToArrayBuffer(_position, utcBytes);
	}

	/**
	 *  Writes a UTF-8 string to the BinaryData. Similar to the writeUTF() method,
	 *  but writeUTFBytes() does not prefix the string with a 16-bit length word, and
	 *  therefore also permits strings longer than 65535 bytes (note: byte length will not
	 *  necessarily be the same as string length because some characters can be
	 *  multibyte characters).
	 *
	 *  @param {String} str The string value to be written.
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10.2
	 *  @playerversion AIR 2.6
	 *  @productversion Royale 0.7.0
	 */
	public function writeUTFBytes(str:String):Void {
		var utcBytes:Uint8Array = getUTFBytes(str, false);
		_position = mergeInToArrayBuffer(_position, utcBytes);
	}

	private function mergeInToArrayBuffer(offset:UInt, newBytes:Uint8Array):UInt {
		var newContentLength:UInt = newBytes.length;
		var dest:Uint8Array;
		var mergeUpperBound:UInt = offset + newContentLength;
		if (mergeUpperBound > _len) {
			dest = new Uint8Array(mergeUpperBound);
			if (_len > 0) {
				var copyOffset:UInt = Std.int(Math.min(offset, _len));
				if (copyOffset > 0) {
					dest.set(new Uint8Array(ba, 0, copyOffset));
				}
			}
			dest.set(newBytes, offset);
			ba = dest.buffer;
			_typedArray = dest;
			_dataView = null;
			_len = mergeUpperBound;
		} else {
			dest = new Uint8Array(ba, offset, newContentLength);
			dest.set(newBytes);
		}
		return mergeUpperBound;
	}

	private function getUTFBytes(str:String, prependLength:Bool):Uint8Array {
		// Code taken from GC
		// Use native implementations if/when available
		var bytes:Uint8Array;
		// if ('TextEncoder' in window) {
		var encoder:TextEncoder = Type.createInstance(TextEncoder, ['utf-8']); // new TextEncoder('utf-8');
		bytes = encoder.encode(str);
		// } else {
		// 	var out:Array = [];
		// 	var p:Int = 0;
		// 	var c:Int;

		// 	for (i in 0...str.length) {
		// 		c = str.charCodeAt(i);
		// 		if (c < 128) {
		// 			out[p++] = c;
		// 		} else if (c < 2048) {
		// 			out[p++] = (c >> 6) | 192;
		// 			out[p++] = (c & 63) | 128;
		// 		} else if (((c & 0xFC00) == 0xD800) && (i + 1) < str.length && ((str.charCodeAt(i + 1) & 0xFC00) == 0xDC00)) {
		// 			// Surrogate Pair
		// 			c = 0x10000 + ((c & 0x03FF) << 10) + (str.charCodeAt(++i) & 0x03FF);
		// 			out[p++] = (c >> 18) | 240;
		// 			out[p++] = ((c >> 12) & 63) | 128;
		// 			out[p++] = ((c >> 6) & 63) | 128;
		// 			out[p++] = (c & 63) | 128;
		// 		} else {
		// 			out[p++] = (c >> 12) | 224;
		// 			out[p++] = ((c >> 6) & 63) | 128;
		// 			out[p++] = (c & 63) | 128;
		// 		}
		// 	}
		// 	bytes = new Uint8Array(out);
		// }
		if (prependLength) {
			var len:UInt = bytes.length;
			if (len > 0xffff) {
				// throw error, similar to swf ByteArray behavior:
				throw new RangeError("UTF max string length of 65535 bytes exceeded : BinaryData.writeUTF");
			}
			var temp:Uint8Array = new Uint8Array(bytes.length + 2);
			temp.set(bytes, 2);
			// pre-convert to alternate endian if needed
			new Uint16Array(temp.buffer, 0, 1)[0] = _sysEndian ? len : (((len & 0xff00) >> 8) | ((len & 0xff) << 8));
			bytes = temp;
		}
		return bytes;
	}
}
#end
