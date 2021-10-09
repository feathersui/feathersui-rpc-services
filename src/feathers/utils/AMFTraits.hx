package feathers.utils;

import haxe.Constraints.Function;

class AMFTraits {
	public static function createInstanceVariableGetterSetter(reflectionFunction:Function, type:String):Dynamic {
		var ret:Dynamic = {
			setValue: function(inst:Dynamic, value:Dynamic):Void {
				reflectionFunction(inst, value);
			}
		};

		if (type == "*") {
			ret.getValue = function(inst:Dynamic):Dynamic {
				return reflectionFunction(inst, reflectionFunction);
			}
		} else {
			ret.getValue = function(inst:Dynamic):Dynamic {
				return reflectionFunction(inst);
			}
		}
		return ret;
	}

	public static function createInstanceAccessorGetterSetter(fieldName:String):Dynamic {
		return {
			getValue: function(inst:Dynamic):Dynamic {
				return Reflect.getProperty(inst, fieldName);
			},
			setValue: function(inst:Dynamic, value:Dynamic):Dynamic {
				Reflect.setProperty(inst, fieldName, value);
				return Reflect.getProperty(inst, fieldName);
			}
		};
	}

	public static function markTransient(fieldName:String, traits:AMFTraits):Void {
		if (traits.transients == null) {
			traits.transients = {};
		}
		Reflect.setField(traits.transients, fieldName, true);
	}

	private static var _emtpy_object:AMFTraits;

	public static function getClassTraits(fields:Array<String>, qName:String):AMFTraits {
		var traits:AMFTraits = new AMFTraits();
		traits.qName = '[Class] ' + qName;
		traits.isDynamic = true;
		traits.externalizable = false;
		traits.props = fields;

		return traits;
	}

	public static function getBaseObjectTraits():AMFTraits {
		if (_emtpy_object != null)
			return _emtpy_object;
		var traits:AMFTraits = _emtpy_object = new AMFTraits();
		traits.qName = 'Object';
		traits.externalizable = false;
		traits.isDynamic = true;
		return traits;
	}

	public static function getDynObjectTraits(fields:Array<String>):AMFTraits {
		var traits:AMFTraits;
		traits = new AMFTraits();
		traits.qName = 'Object';
		traits.externalizable = false;
		traits.isDynamic = true;
		traits.props = fields;
		return traits;
	}

	public function new() {}

	public var alias:String = "";
	public var qName:String;
	public var externalizable:Bool;
	public var isDynamic:Bool;
	public var count:UInt = 0;
	public var props:Array<String> = [];
	public var nullValues:Any = {};

	public var getterSetters:Any = {};
	public var transients:Any;

	public function hasProp(prop:String):Bool {
		return props.indexOf(prop) != -1;
	}

	public function isTransient(prop:String):Bool {
		return transients != null && Reflect.hasField(transients, prop);
	}

	public function toString():String {
		#if debug
		return 'Traits for \'' + qName + '\'\n' + 'alias: \'' + alias + '\'\n' + 'externalizable:' + (externalizable == true) + '\n' + 'isDynamic:'
			+ (isDynamic == true) + '\n' + 'count:' + count + '\n' + 'props:\n\t' + props.join('\n\t');
		#else
		return 'Traits';
		#end
	}
}
