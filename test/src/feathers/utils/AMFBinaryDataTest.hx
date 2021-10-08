package feathers.utils;

import haxe.Constraints.Function;
import openfl.errors.Error;
import openfl.utils.ByteArray;
import openfl.utils.IDataInput;
import openfl.utils.IDataOutput;
import openfl.utils.IExternalizable;
import utest.Assert;
import utest.Test;

class AMFBinaryDataTest extends Test {
	// util check functions
	private static function bytesMatchExpectedData(bd:AMFBinaryData, expected:Array<UInt>, offset:Int = 0):Bool {
		var len = expected.length;
		var end = offset + len;
		for (i in offset...end) {
			var check = bd.readByteAt(i);
			if (expected[i - offset] != check) {
				trace("failed at " + i, expected[i - offset], check);
				return false;
			}
		}
		return true;
	}

	private static function dynamicKeyCountMatches(forObject:Dynamic, expectedCount:UInt):Bool {
		return Reflect.fields(forObject).length == expectedCount;
	}

	public function new() {
		super();
	}

	public function testEmptyString():Void {
		var ba = new AMFBinaryData();
		var testString = "";

		ba.writeObject(testString);

		Assert.equals(2, ba.length);
		Assert.equals(2, ba.position);
		ba.position = 0;
		Assert.equals(testString, ba.readObject());
		Assert.equals(0, ba.bytesAvailable);
	}

	public function testString():Void {
		var ba = new AMFBinaryData();
		var testString = "testString";

		ba.writeObject(testString);

		Assert.equals(12, ba.length);
		Assert.equals(12, ba.position);
		ba.position = 0;
		Assert.equals(testString, ba.readObject());
		Assert.equals(0, ba.bytesAvailable);
	}

	public function testBooleanTrue():Void {
		var ba = new AMFBinaryData();

		ba.writeObject(true);

		Assert.equals(1, ba.length);
		Assert.equals(1, ba.position);
		ba.position = 0;

		Assert.equals(true, ba.readObject());
		Assert.equals(0, ba.bytesAvailable);
	}

	public function testBooleanFalse():Void {
		var ba = new AMFBinaryData();

		ba.writeObject(false);

		Assert.equals(1, ba.length);
		Assert.equals(1, ba.position);
		ba.position = 0;

		Assert.equals(false, ba.readObject());
		Assert.equals(0, ba.bytesAvailable);
	}

	public function testFloat():Void {
		var ba = new AMFBinaryData();

		ba.writeObject(Math.NaN);
		ba.writeObject(0.0);
		ba.writeObject(1.0);
		ba.writeObject(-1.0);
		ba.writeObject(1.5);
		ba.writeObject(-1.5);
		ba.writeObject(Math.POSITIVE_INFINITY);
		ba.writeObject(Math.NEGATIVE_INFINITY);

		Assert.equals(58, ba.length);
		Assert.equals(58, ba.position);
		ba.position = 0;

		var num = ba.readObject();
		Assert.isTrue((num is Float));
		Assert.isTrue(Math.isNaN(num));
		num = ba.readObject();
		Assert.isTrue((num is Float));
		Assert.equals(0.0, num);
		num = ba.readObject();
		Assert.isTrue((num is Float));
		Assert.equals(1.0, num);
		num = ba.readObject();
		Assert.isTrue((num is Float));
		Assert.equals(-1.0, num);
		num = ba.readObject();
		Assert.isTrue((num is Float));
		Assert.equals(1.5, num);
		num = ba.readObject();
		Assert.isTrue((num is Float));
		Assert.equals(-1.5, num);
		num = ba.readObject();
		Assert.isTrue((num is Float));
		Assert.isTrue(!Math.isFinite(num));
		Assert.isTrue(num > 0);
		Assert.equals(Math.POSITIVE_INFINITY, num);
		num = ba.readObject();
		Assert.isTrue((num is Float));
		Assert.isTrue(!Math.isFinite(num));
		Assert.isTrue(num < 0);
		Assert.equals(Math.NEGATIVE_INFINITY, num);
		Assert.equals(0, ba.bytesAvailable);
	}

	public function testNull():Void {
		var ba = new AMFBinaryData();
		ba.writeObject(null);

		ba.position = 0;
		var val = ba.readObject();
		Assert.isNull(val);
		Assert.equals(0, ba.bytesAvailable);
	}

	public function testUndefined():Void {
		#if html5
		var ba = new AMFBinaryData();
		ba.writeObject(js.Lib.undefined);

		ba.position = 0;

		var val = ba.readObject();
		Assert.equals(js.Lib.undefined, val);
		Assert.isNull(val);
		Assert.equals(0, ba.bytesAvailable);
		#else
		Assert.pass();
		#end
	}

	public function testEmptyArray():Void {
		var ba = new AMFBinaryData();
		var instance:Array<Dynamic> = [];
		ba.writeObject(instance);

		Assert.equals(3, ba.length);
		Assert.equals(3, ba.position);

		ba.position = 0;
		var val:Array<Dynamic> = ba.readObject();
		Assert.isTrue((val is Array));
		Assert.equals(0, val.length);
		Assert.equals(0, ba.bytesAvailable);
	}

	public function testArrayInstance():Void {
		var ba = new AMFBinaryData();
		var instance:Array<Dynamic> = [99];
		ba.length = 0;
		ba.writeObject(instance);
		ba.position = 0;
		Assert.isTrue(bytesMatchExpectedData(ba, [9, 3, 1, 4, 99]));
		instance = ba.readObject();
		Assert.equals(1, instance.length);
		Assert.equals(99, instance[0]);
		Assert.equals(0, ba.bytesAvailable);
	}

	public function testEmptyStructure():Void {
		var ba = new AMFBinaryData();

		var instance = {};
		ba.writeObject(instance);

		Assert.equals(4, ba.length);
		Assert.equals(4, ba.position);
		ba.position = 0;
		var val = ba.readObject();

		Assert.isTrue(Type.typeof(val) == TObject);
		Assert.isTrue(dynamicKeyCountMatches(instance, 0));
		Assert.equals(0, ba.bytesAvailable);
	}

	public function testStructure():Void {
		var ba = new AMFBinaryData();

		var obj1 = {test: true};
		var obj2 = {test: "maybe"};
		var obj3 = {test: true};
		ba.writeObject([obj1, obj2, obj3]);
		ba.position = 0;
		Assert.isTrue(bytesMatchExpectedData(ba, [
			9, 7, 1, 10, 11, 1, 9, 116, 101, 115, 116, 3, 1, 10, 1, 0, 6, 11, 109, 97, 121, 98, 101, 1, 10, 1, 0, 3, 1
		]));
	}

	public function testFunction():Void {
		var ba = new AMFBinaryData();
		// functions are always encoded as undefined
		var instance = function():Void {};
		ba.writeObject(instance);

		Assert.equals(1, ba.length);
		Assert.equals(1, ba.position);
		ba.position = 0;

		Assert.isTrue(bytesMatchExpectedData(ba, [0]));
		instance = ba.readObject();

		Assert.isNull(instance);

		// for a property that has a function value, the property is also undefined
		var objectWithFunction = {
			'function': function():Void {}
		};
		ba.length = 0;
		ba.writeObject(objectWithFunction);

		Assert.equals(4, ba.length);
		Assert.equals(4, ba.position);
		ba.position = 0;
		Assert.isTrue(bytesMatchExpectedData(ba, [10, 11, 1, 1]));

		// the dynamic deserialized object has no key for the function value
		// var obj = ba.readObject();
		// Assert.isTrue(dynamicKeyCountMatches(obj, 0));

		// ba.length = 0;
		// var tc4 = new TestClass4();
		// tc4.testField1 = function():Void {};

		// ba.writeObject(tc4);
		// Assert.equals(15, ba.length);
		// Assert.equals(15, ba.position);

		// Assert.isTrue(bytesMatchExpectedData(ba, [10, 19, 1, 21, 116, 101, 115, 116, 70, 105, 101, 108, 100, 49, 0]));
	}

	public function testBasicClassInstance():Void {
		var ba = new AMFBinaryData();

		var instance = new TestClass1();
		ba.writeObject(instance);

		Assert.equals(16, ba.length);
		Assert.equals(16, ba.position);

		ba.position = 0;
		Assert.isTrue(bytesMatchExpectedData(ba, [10, 19, 1, 21, 116, 101, 115, 116, 70, 105, 101, 108, 100, 49, 6, 1]));
		ba.position = 0;

		var anonObject = ba.readObject();

		// should not be typed
		Assert.isFalse((anonObject is TestClass1));
		Assert.equals(instance.testField1, Reflect.field(anonObject, 'testField1'));

		var multipleDifferentInstances:Array<Dynamic> = [new TestClass1(), new TestClass2()];
		ba.length = 0;
		ba.writeObject(multipleDifferentInstances);

		Assert.equals(24, ba.length);
		Assert.equals(24, ba.position);
		ba.position = 0;

		Assert.isTrue(bytesMatchExpectedData(ba, [
			9, 5, 1, 10, 19, 1, 21, 116, 101, 115, 116, 70, 105, 101, 108, 100, 49, 6, 1, 10, 19, 1, 0, 3
		]));
	}

	public function testByteArray():Void {
		var source = new ByteArray();

		for (i in 0...26) {
			source.writeByte(i);
		}
		var ba = new AMFBinaryData();
		var holder = [source, source];

		ba.writeObject(holder);
		Assert.equals(33, ba.length);
		Assert.equals(33, ba.position);
		ba.position = 0;
		Assert.isTrue(bytesMatchExpectedData(ba, [
			9, 5, 1, 12, 53, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 12, 2
		]));
	}

	public function testAMFBinaryData():Void {
		var source = new AMFBinaryData();

		for (i in 0...26) {
			source.writeByte(i);
		}
		var ba = new AMFBinaryData();
		var holder = [source, source];

		ba.writeObject(holder);
		Assert.equals(33, ba.length);
		Assert.equals(33, ba.position);
		ba.position = 0;
		Assert.isTrue(bytesMatchExpectedData(ba, [
			9, 5, 1, 12, 53, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 12, 2
		]));
	}

	public function testExternalizableWithoutRegisterClassAlias():Void {
		var ba = new AMFBinaryData();
		var test3 = new TestClass3();
		// TestClass3 is externalizable and does not have an alias, this is an error in flash

		var err:Error = null;
		try {
			ba.writeObject(test3);
		} catch (e:Error) {
			err = e;
		}

		Assert.notNull(err);
		Assert.equals(1, ba.length);
		Assert.equals(1, ba.position);
		ba.position = 0;
		Assert.isTrue(bytesMatchExpectedData(ba, [10]));
	}

	public function testExternalizable():Void {
		var ba = new AMFBinaryData();
		var test3 = new TestClass3();
		// register an alias
		openfl.Lib.registerClassAlias("TestClass3", TestClass3);
		ba.writeObject(test3);
		Assert.equals(18, ba.length);
		Assert.equals(18, ba.position);

		ba.position = 0;
		Assert.isTrue(bytesMatchExpectedData(ba, [10, 7, 21, 84, 101, 115, 116, 67, 108, 97, 115, 115, 51, 9, 3, 1, 6, 0]));

		var chars = (test3.content[0]).split("");
		chars.reverse();
		test3.content[0] = chars.join("");
		ba.writeObject(test3);
		Assert.equals(28, ba.length);
		Assert.equals(28, ba.position);
		Assert.isTrue(bytesMatchExpectedData(ba, [
			10, 7, 21, 84, 101, 115, 116, 67, 108, 97, 115, 115, 51, 9, 3, 1, 6, 21, 51, 115, 115, 97, 108, 67, 116, 115, 101, 84
		]));

		ba.position = 0;
		var test3Read:TestClass3 = cast(ba.readObject(), TestClass3);

		// proof that it created a new instance, and that the reversed content string content is present in the new instance
		Assert.equals(test3.content[0], test3Read.content[0]);
	}
}

private class TestClass1 {
	public function new() {}

	public var testField1:String = '';
}

private class TestClass2 {
	// Note: do not change this test class unless you change the related tests to
	// support any changes that might appear when testing reflection into it
	public function new() {}

	public var testField1:Bool = true;
}

private class TestClass3 implements IExternalizable {
	public function new() {}

	public var content:Array<String> = ["TestClass3"];

	public function readExternal(input:IDataInput):Void {
		var content:Array<String> = (input.readObject() : Array<String>);
		this.content = content;
	}

	public function writeExternal(output:IDataOutput):Void {
		output.writeObject(content);
	}
}

private class TestClass4 {
	public function new() {}

	public var testField1:Function;
}
