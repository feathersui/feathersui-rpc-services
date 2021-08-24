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

import feathers.messaging.errors.InvalidDestinationError;
import openfl.Lib;
import openfl.errors.Error;

/**
 *  This class provides access to the server messaging configuration information.
 *  This class encapsulates information from the services-config.xml file on the client
 *  and is used by the messaging system to provide configured ChannelSets and Channels
 *  to the messaging framework.
 *
 *  <p>The XML source is provided during the compilation process.
 *  However, there is currently no internal restriction preventing the
 *  acquisition of this XML data by other means, such as network, local file
 *  system, or shared object at runtime.</p>
 *  
 *  @langversion 3.0
 *  @playerversion Flash 9
 *  @playerversion AIR 1.1
 *  @productversion BlazeDS 4
 *  @productversion LCDS 3 
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
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion BlazeDS 4
	 *  @productversion LCDS 3 
	 */
	@:flash.property
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
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion BlazeDS 4
	 *  @productversion LCDS 3 
	 */
	public static function checkChannelConsistency(destinationA:String, destinationB:String):Void {
		throw new Error("checkChannelConsistency() not implemented");
		// var channelIdsA = getChannelIdList(destinationA);
		// var channelIdsB = getChannelIdList(destinationB);
		// if (ObjectUtil.compare(channelIdsA, channelIdsB) != 0)
		// 	throw new ArgumentError("Specified destinations are not channel consistent");
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
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion BlazeDS 4
	 *  @productversion LCDS 3 
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
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion BlazeDS 4
	 *  @productversion LCDS 3 
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
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion BlazeDS 4
	 *  @productversion LCDS 3 
	 */
	public static function getProperties(destinationId:String):Any /*XMLList*/ {
		// var destination:XMLList = xml..destination.(@id == destinationId);

		// if (destination.length() > 0)
		// {
		// 	return destination.properties;
		// }
		// else
		{
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
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion BlazeDS 4
	 *  @productversion LCDS 3 
	 */
	private static function channelSetMatchesDestinationConfig(channelSet:ChannelSet, destination:String):Bool {
		// if (channelSet != null)
		// {
		// 	if (ObjectUtil.compare(channelSet.channelIds, getChannelIdList(destination)) == 0)
		// 		return true;

		// 	// if any of the specified channelset channelIds do not match then
		// 	// we have to move to comparing the uris, as the ids could be null
		// 	// in the specified channelset.
		// 	var csUris:Array = [];
		// 	var csChannels = channelSet.channels;
		// 	for (i in 0...csChannels.length)
		// 		csUris.push(csChannels[i].uri);

		// 	var ids = getChannelIdList(destination);
		// 	var dsUris:Array = [];
		// 	var dsChannels:XMLList;
		// 	var channelConfig:XML;
		// 	var endpoint:XML;
		// 	var dsUri:String;
		// 	for (j in 0...ids.length)
		// 	{
		// 		dsChannels = xml.channels.channel.(@id == ids[j]);
		// 		channelConfig = dsChannels[0];
		// 		endpoint = channelConfig.endpoint;
		// 		// uri might be undefined when client-load-balancing urls are specified.
		// 		dsUri = endpoint.length() > 0? endpoint[0].attribute(URI_ATTR).toString() : null;
		// 		if (dsUri != null)
		// 			dsUris.push(dsUri);
		// 	}

		// 	return ObjectUtil.compare(csUris, dsUris) == 0;

		// }
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
	private static function updateServerConfigData(serverConfig:Any /*ConfigMap*/, endpoint:String = null):Void {
		// if (serverConfig != null)
		// {
		// 	if (endpoint != null)
		// 	{
		// 		// Add the endpoint uri to the list of uris whose configuration
		// 		// has been fetched.
		// 		if (_configFetchedChannels == null)
		// 			_configFetchedChannels = {};

		// 		_configFetchedChannels[endpoint] = true;
		// 	}

		// 	var newServices:XML = <services></services>;
		// 	convertToXML(serverConfig, newServices);

		// 	// Update default-channels of the application.
		// 	xml["default-channels"] = newServices["default-channels"];

		// 	// Update the service destinations.
		// 	for each (var newService:XML in newServices..service)
		// 	{
		// 		var oldServices:XMLList = xml.service.(@id == newService.@id);
		// 		var oldDestinations:XMLList;
		// 		var newDestination:XML;
		// 		// The service already exists, update its destinations.
		// 		if (oldServices.length() != 0)
		// 		{
		// 			var oldService:XML = oldServices[0]; // Service ids are unique.
		// 			for each (newDestination in newService..destination)
		// 			{
		// 				oldDestinations = oldService.destination.(@id == newDestination.@id);
		// 				if (oldDestinations.length() != 0)
		// 					delete oldDestinations[0]; // Destination ids are unique.
		// 				oldService.appendChild(newDestination.copy());
		// 			}
		// 		}
		// 		// The service does not exist which means that this is either a new
		// 		// service with its destinations, or a proxy service (eg. GatewayService)
		// 		// with configuration for existing destinations for other services.
		// 		else
		// 		{
		// 			for each (newDestination in newService..destination)
		// 			{
		// 				oldDestinations = xml..destination.(@id == newDestination.@id);
		// 				if (oldDestinations.length() != 0) // Replace the existing destination.
		// 				{
		// 					oldDestinations[0] = newDestination[0].copy(); // Destination ids are unique.
		// 					delete newService..destination.(@id == newDestination.@id)[0];
		// 				}
		// 			}

		// 			if (newService.children().length() > 0) // Add the new service.
		// 				xml.appendChild(newService);
		// 		}
		// 	}

		// 	// Update the channels
		// 	var newChannels:XMLList = newServices.channels;
		// 	if (newChannels.length() > 0)
		// 	{
		// 		var oldChannels:XML = xml.channels[0];
		// 		if (oldChannels == null || oldChannels.length() == 0)
		// 		{
		// 			xml.appendChild(newChannels);
		// 		}
		// 	}
		// }
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
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion BlazeDS 4
	 *  @productversion LCDS 3 
	 */
	private static function createChannel(channelId:String):Channel {
		throw new Error("createChannel() not implemented");
		// var message:String;

		// var channels:XMLList = xml.channels.channel.(@id == channelId);
		// if (channels.length() == 0) {
		// 	message = resourceManager.getString("messaging", "unknownChannelWithId", [channelId]);
		// 	throw new InvalidChannelError(message);
		// }

		// var channelConfig:XML = channels[0];
		// var className:String = channelConfig.attribute(CLASS_ATTR).toString();
		// var endpoint:XMLList = channelConfig.endpoint;
		// /// uri might be undefined when client-load-balancing urls are specified.
		// var uri:String = endpoint.length() > 0 ? endpoint[0].attribute(URI_ATTR).toString() : null;
		// var channel:Channel = null;
		// try {
		// 	var channelClass:Class = getDefinitionByName(className)
		// 	as
		// 	Class;
		// 	channel = new channelClass(channelId, uri);
		// 	channel.applySettings(channelConfig);

		// 	// If we have an WSRP_ENCODED_CHANNEL in FlashVars,
		// 	// use that instead of uri configured in the config file
		// 	if (LoaderConfig.parameters != null && LoaderConfig.parameters.WSRP_ENCODED_CHANNEL != null)
		// 		channel.url = LoaderConfig.parameters.WSRP_ENCODED_CHANNEL;
		// } catch (e:ReferenceError) {
		// 	message = resourceManager.getString("messaging", "unknownChannelClass", [className]);
		// 	throw new InvalidChannelError(message);
		// }
		// return channel;
	}

	/**
	 * Converts the ConfigMap of properties into XML
	 *  
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion BlazeDS 4
	 *  @productversion LCDS 3 
	 */
	private static function convertToXML(config:Any /*ConfigMap*/, configXML:Xml):Void {
		throw new Error("convertToXML() not implemented");
		// for (var propertyKey:Object in config)
		// {
		// 	var propertyValue:Object = config[propertyKey];

		// 	if ((propertyValue is String))
		// 	{
		// 		if (propertyKey == "")
		// 		{
		// 			// Add as a value
		// 			configXML.appendChild(propertyValue);
		// 		}
		// 		else
		// 		{
		// 			// Add as an attribute
		// 			configXML.@[propertyKey] = propertyValue;
		// 		}
		// 	}
		// 	else if ((propertyValue is ArrayCollection) || (propertyValue is Array))
		// 	{
		// 		var propertyValueList:Array;
		// 		if ((propertyValue is ArrayCollection))
		// 			propertyValueList = ArrayCollection(propertyValue).toArray();
		// 		else
		// 			propertyValueList = propertyValue as Array;

		// 		for (var i:Int = 0; i < propertyValueList.length; i++)
		// 		{
		// 			var propertyXML1:XML = <{propertyKey}></{propertyKey}>
		// 			configXML.appendChild(propertyXML1);
		// 			convertToXML(propertyValueList[i] as ConfigMap, propertyXML1);
		// 		}
		// 	}
		// 	else // assuming that it is ConfigMap
		// 	{
		// 		var propertyXML2:XML = <{propertyKey}></{propertyKey}>
		// 		configXML.appendChild(propertyXML2);
		// 		convertToXML(propertyValue as ConfigMap, propertyXML2);
		// 	}
		// }
	}

	private static function getChannelIds(destinationConfig:Xml):Array<String> {
		throw new Error("getChannelIds() not implemented");
		// var result:Array = [];
		// var channels:XMLList = destinationConfig.channels.channel;
		// var n:Int = channels.length();
		// for (i in 0...n) {
		// 	result.push(channels[i].@ref.toString() );
		// }
		// return result;
	}

	/**
	 * @private
	 * This method returns a list of default channel ids for the application
	 */
	private static function getDefaultChannelIds():Array<String> {
		throw new Error("getDefaultChannelIds() not implemented");
		// var result:Array = [];
		// var channels:XMLList = xml["default-channels"].channel;
		// var n:Int = channels.length();
		// for (i in 0...n) {
		// 	result.push(channels[i].@ref.toString() );
		// }
		// return result;
	}

	/**
	 *  Returns the destination XML data specific to the destination and message
	 *  type specified. Returns null if the destination is not found.
	 *  
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion BlazeDS 4
	 *  @productversion LCDS 3 
	 */
	private static function getDestinationConfig(destinationId:String):Xml {
		throw new Error("getDestinationConfig() not implemented");
		// var destinations:XMLList = xml..destination.(@id == destinationId);
		// var destinationCount:Int = destinations.length();
		// if (destinationCount == 0) {
		// 	return null;
		// } else {
		// 	// Destination ids are unique among services
		// 	return destinations[0];
		// }
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
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion BlazeDS 4
	 *  @productversion LCDS 3 
	 */
	private static function internalGetChannelSet(destinationConfig:Xml, destinationId:String):ChannelSet {
		throw new Error("internalGetChannelSet() not implemented");
		// var channelIds:Array<String>;
		// var clustered:Bool;

		// if (destinationConfig == null) {
		// 	channelIds = getDefaultChannelIds();
		// 	if (channelIds.length == 0) {
		// 		var message:String = 'Destination \'${destinationId}\' either does not exist or the destination has no channels defined (and the application does not define any default channels.)';
		// 		throw new InvalidDestinationError(message);
		// 	}
		// 	clustered = false;
		// } else {
		// 	channelIds = getChannelIds(destinationConfig);
		// 	clustered = (destinationConfig.properties.network.cluster.length() > 0) ? true : false;
		// }

		// var channelSetId:String = channelIds.join(",") + ":" + clustered;

		// if (channelSetId in _channelSets) {
		// 	return _channelSets[channelSetId];
		// } else {
		// 	var channelSet:ChannelSet = Type.createInstance(channelSetFactory, [channelIds, clustered]);
		// 	var heartbeatMillis:Int = serverConfigData["flex-client"]["heartbeat-interval-millis"];
		// 	if (heartbeatMillis > 0)
		// 		channelSet.heartbeatInterval = heartbeatMillis;
		// 	if (clustered)
		// 		channelSet.initialDestinationId = destinationId;
		// 	_channelSets[channelSetId] = channelSet;
		// 	return channelSet;
		// }
	}
}
