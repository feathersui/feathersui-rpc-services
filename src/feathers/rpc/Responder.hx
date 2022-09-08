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

/**
	This class provides a default implementation of 
	the mx.rpc.IResponder interface.
**/
class Responder implements IResponder {
	/**
		Constructs an instance of the responder with the specified handlers.

		@param  result Function that should be called when the request has
		completed successfully.
		@param  fault Function that should be called when the request has
		completed with errors.
	**/
	public function new(result:Dynamic->Void, fault:Dynamic->Void) {
		_resultHandler = result;
		_faultHandler = fault;
	}

	/**
		This method is called by a remote service when the return value has been 
		received.

		@param data Object containing the information about the error that occured. .
		While `data` is typed as Object, it is often (but not always) 
		an mx.rpc.events.ResultEvent.
	**/
	public function result(data:Dynamic):Void {
		_resultHandler(data);
	}

	/**
		This method is called by a service when an error has been received.

		@param info Object containing the information returned from the request.
		While `info` is typed as Object, it is often (but not always) 
		an mx.rpc.events.FaultEvent.
	**/
	public function fault(info:Dynamic):Void {
		_faultHandler(info);
	}

	private var _resultHandler:Dynamic->Void;

	private var _faultHandler:Dynamic->Void;
}
