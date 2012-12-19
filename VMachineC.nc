#include <stdlib.h>
#include "Timer.h"
#include "VMachine.h"
#include "TestSerial.h"


module VMachineC @safe()
{
	uses interface Timer<TMilli> as Timer0;
	uses interface Timer<TMilli> as Timer1;
	uses interface Timer<TMilli> as Timer2;
	uses interface Timer<TMilli> as Timer3;

	uses interface Leds;
	uses interface Boot;
	
	//Radio interfaces
	/*uses interface Packet;
	uses interface AMPacket;
	uses interface AMSend;
	uses interface Receive;
	uses interface SplitControl as AMControl;*/
	
	
	//Sensor interface
	uses interface Read<uint16_t> as light;

	//Serial interfaces
	uses interface SplitControl as serialControl;
	uses interface Packet as serialPacket;
	uses interface AMSend as serialAMSend;
	uses interface Receive as serialReceive;
}


/* 
TODO
1 na teleiwsoume th seiriaki
otan treksoume th seiriakh na vgaloume to  post RR apo to boot
*/

implementation {

	message_t serialp;

	struct cacheTimer{
		uint16_t value;
		uint32_t lastRead;
	}cTime;

	typedef struct appFieldStruct{
		uint8_t data[DATASIZE]; 		//binary for each application
		bool execNext; 					//execute next instruction
		uint8_t pc; 					//program counter
		bool avail; 					//app space: TRUE free, FALSE is used
		uint8_t id; 					// application id. set from user
		int8_t r[6];					//registers
		bool askSensor; 				//app asked sensor value
		uint8_t regSensor; 				//register num to store sensor value
		
	}appStruct; 

	appStruct app[3]; 			//max 3 appliccations


	uint8_t nofApps = 0; 		//ari8mos efarmogwn pou exw lavei apo serial
	uint8_t appi=0;
	uint8_t currentApp;

	task void RRscheduling();

	void init(){
		int i,j;
		for(i=0; i<3; i++){
			app[i].execNext = FALSE;
			app[i].pc = 3; //first instruction of Init handler
			app[i].avail = TRUE;
			app[i].askSensor = FALSE;
			app[i].regSensor = 0;  //useless init
			for (j=0; j<DATASIZE; j++)
				app[i].data[j] = 0;

			for (j=0; j<6; j++)
				app[i].r[j]=0;
		}
		call Timer3.startPeriodic(1000);
		cTime.value = 0;
		cTime.lastRead = call Timer3.getNow();
	}
	
	
	void ledOnOff(uint8_t state){
		if(state){
			if (currentApp == 0){
				dbg("DBG", "led0On @ %s\n", sim_time_string());
				call Leds.led0On();
			}
			else if (currentApp == 1){
				dbg("DBG", "led1On @ %s\n", sim_time_string());
				call Leds.led1On();
			}
			else{
				dbg("DBG", "led2On @ %s\n", sim_time_string());
				call Leds.led2On();
			}
		}
		else{
			if (currentApp == 0){
				dbg("DBG", "led0Off @ %s\n", sim_time_string());
				call Leds.led0Off();
			}
			else if (currentApp == 1){
				dbg("DBG", "led1Off @ %s\n", sim_time_string());
				call Leds.led1Off();
			}
			else{
				dbg("DBG", "led2Off @ %s\n", sim_time_string());
				call Leds.led2Off();
			}
		}
	}
	



	void setTimer(uint8_t value){ 
		if(value == 0){
			if (currentApp == 0){
				dbg("DBG", "Tmer0.stop @ %s\n", sim_time_string());
				call Timer0.stop();
			}
			else if (currentApp == 1){
				dbg("DBG", "Tmer1.stop @ %s\n", sim_time_string());
				call Timer1.stop();
			}
			else{
				dbg("DBG", "Tmer2.stop @ %s\n", sim_time_string());
				call Timer2.stop();
			}
		}
		else{
			if (currentApp == 0){
				//dbg("DBG", "Timer0.startPeriodic millisec:%d @ %s\n", value*1000, sim_time_string());
				call Timer0.startPeriodic(value*1000);
			}
			else if (currentApp == 1){
				//dbg("DBG", "Timer1.startPeriodic @ %s\n", sim_time_string());
				call Timer1.startPeriodic(value*1000);
			}
			else{
				//dbg("DBG", "Timer2.startPeriodic @ %s\n", sim_time_string());
				call Timer2.startPeriodic(value*1000);
			}
		}
	}



	/*
	*	find next instr of app currentApp
	*	and exec it
	*/
	task void execApp(){

		uint8_t pc;
		uint8_t instr;
		uint8_t lsb, msb;

		pc = app[currentApp].pc;
		instr = app[currentApp].data[pc];

		msb = instr & 0xF0;
		lsb = instr & 0x0F;
		switch(msb){
			case retrn:
				dbg("DBG", "RET app:%d pc:%d @ %s\n", currentApp, app[currentApp].pc, sim_time_string());
				app[currentApp].execNext = FALSE;
//				app[currentApp].pc++; //8a 8etei ton pc o timer
				post RRscheduling();
				break;
			case set:
				instr = app[currentApp].data[pc+1]; //val
				app[currentApp].pc++;
				app[currentApp].r[lsb-1] = instr; //rx=val
				dbg("DBG", "SET App: %d pc:%d reg:%d val:%d @ %s\n", currentApp, app[currentApp].pc, lsb-1, instr, sim_time_string());					
				app[currentApp].pc++;
				post RRscheduling();
				break;
			case cpy:
				instr = app[currentApp].data[pc+1]; //ry
				app[currentApp].pc++;
				app[currentApp].r[lsb-1] = app[currentApp].r[instr]; //rx=ry
				dbg("DBG", "CPY reg:%d val:%d @ %s\n", lsb-1, instr, sim_time_string());
				app[currentApp].pc++;
				post RRscheduling();
				break;
			case add:
				instr = app[currentApp].data[pc+1]; //ry
				app[currentApp].pc++;
				app[currentApp].r[lsb-1] = app[currentApp].r[lsb-1] + app[currentApp].r[instr]; // rx = rx + ry
				dbg("DBG", "ADD App: %d pc: %d @ %s\n", currentApp, app[currentApp].pc, sim_time_string());
				app[currentApp].pc++;
				post RRscheduling();
				break;
			case sub:
				instr = app[currentApp].data[pc+1]; //ry
				app[currentApp].pc++;
				app[currentApp].r[lsb-1] = app[currentApp].r[lsb-1] - app[currentApp].r[instr]; // rx = rx - ry
				dbg("DBG", "SUB @ %s\n", sim_time_string());
				app[currentApp].pc++;
				post RRscheduling();
				break;
			case inc:
				app[currentApp].r[lsb-1] = app[currentApp].r[lsb-1] + 1; // rx = rx + 1
				dbg("DBG", "INC App: %d @ %s\n", currentApp, sim_time_string());
				app[currentApp].pc++;
				post RRscheduling();
				break;
			case dec:
				app[currentApp].r[lsb-1] = app[currentApp].r[lsb-1] - 1; // rx = rx - 1
				dbg("DBG", "DEC App: %d @ %s\n", currentApp, sim_time_string());
				app[currentApp].pc++;
				post RRscheduling();
				break;
			case max:
				instr = app[currentApp].data[pc+1]; //ry
				app[currentApp].pc++;
				if (app[currentApp].r[instr] > app[currentApp].r[lsb-1]) //ry > rx
					app[currentApp].r[lsb-1] = app[currentApp].r[instr]; //rx = ry
				dbg("DBG", "MAX @ %s\n", sim_time_string());
				app[currentApp].pc++;
				post RRscheduling();
				break;
			case min:
				instr = app[currentApp].data[pc+1]; //ry
				app[currentApp].pc++;
				if (app[currentApp].r[instr] < app[currentApp].r[lsb-1]) //ry < rx
					app[currentApp].r[lsb-1] = app[currentApp].r[instr]; //rx = ry
				dbg("DBG", "MIN @ %s\n", sim_time_string());
				app[currentApp].pc++;
				post RRscheduling();
				break;
			case bgz:
				instr = app[currentApp].data[pc+1]; //off
				app[currentApp].pc++;
				if (app[currentApp].r[lsb-1]>0) //rx > 0
					app[currentApp].pc += instr; //pc = pc + off
				dbg("DBG", "BGZ @ %s\n", sim_time_string());
				post RRscheduling();
				break;
			case bez:
				instr = app[currentApp].data[pc+1]; //off
				app[currentApp].pc++;
				if (app[currentApp].r[lsb-1]==0) //rx == 0
					app[currentApp].pc += instr; //pc = pc + off
				dbg("DBG", "BEZ App: %d to: %d @ %s\n", currentApp, app[currentApp].pc, sim_time_string());
				post RRscheduling();
				break;
			case bra:
				instr = app[currentApp].data[pc+1]; //off
				app[currentApp].pc++;
				app[currentApp].pc += instr; //pc = pc + off
				dbg("DBG", "BRA @ %s\n", sim_time_string());
				post RRscheduling();
				break;
			case led:
				dbg("DBG", "LED App: %d @ %s\n", currentApp, sim_time_string());
				ledOnOff(lsb); //if ( val != 0 ) turn led on else turn led off
				app[currentApp].pc++;
				post RRscheduling();
				break;
			case rdb:
				//rx = current brightness value /*TODO concurrent reads*/
				app[currentApp].regSensor = lsb; //rx


				if(call Timer3.getNow() - cTime.lastRead <= 3000){
					app[currentApp].r[app[currentApp].regSensor] = cTime.value;
					dbg("DBG", "RDB App: %d cachingValue: %d @ %s\n", currentApp, cTime.value, sim_time_string());
				}
				else{
					app[currentApp].askSensor = TRUE; //asking for sensor value
					app[currentApp].execNext = FALSE; //wait until rx get his  value
					dbg("DBG", "RDB App: %d CALL_sensor @ %s\n", currentApp, sim_time_string());
					call light.read();
				}

				app[currentApp].pc++;
				
				post RRscheduling();	
				break;
			case tmr:
				//set timer to expire after val seconds (0 cancels the timer)
				instr = app[currentApp].data[pc+1]; //val /*TODO timer in seconds! TMilli; T32khz; TMicro;*/
				dbg("DBG", "TMR App: %d sec:%d @ %s\n", currentApp, instr, sim_time_string());
				app[currentApp].pc++;
				setTimer(instr);
				app[currentApp].pc++;	
				post RRscheduling();
				break;
			default:
				dbg("DBG", "unknown command!!\n");
				break;
		}
	}


	/*
	*	if an app has an instruction ready 
	*	for execution, exec and round-robin (RR) for next
	*/
	task void RRscheduling(){
		uint8_t i;
		//dbg("DBG", "RRsceduling... %d execNext:%d @ %s\n", appi, app[appi].execNext,  sim_time_string());
			if(app[appi].execNext){
				currentApp = appi;
				while (post execApp()!=SUCCESS){}
				appi++;
				appi = appi%3;
			}
			else{
				for( i=0; i<3; i++ ){
					if(app[i].execNext){
						appi++;
						appi = appi%3;
						post RRscheduling();
						break;
					}
				}
			}
			//dbg("DBG", "post execApp for app %d @ %s\n", currentApp, sim_time_string());
	}



	event void Boot.booted() {
		//call AMControl.start();

		call serialControl.start();

		dbg("DBG", "node booted @ %s\n", sim_time_string());

		init();
		
#ifndef SERIAL
		//call Timer0.startPeriodic(10);

		//--init--
		app[0].data[1] = 0x09; //init length
		app[0].data[2] = 0x04; //timer length
		app[0].data[3] = 0x11; //set r0 SET
		app[0].data[4] = 0x06; //to 6
		app[0].data[5] = 0x12; //set r1 SET
		app[0].data[6] = 0x04; //to 4
		app[0].data[7] = 0x31; //add r0 ADD
		app[0].data[8] = 0x02; //+ r1 
		app[0].data[9] = 0xE0; //set timer TMR
		app[0].data[10] = 0x01; //to 1 sec
		app[0].data[11] = 0x00; //return
		// --timer--
		app[0].data[12] = 0x53; // r2++ INC
		app[0].data[13] = 0x21;	//r0 = r2 CPY
		app[0].data[14] = 0x03;
		app[0].data[15] = 0x00; //return
		app[0].id = 1;
		app[0].execNext = TRUE;
		nofApps++;

		//--init--
		app[1].data[1] = 0x06; //init length
		app[1].data[2] = 0x07; //timer length
		app[1].data[3] = 0x11; //set r1
		app[1].data[4] = 0x05; //to 5
		app[1].data[5] = 0xE0; //set timer
		app[1].data[6] = 0x01; //to 1 sec
		app[1].data[7] = 0xD3;  //r3 = brightness value
		app[1].data[8] = 0x00; //return
		//--timer--
		app[1].data[9] = 0x61; //r1--
		app[1].data[10] = 0xA1; //if r1 == 0 goto L1
		app[1].data[11] = 0x02; //
		app[1].data[12] = 0x00; //return
		app[1].data[13] = 0x11; //L1: set r1=5
		app[1].data[14] = 0x05; 
		app[1].data[15] = 0x00;  //retrun
		app[1].id = 2;
		app[1].execNext = TRUE;
		nofApps++;
	
		post RRscheduling(); 
#endif
	}

	
	event void serialControl.startDone(error_t err) {

		if (err == SUCCESS){}
		else 
			call serialControl.start();
	}
	
	event void serialControl.stopDone(error_t err) {}
	
	event void serialAMSend.sendDone(message_t *msg, error_t err) {}



/*TODO
kaloume to timer0.startPeriodic apo ena task. ok.
ta tasks synexizoun tin ektelesh tous. ok.
otan o timer0 kanei fired 8a diakopsei thn ektelesh twn tasks 
gia na ektelesei ton kwdika tou??? oxi mpainei sto queue me ta tasks
*/
	//Application 0 Timer
	event void Timer0.fired() {
		dbg("DBG", "Timer0.fired @ %s\n", sim_time_string());
		app[0].pc = 3 + app[0].data[1]; //timer handler first instr
		app[0].execNext = TRUE;
		call Timer0.stop();
		post RRscheduling();

	}
	//Application 1 Timer
	event void Timer1.fired() {
		dbg("DBG", "Timer1.fired @ %s\n", sim_time_string());
		app[1].pc = 3 + app[1].data[1]; //timer handler first instr
		app[1].execNext = TRUE;
		call Timer1.stop();
		post RRscheduling();
	}
	//Application 2 Timer
	event void Timer2.fired() {
		dbg("DBG", "Timer2.fired @ %s\n", sim_time_string());
		app[2].pc = 3 + app[2].data[1]; //timer handler first instr
		app[2].execNext = TRUE;
		call Timer2.stop();
		post RRscheduling();
	}
	//cache Timer
	event void Timer3.fired() {

	}



	event void light.readDone(error_t result, uint16_t data) {
		//dbg("DBG", "Read value: %d  @ %s\n", data, sim_time_string());
		uint8_t i;
		if (result == SUCCESS) {
			for(i=0; i<3; i++){
				if (app[i].askSensor){
					cTime.value = data;
					cTime.lastRead = call Timer3.getNow();
					app[i].r[app[i].regSensor] = (uint8_t) data; /*TODO chk typecasting*/
					app[i].askSensor = FALSE;
					app[i].execNext = TRUE;
					dbg("DBG", "RDB App: %d ReadDone_value: %d @ %s\n", currentApp, data, sim_time_string());
				}
			}
			post RRscheduling();
		}
	}



	event message_t *serialReceive.receive(message_t *msg, void *payload, uint8_t len)
	{
		test_serial_msg_t *payl;
		
		uint8_t i, pos;
		
		if (len == sizeof(test_serial_msg_t)){

			payl = (test_serial_msg_t *)payload;

			if (payl->typeMsg == 1 ){	//load app
				
				//Check if app is already loaded
				for(pos=0; pos<3; pos++) {
					if (app[pos].id == payl->appId) {		//if yes, overwrite current app

						app[pos].execNext = FALSE;
						for(i=0; i < payl->data[0]; i++){
							app[pos].data[i] = payl->data[i];
						}
						app[pos].pc = 3;
						app[pos].askSensor = FALSE;
						//To avalaible tha eina idi false?? etsi den einai?
						for (i=0; i<6; i++)
							app[pos].r[i]=0;
						
						app[pos].regSensor = 0;
						app[pos].execNext = TRUE;
						
						post RRscheduling();

						return msg;
					}
				}
				
				//If not, find next available space
				if(!(pos<3)){
					for(pos=0; pos<3; pos++) {
						if (app[pos].avail)
							break;
					}
				}
				
				//If there's enough space, load new app
				if(pos < 3) {
					for(i=0; i < payl->data[0]; i++){
						app[pos].data[i] = payl->data[i];
					}
					app[pos].id = payl->appId;
					app[pos].execNext = TRUE;
					app[pos].avail = FALSE;

					//oi registers einai hdh mhden
					//o pc eiani hdh 3
					//o askSensor einai hdh 0
					nofApps++;
				}
			
				post RRscheduling();

				
			}
			else if (payl->typeMsg == 0){ 		//terminate app
		
				for(pos=0; pos<3; pos++) { 
					if (app[pos].id == payl->appId)
						break;
				}
				
				if( pos<3) {
					if(pos == 0)
						call Timer0.stop();
					else if (pos == 1)
						call Timer1.stop();
					else
						call Timer2.stop();					
					//app[pos].id = 10;				//Arxikopoisi ??? Xreiazetai?? Mallon oxi
					app[pos].execNext = FALSE;
					app[pos].avail = TRUE;
					app[pos].pc = 3;
					app[pos].askSensor = FALSE;
					app[pos].regSensor = 0;
					//for (i=0; i<DATASIZE; i++)		//Mallon de xreiazetai
						//app[pos].data[i] = 0;
					
					for (i=0; i<6; i++)
						app[pos].r[i]=0;

					nofApps--;
				}
			}
		}
		return msg;
	}



}
