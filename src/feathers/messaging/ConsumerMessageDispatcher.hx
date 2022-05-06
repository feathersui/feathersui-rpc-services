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

import feathers.messaging.events.MessageEvent;

/**
	Helper class that listens for MessageEvents dispatched by ChannelSets that Consumers are subscribed over.
	This class is necessary because the server maintains queues of messages to push to this Flex client on a
	per-endpoint basis but the client may create more than one Channel that connects to a single server endpoint.
	In this scenario, messages can be pushed/polled to the client over a different channel instance than the one 
	that the target Consumer subscribed over. The server isn't aware of this difference because both channels are 
	pointed at the same endpoint. Here's a diagram to illustrate.

	```
	Client:
				 Consumer 1           Consumer 2    Consumer 3
					|                       |       /
				 ChannelSet 1            ChannelSet 2
					|                       |
				 Channel 1               Channel 2  <- The endpoint URIs for these two channels are identical
					|                       |
					\_______________________/
	Server:                     |
								|
							Endpoint (that the two channels point to)
								|
					FlexClientOutboundQueue (for this endpoint for this FlexClient)
								\-- Outbound messages for the three Consumer subscriptions
	```

	When the endpoint receives a poll request from Channel 1 it will return queued messages for all three subscriptions
	but back on the client when Channel 1 dispatches message events for Consumer 2 and 3's subscriptions they won't see
	them because they're directly connected to the separate Channel2/ChannelSet2.
	This helper class keeps track of Consumer subscriptions and watches all ChannelSets for message events to 
	ensure they're dispatched to the proper Consumer even when the client has been manually (miss)configured as the
	diagram illustrates.

	This class is a singleton that maintains a table of all subscribed Consumers and ref-counts the number of active
	subscriptions per ChannelSet to determine whether it needs to be listening for message events from a given 
	ChannelSet or not; it dispatches message events from these ChannelSets to the proper Consumer instance
	by invoking the Consumer's messageHandler() method directly.
**/
@:dox(hide)
@:access(feathers.messaging.AbstractConsumer)
class ConsumerMessageDispatcher {
	//--------------------------------------------------------------------------
	//
	//  Class variables
	//
	//--------------------------------------------------------------------------

	/**
		The sole instance of this singleton class.
	**/
	private static var _instance:ConsumerMessageDispatcher;

	//--------------------------------------------------------------------------
	//
	//  Class methods
	//
	//--------------------------------------------------------------------------

	/**
		Returns the sole instance of this singleton class,
		creating it if it does not already exist.
	**/
	public static function getInstance():ConsumerMessageDispatcher {
		if (_instance == null)
			_instance = new ConsumerMessageDispatcher();

		return _instance;
	}

	//--------------------------------------------------------------------------
	//
	//  Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructor.
		Use getInstance() instead of "new" to create.
	**/
	public function new() {}

	//--------------------------------------------------------------------------
	//
	//  Variables
	//
	//--------------------------------------------------------------------------

	/**
		Lookup table for subscribed Consumer instances; Object<Consumer clientId, Consumer>
		This is used to dispatch pushed/polled messages to the proper Consumer instance.
	**/
	private final _consumers:Dynamic = {};

	/**
		Table of ref-counts per ChannelSet that subscribed Consumer instances are using; Dictionary<ChannelSet, ref-count> (non-weak keys).
		The ref-count is the number of subscribed Consumers for the ChannelSet.
		When we add a new ChannelSet we need to start listening on it for MessageEvents to redispatch to subscribed Consumers.
		When the ref-count drops to zero we need to stop listening on it for MessageEvents and remove it from the table.
	**/
	private final _channelSetRefCounts:Map<ChannelSet, Int> = [];

	/**
		Table used to prevent duplicate delivery of messages to a Consumer when multiple ChannelSets are
		connected to the same server endpoint over a single, underlying shared Channel.
	**/
	private final _consumerDuplicateMessageBarrier:Dynamic = {};

	//--------------------------------------------------------------------------
	//
	//  Public Methods
	//
	//--------------------------------------------------------------------------

	/**
		Determines whether any subscriptions are using the specified channel.
	**/
	public function isChannelUsedForSubscriptions(channel:Channel):Bool {
		var memberOfChannelSets = channel.channelSets;
		var cs:ChannelSet = null;
		var n:Int = memberOfChannelSets.length;
		for (i in 0...n) {
			cs = memberOfChannelSets[i];
			if ((_channelSetRefCounts.exists(cs)) && (cs.currentChannel == channel))
				return true;
		}
		return false;
	}

	/**
		Registers a Consumer subscription.
		This will cause the ConsumerMessageDispatcher to start listening for MessageEvents
		from the underlying ChannelSet used to subscribe and redispatch messages to Consumers.
	**/
	public function registerSubscription(consumer:AbstractConsumer):Void {
		Reflect.setField(_consumers, consumer.clientId, consumer);
		if (_channelSetRefCounts[consumer.channelSet] == null) {
			// If this is the first time we've seen this ChannelSet start listening for message events
			// and initialize its ref-count.
			consumer.channelSet.addEventListener(MessageEvent.MESSAGE, messageHandler);
			_channelSetRefCounts[consumer.channelSet] = 1;
		} else {
			// We're already listening for message events; just increment the ref-count.
			_channelSetRefCounts[consumer.channelSet]++;
		}
	}

	/**
		Unregisters a Consumer subscription.
		The ConsumerMessageDispatcher will stop monitoring underlying channels for messages for
		this Consumer.
	**/
	public function unregisterSubscription(consumer:AbstractConsumer):Void {
		Reflect.deleteField(_consumers, consumer.clientId);
		var refCount:Int = _channelSetRefCounts.get(consumer.channelSet);
		if (--refCount == 0) {
			// If this was the last Consumer using this ChannelSet stop listening for message events
			// and blow away the ref-count.
			consumer.channelSet.removeEventListener(MessageEvent.MESSAGE, messageHandler);
			_channelSetRefCounts.remove(consumer.channelSet);

			// And clean up the duplicate message delivery barrier if necessary.
			if (Reflect.field(_consumerDuplicateMessageBarrier, consumer.id) != null)
				Reflect.deleteField(_consumerDuplicateMessageBarrier, consumer.id);
		} else {
			// Save the decremented ref-count.
			_channelSetRefCounts[consumer.channelSet] = refCount;
		}
	}

	//--------------------------------------------------------------------------
	//
	//  Private Methods
	//
	//--------------------------------------------------------------------------

	/**
		Handles message events from ChannelSets that Consumers are subscribed over.
		We just need to redirect the event to the proper Consumer instance.
	**/
	private function messageHandler(event:MessageEvent):Void {
		var consumer:AbstractConsumer = Reflect.field(_consumers, event.message.clientId);
		if (consumer == null) {
			// if (Log.isDebug())
			// 	Log.getLogger("mx.messaging.Consumer")
			// 		.debug("'{0}' received pushed message for consumer but no longer subscribed: {1}", event.message.clientId, event.message);
			return;
		}

		// Determine how many of these will actually redispatch the same event from the shared underlying channel.
		var eventTarget = cast(event.target, ChannelSet);
		if (eventTarget.currentChannel.channelSets.length > 1) {
			var count:Int = 0;
			for (cs in eventTarget.currentChannel.channelSets) {
				if (_channelSetRefCounts.exists(cs))
					++count;
			}

			if (count > 1) {
				// We need to dispatch this message to the target Consumer only once and filter out
				// the duplicate events.
				if (Reflect.field(_consumerDuplicateMessageBarrier, consumer.id) == null) {
					// Record the number of times we will receive a message event for this message.
					Reflect.setField(_consumerDuplicateMessageBarrier, consumer.id, [event.messageId, Std.string(count)]);

					// Dispatch once - only the first time we see this message for this Consumer.
					consumer.messageHandler(event);
				}

				// Cleanup.
				var duplicateDispatchGuard:Array<Int> = Reflect.field(_consumerDuplicateMessageBarrier, consumer.id);
				if (Std.string(duplicateDispatchGuard[0]) == event.messageId) {
					if (--duplicateDispatchGuard[1] == 0)
						Reflect.deleteField(_consumerDuplicateMessageBarrier, consumer.id);
				}

				return; // Exit early.
			}
		}

		// Only one ChannelSet so we don't need to worry about this.
		consumer.messageHandler(event);
	}
}
