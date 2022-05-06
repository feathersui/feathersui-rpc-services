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

package feathers.messaging.utils;

import feathers.messaging.messages.ActionMessage;
import feathers.messaging.messages.MessageBody;
import feathers.messaging.messages.MessageHeader;
import feathers.messaging.messages.RemotingMessage;
import feathers.messaging.messages.MessagePerformanceInfo;
import feathers.messaging.messages.HTTPRequestMessage;
import feathers.messaging.messages.ErrorMessage;
import feathers.messaging.messages.CommandMessageExt;
import feathers.messaging.messages.CommandMessage;
import feathers.messaging.messages.AsyncMessageExt;
import feathers.messaging.messages.AsyncMessage;
import feathers.messaging.messages.AcknowledgeMessageExt;
import feathers.messaging.messages.AcknowledgeMessage;
import feathers.data.ArrayCollection;

/**
	The RpcClassAliasInitializer class registers all 
	classes for AMF serialization needed by the Flex RPC library.
**/
class RpcClassAliasInitializer {
	/**
		In the event that an application does not use the Flex UI classes which processes
		the <code>[RemoteClass(alias="")]</code> bootstrap code, this function registers all the
		classes for AMF serialization needed by the Flex RPC library.
	**/
	public static function registerClassAliases():Void {
		#if (openfl >= "9.2.0")
		#if !flash
		openfl.Lib.registerClassAlias("flex.messaging.io.amf.MessageHeader", MessageHeader);
		openfl.Lib.registerClassAlias("flex.messaging.io.amf.MessageBody", MessageBody);
		openfl.Lib.registerClassAlias("flex.messaging.io.amf.ActionMessage", ActionMessage);
		#end

		// Flex classes
		openfl.Lib.registerClassAlias("flex.messaging.io.ArrayCollection", ArrayCollection);
		// openfl.Lib.registerClassAlias("flex.messaging.io.ArrayList", ArrayList);
		// openfl.Lib.registerClassAlias("flex.messaging.io.ObjectProxy", ObjectProxy);

		// rpc classes
		openfl.Lib.registerClassAlias("flex.messaging.messages.AcknowledgeMessage", AcknowledgeMessage);
		openfl.Lib.registerClassAlias("DSK", AcknowledgeMessageExt);
		openfl.Lib.registerClassAlias("flex.messaging.messages.AsyncMessage", AsyncMessage);
		openfl.Lib.registerClassAlias("DSA", AsyncMessageExt);
		openfl.Lib.registerClassAlias("flex.messaging.messages.CommandMessage", CommandMessage);
		openfl.Lib.registerClassAlias("DSC", CommandMessageExt);
		// openfl.Lib.registerClassAlias("flex.messaging.config.ConfigMap", ConfigMap);
		openfl.Lib.registerClassAlias("flex.messaging.messages.ErrorMessage", ErrorMessage);
		openfl.Lib.registerClassAlias("flex.messaging.messages.HTTPMessage", HTTPRequestMessage);
		openfl.Lib.registerClassAlias("flex.messaging.messages.MessagePerformanceInfo", MessagePerformanceInfo);
		openfl.Lib.registerClassAlias("flex.messaging.messages.RemotingMessage", RemotingMessage);
		// openfl.Lib.registerClassAlias("flex.messaging.messages.SOAPMessage", SOAPMessage);
		#elseif flash
		// Flex classes
		untyped __global__["flash.net.registerClassAlias"]("flex.messaging.io.ArrayCollection", ArrayCollection);
		// untyped __global__["flash.net.registerClassAlias"]("flex.messaging.io.ArrayList", ArrayList);
		// untyped __global__["flash.net.registerClassAlias"]("flex.messaging.io.ObjectProxy", ObjectProxy);

		// rpc classes
		untyped __global__["flash.net.registerClassAlias"]("flex.messaging.messages.AcknowledgeMessage", AcknowledgeMessage);
		untyped __global__["flash.net.registerClassAlias"]("DSK", AcknowledgeMessageExt);
		untyped __global__["flash.net.registerClassAlias"]("flex.messaging.messages.AsyncMessage", AsyncMessage);
		untyped __global__["flash.net.registerClassAlias"]("DSA", AsyncMessageExt);
		untyped __global__["flash.net.registerClassAlias"]("flex.messaging.messages.CommandMessage", CommandMessage);
		untyped __global__["flash.net.registerClassAlias"]("DSC", CommandMessageExt);
		// untyped __global__["flash.net.registerClassAlias"]("flex.messaging.config.ConfigMap", ConfigMap);
		untyped __global__["flash.net.registerClassAlias"]("flex.messaging.messages.ErrorMessage", ErrorMessage);
		untyped __global__["flash.net.registerClassAlias"]("flex.messaging.messages.HTTPMessage", HTTPRequestMessage);
		untyped __global__["flash.net.registerClassAlias"]("flex.messaging.messages.MessagePerformanceInfo", MessagePerformanceInfo);
		untyped __global__["flash.net.registerClassAlias"]("flex.messaging.messages.RemotingMessage", RemotingMessage);
		// untyped __global__["flash.net.registerClassAlias"]("flex.messaging.messages.SOAPMessage", SOAPMessage);

		// management classes - these are used in the flexadmin GUI program,
		// so will get registered in the usual way, don't do them here
		// untyped __global__["flash.net.registerClassAlias"]("flex.management.jmx.MBeanAttributeInfo", MBeanAttributeInfo);
		// untyped __global__["flash.net.registerClassAlias"]("flex.management.jmx.MBeanConstructorInfo", MBeanConstructorInfo);
		// untyped __global__["flash.net.registerClassAlias"]("flex.management.jmx.MBeanFeatureInfo", MBeanFeatureInfo);
		// untyped __global__["flash.net.registerClassAlias"]("flex.management.jmx.MBeanInfo", MBeanInfo);
		// untyped __global__["flash.net.registerClassAlias"]("flex.management.jmx.MBeanOperationInfo", MBeanOperationInfo);
		// untyped __global__["flash.net.registerClassAlias"]("flex.management.jmx.MBeanParameterInfo", MBeanParameterInfo);
		// untyped __global__["flash.net.registerClassAlias"]("flex.management.jmx.ObjectInstance", ObjectInstance);
		// untyped __global__["flash.net.registerClassAlias"]("flex.management.jmx.ObjectName", ObjectName);
		#end
	}
}
