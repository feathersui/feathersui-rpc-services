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

import haxe.crypto.Base64;
import openfl.utils.ByteArray;
import feathers.messaging.Channel;
import feathers.messaging.channels.PollingChannel;
import feathers.messaging.config.ServerConfig;
import feathers.messaging.errors.InvalidDestinationError;
import feathers.messaging.events.ChannelEvent;
import feathers.messaging.events.ChannelFaultEvent;
import feathers.messaging.events.MessageAckEvent;
import feathers.messaging.events.MessageFaultEvent;
import feathers.messaging.messages.AbstractMessage;
import feathers.messaging.messages.AcknowledgeMessage;
import feathers.messaging.messages.CommandMessage;
import feathers.messaging.messages.ErrorMessage;
import feathers.messaging.messages.IMessage;
import feathers.rpc.utils.RPCUIDUtil;
import openfl.errors.Error;
import openfl.events.EventDispatcher;
#if flash
import feathers.messaging.config.ConfigMap;
#end

@:access(feathers.messaging.Channel)
@:access(feathers.messaging.config.ServerConfig)
class MessageAgent extends EventDispatcher /*implements IMXMLObject*/ {
	//--------------------------------------------------------------------------
	//
	// Internal Static Constants
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 *  Indicates that the MessageAgent is used an automatically configured ChannelSet
	 *  obtained from ServerConfig.
	 */
	private static final AUTO_CONFIGURED_CHANNELSET:Int = 0;

	/**
	 *  @private
	 *  Indicates that the MessageAgent is using a manually assigned ChannelSet.
	 */
	private static final MANUALLY_ASSIGNED_CHANNELSET:Int = 1;

	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
	 *  Constructor.
	 */
	public function new() {
		super();
	}

	//--------------------------------------------------------------------------
	//
	// Variables
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 *  The type of MessageAgent.
	 *  This variable is used for logging and MUST be assigned by subclasses.
	 */
	private var _agentType:String = "mx.messaging.MessageAgent";

	/**
	 *  @private
	 *  The Base64 encoded credentials that will be passed through to
	 *  the ChannelSet.
	 */
	private var _credentials:String;

	/**
	 *  @private
	 *  The character set encoding used to create the credentials String.
	 */
	private var _credentialsCharset:String;

	/**
	 *  @private
	 *  Indicates whether the agent is explicitly disconnected.
	 *  This allows agents to supress processing of acks/faults that return
	 *  after the client has issued an explicit disconnect().
	 */
	private var _disconnectBarrier:Bool;

	/**
	 *  @private
	 *  This helps in the runtime configuration setup by delaying the connect
	 *  event until the configuration has been setup. See acknowledge().
	 */
	private var _pendingConnectEvent:ChannelEvent;

	/**
	 *  @private
	 *  The Base64 encoded credentials that are passed through to a
	 *  3rd party.
	 */
	private var _remoteCredentials:String = "";

	/**
	 *  @private
	 *  The character set encoding used to create the remoteCredentials String.
	 */
	private var _remoteCredentialsCharset:String;

	/**
	 *  @private
	 *  Indicates that the remoteCredentials value has changed and should
	 *  be sent to the server.
	 */
	private var _sendRemoteCredentials:Bool;

	/**
	 *  @private
	 *  The logger MUST be assigned by subclasses, for example
	 *  Consumer and Producer.
	 */
	private var _log:Any /*ILogger*/;

	/**
	 *  @private
	 *  A queue to store pending outbound messages while waiting for a server response
	 *  that contains a server-generated clientId.
	 *  Serializing messages from a MessageAgent to the server is essential until we
	 *  receive a response containing a server-generated clientId; otherwise the server
	 *  will treat each message as if it was sent by a different, "new" MessageAgent instance.
	 */
	private var _clientIdWaitQueue:Array<IMessage>;

	/**
	 *  @private
	 * Flag being set to true denotes that we should skip remaining fault
	 * processing logic because the fault has already been handled.
	 * Currently used during an automatic resend of a faulted message if the fault
	 * was due to a server session timeout and is authentication/authorization related.
	 */
	private var _ignoreFault:Bool = false;

	//--------------------------------------------------------------------------
	//
	// Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  authenticated
	//----------------------------------

	/**
	 *  @private
	 */
	private var _authenticated:Bool;

	// [Bindable(event="propertyChange")]

	/**
	 *  Indicates if this MessageAgent is using an authenticated connection to
	 *  its destination.
	 */
	@:flash.property
	public var authenticated(get, never):Bool;

	private function get_authenticated():Bool {
		return _authenticated;
	}

	/**
	 *  @private
	 */
	private function setAuthenticated(value:Bool, creds:String):Void {
		if (_authenticated != value) {
			// var event:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "authenticated", _authenticated, value);
			_authenticated = value;
			// dispatchEvent(event);

			if (value)
				assertCredentials(creds);
		}
	}

	//----------------------------------
	//  channelSet
	//----------------------------------

	/**
	 *  @private
	 */
	private var _channelSet:ChannelSet;

	// [Bindable(event="propertyChange")]

	/**
	 *  Provides access to the ChannelSet used by the MessageAgent. The
	 *  ChannelSet can be manually constructed and assigned, or it will be
	 *  dynamically initialized to use the configured Channels for the
	 *  destination for this MessageAgent.
	 */
	@:flash.property
	public var channelSet(get, set):ChannelSet;

	private function get_channelSet():ChannelSet {
		return _channelSet;
	}

	/**
	 *  @private
	 */
	private function set_channelSet(value:ChannelSet):ChannelSet {
		internalSetChannelSet(value);
		_channelSetMode = MANUALLY_ASSIGNED_CHANNELSET;
		return _channelSet;
	}

	/**
	 *  @private
	 *  This method is called by ChannelSet.connect(agent) to set up the bidirectional
	 *  relationship between the MessageAgent and the ChannelSet.
	 *  It also handles the case of customer code calling channelSet.connect(agent)
	 *  directly rather than assigning the ChannelSet to the MessageAgent's channelSet
	 *  property.
	 */
	private function internalSetChannelSet(value:ChannelSet):Void {
		if (_channelSet != value) {
			if (_channelSet != null)
				_channelSet.disconnect(this);

			// var event:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "channelSet", _channelSet, value);
			_channelSet = value;

			if (_channelSet != null) {
				if (_credentials != null)
					_channelSet.setCredentials(_credentials, this, _credentialsCharset);

				_channelSet.connect(this);
			}

			// dispatchEvent(event);
		}
	}

	//----------------------------------
	//  clientId
	//----------------------------------

	/**
	 *  @private
	 */
	private var _clientId:String;

	// [Bindable(event="propertyChange")]

	/**
	 *  Provides access to the client id for the MessageAgent.
	 *  MessageAgents are assigned their client id by the remote destination
	 *  and this value is used to route messages from the remote destination to
	 *  the proper MessageAgent.
	 */
	@:flash.property
	public var clientId(get, never):String;

	private function get_clientId():String {
		return _clientId;
	}

	/**
	 *  @private
	 *  This method is used to assign a server-generated client id to the MessageAgent
	 *  in the common scenario.
	 *  It may also be used by the framework to sync up cooperating MessageAgents under
	 *  a single client id value so that they appear as a single MessageAgent to the server.
	 *  Assigning a client id value will flush any messages that have been queued while we
	 *  were waiting for a server-generated client id value to be returned.
	 *  Queued messages are sent to the server in order.
	 */
	private function setClientId(value:String):Void {
		if (_clientId != value) {
			// var event:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "clientId", _clientId, value);
			_clientId = value;
			flushClientIdWaitQueue();
			// dispatchEvent(event);
		}
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
	 *  Indicates whether this MessageAgent is currently connected to its
	 *  destination via its ChannelSet. The <code>propertyChange</code> event is dispatched when
	 *  this property changes.
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
			// var event:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "connected", _connected, value);
			_connected = value;
			// dispatchEvent(event);
			setAuthenticated(value && channelSet != null && channelSet.authenticated, _credentials);
		}
	}

	//----------------------------------
	//  destination
	//----------------------------------

	/**
	 *  @private
	 */
	private var _destination:String = "";

	// [Bindable(event="propertyChange")]

	/**
	 *  Provides access to the destination for the MessageAgent.
	 *  Changing the destination will disconnect the MessageAgent if it is
	 *  currently connected.
	 *
	 *  @throws mx.messaging.errors.InvalidDestinationError If the destination is null or
	 *                                  zero-length.
	 */
	@:flash.property
	public var destination(get, set):String;

	private function get_destination():String {
		return _destination;
	}

	/**
	 *  @private
	 */
	private function set_destination(value:String):String {
		if ((value == null) || value.length == 0)
			return _destination; // empty/null destination is checked in internalSend.

		if (_destination != value) {
			// If we're using an automatically configured ChannelSet,
			// disconnect from it and null out our ref so we look up the
			// proper configured ChannelSet for the new destination on our next send().
			if ((_channelSetMode == AUTO_CONFIGURED_CHANNELSET) && (channelSet != null)) {
				channelSet.disconnect(this);
				channelSet = null;
			}

			// var event:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "destination", _destination, value);
			_destination = value;
			// dispatchEvent(event);

			// if (Log.isInfo())
			//     _log.info("'{0}' {2} set destination to '{1}'.", id, _destination,  _agentType);
		}
		return _destination;
	}

	//----------------------------------
	//  id
	//----------------------------------

	/**
	 *  @private
	 */
	private var _id:String = RPCUIDUtil.createUID();

	// [Bindable(event="propertyChange")]

	/**
	 *  @private
	 *  The id of this agent.
	 */
	@:flash.property
	public var id(get, set):String;

	private function get_id():String {
		return _id;
	}

	/**
	 *  @private
	 */
	private function set_id(value:String):String {
		if (_id != value) {
			// var event:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "id", _id, value);
			_id = value;
			// dispatchEvent(event);
		}
		return _id;
	}

	//----------------------------------
	//  requestTimeout
	//----------------------------------

	/**
	 *  @private
	 */
	private var _requestTimeout:Int = -1;

	// [Bindable(event="propertyChange")]

	/**
	 *  Provides access to the request timeout in seconds for sent messages.
	 *  If an acknowledgement, response or fault is not received from the
	 *  remote destination before the timeout is reached the message is faulted on the client.
	 *  A value less than or equal to zero prevents request timeout.
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
		if (_requestTimeout != value) {
			// var event:PropertyChangeEvent = PropertyChangeEvent.createUpdateEvent(this, "requestTimeout", _requestTimeout, value);
			_requestTimeout = value;
			// dispatchEvent(event);
		}
		return _requestTimeout;
	}

	//--------------------------------------------------------------------------
	//
	// Internal Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  channelSetMode
	//----------------------------------

	/**
	 *  @private
	 */
	private var _channelSetMode:Int = AUTO_CONFIGURED_CHANNELSET;

	private var channelSetMode(get, never):Int;

	private function get_channelSetMode():Int {
		return _channelSetMode;
	}

	//----------------------------------
	//  configRequested
	//----------------------------------

	/**
	 *  @private
	 *  Indicates whether the agent has requested configuration from the server.
	 */
	private var configRequested:Bool = false;

	//----------------------------------
	//  needsConfig
	//----------------------------------

	/**
	 * @private
	 */
	private var _needsConfig:Bool;

	/**
	 *  Indicates if this MessageAgent needs to request configuration from the
	 *  server.
	 */
	private var needsConfig(get, set):Bool;

	private function get_needsConfig():Bool {
		return _needsConfig;
	}

	/**
	 *  @private
	 */
	private function set_needsConfig(value:Bool):Bool {
		if (_needsConfig == value)
			return _needsConfig;

		_needsConfig = value;
		if (_needsConfig) {
			var cs:ChannelSet = channelSet;
			try {
				disconnect();
				// was in finally
				internalSetChannelSet(cs);
			} catch (e:Any) {
				internalSetChannelSet(cs);
			}
		}
		return _needsConfig;
	}

	//--------------------------------------------------------------------------
	//
	// Methods
	//
	//--------------------------------------------------------------------------

	/**
	 *  Invoked by a MessageResponder upon receiving a result for a sent
	 *  message. Subclasses may override this method if they need to perform
	 *  custom acknowledgement processing, but must invoke
	 *  <code>super.acknowledge()</code> as well. This method dispatches a
	 *  MessageAckEvent.
	 *
	 *  @param ackMsg The AcknowledgMessage returned.
	 *
	 *  @param msg The original sent message.
	 */
	public function acknowledge(ackMsg:AcknowledgeMessage, msg:IMessage):Void {
		// if (Log.isInfo())
		// 	_log.info("'{0}' {2} acknowledge of '{1}'.", id, msg.messageId, _agentType);

		// if (Log.isDebug() && isCurrentChannelNotNull() && getCurrentChannel().mpiEnabled) {
		// 	try {
		// 		var mpiutil:MessagePerformanceUtils = new MessagePerformanceUtils(ackMsg);
		// 		_log.debug(mpiutil.prettyPrint());
		// 	} catch (e:Error) {
		// 		_log.debug("Could not get message performance information for: " + msg.toString());
		// 	}
		// }

		if (configRequested) {
			configRequested = false;
			ServerConfig.updateServerConfigData(#if flash cast(ackMsg.body, ConfigMap) #else ackMsg.body #end);
			needsConfig = false;
			if (_pendingConnectEvent != null)
				channelConnectHandler(_pendingConnectEvent);

			_pendingConnectEvent = null;
		}
		if (clientId == null) {
			if (ackMsg.clientId != null)
				setClientId(ackMsg.clientId); // Triggers a call to flush the clientId wait queue.
			else
				flushClientIdWaitQueue();
		}

		dispatchEvent(MessageAckEvent.createEvent(ackMsg, msg));
		monitorRpcMessage(ackMsg, msg);
	}

	/**
	 *  Disconnects the MessageAgent's network connection.
	 *  This method does not wait for outstanding network operations to complete.
	 */
	public function disconnect():Void {
		if (!_disconnectBarrier) {
			// Ensure wait queue for client id value is destroyed.
			_clientIdWaitQueue = null;

			// Only set the barrier used to discard post-disconnect results/faults
			// if the agent is currently connected (otherwise, if this is invoked before
			// connecting and the client fails to connect to the server, no faults will be
			// dispatched).
			if (connected)
				_disconnectBarrier = true;

			if (_channelSetMode == AUTO_CONFIGURED_CHANNELSET)
				internalSetChannelSet(null);
			else if (_channelSet != null)
				_channelSet.disconnect(this);
		}
	}

	/**
	 *  Invoked by a MessageResponder upon receiving a fault for a sent message.
	 *  Subclasses may override this method if they need to perform custom fault
	 *  processing, but must invoke <code>super.fault()</code> as well. This
	 *  method dispatchs a MessageFaultEvent.
	 *
	 *  @param errMsg The ErrorMessage.
	 *
	 *  @param msg The original sent message that caused this fault.
	 */
	public function fault(errMsg:ErrorMessage, msg:IMessage):Void {
		// if (Log.isError())
		// 	_log.error("'{0}' {2} fault for '{1}'.", id, msg.messageId, _agentType);

		_ignoreFault = false;
		configRequested = false;

		// Remove retryable hint.
		if (Reflect.field(errMsg.headers, ErrorMessage.RETRYABLE_HINT_HEADER) != null)
			Reflect.deleteField(errMsg.headers, ErrorMessage.RETRYABLE_HINT_HEADER);

		if (clientId == null) {
			if (errMsg.clientId != null)
				setClientId(errMsg.clientId); // Triggers a call to flush the clientId wait queue.
			else
				flushClientIdWaitQueue();
		}

		dispatchEvent(MessageFaultEvent.createEvent(errMsg));
		monitorRpcMessage(errMsg, msg);

		handleAuthenticationFault(errMsg, msg);
	}

	/**
	 *  Handles a CONNECT ChannelEvent. Subclasses that need to perform custom
	 *  processing should override this method, and invoke
	 *  <code>super.channelConnectHandler()</code>.
	 *
	 *  @param event The ChannelEvent.
	 */
	public function channelConnectHandler(event:ChannelEvent):Void {
		_disconnectBarrier = false;
		// If we are waiting on config to come in we can't be connected until
		// we get it. See acknowledge().
		if (needsConfig) {
			// if (Log.isInfo())
			// 	_log.info("'{0}' {1} waiting for configuration information.", id, _agentType);

			_pendingConnectEvent = event;
		} else {
			// if (Log.isInfo())
			// 	_log.info("'{0}' {1} connected.", id, _agentType);
			setConnected(true);
			dispatchEvent(event);
		}
	}

	/**
	 *  Handles a DISCONNECT ChannelEvent. Subclasses that need to perform
	 *  custom processing should override this method, and invoke
	 *  <code>super.channelDisconnectHandler()</code>.
	 *
	 *  @param event The ChannelEvent.
	 */
	public function channelDisconnectHandler(event:ChannelEvent):Void {
		// if (Log.isWarn())
		// 	_log.warn("'{0}' {1} channel disconnected.", id, _agentType);
		setConnected(false);
		// If we have remoteCredentials we need to send them on reconnect.
		if (_remoteCredentials != null) {
			_sendRemoteCredentials = true;
		}
		dispatchEvent(event);
	}

	/**
	 *  Handles a ChannelFaultEvent. Subclasses that need to perform custom
	 *  processing should override this method, and invoke
	 *  <code>super.channelFaultHandler()</code>.
	 *
	 *  @param The ChannelFaultEvent
	 */
	public function channelFaultHandler(event:ChannelFaultEvent):Void {
		// if (Log.isWarn())
		// 	_log.warn("'{0}' {1} channel faulted with {2} {3}", id, _agentType, event.faultCode, event.faultDetail);

		if (!event.channel.connected) {
			setConnected(false);
			// If we have remoteCredentials we need to send them on reconnect.
			if (_remoteCredentials != null) {
				_sendRemoteCredentials = true;
			}
		}
		dispatchEvent(event);
	}

	/**
	 *  Called after the implementing object has been created
	 *  and all properties specified on the tag have been assigned.
	 *
	 *  @param document MXML document that created this object.
	 *
	 *  @param id id used by the document to refer to this object.
	 *  If the object is a deep property on the document, id is null.
	 */
	public function initialized(document:Any, id:String):Void {
		this.id = id;
	}

	/**
	 *  Logs the MessageAgent out from its remote destination.
	 *  Logging out of a destination applies to everything connected using the same ChannelSet
	 *  as specified in the server configuration. For example, if several DataService components
	 *  are connected over an RTMP channel and <code>logout()</code> is invoked on one of them,
	 *  all other client components that are connected using the same ChannelSet are also logged out.
	 *
	 *  **Note:** Adobe recommends that you use the mx.messaging.ChannelSet.logout() method
	 *  rather than this method.
	 *
	 *  @see mx.messaging.ChannelSet#logout()
	 */
	public function logout():Void {
		_credentials = null;
		if (channelSet != null)
			channelSet.logout(this);
	}

	/**
	 *  Sets the credentials that the MessageAgent uses to authenticate to
	 *  destinations.
	 *  The credentials are applied to all services connected over the same ChannelSet.
	 *
	 *  @param username The username.
	 *  @param password The password.
	 *  @param charset The character set encoding to use while encoding the
	 *  credentials. The default is null, which implies the legacy charset of
	 *  ISO-Latin-1. The only other supported charset is &quot;UTF-8&quot;.
	 *
	 *  @throws flash.errors.IllegalOperationError in two situations; if credentials
	 *  have already been set and an authentication is in progress with the remote
	 *  detination, or if authenticated and the credentials specified don't match
	 *  the currently authenticated credentials.
	 */
	public function setCredentials(username:String, password:String, charset:String = null):Void {
		if (username == null && password == null) {
			_credentials = null;
			_credentialsCharset = null;
		} else {
			var cred:String = username + ":" + password;
			var bytes = new ByteArray();
			bytes.endian = BIG_ENDIAN;
			if (charset == "UTF-8") {
				bytes.writeUTFBytes(cred);
				_credentials = Base64.encode(bytes);
			} else {
				for (i in 0...cred.length) {
					var charCode = cred.charCodeAt(i);
					bytes.writeByte(charCode);
				}
				_credentials = Base64.encode(bytes);
			}
			_credentialsCharset = charset;
		}

		if (channelSet != null)
			channelSet.setCredentials(_credentials, this, _credentialsCharset);
	}

	/**
	 *  Sets the remote credentials that will be passed through to the remote destination
	 *  for authenticating to secondary systems.
	 *
	 *  @param username The username.
	 *  @param password The password.
	 *  @param charset The character set encoding to use while encoding the
	 *  remote credentials. The default is null, which implies the legacy
	 *  charset of ISO-Latin-1. The only other currently supported option is
	 *  &quot;UTF-8&quot;.
	 */
	public function setRemoteCredentials(username:String, password:String, charset:String = null):Void {
		if (username == null && password == null) {
			_remoteCredentials = "";
			_remoteCredentialsCharset = null;
		} else {
			var cred:String = username + ":" + password;
			var bytes = new ByteArray();
			bytes.endian = BIG_ENDIAN;
			if (charset == "UTF-8") {
				bytes.writeUTFBytes(cred);
				_remoteCredentials = Base64.encode(bytes);
			} else {
				for (i in 0...cred.length) {
					var charCode = cred.charCodeAt(i);
					bytes.writeByte(charCode);
				}
				_remoteCredentials = Base64.encode(bytes);
			}
			_remoteCredentialsCharset = charset;
		}
		_sendRemoteCredentials = true;
	}

	/**
	 * Returns true if there are any pending requests for the passed in message.
	 * This method should be overriden by subclasses
	 *
	 * @param msg The message for which the existence of pending requests is checked.
	 *
	 * @return Returns <code>true</code> if there are any pending requests for the
	 * passed in message.
	 *
	 */
	public function hasPendingRequestForMessage(msg:IMessage):Bool {
		return false;
	}

	//--------------------------------------------------------------------------
	//
	// Internal Methods
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 *  Internal hook for ChannelSet to assign credentials when it has authenticated
	 *  successfully via a direct <code>login(...)</code> call to the server or logged
	 *  out directly.
	 */
	private function internalSetCredentials(credentials:String):Void {
		_credentials = credentials;
	}

	//--------------------------------------------------------------------------
	//
	// Protected Methods
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 */
	final private function assertCredentials(value:String):Void {
		if (_credentials != null && (_credentials != value)) {
			var errMsg:ErrorMessage = new ErrorMessage();
			errMsg.faultCode = "Client.Authentication.Error";
			errMsg.faultString = "Credentials specified do not match those used on underlying connection.";
			errMsg.faultDetail = "Channel was authenticated with a different set of credentials than those used for this agent.";
			dispatchEvent(MessageFaultEvent.createEvent(errMsg));
		}
	}

	/**
	 *  @private
	 *  Utility method to flush any pending queued messages to send once we have
	 *  received a clientId from the remote destination.
	 */
	final private function flushClientIdWaitQueue():Void {
		if (_clientIdWaitQueue != null) {
			// If we have a valid clientId, flush all pending messages.
			if (clientId != null) {
				while (_clientIdWaitQueue.length > 0) {
					internalSend(_clientIdWaitQueue.shift());
				}
			}

			if (clientId == null) {
				// If we still don't have a clientId, remove the first queued message and send it.
				// Leave the queue intact to buffer subsequent sends until we get a response/fault
				// back for this one.
				if (_clientIdWaitQueue.length > 0) {
					var saveQueue = _clientIdWaitQueue;
					// Make sure we don't just put it back into the queue - we let the first
					// one through if this is null.
					_clientIdWaitQueue = null;
					internalSend(saveQueue.shift());
					_clientIdWaitQueue = saveQueue;
				} else {
					// Regardless of whether the clientId is defined or not, if the wait queue
					// is empty set it to null to allow the next message to be processed by the
					// send code path rather than being routed to the queue.
					_clientIdWaitQueue = null;
				}
			}
		}
	}

	/**
	 * Handles the authentication fault on the server. If the authenticated flag is true, 
	 * the authentication fault must have been caused by a session expiration on the server.
	 * Set the authenticated state to false and if loginAfterDisconnect flag is enabled,
	 * resend credentials to the server by disconnecting and resending the message again.
	 *
	 *  @param errMsg The Error Message.
	 *  @param msg The message that caused the fault and should be resent once we have
	 *  disconnected/connected causing re-authentication.
	 */
	private function handleAuthenticationFault(errMsg:ErrorMessage, msg:IMessage):Void {
		if (errMsg.faultCode == "Client.Authentication" && authenticated && isCurrentChannelNotNull()) {
			var currentChannel:Channel = getCurrentChannel();
			currentChannel.setAuthenticated(false);

			if ((currentChannel is PollingChannel) && cast(currentChannel, PollingChannel).loginAfterDisconnect) {
				reAuthorize(msg);
				_ignoreFault = true;
			}
		}
	}

	/**
	 *  Used to automatically initialize the <code>channelSet</code> property for the
	 *  MessageAgent before it connects for the first time.
	 *  Subtypes may override to perform custom initialization.
	 *
	 *  @param message The message that needs to be sent.
	 */
	private function initChannelSet(message:IMessage):Void {
		if (_channelSet == null) {
			_channelSetMode = AUTO_CONFIGURED_CHANNELSET;
			internalSetChannelSet(ServerConfig.getChannelSet(destination));
		}

		if (_channelSet.connected && needsConfig && !configRequested) {
			Reflect.setField(message.headers, CommandMessage.NEEDS_CONFIG_HEADER, true);
			configRequested = true;
		}

		_channelSet.connect(this);

		if (_credentials != null)
			channelSet.setCredentials(_credentials, this, _credentialsCharset);
	}

	/**
	 *  Sends a Message from the MessageAgent to its destination using the
	 *  agent's ChannelSet. MessageAgent subclasses must use this method to
	 *  send their messages.
	 *
	 *  @param message The message to send.
	 *
	 *  @param waitForClientId If true the message may be queued until a clientId has been
	 *                         assigned to the agent. In general this is the desired behavior.
	 *                         For special behavior (automatic reconnect and resubscribe) the
	 *                         agent may pass false to override the default queuing behavior.
	 *
	 *  @throws mx.messaging.errors.InvalidDestinationError If no destination is set.
	 */
	private function internalSend(message:IMessage, waitForClientId:Bool = true):Void {
		// If we don't have a client or server assigned clientId, we
		// need to send a single message and then store any subsequent messages
		// in a buffer to be sent once we've gotten back a server-generated
		// clientId. Otherwise, N outbound messages sent before receiving an ack for
		// the first will result in the generation of N different clientIds in the
		// response/fault messages from the server.
		if ((message.clientId == null) && waitForClientId && (clientId == null)) {
			if (_clientIdWaitQueue == null) {
				_clientIdWaitQueue = [];
				// Current message will be sent but subsequent messages sent before
				// its ack/fault will be queued.
			} else {
				_clientIdWaitQueue.push(message);
				return; // We've queued the message and will send it once we get a clientId or the outstanding send fails.
			}
		}

		if (message.clientId == null)
			message.clientId = clientId;

		if (requestTimeout > 0)
			Reflect.setField(message.headers, AbstractMessage.REQUEST_TIMEOUT_HEADER, requestTimeout);

		if (_sendRemoteCredentials) {
			if (!((message is CommandMessage) && (cast(message, CommandMessage).operation == CommandMessage.TRIGGER_CONNECT_OPERATION))) {
				Reflect.setField(message.headers, AbstractMessage.REMOTE_CREDENTIALS_HEADER, _remoteCredentials);
				Reflect.setField(message.headers, AbstractMessage.REMOTE_CREDENTIALS_CHARSET_HEADER, _remoteCredentialsCharset);
				_sendRemoteCredentials = false;
			}
		}

		if (channelSet != null) {
			if (!connected && (_channelSetMode == MANUALLY_ASSIGNED_CHANNELSET))
				_channelSet.connect(this);

			if (channelSet.connected && needsConfig && !configRequested) {
				Reflect.setField(message.headers, CommandMessage.NEEDS_CONFIG_HEADER, true);
				configRequested = true;
			}

			channelSet.send(this, message);
			monitorRpcMessage(message, message);
		} else if (destination != null && destination.length > 0) {
			initChannelSet(message);
			if (channelSet != null) {
				channelSet.send(this, message);
				monitorRpcMessage(message, message);
			}
		} else {
			throw new InvalidDestinationError("The MessageAgent's destination must be set to send messages.");
		}
	}

	/**
	 * This function should be overriden by sublasses to implement reauthentication due to
	 * server session time-out behavior specific to them. In general, it should follow disconnect, 
	 * connect, resend message pattern.
	 *
	 *  @param msg The message that caused the fault and should be resent once we have
	 *  disconnected/connected causing reauthentication.
	 */
	private function reAuthorize(msg:IMessage):Void {
		// Disconnect all message agents from the Channel to make sure the Channel
		// is fully disconnected and Channel#internalConnect gets called which
		// sends the login command to reauthenticate the Channel.
		if (channelSet != null)
			channelSet.disconnectAll();
		internalSend(msg);
	}

	/**
	 *  @private
	 */
	private function getCurrentChannel():Channel {
		return channelSet != null ? channelSet.currentChannel : null;
	}

	/**
	 *  @private
	 */
	private function isCurrentChannelNotNull():Bool {
		return getCurrentChannel() != null;
	}

	/**
	 * Monitor a rpc message that is being send
	 */
	private function monitorRpcMessage(message:IMessage, actualMessage:IMessage):Void {
		// if (NetworkMonitor.isMonitoring()) {
		// 	if ((message is ErrorMessage)) {
		// 		NetworkMonitor.monitorFault(actualMessage, MessageFaultEvent.createEvent(ErrorMessage(message)));
		// 	} else if ((message is AcknowledgeMessage)) {
		// 		NetworkMonitor.monitorResult(message, MessageEvent.createEvent(MessageEvent.RESULT, actualMessage));
		// 	} else {
		// 		NetworkMonitor.monitorInvocation(getNetmonId(), message, this);
		// 	}
		// }
	}

	/**
	 * Return the id for the NetworkMonitor.
	 * @private
	 */
	private function getNetmonId():String {
		return null;
	}
}
