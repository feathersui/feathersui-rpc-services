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

import feathers.messaging.channels.PollingChannel;
import feathers.messaging.events.ChannelEvent;
import feathers.messaging.events.ChannelFaultEvent;
import feathers.messaging.events.MessageEvent;
import feathers.messaging.events.MessageFaultEvent;
import feathers.messaging.messages.AcknowledgeMessage;
import feathers.messaging.messages.CommandMessage;
import feathers.messaging.messages.ErrorMessage;
import feathers.messaging.messages.IMessage;
import openfl.errors.ArgumentError;
import openfl.events.TimerEvent;
import openfl.utils.Timer;

/**
	The AbstractConsumer is the base class for both the Consumer and
	MultiTopicConsumer classes.  You use those classes to receive pushed
	messages from the server.
**/
class AbstractConsumer extends MessageAgent {
	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructs a Consumer.

		```haxe
		function initConsumer():Void
		{
			var consumer:Consumer = new Consumer();
			consumer.destination = "NASDAQ";
			consumer.selector = "operation IN ('Bid','Ask')";
			consumer.addEventListener(MessageEvent.MESSAGE, messageHandler);
			consumer.subscribe();
		}

		function messageHandler(event:MessageEvent):Void
		{
			var msg:IMessage = event.message;
			var info:Object = msg.body;
			trace("-App recieved message: " + msg.toString());
		}
		```
	**/
	public function new() {
		super();
		// _log = Log.getLogger("mx.messaging.Consumer");
		_agentType = "consumer";
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------
	// This is the current number of resubscribe attempts that we've done.
	private var _currentAttempt:Int;

	// The timer used for resubscribe attempts.
	private var _resubscribeTimer:Timer;

	// Flag indicating whether this consumer should be subscribed or not.
	private var _shouldBeSubscribed:Bool;

	// Current subscribe message - used for resubscribe attempts.
	private var _subscribeMsg:CommandMessage;

	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  clientId
	//----------------------------------

	/**
		If our clientId has changed we may need to unsubscribe() using the
		current clientId and then resubscribe using the new clientId.
		// TODO - remove this?
		@param value The clientId value.
	**/
	override private function setClientId(value:String):Void {
		if (super.clientId != value) {
			var resetSubscription:Bool = false;
			if (subscribed) {
				unsubscribe();
				resetSubscription = true;
			}

			super.setClientId(value);

			if (resetSubscription)
				subscribe(value);
		}
	}

	//----------------------------------
	//  destination
	//----------------------------------
	// Updates the destination for this Consumer and resubscribes if the
	// Consumer is currently subscribed.
	override public function set_destination(value:String):String {
		if (destination != value) {
			var resetSubscription:Bool = false;
			if (subscribed) {
				unsubscribe();
				resetSubscription = true;
			}

			super.destination = value;

			if (resetSubscription)
				subscribe();
		}
		return _destination;
	}

	//----------------------------------
	//  maxFrequency
	//----------------------------------
	private var _maxFrequency:UInt = 0;

	// [Bindable(event="propertyChange")]

	/**
		Determines the maximum number of messages per second the Consumer wants
		to receive. A server that understands this value will use it as an input
		while it determines how fast to send messages to the Consumer. Default is 0 
		which means Consumer does not have a preference for the message rate. 
		Note that this property should be set before the Consumer subscribes and
		any changes after Consumer subscription will not have any effect until 
		Consumer unsubscribes and resubscribes.
	**/
	@:flash.property
	public var maxFrequency(get, set):UInt;

	private function get_maxFrequency():UInt {
		return _maxFrequency;
	}

	private function set_maxFrequency(value:UInt):UInt {
		// var event:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "maxFrequency", _maxFrequency, value);
		_maxFrequency = value;
		// dispatchEvent(event);
		return _maxFrequency;
	}

	//----------------------------------
	//  resubscribeAttempts
	//----------------------------------
	private var _resubscribeAttempts:Int = 5;

	// [Bindable(event="propertyChange")]

	/**
		The number of resubscribe attempts that the Consumer makes in the event
		that the destination is unavailable or the connection to the destination fails.
		A value of -1 enables infinite attempts.
		A value of zero disables resubscribe attempts.

		Resubscribe attempts are made at a constant rate according to the resubscribe interval
		value. When a resubscribe attempt is made if the underlying channel for the Consumer is not
		connected or attempting to connect the channel will start a connect attempt.
		Subsequent Consumer resubscribe attempts that occur while the underlying
		channel connect attempt is outstanding are effectively ignored until
		the outstanding channel connect attempt succeeds or fails.

		@see mx.messaging.Consumer#resubscribeInterval
	**/
	@:flash.property
	public var resubscribeAttempts(get, set):Int;

	private function get_resubscribeAttempts():Int {
		return _resubscribeAttempts;
	}

	private function set_resubscribeAttempts(value:Int):Int {
		if (_resubscribeAttempts != value) {
			if (value == 0)
				stopResubscribeTimer();

			// var event:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "resubscribeAttempts", _resubscribeAttempts, value);
			_resubscribeAttempts = value;
			// dispatchEvent(event);
		}
		return _resubscribeAttempts;
	}

	//----------------------------------
	//  resubscribeInterval
	//----------------------------------
	private var _resubscribeInterval:Int = 5000;

	// [Bindable(event="propertyChange")]

	/**
		The number of milliseconds between resubscribe attempts.
		If a Consumer doesn't receive an acknowledgement for a subscription
		request, it will wait the specified number of milliseconds before
		attempting to resubscribe.
		Setting the value to zero disables resubscriptions.

		Resubscribe attempts are made at a constant rate according to this
		value. When a resubscribe attempt is made if the underlying channel for the Consumer is not
		connected or attempting to connect the channel will start a connect attempt.
		Subsequent Consumer resubscribe attempts that occur while the underlying
		channel connect attempt is outstanding are effectively ignored until
		the outstanding channel connect attempt succeeds or fails.


		@see mx.messaging.Consumer#resubscribeInterval
		@throws ArgumentError If the assigned value is negative.
	**/
	@:flash.property
	public var resubscribeInterval(get, set):Int;

	private function get_resubscribeInterval():Int {
		return _resubscribeInterval;
	}

	private function set_resubscribeInterval(value:Int):Int {
		if (_resubscribeInterval != value) {
			if (value < 0) {
				var message:String = "resubscribeInterval cannot take a negative value.";
				throw new ArgumentError(message);
			} else if (value == 0) {
				stopResubscribeTimer();
			} else if (_resubscribeTimer != null) {
				_resubscribeTimer.delay = value;
			}

			// var event:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "resubscribeInterval", _resubscribeInterval, value);
			_resubscribeInterval = value;
			// dispatchEvent(event);
		}
		return _resubscribeInterval;
	}

	//----------------------------------
	//  subscribed
	//----------------------------------
	private var _subscribed:Bool;

	// [Bindable(event="propertyChange")]

	/**
		Indicates whether the Consumer is currently subscribed. The <code>propertyChange</code>
		event is dispatched when this property changes.
	**/
	@:flash.property
	public var subscribed(get, never):Bool;

	private function get_subscribed():Bool {
		return _subscribed;
	}

	private function setSubscribed(value:Bool):Void {
		if (_subscribed != value) {
			// var event:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "subscribed", _subscribed, value);
			_subscribed = value;

			// Register or unregister our subscription state with the ConsumerMessageDispatcher.
			// This allows the singleton ConsumerMessageDispatcher to start or stop listening for
			// messages on our behalf.
			if (_subscribed) {
				ConsumerMessageDispatcher.getInstance().registerSubscription(this);
				if (channelSet != null && channelSet.currentChannel != null && (channelSet.currentChannel is PollingChannel))
					cast(channelSet.currentChannel, PollingChannel).enablePolling();
			} else {
				ConsumerMessageDispatcher.getInstance().unregisterSubscription(this);
				if (channelSet != null && channelSet.currentChannel != null && (channelSet.currentChannel is PollingChannel))
					cast(channelSet.currentChannel, PollingChannel).disablePolling();
			}

			// dispatchEvent(event);
		}
	}

	//----------------------------------
	//  timestamp
	//----------------------------------
	private var _timestamp:Float = -1;

	// [Bindable(event="propertyChange")]

	/**
		Contains the timestamp of the most recent message this Consumer
		has received.
		This value is passed to the destination in a <code>receive()</code> call
		to request that it deliver messages for the Consumer from the timestamp
		forward.
		All messages with a timestamp value greater than the
		<code>timestamp</code> value will be returned during a poll operation.
		Setting this value to -1 will retrieve all cached messages from the
		destination.
	**/
	@:flash.property
	public var timestamp(get, set):Float;

	private function get_timestamp():Float {
		return _timestamp;
	}

	private function set_timestamp(value:Float):Float {
		if (_timestamp != value) {
			// var event:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "timestamp", _timestamp, value);
			_timestamp = value;
			// dispatchEvent(event);
		}
		return _timestamp;
	}

	//--------------------------------------------------------------------------
	//
	// Overridden Methods
	//
	//--------------------------------------------------------------------------

	/**
		Custom processing for subscribe, unsubscribe and poll message
		acknowledgments.

		@param ackMsg The AcknowledgeMessage.

		@param msg The original subscribe, unsubscribe or poll message.
	**/
	@:dox(hide)
	override public function acknowledge(ackMsg:AcknowledgeMessage, msg:IMessage):Void {
		// Ignore acks for any outstanding messages that return after disconnect() is invoked.
		if (_disconnectBarrier)
			return;

		// Only run Consumer processing if this isn't an error.
		if (Reflect.field(ackMsg.headers, AcknowledgeMessage.ERROR_HINT_HEADER) == null && (msg is CommandMessage)) {
			var command:CommandMessage = Std.downcast(msg, CommandMessage);

			var op:UInt = command.operation;

			// For MultiTopicConsumers, the message gets marked if this is the
			// message completely unsubscribes the client.
			if (op == CommandMessage.MULTI_SUBSCRIBE_OPERATION) {
				if (Reflect.field(msg.headers, "DSlastUnsub") != null)
					op = CommandMessage.UNSUBSCRIBE_OPERATION;
				else
					op = CommandMessage.SUBSCRIBE_OPERATION;
			}

			switch (op) {
				case CommandMessage.UNSUBSCRIBE_OPERATION:
					// if (Log.isInfo())
					// 	_log.info("'{0}' {1} acknowledge for unsubscribe.", id, _agentType);
					super.setClientId(null);
					setSubscribed(false); // Stop listening for messages.
					ackMsg.clientId = null; // Force the ack's clientId to null as well before ack'ing it.
					super.acknowledge(ackMsg, msg);

				case CommandMessage.SUBSCRIBE_OPERATION:
					stopResubscribeTimer();
					// NOTE: the -1 in the timestamp assignment below.
					// This works around a bug where if a Producer sends
					// a message in the same batch as the subscribe,
					// it will end up with (likely) the same timestamp
					// as the consumer.  Because the message is sent
					// by the client after the subscribe though, it
					// should still be delivered.
					// TODO: Improve solution here.
					if (ackMsg.timestamp > _timestamp)
						_timestamp = ackMsg.timestamp - 1;

					// if (Log.isInfo())
					// 	_log.info("'{0}' {1} acknowledge for subscribe. Client id '{2}' new timestamp {3}",
					// 				id, _agentType, ackMsg.clientId, _timestamp);
					super.setClientId(ackMsg.clientId);
					setSubscribed(true);
					super.acknowledge(ackMsg, msg);

				// Handle the result of a receive() invocation (a Consumer instance-specific poll request).
				case CommandMessage.POLL_OPERATION:
					if ((ackMsg.body != null) && (ackMsg.body is Array)) {
						var messageList:Array<IMessage> = ackMsg.body;
						for (message in messageList)
							messageHandler(MessageEvent.createEvent(MessageEvent.MESSAGE, message));
					}
					super.acknowledge(ackMsg, msg);
			}
		} else {
			super.acknowledge(ackMsg, msg);
		}
	}

	/**
		Disconnects the Consumer from its remote destination.
		This method should be invoked on a Consumer that is no longer
		needed by an application after unsubscribing.
		This method does not wait for outstanding network operations to complete
		and does not send an unsubscribe message to the server.
		After invoking disconnect(), the Consumer will report that it is in an
		disconnected, unsubscribed state because it will not receive any more
		messages until it has reconnected and resubscribed.
		Disconnecting stops automatic resubscription attempts if they are running.
	**/
	override public function disconnect():Void {
		// We don't invoke unsubscribe() in this case because a Consumer subscribed to a
		// JMS destination durably will blow away the durable subscription.
		_shouldBeSubscribed = false; // Prevent resubscribe attempts.
		stopResubscribeTimer();
		setSubscribed(false);

		super.disconnect();
	}

	/**
		The Consumer supresses ErrorMessage processing if the error is
		retryable and it is configured to resubscribe.

		@param errMsg The ErrorMessage describing the fault.
		@param msg The original message (generally a subscribe).
	**/
	override public function fault(errMsg:ErrorMessage, msg:IMessage):Void {
		// Ignore faults for any outstanding messages that return after disconnect() is invoked.
		if (_disconnectBarrier)
			return;

		if (Reflect.field(errMsg.headers, ErrorMessage.RETRYABLE_HINT_HEADER)) {
			if (_resubscribeTimer == null) {
				// If this error correlates to our current subscribe message,
				// we should no longer be subscribed.
				if ((_subscribeMsg != null) && (errMsg.correlationId == _subscribeMsg.messageId))
					_shouldBeSubscribed = false;
				super.fault(errMsg, msg);
			}
			// Else, suppress the fault dispatch because the resubscribe
			// timer is running and will generate a fault when it runs out of
			// allowed resubscribe attempts.
		} else {
			super.fault(errMsg, msg);
		}
	}

	/**
		Custom processing to warn the user if the consumer is connected over
		a non-real channel.

		@param event The ChannelEvent.
	**/
	@:dox(hide)
	override public function channelConnectHandler(event:ChannelEvent):Void {
		super.channelConnectHandler(event);

		// if (connected && channelSet != null && channelSet.currentChannel != null
		// 		&& !channelSet.currentChannel.realtime && Log.isWarn())
		// {
		// 	_log.warn("'{0}' {1} connected over a non-realtime channel '{2}'"
		// 		+ " which means channel is not automatically receiving updates via polling or server push."
		// 		, id, _agentType, channelSet.currentChannel.id);
		// }
	}

	/**
		Custom processing to start up a resubscribe timer if our channel is
		disconnected when we should be subscribed.

		@param event The ChannelEvent.
	**/
	@:dox(hide)
	override public function channelDisconnectHandler(event:ChannelEvent):Void {
		setSubscribed(false);

		super.channelDisconnectHandler(event);

		if (_shouldBeSubscribed && !event.rejected)
			startResubscribeTimer();
	}

	/**
		Custom processing to start up a resubscribe timer if our channel faults
		when we should be subscribed.

		@param event The ChannelFaultEvent.
	**/
	@:dox(hide)
	override public function channelFaultHandler(event:ChannelFaultEvent):Void {
		if (!event.channel.connected)
			setSubscribed(false);

		super.channelFaultHandler(event);

		if (_shouldBeSubscribed && !event.rejected && !event.channel.connected)
			startResubscribeTimer();
	}

	//--------------------------------------------------------------------------
	//
	// Methods
	//
	//--------------------------------------------------------------------------

	/**
		Requests any messages that are queued for this Consumer on the server.
		This method should only be used for Consumers that subscribe over non-realtime,
		non-polling channels.
		This method is a no-op if the Consumer is not subscribed.

		@param timestamp This argument is deprecated and is ignored.

	**/
	public function receive(timestamp:Float = 0):Void {
		if (clientId != null) // We need a clientId to distinguish this from a generic poll request sent by a polling channel.
		{
			var msg:CommandMessage = new CommandMessage();
			msg.operation = CommandMessage.POLL_OPERATION;
			msg.destination = destination;
			internalSend(msg);
		}
	}

	/**
		Subscribes to the remote destination.

		@param clientId The client id to subscribe with. Use null for non-durable Consumers. If the subscription is durable, a consistent
		value must be supplied every time the Consumer subscribes in order
		to reconnect to the correct durable subscription in the remote destination.

		@throws mx.messaging.errors.InvalidDestinationError If no destination is set.

	**/
	public function subscribe(clientId:String = null):Void {
		// Set a flag to determine whether the passed clientId differs from the
		// current value and should be assigned.
		var resetClientId:Bool = ((clientId != null) && (super.clientId != clientId)) ? true : false;

		if (subscribed && resetClientId) {
			// We're already subscribed, but we need to resubscribe under
			// the new clientId.
			unsubscribe();
		}

		// Make sure any resubscribe timer is stopped.
		stopResubscribeTimer();

		_shouldBeSubscribed = true;
		if (resetClientId)
			super.setClientId(clientId);
		// if (Log.isInfo())
		// 	_log.info("'{0}' {1} subscribe.", id, _agentType);
		_subscribeMsg = buildSubscribeMessage();

		internalSend(_subscribeMsg);
	}

	/**
		Unsubscribes from the remote destination. In the case of durable JMS
		subscriptions, this will destroy the durable subscription on the JMS server.

		@param preserveDurable - when true, durable JMS subscriptions are not destroyed
		allowing consumers to later resubscribe and receive missed messages
	**/
	public function unsubscribe(preserveDurable:Bool = false):Void {
		_shouldBeSubscribed = false;
		if (subscribed) {
			// Stop listening now for any messages as we could be set to a new
			// channel before the ack comes back, and once the ack returns we
			// will no longer have a valid client id.
			if (channelSet != null)
				channelSet.removeEventListener(destination, messageHandler);

			// if (Log.isInfo())
			// 	_log.info("'{0}' {1} unsubscribe.", id, _agentType);

			internalSend(buildUnsubscribeMessage(preserveDurable));
		} else {
			stopResubscribeTimer();
		}
	}

	//--------------------------------------------------------------------------
	//
	// Internal Methods
	//
	//--------------------------------------------------------------------------

	/**
		Consumers subscribe for messages from a destination and this is the handler
		method that is invoked when a message for this Consumer is pushed or polled
		from the server.

		@param event The MessageEvent.
	**/
	private function messageHandler(event:MessageEvent):Void {
		// NOTE: This method is invoked directly by the ConsumerMessageDispatcher.
		// The event flow for a pushed message is:
		// 1. Channel receives a pushed/polled message and dispatches a message event
		// 2. Any ChannelSets connected to the Channel will handle these events in ChannelSet.messageHandler();
		//    simply redispatching them.
		// 3. Consumers that subscribe to a destination trigger the internal use of a shared ConsumerMessageDispatcher
		//    that listens for message events from any ChannelSets that Consumers have subscribed over and this helper routes pushed messages to the proper Consumer instances.
		var message:IMessage = event.message;
		if ((message is CommandMessage)) {
			var command:CommandMessage = cast(message, CommandMessage);
			switch (command.operation) {
				case CommandMessage.SUBSCRIPTION_INVALIDATE_OPERATION:
					// We've been unsubscribed but it wasn't the result of an unsubscribe
					// message this agent sent. Set unsubscribe to false which will inform
					// the polling channel to stop polling if a polling channel is being used.
					setSubscribed(false);
				default:
					// if (Log.isWarn())
					// 	_log.warn("'{0}' received a CommandMessage '{1}' that could not be handled.", id, CommandMessage.getOperationAsString(command.operation));
			}
			/*
				Command messages are handled internally by the Consumer and
				are not dispatched to message listeners via MessageEvents.
			 */
			return;
		}

		if (message.timestamp > _timestamp)
			_timestamp = message.timestamp;

		// Server might push out error messages (eg. during MessageClient.invalidate)
		// that need to be dispatched as message fault events.
		if ((message is ErrorMessage))
			dispatchEvent(MessageFaultEvent.createEvent(cast(message, ErrorMessage)));
		else
			dispatchEvent(MessageEvent.createEvent(MessageEvent.MESSAGE, message));
	}

	//--------------------------------------------------------------------------
	//
	// Protected Methods
	//
	//--------------------------------------------------------------------------

	/**
		Returns a subscribe message.
		This method should be overridden by subclasses if they need custom
		subscribe messages.

		@return The subscribe CommandMessage.

	**/
	private function buildSubscribeMessage():CommandMessage {
		var msg:CommandMessage = new CommandMessage();
		msg.operation = CommandMessage.SUBSCRIBE_OPERATION;
		msg.clientId = clientId;
		msg.destination = destination;
		if (maxFrequency > 0)
			Reflect.setField(msg.headers, CommandMessage.MAX_FREQUENCY_HEADER, maxFrequency);
		return msg;
	}

	/**
		Returns an unsubscribe message.
		This method should be overridden by subclasses if they need custom
		unsubscribe messages.

		@param preserveDurable - when true, durable JMS subscriptions are not destroyed
		allowing consumers to later resubscribe and receive missed messages

		@return The unsubscribe CommandMessage.

	**/
	private function buildUnsubscribeMessage(preserveDurable:Bool):CommandMessage {
		var msg:CommandMessage = new CommandMessage();
		msg.operation = CommandMessage.UNSUBSCRIBE_OPERATION;
		msg.clientId = clientId;
		msg.destination = destination;

		// only include the PRESERVE_DURABLE_HEADER param in the message if
		// its value is true
		if (preserveDurable)
			Reflect.setField(msg.headers, CommandMessage.PRESERVE_DURABLE_HEADER, preserveDurable);

		return msg;
	}

	/**
		Attempt to resubscribe.
		This can be called directly or from a Timer's event handler.

		@param event The timer event for resubscribe attempts.
	**/
	private function resubscribe(event:TimerEvent):Void {
		// If we're past our limit of attempts, fault out.
		if ((_resubscribeAttempts != -1) && (_currentAttempt >= _resubscribeAttempts)) {
			stopResubscribeTimer();
			_shouldBeSubscribed = false;
			var errMsg:ErrorMessage = new ErrorMessage();
			errMsg.faultCode = "Client.Error.Subscribe";
			errMsg.faultString = "Consumer subscribe error";
			errMsg.faultDetail = "The consumer was not able to subscribe to its target destination.";
			errMsg.correlationId = _subscribeMsg.messageId;
			fault(errMsg, _subscribeMsg);
			return;
		}

		// if (Log.isDebug())
		// 	_log.debug("'{0}' {1} trying to resubscribe.", id, _agentType);

		_resubscribeTimer.delay = _resubscribeInterval;
		_currentAttempt++;
		// Send the resubscribe message, skipping the MessageAgent's queue that blocks
		// messages until the clientId is set.
		internalSend(_subscribeMsg, false);
	}

	/**
		This method will start a timer which attempts to resubscribe
		periodically.
	**/
	private function startResubscribeTimer():Void {
		if (_shouldBeSubscribed && (_resubscribeTimer == null)) {
			// If we're configured for resubscribe start up the timer.
			if ((_resubscribeAttempts != 0) && (_resubscribeInterval > 0)) {
				// if (Log.isDebug())
				// 	_log.debug("'{0}' {1} starting resubscribe timer.", id, _agentType);
				/*
					Initially, the timeout is set to 1 so we try to
					reconnect immediately (perhaps to a different channel).
					after that, it will poll at the configured time interval.
				 */
				_resubscribeTimer = new Timer(1);
				_resubscribeTimer.addEventListener(TimerEvent.TIMER, resubscribe);
				_resubscribeTimer.start();
				_currentAttempt = 0;
			}
		}
	}

	/**
		Stops a resubscribe timer if one is running.
	**/
	private function stopResubscribeTimer():Void {
		if (_resubscribeTimer != null) {
			// if (Log.isDebug())
			// 	_log.debug("'{0}' {1} stopping resubscribe timer.", id, _agentType);

			_resubscribeTimer.removeEventListener(TimerEvent.TIMER, resubscribe);
			_resubscribeTimer.reset();
			_resubscribeTimer = null;
		}
	}
}
