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

import openfl.display.DisplayObject;

/**
	This class acts as a context for the messaging framework so that it
	has access the URL and arguments of the SWF without needing
	access to the root MovieClip's LoaderInfo or Flex's Application
	class.
**/
@:dox(hide)
class LoaderConfig {
	// include "../../core/Version.as";
	//--------------------------------------------------------------------------
	//
	//  class initialization
	//
	//--------------------------------------------------------------------------
	public static function init(root:DisplayObject):Void {
		// if somebody has set this in our applicationdomain hierarchy, don't overwrite it
		if (_url == null) {
			// _url = LoaderUtil.normalizeURL(root.loaderInfo);
			_url = root.loaderInfo.url;
			_parameters = root.loaderInfo.parameters;
			#if flash
			_swfVersion = root.loaderInfo.swfVersion;
			#else
			_swfVersion = 10;
			#end
		}
	}

	//--------------------------------------------------------------------------
	//
	//  Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructor.

		One instance of LoaderConfig is created by the SystemManager. 
		You should not need to construct your own.
	**/
	public function new() {}

	//--------------------------------------------------------------------------
	//
	//  Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  parameters
	//----------------------------------

	/**
		Storage for the parameters property.
	**/
	private static var _parameters:Dynamic;

	/**
		If the LoaderConfig has been initialized, this
		should represent the top-level MovieClip's parameters.
	**/
	@:flash.property
	public static var parameters(get, never):Dynamic;

	private static function get_parameters():Dynamic {
		return _parameters;
	}

	//----------------------------------
	//  swfVersion
	//----------------------------------
	private static var _swfVersion:UInt;

	/**
		If the LoaderConfig has been initialized, this should represent the
		top-level MovieClip's swfVersion.
	**/
	@:flash.property
	public static var swfVersion(get, never):UInt;

	private static function get_swfVersion():UInt {
		return _swfVersion;
	}

	//----------------------------------
	//  url
	//----------------------------------

	/**
		Storage for the url property.
	**/
	private static var _url:String = null;

	/**
		If the LoaderConfig has been initialized, this
		should represent the top-level MovieClip's URL.
	**/
	@:flash.property
	public static var url(get, never):String;

	private static function get_url():String {
		return _url;
	}
}
