// $Id: TestLplC.nc,v 1.2 2009-10-21 19:11:51 razvanm Exp $

/*
 * "Copyright (c) 2000-2005 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 * Copyright (c) 2002-2003 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */

#include "Timer.h"
#include <printf.h>

/**
 * Simple test code for low-power-listening. Sends a sequence of packets,
 * changing the low-power-listening settings every ~32s. See README.txt
 * for more details.
 *
 *  @author Philip Levis, David Gay
 *  @date   Oct 27 2006
 */


#define WITH_ACKS
#define NUM_MSG 300


typedef nx_struct Msg {
	nx_uint16_t seqn;
} Msg;

module TestLplC {
  uses {
    interface Leds;
    interface Boot;
    interface Receive;
    interface AMSend;
    interface Timer<TMilli> as MilliTimer;
    interface SplitControl;
    interface LowPowerListening;
    interface PacketAcknowledgements;
	interface Packet;
  }
}
implementation 
{
  message_t packet;
  uint16_t counter = 0;
  int16_t sendInterval;

  event void Boot.booted() {
    call SplitControl.start();
  }

  event void MilliTimer.fired()
  {
    am_addr_t dst;
	Msg* msg = call Packet.getPayload(&packet, sizeof(Msg));

	msg->seqn = counter;
    call LowPowerListening.setRemoteWakeupInterval(&packet, sendInterval);

#ifdef WITH_ACKS
    call PacketAcknowledgements.requestAck(&packet);
    dst = TOS_NODE_ID == 1 ? 2 : 1;
#endif

    if (call AMSend.send(dst, &packet, sizeof(Msg)) == SUCCESS)
    {
      call Leds.led0On();
    }
    counter++;
  }

  event message_t* Receive.receive(message_t* bufPtr, 
                   void* payload, uint8_t len)
  {
    call Leds.led1Toggle();
	printf("Recv seqn %d\n", ((Msg*)payload)->seqn);
	printfflush();
    return bufPtr;
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error)
  {
    if (&packet == bufPtr)
      call Leds.led0Off();

	if (counter >= NUM_MSG)
		call MilliTimer.stop();

  }

  event void SplitControl.startDone(error_t err)
  {
    sendInterval = 125; 
    call LowPowerListening.setLocalWakeupInterval(sendInterval);
	if (TOS_NODE_ID == 1)
    	call MilliTimer.startPeriodic(1024);
  }

  event void SplitControl.stopDone(error_t err) { }
}




