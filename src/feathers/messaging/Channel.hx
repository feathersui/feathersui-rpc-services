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

import feathers.data.ArrayCollection;
import feathers.messaging.config.LoaderConfig;
import feathers.messaging.config.ServerConfig;
import feathers.messaging.errors.InvalidChannelError;
import feathers.messaging.errors.InvalidDestinationError;
import feathers.messaging.events.ChannelEvent;
import feathers.messaging.events.ChannelFaultEvent;
import feathers.messaging.messages.AbstractMessage;
import feathers.messaging.messages.CommandMessage;
import feathers.messaging.messages.ErrorMessage;
import feathers.messaging.messages.IMessage;
import feathers.rpc.AsyncDispatcher;
import feathers.rpc.utils.RPCURLUtil;
import openfl.errors.Error;
import openfl.errors.IllegalOperationError;
import openfl.events.Event;
import openfl.events.EventDispatcher;
import openfl.events.TimerEvent;
import openfl.utils.Timer;

/**
 *  The Channel class is the base message channel class that all channels in the messaging
 *  system must extend.
 *
 *  <p>Channels are specific protocol-based conduits for messages sent between 
 *  MessageAgents and remote destinations.
 *  Preconfigured channels are obtained within the framework using the
 *  <code>ServerConfig.getChannel()</code> method.
 *  You can create a Channel directly using the <code>new</code> operator and
 *  add it to a ChannelSet directly.</p>
 * 
 *  <p>
 *  Channels represent a physical connection to a remote endpoint.
 *  Channels are shared across destinations by default.
 *  This means that a client targetting different destinations may use
 *  the same Channel to communicate with these destinations.
 *  </p>
 *
 *  <p><b>Note:</b> This class is for advanced use only.
 *  Use this class for creating custom channels like the existing RTMPChannel,
 *  AMFChannel, and HTTPChannel.</p>
 *
 *  @langversion 3.0
 *  @playerversion Flash 9
 *  @playerversion AIR 1.1
 *  @productversion BlazeDS 4
 *  @productversion LCDS 3 
 */
@:access(feathers.messaging.ChannelSet)
@:access(feathers.messaging.FlexClient)
@:access(feathers.messaging.MessageAgent)
@:access(feathers.messaging.config.ServerConfig)
class Channel extends EventDispatcher /*implements IMXMLObject*/ {
	//--------------------------------------------------------------------------
	//
	// Protected Static Constants
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 *  Channel config parsing constants. 
	 */
	private static final CLIENT_LOAD_BALANCING:String = "client-load-balancing";

	private static final CONNECT_TIMEOUT_SECONDS:String = "connect-timeout-seconds";
	private static final ENABLE_SMALL_MESSAGES:String = "enable-small-messages";
	private static final FALSE:String = "false";
	private static final RECORD_MESSAGE_TIMES:String = "record-message-times";
	private static final RECORD_MESSAGE_SIZES:String = "record-message-sizes";
	private static final REQUEST_TIMEOUT_SECONDS:String = "request-timeout-seconds";
	private static final SERIALIZATION:String = "serialization";
	private static final TRUE:String = "true";

	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
	 *  Constructs an instance of a generic Channel that connects to the
	 *  specified endpoint URI.
	 *
	 *  <b>Note</b>: The Channel type should not be constructed directly. Instead
	 *  create instances of protocol specific subclasses such as RTMPChannel or
	 *  AMFChannel.
	 *
	 *  @param id The id of this channel.
	 * 
	 *  @param uri The endpoint URI for this channel.
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion BlazeDS 4
	 *  @productversion LCDS 3      
	 */
	public function new(id:String = null, uri:String = null) {
		super();

		// _log = Log.getLogger("mx.messaging.Channel");
		_failoverIndex = -1;
		this.id = id;
		_primaryURI = uri;
		this.uri = uri; // Current URI
	}

	/**
	 * @private
	 */
	public function initialized(document:Any, id:String):Void {
		this.id = id;
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 *  Used to prevent multiple logouts.
	 */
	private var authenticating:Bool;

	/**
	 *  @private
	 *  The credentials string that is passed via a CommandMessage to the server when the
	 *  Channel connects. Channels inherit the credentials of connected ChannelSets that
	 *  inherit their credentials from connected MessageAgents. 
	 *  <code>MessageAgent.setCredentials(username, password)</code> is generally used
	 *  to set credentials.
	 */
	private var credentials:String;

	/**
	 * @private
	 * A channel specific override to determine whether small messages should
	 * be used. If set to false, small messages will not be used even if they
	 * are supported by an endpoint.
	 */
	public var enableSmallMessages:Bool = true;

	/**
	 *  @private
	 *  Provides access to a logger for this channel.
	 */
	private var _log:Any /*ILogger*/;

	/**
	 *  @private
	 *  Flag indicating whether the Channel is in the process of connecting.
	 */
	private var _connecting:Bool;

	/**
	 *  @private
	 *  Timer to track connect timeouts.
	 */
	private var _connectTimer:Timer;

	/**
	 *  @private
	 *  Current index into failover URIs during a failover attempt.
	 *  When not failing over, this variable is reset to a sentinal
	 *  value of -1.
	 */
	private var _failoverIndex:Int;

	/**
	 * @private
	 * Flag indicating whether the endpoint has been calculated from the uri.
	 */
	private var _isEndpointCalculated:Bool;

	/**
	 * @private
	 * The messaging version implies which features are enabled on this client
	 * channel. Channel endpoints exchange this information through headers on
	 * the ping CommandMessage exchanged during the connection handshake.
	 */
	private var messagingVersion:Float = 1.0;

	/**
	 *  @private
	 *  Flag indicating whether this Channel owns the wait guard for managing initial connect attempts.
	 */
	private var _ownsWaitGuard:Bool;

	/**
	 *  @private
	 *  Indicates whether the Channel was previously connected successfully. Used for pinned reconnect
	 *  attempts before trying failover options.
	 */
	private var _previouslyConnected:Bool;

	/**
	 *  @private
	 *  Primary URI; the initial URI for this channel.
	 */
	private var _primaryURI:String;

	/**
	 *  @private
	 *  Used for pinned reconnect attempts.
	 */
	private var reliableReconnectDuration:Int = -1;

	private var _reliableReconnectBeginTimestamp:Float;
	private var _reliableReconnectLastTimestamp:Float;
	private var _reliableReconnectAttempts:Int;

	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  channelSets
	//----------------------------------

	/**
	 *  @private
	 */
	private var _channelSets:Array<ChannelSet> = [];

	/**
	 *  Provides access to the ChannelSets connected to the Channel.
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion BlazeDS 4
	 *  @productversion LCDS 3 
	 */
	@:flash.property
	public var channelSets(get, never):Array<ChannelSet>;

	private function get_channelSets():Array<ChannelSet> {
		return _channelSets;
	}

	//----------------------------------
	//  connected
	//----------------------------------

	/**
	 *  @private
	 */
	private var _connected:Bool = false;

	// [Bindable(event="propertyChange")]

	/**
	 *  Indicates whether this channel has established a connection to the 
	 *  remote destination.
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion BlazeDS 4
	 *  @productversion LCDS 3      
	 */
	@:flash.property
	public var connected(get, never):Bool;

	private function get_connected():Bool {
		return _connected;
	}

	/**
	 *  @private
	 */
	private function setConnected(value:Bool):Void {
		if (_connected != value) {
			if (_connected)
				_previouslyConnected = true;

			// var event:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "connected", _connected, value);
			_connected = value;
			// dispatchEvent(event);
			if (!value)
				setAuthenticated(false);
		}
	}

	//----------------------------------
	//  connectTimeout
	//----------------------------------

	/**
	 *  @private
	 */
	private var _connectTimeout:Int = -1;

	/**
	 *  Provides access to the connect timeout in seconds for the channel. 
	 *  A value of 0 or below indicates that a connect attempt will never 
	 *  be timed out on the client.
	 *  For channels that are configured to failover, this value is the total
	 *  time to wait for a connection to be established.
	 *  It is not reset for each failover URI that the channel may attempt 
	 *  to connect to.
	 *  
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion BlazeDS 4
	 *  @productversion LCDS 3 
	 */
	@:flash.property
	public var connectTimeout(get, set):Int;

	private function get_connectTimeout():Int {
		return _connectTimeout;
	}

	/**
	 *  @private
	 */
	private function set_connectTimeout(value:Int):Int {
		_connectTimeout = value;
		return _connectTimeout;
	}

	//----------------------------------
	//  endpoint
	//----------------------------------

	/**
	 *  @private
	 */
	private var _endpoint:String;

	/**
	 *  Provides access to the endpoint for this channel.
	 *  This value is calculated based on the value of the <code>uri</code>
	 *  property.
	 */
	@:flash.property
	public var endpoint(get, never):String;

	private function get_endpoint():String {
		if (!_isEndpointCalculated)
			calculateEndpoint();
		return _endpoint;
	}

	//----------------------------------
	//  recordMessageTimes
	//----------------------------------

	/**
	 * @private
	 */
	private var _recordMessageTimes:Bool = false;

	/**
	 * Channel property determines the level of performance information injection - whether
	 * we inject timestamps or not. 
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion BlazeDS 4
	 *  @productversion LCDS 3 
	 */
	@:flash.property
	public var recordMessageTimes(get, never):Bool;

	private function get_recordMessageTimes():Bool {
		return _recordMessageTimes;
	}

	//----------------------------------
	//  recordMessageSizes
	//----------------------------------

	/**
	 * @private
	 */
	private var _recordMessageSizes:Bool = false;

	/**
	 * Channel property determines the level of performance information injection - whether
	 * we inject message sizes or not.
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion BlazeDS 4
	 *  @productversion LCDS 3      
	 */
	@:flash.property
	public var recordMessageSizes(get, never):Bool;

	private function get_recordMessageSizes():Bool {
		return _recordMessageSizes;
	}

	//----------------------------------
	//  reconnecting
	//----------------------------------

	/**
	 *  @private
	 */
	private var _reconnecting:Bool = false;

	// [Bindable(event="propertyChange")]

	/**
	 *  Indicates whether this channel is in the process of reconnecting to an
	 *  alternate endpoint.
	 */
	@:flash.property
	public var reconnecting(get, never):Bool;

	private function get_reconnecting():Bool {
		return _reconnecting;
	}

	private function setReconnecting(value:Bool):Void {
		if (_reconnecting != value) {
			// var event:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "reconnecting", _reconnecting, value);
			_reconnecting = value;
			// dispatchEvent(event);
		}
	}

	//----------------------------------
	//  failoverURIs
	//----------------------------------

	/**
	 *  @private
	 */
	private var _failoverURIs:Array<String>;

	/**
	 *  Provides access to the set of endpoint URIs that this channel can
	 *  attempt to failover to if the endpoint is clustered.
	 *
	 *  <p>This property is automatically populated when clustering is enabled.
	 *  If you don't use clustering, you can set your own values.</p>
	 */
	@:flash.property
	public var failoverURIs(get, set):Array<String>;

	private function get_failoverURIs():Array<String> {
		return (_failoverURIs != null) ? _failoverURIs : [];
	}

	/**
	 *  @private
	 */
	private function set_failoverURIs(value:Array<String>):Array<String> {
		if (value != null) {
			_failoverURIs = value;
			_failoverIndex = -1; // Reset the index, because URIs have changed
		}
		return (_failoverURIs != null) ? _failoverURIs : [];
	}

	//----------------------------------
	//  id
	//----------------------------------

	/**
	 *  @private
	 */
	private var _id:String;

	/**
	 *  Provides access to the id of this channel.
	 */
	@:flash.property
	public var id(get, set):String;

	private function get_id():String {
		return _id;
	}

	private function set_id(value:String):String {
		if (_id != value)
			_id = value;
		return _id;
	}

	//----------------------------------
	//  authenticated
	//----------------------------------
	private var _authenticated:Bool = false;

	// [Bindable(event="propertyChange")]

	/**
	 *  Indicates if this channel is authenticated.
	 */
	@:flash.property
	public var authenticated(get, never):Bool;

	private function get_authenticated():Bool {
		return _authenticated;
	}

	private function setAuthenticated(value:Bool):Void {
		if (value != _authenticated) {
			// var event:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "authenticated", _authenticated, value);
			_authenticated = value;

			var cs:ChannelSet;
			for (i in 0..._channelSets.length) {
				cs = _channelSets[i];
				cs.setAuthenticated(authenticated, credentials);
			}

			// dispatchEvent(event);
		}
	}

	//----------------------------------
	//  protocol
	//----------------------------------

	/**
	 *  Provides access to the protocol that the channel uses.
	 *
	 *  <p><b>Note:</b> Subclasses of Channel must override this method and return 
	 *  a string that represents their supported protocol.
	 *  Examples of supported protocol strings are "rtmp", "http" or "https".
	 * </p>
	 */
	@:flash.property
	public var protocol(get, never):String;

	private function get_protocol():String {
		throw new IllegalOperationError("Channel subclasses must override " + "the get function for 'protocol' to return the proper protocol " + "string.");
	}

	//----------------------------------
	//  realtime
	//----------------------------------

	/**
	 *  @private
	 *  Returns true if the channel supports realtime behavior via server push or client poll.
	 */
	@:flash.property
	private var realtime(get, never):Bool;

	private function get_realtime():Bool {
		return false;
	}

	//----------------------------------
	//  requestTimeout
	//----------------------------------

	/**
	 *  @private
	 */
	private var _requestTimeout:Int = -1;

	/**
	 *  Provides access to the default request timeout in seconds for the 
	 *  channel. A value of 0 or below indicates that outbound requests will 
	 *  never be timed out on the client.
	 *  <p>Request timeouts are most useful for RPC style messaging that 
	 *  requires a response from the remote destination.</p>
	 */
	@:flash.property
	public var requestTimeout(get, set):Int;

	private function get_requestTimeout():Int {
		return _requestTimeout;
	}

	/**
	 *  @private
	 */
	private function set_requestTimeout(value:Int):Int {
		_requestTimeout = value;
		return _requestTimeout;
	}

	//----------------------------------
	//  shouldBeConnected
	//----------------------------------

	/**
	 *  @private  
	 */
	private var _shouldBeConnected:Bool;

	/**
	 *  Indicates whether this channel should be connected to its endpoint.
	 *  This flag is used to control when fail over should be attempted and when disconnect
	 *  notification is sent to the remote endpoint upon disconnect or fault.
	 */
	@:flash.property
	private var shouldBeConnected(get, never):Bool;

	private function get_shouldBeConnected():Bool {
		return _shouldBeConnected;
	}

	//----------------------------------
	//  uri
	//----------------------------------

	/**
	 *  @private
	 */
	private var _uri:String;

	/**
	 *  Provides access to the URI used to create the whole endpoint URI for this channel. 
	 *  The URI can be a partial path, in which case the full endpoint URI is computed as necessary.
	 */
	@:flash.property
	public var uri(get, set):String;

	private function get_uri():String {
		return _uri;
	}

	private function set_uri(value:String):String {
		if (value != null) {
			_uri = value;
			calculateEndpoint();
		}
		return _uri;
	}

	/**
	 * @private
	 * This alternate property for an endpoint URL is provided to match the
	 * endpoint configuration attribute &quot;url&quot;. This property is
	 * equivalent to the <code>uri</code> property.
	 */
	@:flash.property
	public var url(get, set):String;

	private function get_url():String {
		return uri;
	}

	/**
	 * @private
	 */
	private function set_url(value:String):String {
		uri = value;
		return uri;
	}

	//----------------------------------
	//  useSmallMessages
	//----------------------------------

	/**
	 * @private
	 */
	private var _smallMessagesSupported:Bool;

	/**
	 * This flag determines whether small messages should be sent if the
	 * alternative is available. This value should only be true if both the
	 * client channel and the server endpoint have successfully advertised that
	 * they support this feature.
	 * @private
	 */
	@:flash.property
	public var useSmallMessages(get, set):Bool;

	private function get_useSmallMessages():Bool {
		return _smallMessagesSupported && enableSmallMessages;
	}

	/**
	 * @private
	 */
	private function set_useSmallMessages(value:Bool):Bool {
		_smallMessagesSupported = value;
		return _smallMessagesSupported && enableSmallMessages;
	}

	//--------------------------------------------------------------------------
	//
	// Methods
	//
	//--------------------------------------------------------------------------

	/**
	 *  Subclasses should override this method to apply any settings that may be
	 *  necessary for an individual channel.
	 *  Make sure to call <code>super.applySettings()</code> to apply common settings for the channel. * *  This method is used primarily in Channel subclasses.
	 *
	 *  @param settings XML fragment of the services-config.xml file for this channel.
	 */
	public function applySettings(settings:Xml):Void {
		// if (Log.isInfo())
		// 	_log.info("'{0}' channel settings are:\n{1}", id, settings);

		for (props in settings.elementsNamed("properties")) {
			applyClientLoadBalancingSettings(props);
			for (connect in props.elementsNamed(CONNECT_TIMEOUT_SECONDS)) {
				connectTimeout = Std.parseInt(Std.string(connect.nodeValue));
			}
			for (record in props.elementsNamed(RECORD_MESSAGE_TIMES)) {
				_recordMessageTimes = record.nodeValue == TRUE;
			}
			for (record in props.elementsNamed(RECORD_MESSAGE_SIZES)) {
				_recordMessageSizes = record.nodeValue == TRUE;
			}
			for (timeout in props.elementsNamed(REQUEST_TIMEOUT_SECONDS)) {
				requestTimeout = Std.parseInt(Std.string(timeout.nodeValue));
			}
			for (serializationProps in props.elementsNamed(SERIALIZATION)) {
				for (enable in serializationProps.elementsNamed(ENABLE_SMALL_MESSAGES)) {
					if (Std.string(enable.nodeValue) == FALSE) {
						enableSmallMessages = false;
					}
					break;
				}
			}
			break;
		}
	}

	/**
	 *  Applies the client load balancing urls if they exists. It randomly picks
	 *  a url from the set of client load balancing urls and sets it as the channel's
	 *  main url; then it assigns the rest of the urls as the <code>failoverURIs</code>
	 *  of the channel.
	 *
	 *  @param props The properties section of the XML fragment of the services-config.xml
	 *  file for this channel.
	 */
	private function applyClientLoadBalancingSettings(props:Xml):Void {
		// Add urls to an array, so they can be shuffled.
		var urls:Array<String> = [];
		for (clientLoadBalancing in props.elementsNamed(CLIENT_LOAD_BALANCING)) {
			for (url in clientLoadBalancing.elementsNamed("url")) {
				urls.push(url.nodeValue);
			}
		}

		shuffle(urls);

		// Select the first url as the main url.
		// if (Log.isInfo())
		// 	_log.info("'{0}' channel picked {1} as its main url.", id, urls[0]);
		this.url = urls[0];

		// Assign the rest of the urls as failoverUris.
		var failoverURIs:Array<String> = urls.slice(1);
		if (failoverURIs.length > 0)
			this.failoverURIs = failoverURIs;
	}

	/**
	 *  Connects the ChannelSet to the Channel. If the Channel has not yet
	 *  connected to its endpoint, it attempts to do so.
	 *  Channel subclasses must override the <code>internalConnect()</code> 
	 *  method, and call the <code>connectSuccess()</code> method once the
	 *  underlying connection is established.
	 * 
	 *  @param channelSet The ChannelSet to connect to the Channel.
	 */
	final public function connect(channelSet:ChannelSet):Void {
		var exists:Bool = false;
		var n:Int = _channelSets.length;
		for (i in 0..._channelSets.length) {
			if (_channelSets[i] == channelSet) {
				exists = true;
				break;
			}
		}

		_shouldBeConnected = true;
		if (!exists) {
			_channelSets.push(channelSet);
			// Wire up ChannelSet's channel event listeners.
			addEventListener(ChannelEvent.CONNECT, channelSet.channelConnectHandler);
			addEventListener(ChannelEvent.DISCONNECT, channelSet.channelDisconnectHandler);
			addEventListener(ChannelFaultEvent.FAULT, channelSet.channelFaultHandler);
		}
		// If we are already connected, notify the ChannelSet. Otherwise connect
		// if necessary.
		if (connected) {
			channelSet.channelConnectHandler(ChannelEvent.createEvent(ChannelEvent.CONNECT, this, false, false, connected));
		} else if (!_connecting) {
			_connecting = true;

			// If a connect timeout is defined, start the corresponding timer.
			if (connectTimeout > 0) {
				_connectTimer = new Timer(connectTimeout * 1000, 1);
				_connectTimer.addEventListener(TimerEvent.TIMER, connectTimeoutHandler);
				_connectTimer.start();
			}

			// We have to prevent a race between multipe Channel instances attempting to connect concurrently
			// at application startup. We detect this situation by testing whether the FlexClient Id has been assigned or not.
			if (FlexClient.getInstance().id == null) {
				var flexClient:FlexClient = FlexClient.getInstance();
				if (!flexClient.waitForFlexClientId) {
					flexClient.waitForFlexClientId = true;
					// This will cause other Channels to wait to attempt to connect.
					// This Channel can continue its attempt.
					_ownsWaitGuard = true;
					internalConnect();
				} else {
					// This Channel should wait to attempt to connect.
					throw new Error("Not implemented");
					// flexClient.addEventListener(PropertyChangeEvent.PROPERTY_CHANGE, flexClientWaitHandler);
				}
			} else {
				// Another Channel has connected and we have an assigned FlexClient Id.
				internalConnect();
			}
		}
	}

	/**
	 *  Disconnects the ChannelSet from the Channel. If the Channel is connected
	 *  to its endpoint and it has no more connected ChannelSets it will 
	 *  internally disconnect.
	 *
	 *  <p>Channel subclasses need to override the 
	 *  <code>internalDisconnect()</code> method, and call the
	 *  <code>disconnectSuccess()</code> method when the underlying connection
	 *  has been terminated.</p>
	 * 
	 *  @param channelSet The ChannelSet to disconnect from the Channel.
	 */
	final public function disconnect(channelSet:ChannelSet):Void {
		// If we own the wait guard for initial Channel connects release it.
		// This will only be true if this Channel is the first to attempt to connect
		// but its connect attempt is still pending when disconnect() is invoked.
		if (_ownsWaitGuard) {
			_ownsWaitGuard = false;
			FlexClient.getInstance().waitForFlexClientId = false; // Allow other Channels to connect.
		}

		// Disconnect the channelSet.
		var i:Int = channelSet != null ? _channelSets.indexOf(channelSet) : -1;
		if (i != -1) {
			_channelSets.splice(i, 1);
			// Remove the ChannelSet as a listener to this Channel.
			removeEventListener(ChannelEvent.CONNECT, channelSet.channelConnectHandler, false);
			removeEventListener(ChannelEvent.DISCONNECT, channelSet.channelDisconnectHandler, false);
			removeEventListener(ChannelFaultEvent.FAULT, channelSet.channelFaultHandler, false);

			// Notify the ChannelSet of the disconnect.
			if (connected) {
				channelSet.channelDisconnectHandler(ChannelEvent.createEvent(ChannelEvent.DISCONNECT, this, false));
			}

			// Shut down the underlying connection if this Channel has no more
			// ChannelSets using it.
			if (_channelSets.length == 0) {
				_shouldBeConnected = false;
				if (connected)
					internalDisconnect();
			}
		}
	}

	/**
	 *  Sends a CommandMessage to the server to logout if the Channel is connected.
	 *  Current credentials are cleared.
	 * 
	 *  @param agent The MessageAgent to logout.
	 */
	public function logout(agent:MessageAgent):Void {
		if ((connected && authenticated && credentials != null && credentials.length > 0)
			|| (authenticating && credentials != null && credentials.length > 0)) {
			var msg:CommandMessage = new CommandMessage();
			msg.operation = CommandMessage.LOGOUT_OPERATION;
			internalSend(new AuthenticationMessageResponder(agent, msg, this, _log));
			authenticating = true;
		}
		credentials = null;
	}

	/**
	 *  Sends the specified message to its target destination.
	 *  Subclasses must override the <code>internalSend()</code> method to
	 *  perform the actual send.
	 *
	 *  @param agent The MessageAgent that is sending the message.
	 * 
	 *  @param message The Message to send.
	 * 
	 *  @throws mx.messaging.errors.InvalidDestinationError If neither the MessageAgent nor the
	 *                                  message specify a destination.
	 */
	public function send(agent:MessageAgent, message:IMessage):Void {
		// Set the destination header of the message if it is not already set.
		if (message.destination.length == 0) {
			if (agent.destination.length == 0) {
				throw new InvalidDestinationError("A destination name must be specified.");
			}
			message.destination = agent.destination;
		}

		// if (Log.isDebug())
		// 	_log.debug("'{0}' channel sending message:\n{1}", id, message.toString());

		// Tag the message with a header indicating the Channel/Endpoint used for transport.
		Reflect.setField(message.headers, AbstractMessage.ENDPOINT_HEADER, id);

		var responder:MessageResponder = getMessageResponder(agent, message);
		initializeRequestTimeout(responder);
		internalSend(responder);
	}

	/**
	 *  Sets the credentials to the specified value. 
	 *  If the credentials are non-null and the Channel is connected, this method also
	 *  sends a CommandMessage to the server to login using the credentials.
	 * 
	 *  @param credentials The credentials string.
	 *  @param agent The MessageAgent to login, that will handle the login result.
	 *  @param charset The character set encoding used while encoding the
	 *  credentials. The default is null, which implies the legacy charset of
	 *  ISO-Latin-1.
	 *
	 *  @throws flash.errors.IllegalOperationError in two situations; if credentials
	 *  have already been set and an authentication is in progress with the remote
	 *  detination, or if authenticated and the credentials specified don't match
	 *  the currently authenticated credentials.
	 */
	public function setCredentials(credentials:String, agent:MessageAgent = null, charset:String = null):Void {
		var changedCreds:Bool = this.credentials != credentials;

		if (authenticating && changedCreds)
			throw new IllegalOperationError("Credentials cannot be set while authenticating or logging out.");

		if (authenticated && changedCreds)
			throw new IllegalOperationError("Credentials cannot be set when already authenticated. Logout must be performed before changing credentials.");

		this.credentials = credentials;
		if (connected && changedCreds && credentials != null) {
			authenticating = true;
			var msg:CommandMessage = new CommandMessage();
			msg.operation = CommandMessage.LOGIN_OPERATION;
			msg.body = credentials;
			if (charset != null)
				Reflect.setField(msg.headers, CommandMessage.CREDENTIALS_CHARSET_HEADER, charset);
			internalSend(new AuthenticationMessageResponder(agent, msg, this, _log));
		}
	}

	/**
	 * @private     
	 * Should we record any performance metrics
	 */
	@:flash.property
	public var mpiEnabled(get, never):Bool;

	private function get_mpiEnabled():Bool {
		return _recordMessageSizes || _recordMessageTimes;
	}

	//--------------------------------------------------------------------------
	//
	// Internal Methods
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 *  Internal hook for ChannelSet to assign credentials when it has authenticated
	 *  successfully via a direct <code>login(...)</code> call to the server.
	 */
	private function internalSetCredentials(credentials:String):Void {
		this.credentials = credentials;
	}

	/**
	 *  @private
	 *  This is a hook for ChannelSet (not a MessageAgent) to send internal messages. 
	 *  This is used for fetching info on clustered endpoints for a clustered destination
	 *  as well as for optional heartbeats, etc.
	 * 
	 *  @param msgResp The message responder to use for the internal message.
	 */
	private function sendInternalMessage(msgResp:MessageResponder):Void {
		internalSend(msgResp);
	}

	//--------------------------------------------------------------------------
	//
	// Protected Methods
	//
	//--------------------------------------------------------------------------

	/**
	 *  Processes a failed internal connect and dispatches the 
	 *  <code>FAULT</code> event for the channel.
	 *  If the Channel has <code>failoverURI</code> values, it will
	 *  attempt to reconnect automatically by trying these URI values in order until 
	 *  a connection is established or the available values are exhausted.
	 * 
	 *  @param event The ChannelFaultEvent for the failed connect.
	 */
	private function connectFailed(event:ChannelFaultEvent):Void {
		shutdownConnectTimer();
		setConnected(false);

		// if (Log.isError())
		// 	_log.error("'{0}' channel connect failed.", id);

		if (!event.rejected && shouldAttemptFailover()) {
			_connecting = true;
			failover();
		} else // Not attempting failover.
		{
			connectCleanup();
		}

		if (reconnecting)
			event.reconnecting = true;
		dispatchEvent(event);
	}

	/**
	 *  Processes a successful internal connect and dispatches the 
	 *  <code>CONNECT</code> event for the Channel.
	 */
	private function connectSuccess():Void {
		shutdownConnectTimer();

		// If there were any attached agents that needed configuration they
		// should be reset.
		if (ServerConfig.fetchedConfig(endpoint)) {
			for (i in 0...channelSets.length) {
				var messageAgents = channelSets[i].messageAgents;
				for (j in 0...messageAgents.length) {
					messageAgents[j].needsConfig = false;
				}
			}
		}

		setConnected(true);
		_failoverIndex = -1;

		// if (Log.isInfo())
		// 	_log.info("'{0}' channel is connected.", id);

		dispatchEvent(ChannelEvent.createEvent(ChannelEvent.CONNECT, this, reconnecting));

		connectCleanup();
	}

	/**
	 *  Handles a connect timeout by dispatching a ChannelFaultEvent. 
	 *  Subtypes may overide this to shutdown the current connect attempt but must 
	 *  call <code>super.connectTimeoutHandler(event)</code>.
	 * 
	 *  @param event The timer event indicating that the connect timeout has been reached.
	 */
	private function connectTimeoutHandler(event:TimerEvent):Void {
		shutdownConnectTimer();
		if (!connected) {
			_shouldBeConnected = false;
			var errorText:String = "Connect attempt timed out.";
			var faultEvent:ChannelFaultEvent = ChannelFaultEvent.createEvent(this, false, "Channel.Connect.Failed", "error", errorText);
			connectFailed(faultEvent);
		}
	}

	/**
	 *  Processes a successful internal disconnect and dispatches the 
	 *  <code>DISCONNECT</code> event for the Channel.
	 *  If the disconnect is due to a network failure and the Channel has 
	 *  <code>failoverURI</code> values, it will attempt to reconnect automatically 
	 *  by trying these URI values in order until a connection is established or the 
	 *  available values are exhausted.
	 *  
	 *  @param rejected True if the disconnect should skip any
	 *         failover processing that would otherwise be attempted; false
	 *         if failover processing should be allowed to run.
	 */
	private function disconnectSuccess(rejected:Bool = false):Void {
		setConnected(false);

		// if (Log.isInfo())
		// 	_log.info("'{0}' channel disconnected.", id);

		if (!rejected && shouldAttemptFailover()) {
			_connecting = true;
			failover();
		} else {
			connectCleanup();
		}

		dispatchEvent(ChannelEvent.createEvent(ChannelEvent.DISCONNECT, this, reconnecting, rejected));
	}

	/**
	 *  Processes a failed internal disconnect and dispatches the
	 *  <code>FAULT</code> event for the channel.
	 * 
	 *  @param event The ChannelFaultEvent for the failed disconnect.
	 */
	private function disconnectFailed(event:ChannelFaultEvent):Void {
		_connecting = false;
		setConnected(false);

		// if (Log.isError())
		// 	_log.error("'{0}' channel disconnect failed.", id);

		if (reconnecting) {
			resetToPrimaryURI();
			event.reconnecting = false;
		}
		dispatchEvent(event);
	}

	/**
	 *  Handles a change to the guard condition for managing initial Channel connect for the application.
	 *  When this is invoked it means that this Channel is waiting to attempt to connect.
	 * 
	 *  @param event The PropertyChangeEvent dispatched by the FlexClient singleton.
	 */
	private function flexClientWaitHandler(event:Event /*PropertyChangeEvent*/):Void {
		throw new Error("Not implemented");
		// if (event.property == "waitForFlexClientId") {
		// 	var flexClient:FlexClient = Std.downcast(event.source, FlexClient);
		// 	if (flexClient.waitForFlexClientId == false) // The wait is over, claim it and attempt to connect.
		// 	{
		// 		throw new Error("not implemented");
		// 		flexClient.removeEventListener(PropertyChangeEvent.PROPERTY_CHANGE, flexClientWaitHandler);
		// 		flexClient.waitForFlexClientId = true;
		// 		// This will cause other Channels to wait to attempt to connect.
		// 		// This Channel can continue its attempt.
		// 		_ownsWaitGuard = true;
		// 		internalConnect();
		// 	}
		// }
	}

	/**
	 *  Returns the appropriate MessageResponder for the Channel's
	 *  <code>send()</code> method.
	 *  Must be overridden.
	 *
	 *  @param agent The MessageAgent sending the message.
	 * 
	 *  @param message The Message to send.
	 * 
	 *  @return The MessageResponder to handle the result or fault.
	 * 
	 *  @throws flash.errors.IllegalOperationError If the Channel subclass does not override
	 *                                this method.
	 */
	private function getMessageResponder(agent:MessageAgent, message:IMessage):MessageResponder {
		throw new IllegalOperationError("Channel subclasses must override " + " getMessageResponder().");
	}

	/**
	 *  Connects the Channel to its endpoint.
	 *  Must be overridden.
	 */
	private function internalConnect():Void {}

	/**
	 *  Disconnects the Channel from its endpoint. 
	 *  Must be overridden.
	 * 
	 *  @param rejected True if the disconnect was due to a connection rejection or timeout
	 *                  and reconnection should not be attempted automatically; otherwise false. 
	 */
	private function internalDisconnect(rejected:Bool = false):Void {}

	/**
	 *  Sends the Message out over the Channel and routes the response to the
	 *  responder.
	 *  Must be overridden.
	 * 
	 *  @param messageResponder The MessageResponder to handle the response.
	 */
	private function internalSend(messageResponder:MessageResponder):Void {}

	/**
	 * @private
	 * Utility method to examine the reported server messaging version and
	 * thus determine which features are available.
	 */
	private function handleServerMessagingVersion(version:Float):Void {
		useSmallMessages = version >= messagingVersion;
	}

	/**
	 *  @private
	 *  Utility method used to assign the FlexClient Id value to outbound messages.
	 * 
	 *  @param message The message to set the FlexClient Id on.
	 */
	private function setFlexClientIdOnMessage(message:IMessage):Void {
		var id:String = FlexClient.getInstance().id;
		Reflect.setField(message.headers, AbstractMessage.FLEX_CLIENT_ID_HEADER, (id != null) ? id : FlexClient.NULL_FLEXCLIENT_ID);
	}

	//--------------------------------------------------------------------------
	//
	// Private Methods
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private   
	 *  This method calculates the endpoint value based on the current
	 *  <code>uri</code>.
	 */
	private function calculateEndpoint():Void {
		if (uri == null) {
			var message:String = "No url was specified for the channel.";
			throw new InvalidChannelError(message);
		}

		var uriCopy:String = uri;
		var proto:String = RPCURLUtil.getProtocol(uriCopy);

		if (proto.length == 0)
			uriCopy = RPCURLUtil.getFullURL(LoaderConfig.url, uriCopy);

		if (RPCURLUtil.hasTokens(uriCopy) && !RPCURLUtil.hasUnresolvableTokens()) {
			_isEndpointCalculated = false;
			return;
		}

		uriCopy = RPCURLUtil.replaceTokens(uriCopy);

		// Now, check for a final protocol after relative URLs and tokens
		// have been replaced
		proto = RPCURLUtil.getProtocol(uriCopy);

		if (proto.length > 0)
			_endpoint = RPCURLUtil.replaceProtocol(uriCopy, protocol);
		else
			_endpoint = protocol + ":" + uriCopy;

		_isEndpointCalculated = true;

		// if (Log.isInfo())
		// 	_log.info("'{0}' channel endpoint set to {1}", id, _endpoint);
	}

	/**
	 *  @private
	 *  Initializes the request timeout for this message if the outbound message 
	 *  defines a REQUEST_TIMEOUT_HEADER value. 
	 *  If this header is not set and the default requestTimeout for the 
	 *  channel is greater than 0, the channel default is used. 
	 *  Otherwise, no request timeout is enforced on the client.
	 * 
	 *  @param messageResponder The MessageResponder to handle the response and monitor the outbound
	 *                          request for a timeout.
	 */
	private function initializeRequestTimeout(messageResponder:MessageResponder):Void {
		var message:IMessage = messageResponder.message;
		// Turn on request timeout machinery if the message defines it.
		if (Reflect.field(message.headers, AbstractMessage.REQUEST_TIMEOUT_HEADER) != null) {
			messageResponder.startRequestTimeout(Reflect.field(message.headers, AbstractMessage.REQUEST_TIMEOUT_HEADER));
		} else if (requestTimeout > 0) // Use the channel default.
		{
			messageResponder.startRequestTimeout(requestTimeout);
		}
	}

	/**
	 *  @private
	 *  Convenience method to test whether the Channel should attempt to
	 *  failover.
	 * 
	 *  @return <code>true</code> if the Channel should try to failover;
	 *          otherwise <code>false</code>.
	 */
	private function shouldAttemptFailover():Bool {
		return (_shouldBeConnected
			&& (_previouslyConnected || (reliableReconnectDuration != -1) || ((_failoverURIs != null) && (_failoverURIs.length > 0))));
	}

	/**
	 *  @private
	 *  This method attempts to fail the Channel over to the next available URI.
	 */
	private function failover():Void {
		// Potentially enter reliable reconnect loop.
		if (_previouslyConnected) {
			_previouslyConnected = false;

			// var acs:Class = null;
			// try
			// {
			// 	acs = getDefinitionByName("mx.messaging.AdvancedChannelSet") as Class;
			// }
			// catch (ignore:Error) {}
			var duration:Int = -1;
			// if (acs != null)
			// {
			// 	for each (var channelSet:ChannelSet in channelSets)
			// 	{
			// 		if ((channelSet is acs))
			// 		{
			// 			var d:Int = (channelSet as acs)["reliableReconnectDuration"];
			// 			if (d > duration)
			// 				duration = d;
			// 		}
			// 	}
			// }

			if (duration != -1) {
				setReconnecting(true);
				reliableReconnectDuration = duration;
				_reliableReconnectBeginTimestamp = Date.now().getTime();
				new AsyncDispatcher(reconnect, null, 1);
				return; // Exit early.
			}
		}

		// Potentially continue reliable reconnect loop.
		if (reliableReconnectDuration != -1) {
			_reliableReconnectLastTimestamp = Date.now().getTime();
			var remaining:Float = reliableReconnectDuration - (_reliableReconnectLastTimestamp - _reliableReconnectBeginTimestamp);
			if (remaining > 0) {
				// Apply exponential backoff.
				var delay:Int = 1000; // 1 second.
				delay << ++_reliableReconnectAttempts;
				if (delay < remaining) {
					new AsyncDispatcher(reconnect, null, delay);
					return; // Exit early.
				}
			}
			// At this point the reliable reconnect duration has been exhausted.
			reliableReconnectCleanup();
		}

			// General failover handling.
		++_failoverIndex;
		if ((_failoverIndex + 1) <= failoverURIs.length) {
			setReconnecting(true);
			uri = failoverURIs[_failoverIndex];

			// if (Log.isInfo()) {
			// 	_log.info("'{0}' channel attempting to connect to {1}.", id, endpoint);
			// }
			// NetConnection based channels may have their underlying resources
			// GC'ed at the end of the execution of the handler that has
			// invoked this method, which means that the results of a call to
			// internalConnect() for these channels may magically vanish once
			// the handler exits.
			// A timer introduces a slight delay in the reconnect attempt to
			// give the handler time to finish executing, at which point the
			// internals of a NetConnection channel will be stable and we can
			// attempt to connect successfully.
			// This timer is applied to all channels but the impact is small
			// enough and the failover scenario rare enough that special casing
			// this for only NetConnection channels is more trouble than it's
			// worth.
			new AsyncDispatcher(reconnect, null, 1);
		} else {
			// if (Log.isInfo()) {
			// 	_log.info("'{0}' channel has exhausted failover options and has reset to its primary endpoint.", id);
			// }
			// Nothing left to failover to; reset to primary.
			resetToPrimaryURI();
		}
	}

	/**
	 *  @private
	 *  Cleanup following a connect or failover attempt.
	 */
	private function connectCleanup():Void {
		// If we own the wait guard for initial Channel connects release it.
		if (_ownsWaitGuard) {
			_ownsWaitGuard = false;
			FlexClient.getInstance().waitForFlexClientId = false; // Allow other Channels to connect.
		}

		_connecting = false;

		setReconnecting(false); // Ensure the reconnecting flag is turned off; failover is not being attempted.

		reliableReconnectCleanup();
	}

	/**
	 *  @private
	 *  This method is invoked by a timer from failover() and it works around a 
	 *  reconnect issue with NetConnection based channels by invoking 
	 *  internalConnect() after a slight delay.
	 */
	private function reconnect(event:TimerEvent = null):Void {
		internalConnect();
	}

	/**
	 *  @private
	 *  Cleanup following a reliable reconnect attempt.
	 */
	private function reliableReconnectCleanup():Void {
		reliableReconnectDuration = -1;
		_reliableReconnectBeginTimestamp = 0;
		_reliableReconnectLastTimestamp = 0;
		_reliableReconnectAttempts = 0;
	}

	/**
	 *  @private
	 *  This method resets the channel back to its primary URI after
	 *  exhausting all failover URIs.
	 */
	private function resetToPrimaryURI():Void {
		_connecting = false;
		setReconnecting(false);
		uri = _primaryURI;
		_failoverIndex = -1;
	}

	/**
	 *  @private
	 *  Shuffles the array.
	 */
	private function shuffle(elements:Array<String>):Void {
		var length:Int = elements.length;
		for (i in 0...length) {
			var index:Int = Math.floor(Math.random() * length);
			if (index != i) {
				var temp = elements[i];
				elements[i] = elements[index];
				elements[index] = temp;
			}
		}
	}

	/**
	 *  @private
	 *  Shuts down and nulls out the connect timer.
	 */
	private function shutdownConnectTimer():Void {
		if (_connectTimer != null) {
			_connectTimer.stop();
			_connectTimer.removeEventListener(TimerEvent.TIMER, connectTimeoutHandler);
			_connectTimer = null;
		}
	}

	//--------------------------------------------------------------------------
	//
	// Static Constants
	//
	//--------------------------------------------------------------------------

	/**
	 * @private
	 */
	public static final SMALL_MESSAGES_FEATURE:String = "small_messages";

	/**
	 *  @private
	 *  Creates a compile time dependency on ArrayCollection to ensure
	 *  it is present for response data containing collections.
	 */
	private static final dep:ArrayCollection<Dynamic> = null;
}

/**
 *  @private
 *  Responder for processing channel authentication responses.
 */
@:access(feathers.messaging.Channel)
class AuthenticationMessageResponder extends MessageResponder {
	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------
	public function new(agent:MessageAgent, message:IMessage, channel:Channel, log:Any /*ILogger*/) {
		super(agent, message, channel);
		// _log = log;
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 *  Reference to the logger for the associated Channel.
	 */
	private var _log:Any /*ILogger*/;

	//--------------------------------------------------------------------------
	//
	// Methods
	//
	//--------------------------------------------------------------------------

	/**
	 *  Handles an authentication result.
	 * 
	 *  @param msg The result Message.
	 */
	override private function resultHandler(msg:IMessage):Void {
		var cmd:CommandMessage = Std.downcast(message, CommandMessage);
		channel.authenticating = false;
		if (cmd.operation == CommandMessage.LOGIN_OPERATION) {
			// if (Log.isDebug())
			// 	_log.debug("Login successful");

			// we want to set the authenticated property last as it will dispatch
			// an event in this case and handler code shouldn't get called
			// util the system is stable.
			channel.setAuthenticated(true);
		} else // Logout operation.
		{
			// if (Log.isDebug())
			// 	_log.debug("Logout successful");

			channel.setAuthenticated(false);
		}
	}

	/**
	 *  Handles an authentication failure.
	 * 
	 *  @param msg The failure Message.
	 */
	override private function statusHandler(msg:IMessage):Void {
		var cmd:CommandMessage = cast(message, CommandMessage);

		// if (Log.isDebug()) {
		// 	_log.debug("{1} failure: {0}", msg.toString(), cmd.operation == CommandMessage.LOGIN_OPERATION ? "Login" : "Logout");
		// }

		channel.authenticating = false;
		channel.setAuthenticated(false);

		if (agent != null && agent.hasPendingRequestForMessage(message)) {
			agent.fault(cast(msg, ErrorMessage), message);
		} else {
			var errMsg:ErrorMessage = cast(msg, ErrorMessage);
			var channelFault:ChannelFaultEvent = ChannelFaultEvent.createEvent(channel, false, "Channel.Authentication.Error", "warn", errMsg.faultString);
			channelFault.rootCause = errMsg;
			channel.dispatchEvent(channelFault);
		}
	}
}
