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

package feathers.messaging;

import feathers.messaging.messages.AsyncMessage;
import feathers.messaging.messages.CommandMessage;
import feathers.messaging.messages.IMessage;

/**
 *  A Consumer subscribes to a destination to receive messages.
 *  Consumers send subscribe and unsubscribe messages which generate a MessageAckEvent
 *  or MessageFaultEvent depending upon whether the operation was successful or not.
 *  Once subscribed, a Consumer dispatches a MessageEvent for each message it receives.
 *  Consumers provide the ability to filter messages using a selector.
 *  These selectors must be understood by the destination.
 */
class Consumer extends AbstractConsumer {
	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
	 *  Constructor.
	 * 
	 *  @param messageType The alias for the message type processed by the service
	 *                     hosting the remote destination the Consumer will subscribe to.
	 *                     This parameter is deprecated and it is ignored by the
	 *                     constructor.
	 * 
	 *  @example
	 *  <listing version="3.0">
	 *   function initConsumer():Void
	 *   {
	 *       var consumer:Consumer = new Consumer();
	 *       consumer.destination = "NASDAQ";
	 *       consumer.selector = "operation IN ('Bid','Ask')";
	 *       consumer.addEventListener(MessageEvent.MESSAGE, messageHandler);
	 *       consumer.subscribe();
	 *   }
	 *
	 *   function messageHandler(event:MessageEvent):Void
	 *   {
	 *       var msg:IMessage = event.message;
	 *       var info:Object = msg.body;
	 *       trace("-App recieved message: " + msg.toString());
	 *   }
	 *   </listing>
	 *  
	 */
	public function new(messageType:String = "flex.messaging.messages.AsyncMessage") {
		super();
	}

	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  selector
	//----------------------------------

	/**
	 *  @private
	 */
	private var _selector:String = "";

	// [Bindable(event="propertyChange")]
	// [Inspectable(category="General", verbose="1")]

	/**
	 *  The selector for the Consumer. 
	 *  This is an expression that is passed to the destination which uses it
	 *  to filter the messages delivered to the Consumer.
	 * 
	 *  Before a call to the <code>subscribe()</code> method, this property 
	 *  can be set with no side effects. 
	 *  After the Consumer has subscribed to its destination, changing this 
	 *  value has the side effect of updating the Consumer's subscription to 
	 *  use the new selector expression immediately.
	 * 
	 *  The remote destination must understand the value of the selector 
	 *  expression.
	 *  
	 */
	@:flash.property
	public var selector(get, set):String;

	private function get_selector():String {
		return _selector;
	}

	/**
	 *  @private
	 */
	private function set_selector(value:String):String {
		if (_selector != value) {
			// var event:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "selector", _selector, value);

			var resetSubscription:Bool = false;
			if (subscribed) {
				unsubscribe();
				resetSubscription = true;
			}

			_selector = value;

			// Update an existing subscription to use the new selector.
			if (resetSubscription)
				subscribe(clientId);

			// dispatchEvent(event);
		}
		return _selector;
	}

	//----------------------------------
	//  subtopic
	//----------------------------------

	/**
	 *  @private
	 */
	private var _subtopic:String = "";

	// [Bindable(event="propertyChange")]

	/**
	 *  Provides access to the subtopic for the remote destination that the MessageAgent uses.
	 *  
	 */
	@:flash.property
	public var subtopic(get, set):String;

	private function get_subtopic():String {
		return _subtopic;
	}

	/**
	 *  Setting the subtopic when the Consumer is connected and
	 *  subscribed has the side effect of unsubscribing and resubscribing
	 *  the Consumer.
	 *  
	 */
	private function set_subtopic(value:String):String {
		if (subtopic != value) {
			var resetSubscription:Bool = false;
			if (subscribed) {
				unsubscribe();
				resetSubscription = true;
			}

			_subtopic = value;

			if (resetSubscription)
				subscribe();
		}
		return _subtopic;
	}

	//--------------------------------------------------------------------------
	//
	// Protected Methods
	//
	//--------------------------------------------------------------------------

	/**
	 * @private
	 */
	override private function internalSend(message:IMessage, waitForClientId:Bool = true):Void {
		if (subtopic.length > 0)
			Reflect.setField(message.headers, AsyncMessage.SUBTOPIC_HEADER, subtopic);
		if (_selector.length > 0)
			Reflect.setField(message.headers, CommandMessage.SELECTOR_HEADER, _selector);

		super.internalSend(message, waitForClientId);
	}
}
