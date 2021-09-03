package feathers.messaging.utils;

#if flash
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
 *  The RpcClassAliasInitializer class registers all 
 * classes for AMF serialization needed by the Flex RPC library.
 *
 *  @langversion 3.0
 *  @playerversion Flash 10
 *  @playerversion AIR 2.5
 *  @productversion Flex 4.5
 */
class RpcClassAliasInitializer {
	/**
	 * In the event that an application does not use the Flex UI classes which processes
	 * the <code>[RemoteClass(alias="")]</code> bootstrap code, this function registers all the
	 * classes for AMF serialization needed by the Flex RPC library.
	 *
	 *  @langversion 3.0
	 *  @playerversion Flash 10
	 *  @playerversion AIR 2.5
	 *  @productversion Flex 4.5
	 */
	public static function registerClassAliases():Void {
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
	}
}
#end
