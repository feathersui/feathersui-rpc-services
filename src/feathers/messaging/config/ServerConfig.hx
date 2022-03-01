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

package feathers.messaging.config;

import feathers.data.ArrayCollection;
import feathers.messaging.errors.InvalidChannelError;
import feathers.messaging.errors.InvalidDestinationError;
import openfl.Lib;
import openfl.errors.ArgumentError;

/**
 *  This class provides access to the server messaging configuration information.
 *  This class encapsulates information from the services-config.xml file on the client
 *  and is used by the messaging system to provide configured ChannelSets and Channels
 *  to the messaging framework.
 *
 *  The XML source is provided during the compilation process.
 *  However, there is currently no internal restriction preventing the
 *  acquisition of this XML data by other means, such as network, local file
 *  system, or shared object at runtime.
 */
@:access(feathers.messaging.MessageAgent)
class ServerConfig {
	//--------------------------------------------------------------------------
	//
	// Static Constants
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 *  Channel config parsing constant.
	 */
	public static final CLASS_ATTR:String = "type";

	/**
	 *  @private
	 *  Channel config parsing constant.
	 */
	public static final URI_ATTR:String = "uri";

	//--------------------------------------------------------------------------
	//
	// Class variables
	//
	//--------------------------------------------------------------------------
	//--------------------------------------------------------------------------
	//
	// Static Variables
	//
	//--------------------------------------------------------------------------

	/**
	 *  @private
	 *  The server configuration data.
	 */
	public static var serverConfigData:Xml;

	/**
	 *  @private
	 *  Caches shared ChannelSets, keyed by strings having the format:
	 *  <list of comma delimited channel ids>:[true|false] - where the final
	 *  flag indicates whether the ChannelSet should be used for clustered
	 *  destinations or not.
	 */
	private static var _channelSets:Dynamic = {};

	/**
	 *  @private
	 *  Caches shared clustered Channel instances keyed by Channel id.
	 */
	private static var _clusteredChannels:Dynamic = {};

	/**
	 *  @private
	 *  Caches shared unclustered Channel instances keyed by Channel id.
	 */
	private static var _unclusteredChannels:Dynamic = {};

	/**
	 * @private
	 * Keeps track of Channel endpoint uris whose configuration has been fetched
	 * from the server.
	 */
	private static var _configFetchedChannels:Dynamic;

	//--------------------------------------------------------------------------
	//
	// Static Properties
	//
	//--------------------------------------------------------------------------
	//----------------------------------
	//  xml
	//----------------------------------

	/**
	 *  The XML configuration; this value must contain the relevant portions of
	 *  the &lt;services&gt; tag from the services-config.xml file.
	 *  
	 */
	public static var xml(get, set):Xml;

	private static function get_xml():Xml {
		if (serverConfigData == null)
			serverConfigData = Xml.parse("<services/>");
		return serverConfigData;
	}

	/**
	 *  @private
	 */
	private static function set_xml(value:Xml):Xml {
		serverConfigData = value;
		// Reset cached Channels and ChannelSets.
		_channelSets = {};
		_clusteredChannels = {};
		_unclusteredChannels = {};
		return serverConfigData;
	}

	//----------------------------------
	//  channelSetFactory
	//----------------------------------

	/**
	 *  @private
	 *  A Class factory to use to generate auto-instantiated ChannelSet instances
	 *  as is done in getChannelSet(String).
	 *  Default factory is the base ChannelSet class.
	 */
	public static var channelSetFactory:Class<ChannelSet> = ChannelSet;

	//--------------------------------------------------------------------------
	//
	// Static Methods
	//
	//--------------------------------------------------------------------------

	/**
	 *  This method ensures that the destinations specified contain identical
	 *  channel definitions.
	 *  If the channel definitions between the two destinations specified are
	 *  not identical this method will throw an ArgumentError.
	 *
	 *  @param   destinationA:String first destination to compare against
	 *  @param   destinationB:String second destination to compare channels with
	 *  @throw   ArgumentError if the channel definitions of the specified
	 *           destinations aren't identical.
	 *  
	 */
	public static function checkChannelConsistency(destinationA:String, destinationB:String):Void {
		var channelIdsA = getChannelIdList(destinationA);
		var channelIdsB = getChannelIdList(destinationB);
		if (compareArrays(channelIdsA, channelIdsB) != 0)
			throw new ArgumentError("Specified destinations are not channel consistent");
	}

	private static function compareArrays(a:Array<String>, b:Array<String>):Int {
		if (a == null && b == null)
			return 0;

		if (a == null)
			return 1;

		if (b == null)
			return -1;

		var result:Int = 0;

		if (a.length != b.length) {
			if (a.length < b.length)
				result = -1;
			else
				result = 1;
		} else {
			for (i in 0...a.length) {
				var ai = a[i];
				var bi = b[i];
				if (ai != bi) {
					if (ai < bi) {
						return -1;
					} else {
						return 1;
					}
				}
			}
		}

		return result;
	}

	/**
	 *  Returns a shared instance of the configured Channel.
	 *
	 *  @param id The id of the desired Channel.
	 *
	 *  @param clustered True if the Channel will be used in a clustered
	 *                   fashion; otherwise false.
	 *
	 *  @return The Channel instance.
	 *
	 *  @throws mx.messaging.errors.InvalidChannelError If no Channel has the specified id.
	 *  
	 */
	public static function getChannel(id:String, clustered:Bool = false):Channel {
		var channel:Channel;

		if (!clustered) {
			if (Reflect.hasField(_unclusteredChannels, id)) {
				return Reflect.field(_unclusteredChannels, id);
			} else {
				channel = createChannel(id);
				Reflect.setField(_unclusteredChannels, id, channel);
				return channel;
			}
		} else {
			if (Reflect.hasField(_clusteredChannels, id)) {
				return Reflect.field(_clusteredChannels, id);
			} else {
				channel = createChannel(id);
				Reflect.setField(_clusteredChannels, id, channel);
				return channel;
			}
		}
	}

	/**
	 *  Returns a shared ChannelSet for use with the specified destination
	 *  belonging to the service that handles the specified message type.
	 *
	 *  @param destinationId The target destination id.
	 *
	 *  @return The ChannelSet.
	 *
	 *  @throws mx.messaging.errors.InvalidDestinationError If the specified destination
	 *                                  does not have channels and the application
	 *                                  did not define default channels.
	 *  
	 */
	public static function getChannelSet(destinationId:String):ChannelSet {
		var destinationConfig = getDestinationConfig(destinationId);
		return internalGetChannelSet(destinationConfig, destinationId);
	}

	/**
	 *  Returns the property information for the specified destination
	 *
	 *  @param destinationId The id of the desired destination.
	 *
	 *  @return XMLList containing the &lt;property&gt; tag information.
	 *
	 *  @throws mx.messaging.errors.InvalidDestinationError If the specified destination is not found.
	 *  
	 */
	public static function getProperties(destinationId:String):Array<Xml> {
		var destinations:Array<Xml> = [];
		for (destination in xml.elementsNamed("destination")) {
			if (destination.get("id") == destinationId) {
				destinations.push(destination);
			}
		}

		if (destinations.length > 0) {
			var properties:Array<Xml> = [];
			for (destination in destinations) {
				for (property in destination.elementsNamed("properties")) {
					properties.push(property);
				}
			}
			return properties;
		} else {
			var message:String = 'Unknown destination \'${destinationId}\'.';
			throw new InvalidDestinationError(message);
		}

		// return destination;
	}

	//--------------------------------------------------------------------------
	//
	// Static Internal Methods
	//
	//--------------------------------------------------------------------------

	/**
	 *  This method returns true iff the channelset specified has channels with
	 *  ids or uris that match those found in the destination specified.
	 *  
	 */
	private static function channelSetMatchesDestinationConfig(channelSet:ChannelSet, destination:String):Bool {
		if (channelSet != null) {
			if (compareArrays(channelSet.channelIds, getChannelIdList(destination)) == 0)
				return true;

			// if any of the specified channelset channelIds do not match then
			// we have to move to comparing the uris, as the ids could be null
			// in the specified channelset.
			var csUris:Array<String> = [];
			var csChannels = channelSet.channels;
			for (i in 0...csChannels.length)
				csUris.push(csChannels[i].uri);

			var ids = getChannelIdList(destination);
			var dsUris:Array<String> = [];
			for (j in 0...ids.length) {
				var channelConfig:Xml = null;
				for (channels in xml.elementsNamed("channels")) {
					for (channel in channels.elementsNamed("channel")) {
						if (channel.get("id") == ids[j]) {
							channelConfig = channel;
							break;
						}
					}
				}
				if (channelConfig == null) {
					continue;
				}
				// uri might be undefined when client-load-balancing urls are specified.
				var dsUri:String = null;
				for (endpoint in channelConfig.elementsNamed("endpoint")) {
					if (endpoint.exists(URI_ATTR)) {
						dsUri = endpoint.get(URI_ATTR);
						break;
					}
				}
				if (dsUri != null)
					dsUris.push(dsUri);
			}

			return compareArrays(csUris, dsUris) == 0;
		}
		return false;
	}

	/**
	 * @private
	 * returns if the specified endpoint has been fetched already
	 */
	private static function fetchedConfig(endpoint:String):Bool {
		return _configFetchedChannels != null && Reflect.field(_configFetchedChannels, endpoint) != null;
	}

	/**
	 *  @private
	 *  This method returns a list of the channel ids for the given destination
	 *  configuration. If no channels exist for the destination, it returns a
	 *  list of default channel ids for the applcation
	 */
	private static function getChannelIdList(destination:String):Array<String> {
		var destinationConfig:Xml = getDestinationConfig(destination);
		return destinationConfig != null ? getChannelIds(destinationConfig) : getDefaultChannelIds();
	}

	/**
	 *  @private
	 *  Used by the Channels to determine whether the Channel should request
	 *  dynamic configuration from the server for its MessageAgents.
	 */
	private static function needsConfig(channel:Channel):Bool {
		// Configuration for the endpoint has not been fetched by some other channel.
		if (_configFetchedChannels == null || Reflect.field(_configFetchedChannels, channel.endpoint) == null) {
			var channelSets = channel.channelSets;
			var m:Int = channelSets.length;
			for (i in 0...m) {
				// If the channel belongs to an advanced ChannelSet, always fetch runtime config.
				if (Lib.getQualifiedClassName(channelSets[i]).indexOf("Advanced") != -1)
					return true;

				// Otherwise, only fetch if a connected MessageAgent requires it.
				var messageAgents = channelSets[i].messageAgents;
				var n:Int = messageAgents.length;
				for (j in 0...n) {
					if (messageAgents[j].needsConfig)
						return true;
				}
			}
		}
		return false;
	}

	/**
	 *  @private
	 *  This method updates the xml with serverConfig object returned from the
	 *  server during initial client connect
	 */
	private static function updateServerConfigData(serverConfig:#if flash ConfigMap #else Any #end, endpoint:String = null):Void {
		if (serverConfig != null) {
			if (endpoint != null) {
				// Add the endpoint uri to the list of uris whose configuration
				// has been fetched.
				if (_configFetchedChannels == null)
					_configFetchedChannels = {};

				Reflect.setField(_configFetchedChannels, endpoint, true);
			}

			var newServices = Xml.createElement("services");
			convertToXML(serverConfig, newServices);

			// Update default-channels of the application.
			for (defaultChannels in xml.elementsNamed("default-channels")) {
				xml.removeChild(defaultChannels);
			}
			for (defaultChannels in newServices.elementsNamed("default-channels")) {
				xml.addChild(defaultChannels);
			}

			// Update the service destinations.
			for (newService in newServices.elementsNamed("service")) {
				var hasOldService = false;
				for (oldService in xml.elementsNamed("service")) {
					// The service already exists, update its destinations.
					if (oldService.get("id") == newService.get("id")) {
						hasOldService = true;
						for (newDestination in newService.elementsNamed("destination")) {
							for (oldDestination in oldService.elementsNamed("destination")) {
								if (oldDestination.get("id") == newDestination.get("id")) {
									oldService.removeChild(oldDestination);
								}
							}
							oldService.addChild(Xml.parse(newDestination.toString()));
						}
					}
				}
				if (!hasOldService) {
					// The service does not exist which means that this is either a new
					// service with its destinations, or a proxy service (eg. GatewayService)
					// with configuration for existing destinations for other services.
					for (newDestination in newService.elementsNamed("destination")) {
						for (oldDestination in xml.elementsNamed("destination")) {
							if (oldDestination.get("id") == newDestination.get("id")) {
								newService.removeChild(newDestination);
								// Replace the existing destination.
								xml.removeChild(oldDestination);
								xml.addChild(newDestination); // Destination ids are unique.
							}
						}
					}

					if (newService.iterator().hasNext()) // Add the new service.
						xml.addChild(newService);
				}
			}

			// Update the channels
			var newChannelsIterator = newServices.elementsNamed("channels");
			if (newChannelsIterator.hasNext()) {
				var oldChannelsIterator = xml.elementsNamed("channels");
				if (!oldChannelsIterator.hasNext()) {
					while (newChannelsIterator.hasNext()) {
						xml.addChild(newChannelsIterator.next());
					}
				}
			}
		}
	}

	//--------------------------------------------------------------------------
	//
	// Static Private Methods
	//
	//--------------------------------------------------------------------------

	/**
	 *  Helper method that builds a new Channel instance based on the
	 *  configuration for the specified id.
	 *
	 *  @param id The id for the configured Channel to build.
	 *
	 *  @return The Channel instance.
	 *
	 *  @throws mx.messaging.errors.InvalidChannelError If no configuration data for the specified
	 *                             id exists.
	 *  
	 */
	private static function createChannel(channelId:String):Channel {
		var message:String;

		var channelConfig:Xml = null;
		for (channels in xml.elementsNamed("channels")) {
			for (channel in channels.elementsNamed("channel")) {
				if (channel.get("id") == channelId) {
					channelConfig = channel;
					break;
				}
			}
		}
		if (channelConfig == null) {
			message = 'Channel \'$channelId\' does not exist in the configuration.';
			throw new InvalidChannelError(message);
		}

		var channel:Channel = null;
		var className:String = channelConfig.get(CLASS_ATTR);
		for (endpoint in channelConfig.elementsNamed("endpoint")) {
			/// uri might be undefined when client-load-balancing urls are specified.
			var uri:String = endpoint.get(URI_ATTR);
			try {
				var channelClass = Lib.getDefinitionByName(className);
				channel = Type.createInstance(channelClass, [channelId, uri]);
				channel.applySettings(channelConfig);

				// If we have an WSRP_ENCODED_CHANNEL in FlashVars,
				// use that instead of uri configured in the config file
				if (LoaderConfig.parameters != null && LoaderConfig.parameters.WSRP_ENCODED_CHANNEL != null)
					channel.url = LoaderConfig.parameters.WSRP_ENCODED_CHANNEL;
			} catch (e) {
				message = 'The channel class \'$className\' specified was not found.';
				throw new InvalidChannelError(message);
			}
		}
		return channel;
	}

	/**
	 * Converts the ConfigMap of properties into XML
	 *  
	 */
	private static function convertToXML(config:#if flash ConfigMap #else Any #end, configXML:Xml):Void {
		for (propertyKey in Reflect.fields(config)) {
			var propertyValue = Reflect.field(config, propertyKey);

			if ((propertyValue is String)) {
				if (propertyKey == "") {
					// Add as a value
					configXML.addChild(Xml.createPCData(Std.string(propertyValue)));
				} else {
					// Add as an attribute
					configXML.set(propertyKey, Std.string(propertyValue));
				}
			} else if ((propertyValue is ArrayCollection) || (propertyValue is Array)) {
				var propertyValueList:Array<Dynamic>;
				if ((propertyValue is ArrayCollection))
					propertyValueList = cast(propertyValue, ArrayCollection<Dynamic>).toArray();
				else
					propertyValueList = cast(propertyValue, Array<Dynamic>);

				for (i in 0...propertyValueList.length) {
					var propertyXML1 = Xml.createElement(propertyKey);
					configXML.addChild(propertyXML1);
					convertToXML(#if flash Std.downcast(propertyValueList[i], ConfigMap) #else propertyValueList[i] #end, propertyXML1);
				}
			} else // assuming that it is ConfigMap
			{
				var propertyXML2 = Xml.createElement(propertyKey);
				configXML.addChild(propertyXML2);
				convertToXML(#if flash Std.downcast(propertyValue, ConfigMap) #else propertyValue #end, propertyXML2);
			}
		}
	}

	private static function getChannelIds(destinationConfig:Xml):Array<String> {
		var result:Array<String> = [];
		for (channels in destinationConfig.elementsNamed("channels")) {
			for (channel in channels.elementsNamed("channel")) {
				result.push(channel.get("ref"));
			}
		}
		return result;
	}

	/**
	 * @private
	 * This method returns a list of default channel ids for the application
	 */
	private static function getDefaultChannelIds():Array<String> {
		var result:Array<String> = [];
		for (channels in xml.elementsNamed("default-channels")) {
			for (channel in channels.elementsNamed("channel")) {
				result.push(channel.get("ref"));
			}
		}
		return result;
	}

	/**
	 *  Returns the destination XML data specific to the destination and message
	 *  type specified. Returns null if the destination is not found.
	 *  
	 */
	private static function getDestinationConfig(destinationId:String):Xml {
		for (destination in xml.elementsNamed("destination")) {
			if (destination.get("id") == destinationId) {
				// Destination ids are unique among services
				return destination;
			}
		}
		return null;
	}

	/**
	 *  Helper method to look up and return a cached ChannelSet (and build and
	 *  cache an instance if necessary).
	 *
	 *  @param destinationConfig The configuration for the target destination.
	 *  @param destinatonId The id of the target destination.
	 *
	 *  @return The ChannelSet.
	 *  
	 */
	private static function internalGetChannelSet(destinationConfig:Xml, destinationId:String):ChannelSet {
		var channelIds:Array<String>;
		var clustered:Bool;

		if (destinationConfig == null) {
			channelIds = getDefaultChannelIds();
			if (channelIds.length == 0) {
				var message:String = 'Destination \'${destinationId}\' either does not exist or the destination has no channels defined (and the application does not define any default channels.)';
				throw new InvalidDestinationError(message);
			}
			clustered = false;
		} else {
			channelIds = getChannelIds(destinationConfig);
			clustered = false;
			for (properties in destinationConfig.elementsNamed("properties")) {
				for (network in properties.elementsNamed("network")) {
					for (cluster in properties.elementsNamed("cluster")) {
						clustered = true;
						break;
					}
				}
			}
		}

		var channelSetId:String = channelIds.join(",") + ":" + clustered;

		if (Reflect.hasField(_channelSets, channelSetId)) {
			return Reflect.field(_channelSets, channelSetId);
		} else {
			var channelSet:ChannelSet = Type.createInstance(channelSetFactory, [channelIds, clustered]);
			var heartbeatMillis:Int = 0;
			for (flexClient in serverConfigData.elementsNamed("flex-client")) {
				for (heartbeatIntervalMillis in flexClient.elementsNamed("heartbeat-interval-millis")) {
					heartbeatMillis = Std.parseInt(heartbeatIntervalMillis.nodeValue);
				}
			}
			if (heartbeatMillis > 0)
				channelSet.heartbeatInterval = heartbeatMillis;
			if (clustered)
				channelSet.initialDestinationId = destinationId;
			Reflect.setField(_channelSets, channelSetId, channelSet);
			return channelSet;
		}
	}
}
