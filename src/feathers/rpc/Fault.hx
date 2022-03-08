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

package feathers.rpc;

import openfl.errors.Error;

/**
 * The Fault class represents a fault in a remote procedure call (RPC) service
 * invocation.
 */
class Fault extends Error {
	/**
	 * Creates a new Fault object.
	 *
	 * @param faultCode A simple code describing the fault.
	 * @param faultString Text description of the fault.
	 * @param faultDetail Additional details describing the fault.
	 * 
	 */
	public function new(faultCode:String, faultString:String, faultDetail:String = null) {
		super("faultCode:" + faultCode + " faultString:'" + faultString + "' faultDetail:'" + faultDetail + "'");

		this._faultCode = faultCode;
		this._faultString = faultString != null ? faultString : "";
		this._faultDetail = faultDetail;
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/**
	 * The raw content of the fault (if available), such as an HTTP response
	 * body.
	 */
	public var content:Dynamic;

	/**
	 * The cause of the fault. The value will be null if the cause is
	 * unknown or whether this fault represents the root itself.
	 */
	public var rootCause:Dynamic;

	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------

	/**
	 * A simple code describing the fault.
	 */
	@:flash.property
	public var faultCode(get, never):String;

	private function get_faultCode():String {
		return _faultCode;
	}

	/**
	 * Any extra details of the fault.
	 */
	@:flash.property
	public var faultDetail(get, never):String;

	private function get_faultDetail():String {
		return _faultDetail;
	}

	/**
	 * Text description of the fault.
	 */
	@:flash.property
	public var faultString(get, never):String;

	private function get_faultString():String {
		return _faultString;
	}

	//--------------------------------------------------------------------------
	//
	// Methods
	//
	//--------------------------------------------------------------------------

	/**
	 * Returns the string representation of a Fault object.
	 *
	 * @return Returns the string representation of a Fault object.
	 */
	#if !flash override #end public function toString():String {
		var s:String = "[RPC Fault";
		s += " faultString=\"" + faultString + "\"";
		s += " faultCode=\"" + faultCode + "\"";
		s += " faultDetail=\"" + faultDetail + "\"]";
		return s;
	}

	private var _faultCode:String;

	private var _faultString:String;

	private var _faultDetail:String;
}
