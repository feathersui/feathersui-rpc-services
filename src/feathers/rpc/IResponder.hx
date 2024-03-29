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
	This interface provides the contract for any service
	that needs to respond to remote or asynchronous calls.
**/
interface IResponder {
	/**
		This method is called by a service when the return value
		has been received. 
		While `data` is typed as Object, it is often
		(but not always) an mx.rpc.events.ResultEvent object.

		@param data Contains the information returned from the request.
	**/
	function result(data:Dynamic):Void;

	/**
		This method is called by a service when an error has been received.
		While `info` is typed as Object it is often
		(but not always) an mx.rpc.events.FaultEvent object.

		@param info Contains the information about the error that occured.
	**/
	function fault(info:Dynamic):Void;
}
