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

class ActiveCalls {
	private var calls:Dynamic;
	private var callOrder:Array<String>;

	public function new() {
		calls = {};
		callOrder = [];
	}

	public function addCall(id:String, token:AsyncToken):Void {
		Reflect.setField(calls, id, token);
		callOrder.push(id);
	}

	public function getAllMessages():Array<AsyncToken> {
		var msgs:Array<AsyncToken> = [];
		for (id in Reflect.fields(calls)) {
			msgs.push(Reflect.field(calls, id));
		}
		return msgs;
	}

	public function cancelLast():AsyncToken {
		if (callOrder.length > 0) {
			return removeCall(callOrder[callOrder.length - 1]);
		}
		return null;
	}

	public function hasActiveCalls():Bool {
		return callOrder.length > 0;
	}

	public function removeCall(id:String):AsyncToken {
		var token:AsyncToken = Reflect.field(calls, id);
		if (token != null) {
			Reflect.deleteField(calls, id);
			callOrder.splice(callOrder.lastIndexOf(id), 1);
		}
		return token;
	}

	public function wasLastCall(id:String):Bool {
		if (callOrder.length > 0) {
			return callOrder[callOrder.length - 1] == id;
		}
		return false;
	}
}
