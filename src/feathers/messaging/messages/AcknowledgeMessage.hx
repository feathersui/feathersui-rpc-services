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

package feathers.messaging.messages;

import openfl.utils.IDataInput;
import openfl.utils.IDataOutput;

/**
 *  An AcknowledgeMessage acknowledges the receipt of a message that 
 *  was sent previously.
 *  Every message sent within the messaging system must receive an
 *  acknowledgement.
 *  
 *  @langversion 3.0
 *  @playerversion Flash 9
 *  @playerversion AIR 1.1
 *  @productversion BlazeDS 4
 *  @productversion LCDS 3 
 */
@:meta(RemoteClass(alias = "flex.messaging.messages.AcknowledgeMessage"))
class AcknowledgeMessage extends AsyncMessage implements ISmallMessage {
	//--------------------------------------------------------------------------
	//
	// Static Constants
	//
	//--------------------------------------------------------------------------

	/**
	 *  Header name for the error hint header.
	 *  Used to indicate that the acknowledgement is for a message that
	 *  generated an error.
	 *  
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion BlazeDS 4
	 *  @productversion LCDS 3 
	 */
	public static final ERROR_HINT_HEADER:String = "DSErrorHint";

	//--------------------------------------------------------------------------
	//
	// Constructor
	//
	//--------------------------------------------------------------------------

	/**
	 *  Constructs an instance of an AcknowledgeMessage with an empty body and header.
	 *  
	 *  @langversion 3.0
	 *  @playerversion Flash 9
	 *  @playerversion AIR 1.1
	 *  @productversion BlazeDS 4
	 *  @productversion LCDS 3 
	 */
	public function new() {
		super();
	}

	//--------------------------------------------------------------------------
	//
	// Overridden Methods
	//
	//--------------------------------------------------------------------------

	/**
	 * @private
	 */
	override public function getSmallMessage():IMessage {
		if (Type.getClass(this) == AcknowledgeMessage)
			return new AcknowledgeMessageExt(this);
		return null;
	}

	/**
	 * @private
	 */
	override public function readExternal(input:IDataInput):Void {
		super.readExternal(input);

		var flagsArray = readFlags(input);
		for (i in 0...flagsArray.length) {
			var flags = flagsArray[i];
			var reservedPosition:UInt = 0;

			// For forwards compatibility, read in any other flagged objects
			// to preserve the integrity of the input stream...
			if ((flags >> reservedPosition) != 0) {
				for (j in reservedPosition...6) {
					if (((flags >> j) & 1) != 0) {
						input.readObject();
					}
				}
			}
		}
	}

	/**
	 * @private
	 */
	override public function writeExternal(output:IDataOutput):Void {
		super.writeExternal(output);

		var flags:UInt = 0;
		output.writeByte(flags);
	}
}
