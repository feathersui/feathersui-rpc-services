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

package feathers.messaging.channels;

import feathers.messaging.events.ChannelFaultEvent;
import feathers.messaging.events.MessageEvent;
import feathers.messaging.messages.AcknowledgeMessage;
import feathers.messaging.messages.CommandMessage;
import feathers.messaging.messages.ErrorMessage;
import feathers.messaging.messages.IMessage;
import openfl.errors.ArgumentError;
import openfl.errors.Error;
import openfl.events.Event;
import openfl.events.TimerEvent;
import openfl.utils.Timer;

/**
	The PollingChannel class provides the polling behavior that all polling channels in the messaging
	system require.
**/
class PollingChannel extends Channel {
	//--------------------------------------------------------------------------
	//
	// Protected Static Constants
	//
	//--------------------------------------------------------------------------

	/**
		Channel config parsing constants. 
	**/
	private static final POLLING_ENABLED:String = "polling-enabled";

	private static final POLLING_INTERVAL_MILLIS:String = "polling-interval-millis";
	private static final POLLING_INTERVAL_LEGACY:String = "polling-interval-seconds";
	private static final PIGGYBACKING_ENABLED:String = "piggybacking-enabled";
	private static final LOGIN_AFTER_DISCONNECT:String = "login-after-disconnect";

	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Creates a new PollingChannel instance with the specified id. Once a PollingChannel is
		connected and begins polling, it will issue a poll request once every three seconds
		by default.

		**Note:** The PollingChannel type should not be constructed directly. Instead
		create instances of protocol specific subclasses such as HTTPChannel or
		AMFChannel that extend it.

		@param id The id of this Channel.

		@param uri The uri for this Channel.
	**/
	public function new(id:String = null, uri:String = null) {
		super(id, uri);

		_pollingEnabled = true;
		_shouldPoll = false;

		if (timerRequired()) {
			// Poll on a 3 second interval by default.
			// The timer is configured to only dispatch one event per run.
			// It is restarted after a poll response is received for the current outstanding poll request.
			_pollingInterval = DEFAULT_POLLING_INTERVAL;
			_timer = new Timer(_pollingInterval, 1);
			_timer.addEventListener(TimerEvent.TIMER, internalPoll);
		}
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/**
		The base polling interval to use if the server is not triggering adaptive polling
		interval waits via its poll responses.
	**/
	private var _pollingInterval:Float;

	/**
		Indicates whether we should poll but stopped for some reason.
	**/
	private var _shouldPoll:Bool;

	/**
		This reference count allows us to determine when polling is needed and
		when it is not.
	**/
	private var _pollingRef:Int = -1;

	/**
		Guard used to avoid issuing poll requests on top of each other. This is 
		needed when a poll request is issued manually by calling poll() method.
	**/
	private var pollOutstanding:Bool;

	/**
		Used for polling the server at a given interval.  
		This may be null if channel implementation does not require the use of a 
		timer to poll.
	**/
	private var _timer:Timer;

	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  connected
	//----------------------------------

	/**
		Reset polling state following a transient disconnect if possible.

		@param value The new connected state.
	**/
	override private function setConnected(value:Bool):Void {
		if (connected != value) {
			if (value) // Potentially a transient reconnect; check for subscribed Consumers.
			{
				for (channelSet in channelSets) {
					for (agent in channelSet.messageAgents) {
						if ((agent is Consumer) && cast(agent, Consumer).subscribed) {
							enablePolling();
						}
					}
				}
			}

			super.setConnected(value);
		}
	}

	//----------------------------------
	//  loginAfterDisconnect
	//----------------------------------
	private var _loginAfterDisconnect:Bool;

	private var loginAfterDisconnect(get, never):Bool;

	private function get_loginAfterDisconnect():Bool {
		return _loginAfterDisconnect;
	}

	//----------------------------------
	//  piggybackingEnabled
	//----------------------------------
	private var _piggybackingEnabled:Bool;

	private var internalPiggybackingEnabled(get, set):Bool;

	private function get_internalPiggybackingEnabled():Bool {
		return _piggybackingEnabled;
	}

	private function set_internalPiggybackingEnabled(value:Bool):Bool {
		_piggybackingEnabled = value;
		return _piggybackingEnabled;
	}

	//----------------------------------
	//  pollingEnabled
	//----------------------------------
	private var _pollingEnabled:Bool;

	private var internalPollingEnabled(get, set):Bool;

	private function get_internalPollingEnabled():Bool {
		return _pollingEnabled;
	}

	private function set_internalPollingEnabled(value:Bool):Bool {
		_pollingEnabled = value;
		// If the value is false, we want to stop polling only if the timer is
		// definitely running OR the timer isn't running and the polling interval is 0
		// because if the polling interval is 0 and we're polling, the timer isn't on
		// anyway, so we need to include both cases.
		if (!value && (timerRunning || (!timerRunning && (_pollingInterval == 0)))) {
			stopPolling();
		} else if (value && _shouldPoll && !timerRunning) {
			startPolling();
		}
		return _pollingEnabled;
	}

	//----------------------------------
	//  pollingInterval
	//----------------------------------
	private var internalPollingInterval(get, set):Float;

	private function get_internalPollingInterval():Float {
		return (_timer == null) ? 0 : _pollingInterval;
	}

	private function set_internalPollingInterval(value:Float):Float {
		// We have to be careful here because the timer's delay cannot be set to
		// 0 so if we are setting the polling interval to 0, we need to stop the
		// timer AND hold onto the value in the _pollingInterval variable.
		if (value == 0) {
			_pollingInterval = value;

			if (_timer != null) {
				_timer.stop();
			}
			if (_shouldPoll) {
				startPolling();
			}
		} else if (value > 0) {
			if (_timer != null) {
				_timer.delay = _pollingInterval = value;
				if (!timerRunning && _shouldPoll) {
					startPolling();
				}
			}
		} else {
			var message:String = "Channel pollingInterval may only be set to a positive value.";
			throw new ArgumentError(message);
		}
		return (_timer == null) ? 0 : _pollingInterval;
	}

	//----------------------------------
	//  realtime
	//----------------------------------

	/**
		Returns true if the channel supports realtime behavior via server push or client poll.
		Piggybacking does not qualify as real time because no data will arrive from the server
		without a message being explicitly sent by the client.
	**/
	override private function get_realtime():Bool {
		return _pollingEnabled;
	}

	//----------------------------------
	//  timerRunning
	//----------------------------------
	private var timerRunning(get, never):Bool;

	private function get_timerRunning():Bool {
		return (_timer != null) && _timer.running;
	}

	//--------------------------------------------------------------------------
	//
	// Overridden Public Methods
	//
	//--------------------------------------------------------------------------

	/**
		Sends the specified message to its target destination.
		Subclasses must override the `internalSend()` method to
		perform the actual send.
		`PollingChannel` will wrap outbound messages in poll requests if a poll
		is not currently outstanding.

		@param agent The MessageAgent that is sending the message.

		@param message The Message to send.

		@throws mx.messaging.errors.InvalidDestinationError If neither the MessageAgent nor the
		message specify a destination.
	**/
	override public function send(agent:MessageAgent, message:IMessage):Void {
		var piggyback:Bool = false;
		if (!pollOutstanding && _piggybackingEnabled && !(message is CommandMessage)) {
			if (_shouldPoll) {
				piggyback = true;
			} else {
				var consumerDispatcher:ConsumerMessageDispatcher = ConsumerMessageDispatcher.getInstance();
				if (consumerDispatcher.isChannelUsedForSubscriptions(this))
					piggyback = true;
			}
		}
		if (piggyback)
			internalPoll();

		super.send(agent, message);

		if (piggyback) {
			// Manually build and send a terminal poll message to return any pushed messages
			// that may result from the sent message above. Invoking internalPoll() again would
			// be a no-op because we now have the initial poll outstanding.
			var msg:CommandMessage = new CommandMessage();
			msg.operation = CommandMessage.POLL_OPERATION;

			// if (Log.isDebug())
			// 	_log.debug("'{0}' channel sending poll message\n{1}\n", id, msg.toString());

			try {
				internalSend(new PollCommandMessageResponder(null, msg, this, _log));
			} catch (e:Error) {
				// If there was a problem stop polling.
				stopPolling();
				throw e;
			}
		}
	}

	//--------------------------------------------------------------------------
	//
	// Overridden Protected Methods
	//
	//--------------------------------------------------------------------------

	/**
		This method prevents polling from continuing when the Channel can not connect.

		@param event The ChannelFaultEvent.
	**/
	override private function connectFailed(event:ChannelFaultEvent):Void {
		stopPolling();
		super.connectFailed(event);
	}

	/**
		If a consumer sends a subscribe message to the server, we need to
		track that polling should occur.  In addition, we don't however, want
		to begin polling before we actually receive the acknowledgement that
		we have successfully subscribed.  This method is used to return a
		special message handler that will notify us when we have a successful
		subscribe and can safely begin polling.  This case is the reverse for
		unsubscribe, we need to track that we successfully unsubscribed and
		there are no more consumers attached that need polling.

		In addition to handling this case, this method also returns a special
		responder to handle the results or fault for a poll request.

		@param agent MessageAgent that requested the message be sent.
		@param msg Message to be sent.

		@return A PollSyncMessageResponder for subscribe/unsubscriber requests or a
		PollCommandMessageResponder for poll requests; otherwise the default
		message responder.
	**/
	final override private function getMessageResponder(agent:MessageAgent, msg:IMessage):MessageResponder {
		if ((msg is CommandMessage) && (cast(msg, CommandMessage).operation == CommandMessage.POLL_OPERATION)) {
			return new PollCommandMessageResponder(agent, msg, this, _log);
		}
		return getDefaultMessageResponder(agent, msg);
	}

	/**
		Disconnects from the remote destination.
	**/
	override private function internalDisconnect(rejected:Bool = false):Void {
		stopPolling();
		super.internalDisconnect(rejected);
	}

	//--------------------------------------------------------------------------
	//
	// Methods
	//
	//--------------------------------------------------------------------------

	/**
		Enables polling based on the number of times `enablePolling()`
		and `disablePolling()` have been invoked. If the net result is to enable
		polling the channel will poll the server on behalf of connected MessageAgents.

		Invoked automatically based upon subscribing or unsubscribing from a remote
		destination over a PollingChannel.
	**/
	public function enablePolling():Void {
		_pollingRef++;
		if (_pollingRef == 0)
			startPolling();
	}

	/**
		Disables polling based on the number of times `enablePolling()`
		and `disablePolling()` have been invoked. If the net result is to disable
		polling the channel stops polling.

		Invoked automatically based upon subscribing or unsubscribing from a remote
		destination over a PollingChannel.
	**/
	public function disablePolling():Void {
		_pollingRef--;
		if (_pollingRef < 0)
			stopPolling();
	}

	/**
		Initiates a poll operation if there are consumers subscribed to this channel, 
		and polling is enabled for this channel.

		Note that this method will not start a new poll if one is currently in progress.
	**/
	public function poll():Void {
		internalPoll();
	}

	//--------------------------------------------------------------------------
	//
	// Internal Methods
	//
	//--------------------------------------------------------------------------

	/**
		This method allows a PollCommandMessageResponder to indicate that the 
		channel has lost its connectivity.

		@param rejected Channel will be rejected and will not attempt to reconnect if 
		this flag is true
	**/
	private function pollFailed(rejected:Bool = false):Void {
		internalDisconnect(rejected);
	}

	/**
		This method is invoked automatically when `disablePolling()`
		is called and it results in a net negative number of requests to poll.

		mx_internal to allow the poll responder to shut down polling if a general,
		fatal error occurs.
	**/
	private function stopPolling():Void {
		// if (Log.isInfo())
		// 	_log.info("'{0}' channel polling stopped.", id);

		if (_timer != null)
			_timer.stop();

		_pollingRef = -1;
		_shouldPoll = false;
		pollOutstanding = false;
	}

	//--------------------------------------------------------------------------
	//
	// Protected Methods
	//
	//--------------------------------------------------------------------------

	/**
		Processes polling related configuration settings.

		@param settings The Channel settings.
	**/
	private function applyPollingSettings(settings:Xml):Void {
		for (props in settings.elementsNamed("properties")) {
			for (enabled in props.elementsNamed(POLLING_ENABLED)) {
				internalPollingEnabled = enabled.nodeValue == Channel.TRUE;
			}
			for (millis in props.elementsNamed(POLLING_INTERVAL_LEGACY)) {
				internalPollingInterval = Std.parseInt(Std.string(millis.nodeValue)) * 1000;
			}
			for (millis in props.elementsNamed(POLLING_INTERVAL_MILLIS)) {
				internalPollingInterval = Std.parseInt(Std.string(millis.nodeValue));
			}
			for (enabled in props.elementsNamed(PIGGYBACKING_ENABLED)) {
				internalPiggybackingEnabled = enabled.nodeValue == Channel.TRUE;
			}
			for (login in props.elementsNamed(LOGIN_AFTER_DISCONNECT)) {
				_loginAfterDisconnect = login.nodeValue == Channel.TRUE;
			}
			break;
		}
	}

	private function getDefaultMessageResponder(agent:MessageAgent, msg:IMessage):MessageResponder {
		return super.getMessageResponder(agent, msg);
	}

	/**
		Requests the server return any messages queued since the last poll request for this FlexClient.

		@param event Event dispatched by the polling Timer.
	**/
	private function internalPoll(event:Event = null):Void {
		if (!pollOutstanding) {
			// if (Log.isInfo())
			// 	_log.info("'{0}' channel requesting queued messages.", id);

			// If this poll is triggered via a direct invocation make sure no
			// concurrent poll Timer is running.
			if (timerRunning)
				_timer.stop();

			var poll:CommandMessage = new CommandMessage();
			poll.operation = CommandMessage.POLL_OPERATION;
			// Pass a null clientId - this indicates that we're polling for
			// any subscriptions for this client as opposed to receive()'ing
			// messages for a single Consumer instance subscribed to a specific destination.
			// if (Log.isDebug())
			// 	_log.debug("'{0}' channel sending poll message\n{1}\n", id, poll.toString());

			try {
				internalSend(new PollCommandMessageResponder(null, poll, this, _log));
				pollOutstanding = true;
			} catch (e:Error) {
				// If there was a problem stop polling.
				stopPolling();
				throw e;
			}
		} else {
			// if (Log.isInfo())
			// 	_log.info("'{0}' channel waiting for poll response.", id);
		}
	}

	/**
		This method is invoked automatically when `enablePolling()`
		is called and it results in net positive number of requests to poll.
	**/
	private function startPolling():Void {
		if (_pollingEnabled) {
			// if (Log.isInfo())
			// 	_log.info("'{0}' channel polling started.", id);

			_shouldPoll = true;

			poll(); // Poll immediately. Once a result is returned we schedule the next poll invocation.
		}
		// If polling is not enabled, this is a no-op.
	}

	/**
		Returns true if this channel requires a timer for polling.
	**/
	private function timerRequired():Bool {
		return true;
	}

	//--------------------------------------------------------------------------
	//
	// Static Constants
	//
	//--------------------------------------------------------------------------

	/**
		Define the default Polling Interval as 3000ms
	**/
	private static final DEFAULT_POLLING_INTERVAL:Int = 3000;
}

/**
	Used internally to dispatch a batched set of messages returned in the poll
	command message.
**/
@:access(feathers.messaging.channels.PollingChannel)
private class PollCommandMessageResponder extends MessageResponder {
	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Initializes an instance of the message responder that handles
		multiple messages received from a poll request that a Channel makes.

		@param channel PollingChannel.
	**/
	public function new(agent:MessageAgent, msg:IMessage, channel:PollingChannel, log:Any /*ILogger*/) {
		super(agent, msg, channel);
		// _log = log;

		// Track channel connected state.
		// If the channel disconnects while this poll is outstanding, suppress result/fault handling.
		// channel.addEventListener(PropertyChangeEvent.PROPERTY_CHANGE, channelPropertyChangeHandler);
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/**
		Reference to the logger for the associated Channel.
	**/
	private var _log:Any /*ILogger*/;

	private var suppressHandlers:Bool;

	//--------------------------------------------------------------------------
	//
	// Overridden Protected Methods
	//
	//--------------------------------------------------------------------------

	/**
		Handles a poll command result from the server which is either an empty acknowledgement
		if there were no messages to deliver or a response containing a list of messages to 
		dispatch in its body.

		@param msg The result message.
	**/
	override private function resultHandler(msg:IMessage):Void {
		var pollingChannel:PollingChannel = cast(channel, PollingChannel);
		// channel.removeEventListener(PropertyChangeEvent.PROPERTY_CHANGE, channelPropertyChangeHandler);

		if (suppressHandlers) {
			// if (Log.isDebug()) {
			// 	_log.debug("'{0}' channel ignoring response for poll request preceeding most recent disconnect.\n", channel.id);
			// }

			doPoll(); // If the channel has reconnected we may need to start up the polling loop again.
			return;
		}

		if ((msg is CommandMessage)) // Poll response containing pushed messages.
		{
			pollingChannel.pollOutstanding = false;

			// Return early if the response is tagged as a no-op poll.
			if (Reflect.field(msg.headers, CommandMessage.NO_OP_POLL_HEADER) == true)
				return;

			if (msg.body != null) {
				var messageList:Array<IMessage> = msg.body;
				for (message in messageList) {
					// if (Log.isDebug())
					// {
					// 	_log.debug("'{0}' channel got message\n{1}\n", channel.id, message.toString());
					// 	if (channel.mpiEnabled)
					// 	{
					// 		try
					// 		{
					// 			var mpiutil:MessagePerformanceUtils = new MessagePerformanceUtils(message);
					// 			_log.debug(mpiutil.prettyPrint());
					// 		}
					// 		catch (e:Error)
					// 		{
					// 			_log.debug("Could not get message performance information for: " + msg.toString());
					// 		}
					// 	}
					// }
					channel.dispatchEvent(MessageEvent.createEvent(MessageEvent.MESSAGE, message));
				}
			}
		} else if ((msg is AcknowledgeMessage)) // Empty response (no messages to push).
		{
			pollingChannel.pollOutstanding = false;
			// The server returns an empty ack if there are no messages to return.
			// We don't need to do anything here.
		} else // Generally, the result of a connection failure while the poll was on the network.
		{
			var errMsg:ErrorMessage = new ErrorMessage();
			errMsg.faultDetail = "Received null.";
			status(errMsg);
			return;
		}

		// If no errors, continue the polling interval.
		if (Reflect.field(msg.headers, CommandMessage.POLL_WAIT_HEADER) != null) {
			doPoll(Reflect.field(msg.headers, CommandMessage.POLL_WAIT_HEADER));
		} else {
			doPoll();
		}
	}

	/**
		Handles a fault while attempting to poll.

		@param msg The ErrorMessage from the remote destination.
	**/
	override private function statusHandler(msg:IMessage):Void {
		// channel.removeEventListener(PropertyChangeEvent.PROPERTY_CHANGE, channelPropertyChangeHandler);

		if (suppressHandlers) {
			// if (Log.isDebug()) {
			// 	_log.debug("'{0}' channel ignoring response for poll request preceeding most recent disconnect.\n", channel.id);
			// }

			return;
		}

		var pollingChannel:PollingChannel = cast(channel, PollingChannel);
		pollingChannel.stopPolling(); // Shut down all polling.
		var errMsg:ErrorMessage = Std.downcast(msg, ErrorMessage);
		var details:String = (errMsg != null) ? errMsg.faultDetail : "";
		var faultEvent:ChannelFaultEvent = ChannelFaultEvent.createEvent(pollingChannel, false, "Channel.Polling.Error", "error", details);
		faultEvent.rootCause = msg;
		pollingChannel.dispatchEvent(faultEvent);

		// Reject this channel if the server does not support polling
		if (errMsg != null && errMsg.faultCode == "Server.PollNotSupported") {
			pollingChannel.pollFailed(true);
		} else {
			pollingChannel.pollFailed(false);
		}
	}

	/**
		Watch for 'connected' property change and in the event of a disconnect,
		suppress poll result/fault handling.

		@param event A PropertyChangeEvent dispatched by the underlying channel.
	**/
	private function channelPropertyChangeHandler(event:Event /*PropertyChangeEvent*/):Void {
		throw new Error("Not implemented");
		// if (event.property == "connected" && !event.newValue) {
		// 	suppressHandlers = true;
		// }
	}

	/**
		Helper method to run or schedule the next poll for the underlying channel.

		@param adaptivePollWait The optional wait time before the next poll should be issued.
	**/
	private function doPoll(adaptivePollWait:Int = 0):Void {
		var pollingChannel:PollingChannel = cast(channel, PollingChannel);
		// Only set up the next poll if the channel is still connected.
		// Subscription invalidation commands pushed by the server can cause the channel to disconnect
		// and it shouldn't issue another poll request in this case.
		// Also, if the channel is piggybacking but not polling on an interval we don't want to
		// schedule the next poll.
		if (pollingChannel.connected && pollingChannel._shouldPoll) {
			// An adaptive polling value of 0 indicates that the channel should use its default
			// polling interval.
			if (adaptivePollWait == 0) {
				if (pollingChannel.internalPollingInterval == 0) {
					// No need for a Timer at all if we're polling immediately.
					pollingChannel.poll();
				} else if (!pollingChannel.timerRunning) {
					// Poll at the base rate for this Channel; no adaptive poll wait is defined.
					pollingChannel._timer.delay = pollingChannel._pollingInterval;
					pollingChannel._timer.start();
				}
			} else {
				// Use adaptive poll wait.
				pollingChannel._timer.delay = adaptivePollWait;
				pollingChannel._timer.start();
			}
		}
	}
}
