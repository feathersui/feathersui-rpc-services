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

import feathers.messaging.errors.MessagingError;
import feathers.messaging.events.MessageEvent;
import feathers.messaging.events.MessageFaultEvent;
import feathers.messaging.messages.AsyncMessage;
import feathers.messaging.messages.IMessage;
import feathers.rpc.events.AbstractEvent;
import feathers.rpc.events.FaultEvent;
import feathers.rpc.events.InvokeEvent;
import feathers.rpc.events.ResultEvent;
import haxe.Constraints.Function;
import openfl.errors.Error;
import openfl.events.Event;
import openfl.events.EventDispatcher;

/**
 * An invoker is an object that actually executes a remote procedure call (RPC).
 * For example, RemoteObject, HTTPService, and WebService objects are invokers.
 */
@:access(feathers.rpc.AsyncToken)
@:access(feathers.rpc.events.AbstractEvent)
class AbstractInvoker extends EventDispatcher {
	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 */
	public function new() {
		super();
		// _log = Log.getLogger("mx.rpc.AbstractInvoker");
		activeCalls = new ActiveCalls();
	}

	//-------------------------------------------------------------------------
	//
	// Properties
	//
	//-------------------------------------------------------------------------
	private var _keepLastResult:Bool = true;
	private var _keepLastResultSet:Bool = false;

	/**
		Flag indicating whether the operation should keep its last call result for later access.

		If set to true, the last call result will be accessible through <code>lastResult</code> bindable property.

		If set to false, the last call result will be cleared after the call,
		and must be processed in the operation's result handler.
		This will allow the result object to be garbage collected,
		which is especially useful if the operation is only called a few times and returns a large result.

		If not set, will use the <code>keepLastResult</code> value of its owning Service, if any, or the default value.

		@see #lastResult
		@see mx.rpc.AbstractService#keepLastResult
		@default true
	**/
	@:flash.property
	public var keepLastResult(get, never):Bool;

	private function get_keepLastResult():Bool {
		return _keepLastResult;
	}

	private function set_keepLastResult(value:Bool):Bool {
		_keepLastResult = value;
		_keepLastResultSet = true;
		return _keepLastResult;
	}

	/** @private
	 * sets keepLastResult if not set locally, typically by container Service or RemoteObject
	 * @param value
	 */
	private function setKeepLastResultIfNotSet(value:Bool):Void {
		if (!_keepLastResultSet)
			_keepLastResult = value;
	}

	// [Bindable("resultForBinding")]

	/**
	 *  The result of the last invocation.
	 */
	@:flash.property
	public var lastResult(get, never):Dynamic;

	private function get_lastResult():Dynamic {
		return _result;
	}

	// [Inspectable(defaultValue="true", category="General")]

	/**
	 * When this value is true, anonymous objects returned are forced to bindable objects.
	 */
	@:flash.property
	public var makeObjectsBindable(get, set):Bool;

	private function get_makeObjectsBindable():Bool {
		return _makeObjectsBindable;
	}

	private function set_makeObjectsBindable(b:Bool):Bool {
		_makeObjectsBindable = b;
		return _makeObjectsBindable;
	}

	/**
	 * This property is set usually by framework code which wants to modify the
	 * behavior of a service invocation without modifying the way in which the
	 * service is called externally.  This allows you to add a "filter" step on 
	 * the method call to ensure for example that you do not return duplicate
	 * instances for the same id or to insert parameters for performing on-demand
	 * paging.
	 *
	 * When this is set to a non-null value on the send call, the operationManager function 
	 * is called instead.  It returns the token that the caller uses to be notified
	 * of the result.  Typically the called function will at some point clear this
	 * property temporarily, then invoke the operation again actually sending it to 
	 * the server this time.
	 */
	public var operationManager:Function;

	/** 
	 * Specifies an optional return type for the operation.  Used in situations where 
	 * you want to coerce the over-the-wire information into a specific ActionScript class
	 * or to provide metadata for other services as to the return type of this operation.
	 */
	public var resultType:Class<Dynamic>;

	/**
	 * Like resultType, used to define the ActionScript class used by a given operation though
	 * this property only applies to operations which return a multi-valued result (e.g. an Array
	 * or ArrayCollection (IList)).  This property specifies an ActionScript class for the members of the
	 * array or array collection.   When you set resultElementType, you do not have to set 
	 * resultType.  In that case, the operation returns an Array if makeObjectsbindable is
	 * false and an ArrayCollection otherwise.
	 */
	public var resultElementType:Class<Dynamic>;

	/**
	 *  Event dispatched for binding when the <code>result</code> property
	 *  changes.
	 */
	private static final BINDING_RESULT:String = "resultForBinding";

	//-------------------------------------------------------------------------
	//
	//             Public Methods
	//
	//-------------------------------------------------------------------------

	/**
	 *  Cancels the last service invocation or an invokation with the specified ID.
	 *  Even though the network operation may still continue, no result or fault event
	 *  is dispatched.
	 * 
	 *  @param id The messageId of the invocation to cancel. Optional. If omitted, the
	 *         last service invocation is canceled.
	 *  
	 *  @return The AsyncToken associated with the call that is cancelled or null if no call was cancelled.
	 */
	public function cancel(id:String = null):AsyncToken {
		if (id != null)
			return activeCalls.removeCall(id);
		else
			return activeCalls.cancelLast();
	}

	/**
	 *  Sets the <code>result</code> property of the invoker to <code>null</code>.
	 *  This is useful when the result is a large object that is no longer being
	 *  used.
	 *
	 *  @param fireBindingEvent Set to <code>true</code> if you want anything
	 *  bound to the result to update. Otherwise, set to
	 *  <code>false</code>.
	 *  The default value is <code>true</code>
	 */
	public function clearResult(fireBindingEvent:Bool = true):Void {
		if (fireBindingEvent)
			setResult(null);
		else
			_result = null;
	}

	/**
	 *  This hook is exposed to update the lastResult property.  Since lastResult
	 *  is ordinarily updated automatically by the service, you do not typically 
	 *  call this.  It is used by managed services that want to ensure lastResult
	 *  always points to "the" managed instance for a given identity even if the
	 *  the service returns a new copy of the same object.  
	 *
	 *  @param result The new value for the lastResult property.
	 */
	public function setResult(result:Any):Void {
		_result = result;
		dispatchEvent(new flash.events.Event(BINDING_RESULT));
	}

	//-------------------------------------------------------------------------
	//
	// Internal Methods
	//
	//-------------------------------------------------------------------------

	/**
	 *  This method is overridden in subclasses to redirect the event to another
	 *  class.
	 *
	 *  @private
	 */
	private function dispatchRpcEvent(event:AbstractEvent):Void {
		event.callTokenResponders();
		if (!event.isDefaultPrevented()) {
			dispatchEvent(event);
		}
	}

	/**
	 * Monitor an rpc event that is being dispatched
	 */
	private function monitorRpcEvent(event:AbstractEvent):Void {
		// if (NetworkMonitor.isMonitoring()) {
		// 	if ((event is mx.rpc.events.ResultEvent)) {
		// 		NetworkMonitor.monitorResult(event.message, mx.rpc.events.ResultEvent(event).result);
		// 	} else if ((event is mx.rpc.events.FaultEvent)) {
		// 		// trace(" AbstractInvoker: MonitorFault - message:" + event.message);
		// 		NetworkMonitor.monitorFault(event.message, mx.rpc.events.FaultEvent(event).fault);
		// 	}
		// }
	}

	/**
	 *  Take the MessageAckEvent and take the result, store it, and broadcast out
	 *  appropriately.
	 *
	 *  @private
	 */
	private function resultHandler(event:MessageEvent):Void {
		var token:AsyncToken = preHandle(event);

		// if the handler didn't give us something just bail
		if (token == null)
			return;

		if (processResult(event.message, token)) {
			dispatchEvent(new Event(BINDING_RESULT));
			var resultEvent:ResultEvent = ResultEvent.createEvent(_result, token, event.message);
			resultEvent.headers = _responseHeaders;
			dispatchRpcEvent(resultEvent);
			// we are done with the result, clear if not kept, for GC
			if (!_keepLastResult) {
				_result = null;
			}
		}
		// no else, we assume process would have dispatched the faults if necessary
	}

	/**
	 *  Take the fault and convert it into a rpc.events.FaultEvent.
	 *
	 *  @private
	 */
	private function faultHandler(event:MessageFaultEvent):Void {
		var msgEvent:MessageEvent = MessageEvent.createEvent(MessageEvent.MESSAGE, event.message);
		var token:AsyncToken = preHandle(msgEvent);

		// continue only on a matching or empty correlationId
		// empty correlationIds could be the result of de/serialization errors
		if ((token == null)
			&& (cast(event.message, AsyncMessage).correlationId != null)
			&& (cast(event.message, AsyncMessage).correlationId != "")
			&& (event.faultCode != "Client.Authentication")) {
			return;
		}

		if (processFault(event.message, token)) {
			var fault:Fault = new Fault(event.faultCode, event.faultString, event.faultDetail);
			fault.content = event.message.body;
			fault.rootCause = event.rootCause;
			var faultEvent:FaultEvent = FaultEvent.createEvent(fault, token, event.message);
			faultEvent.headers = _responseHeaders;
			dispatchRpcEvent(faultEvent);
		}
	}

	/**
	 * Return the id for the NetworkMonitor.
	 * @private
	 */
	private function getNetmonId():String {
		return null;
	}

	private function invoke(message:IMessage, token:AsyncToken = null):AsyncToken {
		if (token == null)
			token = new AsyncToken(message);
		else
			token.setMessage(message);

		activeCalls.addCall(message.messageId, token);

		var fault:Fault;
		try {
			// asyncRequest.invoke(message, new AsyncResponder(resultHandler, faultHandler, token));
			asyncRequest.invoke(message, new Responder(resultHandler, faultHandler));
			dispatchRpcEvent(InvokeEvent.createEvent(token, message));
		} catch (e:MessagingError) {
			// _log.warn(e.toString());
			var errorText:String = 'Couldn\'t establish a connection to \'${asyncRequest.destination}\'';
			fault = new Fault("InvokeFailed", Std.string(e), errorText);
			new AsyncDispatcher(dispatchRpcEvent, [FaultEvent.createEvent(fault, token, message)], 10);
		} catch (e2:Error) {
			// _log.warn(e2.toString());
			fault = new Fault("InvokeFailed", e2.message);
			new AsyncDispatcher(dispatchRpcEvent, [FaultEvent.createEvent(fault, token, message)], 10);
		}

		return token;
	}

	/**
	 * Find the matching call object and pass it back.
	 *
	 * @private
	 */
	private function preHandle(event:MessageEvent):AsyncToken {
		return activeCalls.removeCall(cast(event.message, AsyncMessage).correlationId);
	}

	/**
	 * @private
	 */
	private function processFault(message:IMessage, token:AsyncToken):Bool {
		return true;
	}

	private function processResult(message:IMessage, token:AsyncToken):Bool {
		var body = message.body;

		// if (makeObjectsBindable && (body != null) && (Lib.getQualifiedClassName(body) == "Object")) {
		// 	_result = new ObjectProxy(body);
		// } else {
		_result = body;
		// }

		return true;
	}

	private var asyncRequest(get, set):AsyncRequest;

	private function get_asyncRequest():AsyncRequest {
		if (_asyncRequest == null) {
			_asyncRequest = new AsyncRequest();
		}
		return _asyncRequest;
	}

	private function set_asyncRequest(req:AsyncRequest):AsyncRequest {
		_asyncRequest = req;
		return _asyncRequest;
	}

	/**
	 * @private
	 */
	private var activeCalls:ActiveCalls;

	/**
	 * @private
	 */
	private var _responseHeaders:Array<Dynamic>;

	/**
	 * @private
	 */
	private var _result:Any;

	/**
	 * @private
	 */
	private var _makeObjectsBindable:Bool;

	/**
	 * @private
	 */
	private var _asyncRequest:AsyncRequest;

	/**
	 * @private
	 */
	private var _log:Any /*ILogger*/;
}
