#include "TestSerial.h"
#include "VMachine.h"

configuration VMachineAppC
{
}
implementation
{
  components MainC, LedsC, VMachineC;
  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  components new TimerMilliC() as Timer2;
  components new TimerMilliC() as Timer3;


  //Radio Components
  /*components new AMSenderC(AM_BLINKTORADIO);
  components new AMReceiverC(AM_BLINKTORADIO);
  components ActiveMessageC;*/
  components new DemoSensorC() as lightSensor;
  components SerialActiveMessageC as AM;

  VMachineC -> MainC.Boot;

  VMachineC.Timer0 -> Timer0;
  VMachineC.Timer1 -> Timer1;
  VMachineC.Timer2 -> Timer2;
  VMachineC.Timer3 -> Timer3;


  VMachineC.Leds -> LedsC;

  
  //Radio wiring
  /*VMachineC.Packet -> AMSenderC;
  VMachineC.AMPacket -> AMSenderC;
  VMachineC.AMSend -> AMSenderC;
  VMachineC.AMControl -> ActiveMessageC;
  VMachineC.Receive -> AMReceiverC;*/
  
  //Sensor Wiring
  VMachineC.light-> lightSensor;

  //Serial
  VMachineC.serialControl -> AM;
  VMachineC.serialAMSend -> AM.AMSend[AM_TEST_SERIAL_MSG];
  VMachineC.serialPacket -> AM;
  VMachineC.serialReceive -> AM.Receive[AM_TEST_SERIAL_MSG];
}