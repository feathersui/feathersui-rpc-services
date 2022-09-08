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

import openfl.utils.ByteArray;
import haxe.crypto.Base64;
import feathers.data.ArrayCollection;
import feathers.messaging.channels.PollingChannel;
import feathers.messaging.config.ServerConfig;
import feathers.messaging.errors.NoChannelAvailableError;
import feathers.messaging.events.ChannelEvent;
import feathers.messaging.events.ChannelFaultEvent;
import feathers.messaging.events.MessageEvent;
import feathers.messaging.events.MessageFaultEvent;
import feathers.messaging.messages.AcknowledgeMessage;
import feathers.messaging.messages.CommandMessage;
import feathers.messaging.messages.ErrorMessage;
import feathers.messaging.messages.IMessage;
import feathers.rpc.AsyncDispatcher;
import feathers.rpc.AsyncToken;
import feathers.rpc.events.AbstractEvent;
import feathers.rpc.events.FaultEvent;
import feathers.rpc.events.ResultEvent;
import openfl.errors.Error;
import openfl.errors.IllegalOperationError;
import openfl.events.EventDispatcher;
import openfl.events.TimerEvent;
import openfl.utils.Timer;
import feathers.messaging.channels.NetConnectionChannel;

/**
	The ChannelSet is a set of Channels that are used to send messages to a
	target destination. The ChannelSet improves the quality of service on the
	client by hunting through its Channels to send messages in the face of
	network failures or individual Channel problems.
**/
@:access(feathers.messaging.Channel)
@:access(feathers.messaging.MessageAgent)
@:access(feathers.rpc.events.AbstractEvent)
class ChannelSet extends EventDispatcher {
	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructs a ChannelSet.
		If the `channelIds` argument is provided, the ChannelSet will
		use automatically configured Channels obtained via `ServerConfig.getChannel()`
		to reach a destination.
		Attempting to manually assign Channels to a ChannelSet that uses configured
		Channels is not allowed.

		If the `channelIds` argument is not provided or is null,
		Channels must be manually created and added to the ChannelSet in order
		to connect and send messages.

		If the ChannelSet is clustered using url-load-balancing (where each server
		declares a unique RTMP or HTTP URL and the client fails over from one URL to
		the next), the first time that a Channel in the ChannelSet successfully connects
		the ChannelSet will automatically make a request for all of the endpoints across
		the cluster for all member Channels and will assign these failover URLs to each
		respective Channel.
		This allows Channels in the ChannelSet to failover individually, and when failover
		options for a specific Channel are exhausted the ChannelSet will advance to the next
		Channel in the set to attempt to reconnect.

		Regardless of clustering, if a Channel cannot connect or looses
		connectivity, the ChannelSet will advance to its next available Channel
		and attempt to reconnect.
		This allows the ChannelSet to hunt through Channels that use different
		protocols, ports, etc., in search of one that can connect to its endpoint
		successfully.

		@param channelIds The ids of configured Channels obtained from ServerConfig for this ChannelSet to
		use. If null, Channels must be manually added to the ChannelSet.

		@param clusteredWithURLLoadBalancing True if the Channels in the ChannelSet are clustered
		using url load balancing.
	**/
	public function new(channelIds:Array<String> = null, clusteredWithURLLoadBalancing:Bool = false) {
		super();
		_clustered = clusteredWithURLLoadBalancing;
		_connected = false;
		_connecting = false;
		_currentChannelIndex = -1;
		if (channelIds != null) {
			_channelIds = channelIds;
			_channels = [];
			_channels.resize(_channelIds.length);
			_configured = true;
		} else {
			_channels = [];
			_configured = false;
		}
		_hasRequestedClusterEndpoints = false;
		_hunting = false;
		_messageAgents = [];
		_pendingMessages = [];
		_pendingSends = [];
		_shouldBeConnected = false;
		_shouldHunt = true;
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/**
		Helper MessageAgent used for direct authentication.
	**/
	private var _authAgent:AuthenticationAgent;

	/**
		Flag indicating whether the ChannelSet is in the process of connecting
		over the current Channel.
	**/
	private var _connecting:Bool;

	/**
		Stored credentials to be set on the member channels.
	**/
	private var _credentials:String;

	/**
		The character-set encoding used to create the credentials String.
	**/
	private var _credentialsCharset:String;

	/**
		Current index into the _channels/_channelIds arrays.
	**/
	private var _currentChannelIndex:Int;

	/**
		This flag restricts our cluster request to only happen upon initial
		connect to the cluster.
	**/
	private var _hasRequestedClusterEndpoints:Bool;

	/**
		Timer used to issue periodic heartbeats to the remote host if the
		client is idle, and not actively sending messages.
	**/
	private var _heartbeatTimer:Timer;

	/**
		Flag indicating whether the ChannelSet is in the process of hunting to a
		new Channel; this lets us control the "reconnecting" flag on
		CONNECT ChannelEvents that we dispatch when we hunt to a new
		Channel that isn't internally failing over. The new Channel doesn't know we're
		in a reconnect attempt when it makes its initial connect attempt so this lets
		us set "reconnecting" to true on the CONNECT event if it succeeds.
	**/
	private var _hunting:Bool;

	/**
		A dictionary of pending messages used to filter out duplicate
		messages passed to the ChannelSet to send while it is not connected.
		This allows agents to perform message resend behavior (i.e. Consumer resubscribe
		attempts) without worrying about duplicate messages queuing up and being sent to
		the server once a connection is established.
	**/
	private var _pendingMessages:Map<IMessage, Bool>;

	/**
		An array of PendingSend instances to pass into send() when a connection
		is (re)established.
	**/
	private var _pendingSends:Array<PendingSend>;

	/**
		A timer used to do a delayed reconnect for NetConnection channels.
	**/
	private var _reconnectTimer:Timer = null;

	/**
		Flag indicating whether the ChannelSet should be connected.
		If true, the ChannelSet will attempt to hunt to the next available
		Channel when a disconnect or fault occurs. If false, hunting is not
		performed.
	**/
	private var _shouldBeConnected:Bool;

	/**
		Flag indicating whether a Channel disconnect/fault should trigger hunting or not;
		used when connected Channels are removed from the ChannelSet which should not trigger
		hunting.
	**/
	private var _shouldHunt:Bool;

	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  authenticated
	//----------------------------------
	private var _authenticated:Bool;

	// [Bindable(event="propertyChange")]

	/**
		Indicates whether the ChannelSet has an underlying Channel that successfully
		authenticated with its endpoint.
	**/
	@:flash.property
	public var authenticated(get, never):Bool;

	private function get_authenticated():Bool {
		return _authenticated;
	}

	private function setAuthenticated(value:Bool, creds:String, notifyAgents:Bool = true):Void {
		if (_authenticated != value) {
			// var event:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "authenticated", _authenticated, value);
			_authenticated = value;

			if (notifyAgents) {
				var ma:MessageAgent;
				for (i in 0..._messageAgents.length) {
					ma = _messageAgents[i];
					ma.setAuthenticated(value, creds);
				}
			}

			if (!value && _authAgent != null)
				_authAgent.state = AuthenticationAgent.LOGGED_OUT_STATE;

			// dispatchEvent(event);
		}
	}

	//----------------------------------
	//  channels
	//----------------------------------
	private var _channels:Array<Channel>;

	/**
		Provides access to the Channels in the ChannelSet.
		This property may be used to assign a set of channels at once or channels
		may be added directly to the ChannelSet via addChannel() individually.
		If this ChannelSet is `configured` automatically the individual
		channels are created lazily and added to this property as needed.

		@throws flash.errors.IllegalOperationError If the ChannelSet is
		`configured`, assigning to this property is not allowed.
	**/
	@:flash.property
	public var channels(get, set):Array<Channel>;

	private function get_channels():Array<Channel> {
		return _channels;
	}

	// [ArrayElementType("mx.messaging.Channel")]

	private function set_channels(values:Array<Channel>):Array<Channel> {
		if (configured) {
			throw new IllegalOperationError("Channels cannot be added to a ChannelSet that targets a configured destination.");
		}

		// Remove existing channels
		var channelsToRemove = _channels.copy();
		var n:Int = channelsToRemove.length;
		for (i in 0...n) {
			removeChannel(channelsToRemove[i]);
		}

		// Add new channels
		if (values != null && values.length > 0) {
			var m:Int = values.length;
			for (j in 0...m) {
				addChannel(values[j]);
			}
		}
		return _channels;
	}

	//----------------------------------
	//  channelIds
	//----------------------------------
	private var _channelIds:Array<String>;

	/**
		The ids of the Channels used by the ChannelSet.
	**/
	@:flash.property
	public var channelIds(get, never):Array<String>;

	private function get_channelIds():Array<String> {
		if (_channelIds != null) {
			return _channelIds;
		} else {
			var ids:Array<String> = [];
			var n:Int = _channels.length;
			for (i in 0...n) {
				if (_channels[i] != null)
					ids.push(_channels[i].id);
				else
					ids.push(null);
			}
			return ids;
		}
	}

	//----------------------------------
	//  currentChannel
	//----------------------------------
	private var _currentChannel:Channel;

	/**
		Returns the current Channel for the ChannelSet.
	**/
	@:flash.property
	public var currentChannel(get, never):Channel;

	private function get_currentChannel():Channel {
		return _currentChannel;
	}

	//----------------------------------
	//  channelFailoverURIs
	//----------------------------------
	private var _channelFailoverURIs:Map<String, Array<String>>;

	/**
		Map of arrays of failoverURIs keyed by channel id for the Channels in this ChannelSet.
		This property is assigned to by the ClusterMessageResponder in order to update the
		member Channels with their failoverURIs.
	**/
	private var channelFailoverURIs(get, set):Map<String, Array<String>>;

	private function get_channelFailoverURIs():Map<String, Array<String>> {
		return _channelFailoverURIs;
	}

	private function set_channelFailoverURIs(value:Map<String, Array<String>>):Map<String, Array<String>> {
		_channelFailoverURIs = value;
		// Update any existing Channels in the set with their current failover endpoint URIs.
		var n:Int = _channels.length;
		for (i in 0...n) {
			var channel:Channel = _channels[i];
			if (channel == null) {
				break; // The rest of the Channels have not been loaded yet.
			} else if (_channelFailoverURIs[channel.id] != null) {
				channel.failoverURIs = _channelFailoverURIs[channel.id];
			}
		}
		return _channelFailoverURIs;
	}

	//----------------------------------
	//  configured
	//----------------------------------
	private var _configured:Bool;

	/**
		Indicates whether the ChannelSet is using automatically configured
		Channels or manually assigned Channels.
	**/
	private var configured(get, never):Bool;

	private function get_configured():Bool {
		return _configured;
	}

	//----------------------------------
	//  connected
	//----------------------------------
	private var _connected:Bool;

	// [Bindable(event="propertyChange")]

	/**
		Indicates whether the ChannelSet is connected.
	**/
	@:flash.property
	public var connected(get, never):Bool;

	private function get_connected():Bool {
		return _connected;
	}

	private function setConnected(value:Bool):Void {
		if (_connected != value) {
			// var event:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "connected", _connected, value)
			_connected = value;
			// dispatchEvent(event);
			setAuthenticated(value && currentChannel != null && currentChannel.authenticated, _credentials,
				false /* Agents also listen for channel disconnects */);
			if (!connected) {
				unscheduleHeartbeat();
			} else if (heartbeatInterval > 0) {
				scheduleHeartbeat();
			}
		}
	}

	//----------------------------------
	//  clustered
	//----------------------------------
	private var _clustered:Bool;

	/**
		Indicates whether the ChannelSet targets a clustered destination.
		If true, upon a successful connection the ChannelSet will query the
		destination for all clustered endpoints for its Channels and will assign
		failoverURIs to them.
		Channel ids are used to assign failoverURIs to the proper Channel instances
		so this requires that all Channels in the ChannelSet have non-null ids and an
		Error will be thrown when this property is set to true if this is not the case.
		If the ChannelSet is not using url load balancing on the client this
		property should not be set to true.
	**/
	@:flash.property
	public var clustered(get, set):Bool;

	private function get_clustered():Bool {
		return _clustered;
	}

	private function set_clustered(value:Bool):Bool {
		if (_clustered != value) {
			if (value) {
				// Cannot have a clustered ChannelSet that contains Channels with null ids.
				var ids:Array<String> = channelIds;
				var n:Int = ids.length;
				for (i in 0...n) {
					if (ids[i] == null) {
						throw new IllegalOperationError("Cannot change clustered property of ChannelSet to true when it contains channels with null ids. ");
					}
				}
			}
			_clustered = value;
		}
		return _clustered;
	}

	//----------------------------------
	//  heartbeatInterval
	//----------------------------------
	private var _heartbeatInterval:Int = 0;

	/**
		The number of milliseconds between heartbeats sent to the remote
		host while this ChannelSet is actively connected but idle.
		Any outbound message traffic will delay heartbeats temporarily, with
		this number of milliseconds elapsing after the last sent message before
		the next heartbeat is issued.

		This property is useful for applications that connect to a remote host
		to received pushed updates and are not actively sending any messages, but
		still wish to be notified of a dropped connection even when the networking
		layer fails to provide such notification directly. By issuing periodic
		heartbeats the client can force the networking layer to report a timeout
		if the underlying connection has dropped without notification and the
		application can respond to the disconnect appropriately.

		Any non-positive value disables heartbeats to the remote host.
		The default value is 0 indicating that heartbeats are disabled.
		If the application sets this value it should prefer a longer rather than
		shorter interval, to avoid placing unnecessary load on the remote host.
		As an illustrative example, low-level TCP socket keep-alives generally
		default to an interval of 2 hours. That is a longer interval than most
		applications that enable heartbeats will likely want to use, but it
		serves as a clear precedent to prefer a longer interval over a shorter
		interval.

		If the currently connected underlying Channel issues poll requests to
		the remote host, heartbeats are suppressed because the periodic poll
		requests effectively take their place.
	**/
	@:flash.property
	public var heartbeatInterval(get, set):Int;

	private function get_heartbeatInterval():Int {
		return _heartbeatInterval;
	}

	private function set_heartbeatInterval(value:Int):Int {
		if (_heartbeatInterval != value) {
			// var event:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "heartbeatInterval", _heartbeatInterval, value);
			_heartbeatInterval = value;
			// dispatchEvent(event);
			if (_heartbeatInterval > 0 && connected) {
				scheduleHeartbeat();
			}
		}
		return _heartbeatInterval;
	}

	//----------------------------------
	//  initialDestinationId
	//----------------------------------
	private var _initialDestinationId:String;

	/**
		Provides access to the initial destination this ChannelSet is used to access.
		When the clustered property is true, this value is used to request available failover URIs
		for the configured channels for the destination.
	**/
	@:flash.property
	public var initialDestinationId(get, set):String;

	private function get_initialDestinationId():String {
		return _initialDestinationId;
	}

	private function set_initialDestinationId(value:String):String {
		_initialDestinationId = value;
		return _initialDestinationId;
	}

	//----------------------------------
	//  messageAgents
	//----------------------------------
	private var _messageAgents:Array<MessageAgent>;

	/**
		Provides access to the set of MessageAgents that use this ChannelSet.
	**/
	@:flash.property
	public var messageAgents(get, never):Array<MessageAgent>;

	private function get_messageAgents():Array<MessageAgent> {
		return _messageAgents;
	}

	//--------------------------------------------------------------------------
	//
	// Overridden Methods
	//
	//--------------------------------------------------------------------------

	/**
		Returns a String containing the ids of the Channels in the ChannelSet.

		@return String representation of the ChannelSet.
	**/
	override public function toString():String {
		var s:String = "[ChannelSet ";
		for (i in 0..._channels.length) {
			if (_channels[i] != null)
				s += _channels[i].id + " ";
		}
		s += "]";
		return s;
	}

	//--------------------------------------------------------------------------
	//
	// Methods
	//
	//--------------------------------------------------------------------------

	/**
		Adds a Channel to the ChannelSet. A Channel with a null id cannot be added
		to the ChannelSet if the ChannelSet targets a clustered destination.

		@param channel The Channel to add.

		@throws flash.errors.IllegalOperationError If the ChannelSet is
		`configured`, adding a Channel is not supported.
		This error is also thrown if the ChannelSet's `clustered` property
		is `true` but the Channel has a null id.
	**/
	public function addChannel(channel:Channel):Void {
		if (channel == null)
			return;

		if (configured) {
			throw new IllegalOperationError("Channels cannot be added to a ChannelSet that targets a configured destination.");
		}

		if (clustered && channel.id == null) {
			throw new IllegalOperationError("Cannot add a channel with null id to ChannelSet when its clustered property is true.");
		}

		if (_channels.indexOf(channel) != -1)
			return; // Channel already exists in the set.

		_channels.push(channel);
		if (_credentials != null && _credentials.length > 0)
			channel.setCredentials(_credentials, null, _credentialsCharset);
	}

	/**
		Removes a Channel from the ChannelSet. If the Channel to remove is
		currently connected and being used by the ChannelSet, it is
		disconnected as well as removed.

		@param channel The Channel to remove.

		@throws flash.errors.IllegalOperationError If the ChannelSet is
		`configured`, removing a Channel is not supported.
	**/
	public function removeChannel(channel:Channel):Void {
		if (configured) {
			throw new IllegalOperationError("Channels cannot be removed from a ChannelSet that targets a configured destination.");
		}

		var channelIndex:Int = _channels.indexOf(channel);
		if (channelIndex > -1) {
			_channels.splice(channelIndex, 1);
			// If the Channel being removed is currently in use, we need
			// to null it out for re-hunting, and potentially disconnect it.
			if ((_currentChannel != null) && (_currentChannel == channel)) {
				if (connected) {
					_shouldHunt = false;
					disconnectChannel();
				}
				_currentChannel = null;
				_currentChannelIndex = -1;
			}
		}
	}

	/**
		Connects a MessageAgent to the ChannelSet. Once connected, the agent
		can use the ChannelSet to send messages.

		@param agent The MessageAgent to connect.
	**/
	public function connect(agent:MessageAgent):Void {
		if ((agent != null) && (_messageAgents.indexOf(agent) == -1)) {
			_shouldBeConnected = true;
			_messageAgents.push(agent);
			agent.internalSetChannelSet(this);
			// Wire up agent's channel event listeners to this ChannelSet.
			addEventListener(ChannelEvent.CONNECT, agent.channelConnectHandler);
			addEventListener(ChannelEvent.DISCONNECT, agent.channelDisconnectHandler);
			addEventListener(ChannelFaultEvent.FAULT, agent.channelFaultHandler);

			// If the ChannelSet is already connected, notify the agent.
			if (connected && !agent.needsConfig)
				agent.channelConnectHandler(ChannelEvent.createEvent(ChannelEvent.CONNECT, _currentChannel, false, false, connected));
		}
	}

	/**
		Disconnects a specific MessageAgent from the ChannelSet. If this is the
		last MessageAgent using the ChannelSet and the current Channel in the set is
		connected, the Channel will physically disconnect from the server.

		@param agent The MessageAgent to disconnect.
	**/
	public function disconnect(agent:MessageAgent):Void {
		if (agent == null) // Disconnect the ChannelSet completely.
		{
			var allMessageAgents:Array<MessageAgent> = _messageAgents.copy();
			var n:Int = allMessageAgents.length;
			for (i in 0...n) {
				allMessageAgents[i].disconnect();
			}
			if (_authAgent != null) {
				_authAgent.state = AuthenticationAgent.SHUTDOWN_STATE;
				_authAgent = null;
			}
		} else // Disconnect a specific MessageAgent.
		{
			var agentIndex:Int = agent != null ? _messageAgents.indexOf(agent) : -1;
			if (agentIndex != -1) {
				_messageAgents.splice(agentIndex, 1);
				// Remove the agent as a listener to this ChannelSet.
				removeEventListener(ChannelEvent.CONNECT, agent.channelConnectHandler);
				removeEventListener(ChannelEvent.DISCONNECT, agent.channelDisconnectHandler);
				removeEventListener(ChannelFaultEvent.FAULT, agent.channelFaultHandler);

				if (connected || _connecting) // Notify the agent of the disconnect.
				{
					agent.channelDisconnectHandler(ChannelEvent.createEvent(ChannelEvent.DISCONNECT, _currentChannel, false));
				} else // Remove any pending sends for this agent.
				{
					var n2:Int = _pendingSends.length;
					var j:Int = 0;
					while (j < n2) {
						var ps:PendingSend = _pendingSends[j];
						if (ps.agent == agent) {
							_pendingSends.splice(j, 1);
							j--;
							n2--;
							_pendingMessages.remove(ps.message);
						}
						j++;
					}
				}
				// Shut down the underlying Channel connection if this ChannelSet has
				// no more agents using it.
				if (_messageAgents.length == 0) {
					_shouldBeConnected = false;
					_currentChannelIndex = -1;
					if (connected)
						disconnectChannel();
				}

				// Null out automatically assigned ChannelSet on agent; if manually assigned leave it alone.
				if (agent.channelSetMode == MessageAgent.AUTO_CONFIGURED_CHANNELSET)
					agent.internalSetChannelSet(null);
			}
		}
	}

	/**
		Disconnects all associated MessageAgents and disconnects any underlying Channel that
		is connected.
		Unlike `disconnect(MessageAgent)` which is invoked by the disconnect implementations
		of specific service components, this method provides a single, convenient point to shut down
		connectivity between the client and server.
	**/
	public function disconnectAll():Void {
		disconnect(null);
	}

	/**
		Handles a CONNECT ChannelEvent and redispatches the event.

		@param event The ChannelEvent.
	**/
	public function channelConnectHandler(event:ChannelEvent):Void {
		_connecting = false;
		_connected = true; // Set internally to allow us to send pending messages before dispatching the connect event.
		_currentChannelIndex = -1; // Reset index so that future disconnects are followed by hunting through all available options in order.

		// Send any pending messages.
		while (_pendingSends.length > 0) {
			var ps:PendingSend = _pendingSends.shift();
			_pendingMessages.remove(ps.message);

			var command:CommandMessage = Std.downcast(ps.message, CommandMessage);

			if (command != null) {
				// Filter out any commands to trigger connection establishment, and ack them locally.
				if (command.operation == CommandMessage.TRIGGER_CONNECT_OPERATION) {
					var ack:AcknowledgeMessage = new AcknowledgeMessage();
					ack.clientId = ps.agent.clientId;
					ack.correlationId = command.messageId;
					ps.agent.acknowledge(ack, command);
					continue;
				}

				if (!ps.agent.configRequested && ps.agent.needsConfig && (command.operation == CommandMessage.CLIENT_PING_OPERATION)) {
					Reflect.setField(command.headers, CommandMessage.NEEDS_CONFIG_HEADER, true);
					ps.agent.configRequested = true;
				}
			}

			send(ps.agent, ps.message);
		}

		if (_hunting) {
			event.reconnecting = true;
			_hunting = false;
		}

		// Redispatch Channel connect event.
		dispatchEvent(event);
		// Dispatch delayed "connected" property change event.
		// var connectedChangeEvent:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "connected", false, true);
		// dispatchEvent(connectedChangeEvent);
	}

	/**
		Handles a DISCONNECT ChannelEvent and redispatches the event.

		@param event The ChannelEvent.
	**/
	public function channelDisconnectHandler(event:ChannelEvent):Void {
		_connecting = false;
		setConnected(false);

		// If we should be connected and the Channel isn't failing over
		// internally and wasn't rejected, hunt and try to reconnect.
		if (_shouldBeConnected && !event.reconnecting && !event.rejected) {
			if (_shouldHunt && hunt()) {
				event.reconnecting = true;
				dispatchEvent(event);
				if ((_currentChannel is NetConnectionChannel)) {
					// Insert slight delay for reconnect to allow NetConnection
					// based channels to shut down and clean up in preparation
					// for our next connect attempt.
					if (_reconnectTimer == null) {
						_reconnectTimer = new Timer(1, 1);
						_reconnectTimer.addEventListener(TimerEvent.TIMER, reconnectChannel);
						_reconnectTimer.start();
					}
				} else // No need to wait with other channel types.
				{
					connectChannel();
				}
			} else // No more hunting options; give up and fault pending sends.
			{
				dispatchEvent(event);
				faultPendingSends(event);
			}
		} else {
			dispatchEvent(event);
			// If the underlying Channel was rejected, fault pending sends.
			if (event.rejected)
				faultPendingSends(event);
		}
		// Flip this back to true in case it was turned off by an explicit Channel removal
		// that triggered the current disconnect event.
		_shouldHunt = true;
	}

	/**
		Handles a ChannelFaultEvent and redispatches the event.

		@param event The ChannelFaultEvent.
	**/
	public function channelFaultHandler(event:ChannelFaultEvent):Void {
		if (event.channel.connected) {
			dispatchEvent(event);
		} else // The channel fault has resulted in disconnecting.
		{
			_connecting = false;
			setConnected(false);

			// If we should be connected and the Channel isn't failing over
			// internally, hunt and try to reconnect.
			if (_shouldBeConnected && !event.reconnecting && !event.rejected) {
				if (hunt()) {
					event.reconnecting = true;
					dispatchEvent(event);
					if ((_currentChannel is NetConnectionChannel)) {
						// Insert slight delay for reconnect to allow
						// NetConnection based channels to shut down and clean
						// up in preparation for our next connect attempt.
						if (_reconnectTimer == null) {
							_reconnectTimer = new Timer(1, 1);
							_reconnectTimer.addEventListener(TimerEvent.TIMER, reconnectChannel);
							_reconnectTimer.start();
						}
					} else // No need to wait with other channel types.
					{
						connectChannel();
					}
				} else // No more hunting options; give up and fault pending sends.
				{
					dispatchEvent(event);
					faultPendingSends(event);
				}
			} else {
				dispatchEvent(event);
				// If the underlying Channel was rejected, fault pending sends.
				if (event.rejected)
					faultPendingSends(event);
			}
		}
	}

	/**
		Authenticates the ChannelSet with the server using the provided credentials.
		Unlike other operations on Channels and the ChannelSet, this operation returns an
		AsyncToken that client code may add a responder to in order to handle success or
		failure directly.
		If the ChannelSet is not connected to the server when this method is invoked it will
		trigger a connect attempt, and if successful, send the login command to the server.
		Only one login or logout operation may be pending at a time and overlapping calls will
		generate an IllegalOperationError.
		Invoking login when the ChannelSet is already authenticated will generate also generate
		an IllegalOperationError.

		@param username The username.
		@param password The password.
		@param charset The character set encoding to use while encoding the
		credentials. The default is null, which implies the legacy charset of
		ISO-Latin-1. The only other supported charset is &quot;UTF-8&quot;.

		@return Returns a token that client code may add a responder to in order to handle
		success or failure directly.

		@throws flash.errors.IllegalOperationError in two situations; if the ChannelSet is
		already authenticated, or if a login or logout operation is currently in progress.
	**/
	public function login(username:String, password:String, charset:String = null):AsyncToken {
		if (authenticated)
			throw new IllegalOperationError("ChannelSet is already authenticated.");

		if ((_authAgent != null) && (_authAgent.state != AuthenticationAgent.LOGGED_OUT_STATE))
			throw new IllegalOperationError("ChannelSet is in the process of logging in or logging out.");

		if (charset != "UTF-8")
			charset = null; // Use legacy charset, ISO-Latin-1.

		var credentials:String = null;
		if (username != null && password != null) {
			var rawCredentials:String = username + ":" + password;
			var bytes = new ByteArray();
			bytes.endian = BIG_ENDIAN;
			if (charset == "UTF-8") {
				bytes.writeUTFBytes(rawCredentials);
				credentials = Base64.encode(bytes);
			} else {
				for (i in 0...rawCredentials.length) {
					var charCode = rawCredentials.charCodeAt(i);
					bytes.writeByte(charCode);
				}
				credentials = Base64.encode(bytes);
			}
		}

		var msg:CommandMessage = new CommandMessage();
		msg.operation = CommandMessage.LOGIN_OPERATION;
		msg.body = credentials;
		if (charset != null)
			Reflect.setField(msg.headers, CommandMessage.CREDENTIALS_CHARSET_HEADER, charset);

		// A non-null, non-empty destination is required to send using an agent.
		// This value is ignored on the server and the message must be handled by an AuthenticationService.
		msg.destination = "auth";

		var token:AsyncToken = new AsyncToken(msg);
		if (_authAgent == null)
			_authAgent = new AuthenticationAgent(this);
		_authAgent.registerToken(token);
		_authAgent.state = AuthenticationAgent.LOGGING_IN_STATE;
		send(_authAgent, msg);
		return token;
	}

	/**
		Logs the ChannelSet out from the server. Unlike other operations on Channels
		and the ChannelSet, this operation returns an AsyncToken that client code may
		add a responder to in order to handle success or failure directly.
		If logout is successful any credentials that have been cached for use in
		automatic reconnects are cleared for the ChannelSet and its Channels and their
		authenticated state is set to false.
		If the ChannelSet is not connected to the server when this method is invoked it
		will trigger a connect attempt, and if successful, send a logout command to the server.

		The MessageAgent argument is present to support legacy logout behavior and client code that
		invokes this method should not pass a MessageAgent reference. Just invoke `logout()`
		passing no arguments.

		This method is also invoked by service components from their `logout()`
		methods, and these components pass a MessageAgent reference to this method when they logout.
		The presence of this argument is the trigger to execute legacy logout behavior that differs
		from the new behavior described above.
		Legacy behavior only sends a logout request to the server if the client is connected
		and authenticated.
		If these conditions are not met the legacy behavior for this method is to do nothing other
		than clear any credentials that have been cached for use in automatic reconnects.

		@param agent Legacy argument. The MessageAgent that is initiating the logout.

		@return Returns a token that client code may
		add a responder to in order to handle success or failure directly.

		@throws flash.errors.IllegalOperationError if a login or logout operation is currently in progress.
	**/
	public function logout(agent:MessageAgent = null):AsyncToken {
		_credentials = null;
		if (agent == null) {
			if ((_authAgent != null)
				&& (_authAgent.state == AuthenticationAgent.LOGGING_OUT_STATE || _authAgent.state == AuthenticationAgent.LOGGING_IN_STATE))
				throw new IllegalOperationError("ChannelSet is in the process of logging in or logging out.");

			// Clear out current credentials on the client.
			var n:Int = _messageAgents.length;
			for (i in 0...n) {
				_messageAgents[i].internalSetCredentials(null);
			}
			n = _channels.length;
			for (i in 0...n) {
				if (_channels[i] != null) {
					_channels[i].internalSetCredentials(null);
					if ((_channels[i] is PollingChannel))
						cast(_channels[i], PollingChannel).disablePolling();
				}
			}

			var msg:CommandMessage = new CommandMessage();
			msg.operation = CommandMessage.LOGOUT_OPERATION;

			// A non-null, non-empty destination is required to send using an agent.
			// This value is ignored on the server and the message must be handled by an AuthenticationService.
			msg.destination = "auth";

			var token:AsyncToken = new AsyncToken(msg);
			if (_authAgent == null)
				_authAgent = new AuthenticationAgent(this);
			_authAgent.registerToken(token);
			_authAgent.state = AuthenticationAgent.LOGGING_OUT_STATE;
			send(_authAgent, msg);
			return token;
		} else // Legacy logout logic.
		{
			var n:Int = _channels.length;
			for (i in 0...n) {
				if (_channels[i] != null)
					_channels[i].logout(agent);
			}
			return null; // Legacy service logout() impls don't expect a token.
		}
	}

	/**
		Sends a message from a MessageAgent over the currently connected Channel.

		@param agent The MessageAgent sending the message.

		@param message The Message to send.

		@throws mx.messaging.errors.NoChannelAvailableError If the ChannelSet has no internal
		Channels to use.
	**/
	public function send(agent:MessageAgent, message:IMessage):Void {
		if (_currentChannel != null && _currentChannel.connected) {
			// Filter out any commands to trigger connection establishment, and
			// ack them locally unless the agent needs config.
			if (((message is CommandMessage) && cast(message, CommandMessage).operation == CommandMessage.TRIGGER_CONNECT_OPERATION)
				&& !agent.needsConfig) {
				var ack:AcknowledgeMessage = new AcknowledgeMessage();
				ack.clientId = agent.clientId;
				ack.correlationId = message.messageId;
				new AsyncDispatcher(agent.acknowledge, [ack, message], 1);
				return;
			}

			// If this ChannelSet targets a clustered destination, request the
			// endpoint URIs for the cluster.
			if (!_hasRequestedClusterEndpoints && clustered) {
				var msg:CommandMessage = new CommandMessage();
				// Fetch failover URIs for the correct destination.
				if ((agent is AuthenticationAgent)) {
					msg.destination = initialDestinationId;
				} else {
					msg.destination = agent.destination;
				}
				msg.operation = CommandMessage.CLUSTER_REQUEST_OPERATION;
				_currentChannel.sendInternalMessage(new ClusterMessageResponder(msg, this));
				_hasRequestedClusterEndpoints = true;
			}
			unscheduleHeartbeat();
			_currentChannel.send(agent, message);
			scheduleHeartbeat();
		} else {
			// Filter out duplicate messages here while waiting for the underlying Channel to connect.
			if (!_pendingMessages.exists(message)) {
				_pendingMessages.set(message, true);
				_pendingSends.push(new PendingSend(agent, message));
			}

			if (!_connecting) {
				if ((_currentChannel == null) || (_currentChannelIndex == -1))
					hunt();

				if ((_currentChannel is NetConnectionChannel)) {
					// Insert a slight delay in case we've hunted to a
					// NetConnection channel that doesn't allow a reconnect
					// within the same frame as a disconnect.
					if (_reconnectTimer == null) {
						_reconnectTimer = new Timer(1, 1);
						_reconnectTimer.addEventListener(TimerEvent.TIMER, reconnectChannel);
						_reconnectTimer.start();
					}
				} else // No need to wait with other channel types.
				{
					connectChannel();
				}
			}
		}
	}

	/**
		Stores the credentials and passes them through to every connected channel.

		@param credentials The credentials for the MessageAgent.
		@param agent The MessageAgent that is setting the credentials.
		@param charset The character set encoding used while encoding the
		credentials. The default is null, which implies the legacy encoding of
		ISO-Latin-1.

		@throws flash.errors.IllegalOperationError in two situations; if credentials
		have already been set and an authentication is in progress with the remote
		detination, or if authenticated and the credentials specified don't match
		the currently authenticated credentials.
	**/
	public function setCredentials(credentials:String, agent:MessageAgent, charset:String = null):Void {
		_credentials = credentials;
		var n:Int = _channels.length;
		for (i in 0...n) {
			if (_channels[i] != null)
				_channels[i].setCredentials(_credentials, agent, charset);
		}
	}

	//--------------------------------------------------------------------------
	//
	// Internal Methods
	//
	//--------------------------------------------------------------------------

	/**
		Handles a successful login or logout operation for the ChannelSet.
	**/
	private function authenticationSuccess(agent:AuthenticationAgent, token:AsyncToken, ackMessage:AcknowledgeMessage):Void {
		// Reset authentication state depending on whether a login or logout was successful.
		var command:CommandMessage = cast(token.message, CommandMessage);
		var handlingLogin:Bool = (command.operation == CommandMessage.LOGIN_OPERATION);
		var creds:String = (handlingLogin) ? Std.string(command.body) : null;
		var delay:Float = 0;

		if (handlingLogin) {
			// First, sync everything with the current credentials.
			_credentials = creds;
			var n:Int = _messageAgents.length;
			for (i in 0...n) {
				_messageAgents[i].internalSetCredentials(creds);
			}
			n = _channels.length;
			for (i in 0...n) {
				if (_channels[i] != null)
					_channels[i].internalSetCredentials(creds);
			}

			agent.state = AuthenticationAgent.LOGGED_IN_STATE;
			// Flip the currently connected channel to authenticated; this percolates
			// back up through the ChannelSet and agent's authenticated properties.
			currentChannel.setAuthenticated(true);
		} else // Logout.
		{
			// Shutdown the current logged out agent.
			agent.state = AuthenticationAgent.SHUTDOWN_STATE;
			_authAgent = null;
			// Slight delay is used to make sure the disconnect message makes it
			// to the server before result is dispatched to avoid duplicate session
			// errors. See Watson 2780176 for details.
			delay = 250;
			disconnect(agent);

			// Flip current channel to *not* authenticated; this percolates
			// back up through the ChannelSet and agent's authenticated properties.
			currentChannel.setAuthenticated(false);
		}

		// Notify.
		var resultEvent:ResultEvent = ResultEvent.createEvent(ackMessage.body, token, ackMessage);
		if (delay > 0)
			new AsyncDispatcher(dispatchRPCEvent, [resultEvent], delay);
		else
			dispatchRPCEvent(resultEvent);
	}

	/**
		Handles a failed login or logout operation for the ChannelSet.
	**/
	private function authenticationFailure(agent:AuthenticationAgent, token:AsyncToken, faultMessage:ErrorMessage):Void {
		var messageFaultEvent:MessageFaultEvent = MessageFaultEvent.createEvent(faultMessage);
		var faultEvent:FaultEvent = FaultEvent.createEventFromMessageFault(messageFaultEvent, token);
		// Leave the ChannelSet in its current auth state and dispose of the auth agent that failed.
		agent.state = AuthenticationAgent.SHUTDOWN_STATE;
		_authAgent = null;
		disconnect(agent);
		// And notify.
		dispatchRPCEvent(faultEvent);
	}

	//--------------------------------------------------------------------------
	//
	// Protected Methods
	//
	//--------------------------------------------------------------------------

	/**
		Helper method to fault pending messages.
		The ErrorMessage is tagged with a __retryable__ header to indicate that
		the error was due to connectivity problems on the client as opposed to
		a server error response and the message can be retried (resent).

		@param event A ChannelEvent.DISCONNECT or a ChannelFaultEvent that is the root cause
		for faulting these pending sends.
	**/
	private function faultPendingSends(event:ChannelEvent):Void {
		while (_pendingSends.length > 0) {
			var ps:PendingSend = _pendingSends.shift();
			var pendingMsg:IMessage = ps.message;
			_pendingMessages.remove(pendingMsg);
			// Fault the message to its agent.
			var errorMsg:ErrorMessage = new ErrorMessage();
			errorMsg.correlationId = pendingMsg.messageId;
			Reflect.setField(errorMsg.headers, ErrorMessage.RETRYABLE_HINT_HEADER, true);
			errorMsg.faultCode = "Client.Error.MessageSend";
			errorMsg.faultString = "Send failed";
			if ((event is ChannelFaultEvent)) {
				var faultEvent:ChannelFaultEvent = cast(event, ChannelFaultEvent);
				errorMsg.faultDetail = faultEvent.faultCode + " " + faultEvent.faultString + " " + faultEvent.faultDetail;
				// This is to make streaming channels report authentication fault
				// codes correctly as they don't report connected until streaming
				// connection is established and hence end up here.
				if (faultEvent.faultCode == "Channel.Authentication.Error")
					errorMsg.faultCode = faultEvent.faultCode;
			}
				// ChannelEvent.DISCONNECT is treated the same as never
			// being able to connect at all.
			else {
				errorMsg.faultDetail = "No connection could be made to the message destination.";
			}
			errorMsg.rootCause = event;
			ps.agent.fault(errorMsg, pendingMsg);
		}
	}

	/**
		Redispatches message events from the currently connected Channel.

		@param event The MessageEvent from the Channel.
	**/
	private function messageHandler(event:MessageEvent):Void {
		dispatchEvent(event);
	}

	/**
		Schedules a heartbeat to be sent in heartbeatInterval milliseconds.
	**/
	private function scheduleHeartbeat():Void {
		if (_heartbeatTimer == null && heartbeatInterval > 0) {
			_heartbeatTimer = new Timer(heartbeatInterval, 1);
			_heartbeatTimer.addEventListener(TimerEvent.TIMER, sendHeartbeatHandler);
			_heartbeatTimer.start();
		}
	}

	/**
		Handles a heartbeat timer event by conditionally sending a heartbeat
		and scheduling the next.
	**/
	private function sendHeartbeatHandler(event:TimerEvent):Void {
		unscheduleHeartbeat();
		if (currentChannel != null) {
			sendHeartbeat();
			scheduleHeartbeat();
		}
	}

	/**
		Sends a heartbeat request.
	**/
	private function sendHeartbeat():Void {
		// Current channel may be actively polling, which suppresses explicit heartbeats.
		var pollingChannel:PollingChannel = Std.downcast(currentChannel, PollingChannel);
		if (pollingChannel != null && pollingChannel._shouldPoll)
			return;
		// Issue an explicit heartbeat and schedule the next.
		var heartbeat:CommandMessage = new CommandMessage();
		heartbeat.operation = CommandMessage.CLIENT_PING_OPERATION;
		Reflect.setField(heartbeat.headers, CommandMessage.HEARTBEAT_HEADER, true);
		currentChannel.sendInternalMessage(new MessageResponder(null /* no agent */, heartbeat));
	}

	/**
		Unschedules any currently scheduled pending heartbeat.
	**/
	private function unscheduleHeartbeat():Void {
		if (_heartbeatTimer != null) {
			_heartbeatTimer.stop();
			_heartbeatTimer.removeEventListener(TimerEvent.TIMER, sendHeartbeatHandler);
			_heartbeatTimer = null;
		}
	}

	//--------------------------------------------------------------------------
	//
	// Private Methods
	//
	//--------------------------------------------------------------------------

	/**
		Helper method to connect the current internal Channel.
	**/
	private function connectChannel():Void {
		_connecting = true;
		_currentChannel.connect(this);
		// Listen for any server pushed messages on the Channel.
		_currentChannel.addEventListener(MessageEvent.MESSAGE, messageHandler);
	}

	/**
		Helper method to disconnect the current internal Channel.
	**/
	private function disconnectChannel():Void {
		_connecting = false;
		// Stop listening for server pushed messages on the Channel.
		_currentChannel.removeEventListener(MessageEvent.MESSAGE, messageHandler);
		_currentChannel.disconnect(this);
	}

	/**
		Helper method to dispatch authentication-related RPC events.

		@param event The event to dispatch.
	**/
	private function dispatchRPCEvent(event:AbstractEvent):Void {
		event.callTokenResponders();
		dispatchEvent(event);
	}

	/**
		Helper method to hunt to the next available internal Channel for the
		ChannelSet.

		@return True if hunting to the next available Channel was successful; false if hunting
		exhausted available channels and has reset to the beginning of the set.

		@throws mx.messaging.errors.NoChannelAvailableError If the ChannelSet has no internal
		Channels to use.
	**/
	private function hunt():Bool {
		if (_channels.length == 0) {
			throw new NoChannelAvailableError("No Channels are available for use.");
		}

		// Unwire from the current channel.
		if (_currentChannel != null)
			disconnectChannel();

		// Advance to next channel, and reset to beginning if all Channels in the set
		// have been attempted.
		if (++_currentChannelIndex >= _channels.length) {
			_currentChannelIndex = -1;
			return false;
		}

		// If we've advanced past the first channel, indicate that we're hunting.
		if (_currentChannelIndex > 0)
			_hunting = true;

		// Set current channel.
		if (configured) {
			if (_channels[_currentChannelIndex] != null) {
				_currentChannel = _channels[_currentChannelIndex];
			} else {
				_currentChannel = ServerConfig.getChannel(_channelIds[_currentChannelIndex], _clustered);
				_currentChannel.setCredentials(_credentials);
				_channels[_currentChannelIndex] = _currentChannel;
			}
		} else {
			_currentChannel = _channels[_currentChannelIndex];
		}

		// Ensure that the current channel is assigned failover URIs it if was lazily instantiated.
		if ((_channelFailoverURIs != null) && (_channelFailoverURIs[_currentChannel.id] != null))
			_currentChannel.failoverURIs = _channelFailoverURIs[_currentChannel.id];

		return true;
	}

	/**
		This method is invoked by a timer and it works around a reconnect issue
		with NetConnection based channels within a single frame by reconnecting after a slight delay.
	**/
	private function reconnectChannel(event:TimerEvent):Void {
		_reconnectTimer.stop();
		_reconnectTimer.removeEventListener(TimerEvent.TIMER, reconnectChannel);
		_reconnectTimer = null;
		connectChannel();
	}
}

/**
	Clustered ChannelSets need to request the clustered channel endpoints for
	the channels they contain upon a successful connect. However, Channels
	require that all outbound messages be sent by a MessageAgent that their
	internal MessageResponder implementations can callback to upon a response
	or fault. The ChannelSet is not a MessageAgent, so in this case, it
	circumvents the regular Channel.send() by passing its own custom responder
	to Channel.sendUsingCustomResponder().

	This is the custom responder.
**/
@:access(feathers.messaging.ChannelSet)
private class ClusterMessageResponder extends MessageResponder {
	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructor.
	**/
	public function new(message:IMessage, channelSet:ChannelSet) {
		super(null, message);
		_channelSet = channelSet;
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/**
		Gives the responder access to this ChannelSet, to pass it failover URIs for
		its channels.
	**/
	private var _channelSet:ChannelSet;

	//--------------------------------------------------------------------------
	//
	// Methods
	//
	//--------------------------------------------------------------------------

	/**
		Handles a cluster message response.

		@param message The response Message.
	**/
	override private function resultHandler(message:IMessage):Void {
		if ((message.body != null) && ((message.body is Array) || (message.body is ArrayCollection))) {
			var channelFailoverURIs:Dynamic = {};
			var mappings = (message.body is Array) ? cast(message.body, Array<Dynamic>) : cast(message.body, ArrayCollection<Dynamic>).toArray();
			var n:Int = mappings.length;
			for (i in 0...n) {
				var channelToEndpointMap:Dynamic = mappings[i];
				for (channelId in Reflect.fields(channelToEndpointMap)) {
					if (Reflect.field(channelFailoverURIs, channelId) == null)
						Reflect.setField(channelFailoverURIs, channelId, []);

					Reflect.field(channelFailoverURIs, channelId).push(Reflect.field(channelToEndpointMap, channelId));
				}
			}
			_channelSet.channelFailoverURIs = channelFailoverURIs;
		}
	}
}

/**
	Stores a pending message to send when the ChannelSet does not have a
	connected Channel to use immediately.
**/
private class PendingSend {
	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructor.

		@param agent The MessageAgent sending the message.

		@param msg The Message to send.
	**/
	public function new(agent:MessageAgent, message:IMessage) {
		this.agent = agent;
		this.message = message;
	}

	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------

	/**
		The MessageAgent.
	**/
	public var agent:MessageAgent;

	/**
		The Message to send.
	**/
	public var message:IMessage;
}

/**
	Helper class for handling and redispatching login and logout results or faults.
**/
@:access(feathers.messaging.ChannelSet)
private class AuthenticationAgent extends MessageAgent {
	//--------------------------------------------------------------------------
	//
	// Public Static Constants
	//
	//--------------------------------------------------------------------------
	// State constants.
	public static final LOGGED_OUT_STATE:Int = 0;
	public static final LOGGING_IN_STATE:Int = 1;
	public static final LOGGED_IN_STATE:Int = 2;
	public static final LOGGING_OUT_STATE:Int = 3;
	public static final SHUTDOWN_STATE:Int = 4;

	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
		Constructor.
	**/
	public function new(channelSet:ChannelSet) {
		super();
		// _log = Log.getLogger("ChannelSet.AuthenticationAgent");
		_agentType = "authentication agent";
		// Must set log and agent type before assigning channelSet.
		this.channelSet = channelSet;
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/**
		Map of login/logout message Ids to associated tokens.
	**/
	private var tokens:Dynamic = {};

	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------
	private var _state:Int = LOGGED_OUT_STATE;

	/**
		Returns the current state for the agent.
		See the static state constants defined by this class.
	**/
	@:flash.property
	public var state(get, set):Int;

	private function get_state():Int {
		return _state;
	}

	private function set_state(value:Int):Int {
		_state = value;
		if (value == SHUTDOWN_STATE)
			tokens = null;
		return _state;
	}

	//--------------------------------------------------------------------------
	//
	// Public Methods
	//
	//--------------------------------------------------------------------------

	/**
		Registers an outbound login/logout message and its associated token for response/fault handling.
	**/
	public function registerToken(token:AsyncToken):Void {
		Reflect.setField(tokens, token.message.messageId, token);
	}

	/**
		Acknowledge message callback.
	**/
	override public function acknowledge(ackMsg:AcknowledgeMessage, msg:IMessage):Void {
		if (state == SHUTDOWN_STATE)
			return;

		var error:Bool = Reflect.field(ackMsg.headers, AcknowledgeMessage.ERROR_HINT_HEADER);
		// Super will clean the error hint from the message.
		super.acknowledge(ackMsg, msg);
		// If acknowledge is *not* for a message that caused an error
		// dispatch a result event.
		if (!error) {
			var token:AsyncToken = Reflect.field(tokens, msg.messageId);
			Reflect.deleteField(tokens, msg.messageId);
			channelSet.authenticationSuccess(this, token, Std.downcast(ackMsg, AcknowledgeMessage));
		}
	}

	/**
		Fault callback.
	**/
	override public function fault(errMsg:ErrorMessage, msg:IMessage):Void {
		if (state == SHUTDOWN_STATE)
			return;

		// For some channel impls, when a logout request is processed the session at the remote host host
		// is invalidated which may trigger a disconnection/drop of the channel connection.
		// This channel disconnect may mask the logout ack. If the root cause for this error is a channel disconnect,
		// assume logout succeeded and locally acknowledge it.
		if ((errMsg.rootCause is ChannelEvent) && cast(errMsg.rootCause, ChannelEvent).type == ChannelEvent.DISCONNECT) {
			var ackMsg:AcknowledgeMessage = new AcknowledgeMessage();
			ackMsg.clientId = clientId;
			ackMsg.correlationId = msg.messageId;
			acknowledge(ackMsg, msg);
			return;
		}

		super.fault(errMsg, msg);

		var token:AsyncToken = Reflect.field(tokens, msg.messageId);
		Reflect.deleteField(tokens, msg.messageId);
		channelSet.authenticationFailure(this, token, Std.downcast(errMsg, ErrorMessage));
	}
}
