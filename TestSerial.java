import java.io.IOException;
import java.util.Scanner;

import net.tinyos.message.*;
import net.tinyos.packet.*;
import net.tinyos.util.*;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

public class TestSerial implements MessageListener {

	private MoteIF moteIF;
	
	public TestSerial(MoteIF moteIF) {
		this.moteIF = moteIF;
		this.moteIF.registerListener(new TestSerialMsg(), this);
	}

	public void sendPackets() {

		byte applicationId, selection;
		String INPUT_FILE_NAME;

		TestSerialMsg payload = new TestSerialMsg();
			
		Scanner keyboard = new Scanner(System.in);
		BytesStreamsAndFiles test = new BytesStreamsAndFiles();
		//read in the bytes
		byte[] fileContents;
		int i;

		try {
			while (true) {

				System.out.println("Ready to load new application!");
				System.out.println("Enter file name: ");
				INPUT_FILE_NAME = keyboard.nextLine();
				fileContents = test.read(INPUT_FILE_NAME);
				for(int i=0; i<fileContents.length; i++) {
							System.out.println(String.format("0x%02X", fileContents[i]));
						}

				System.out.println("Enter 0 to remove an application or 1 to add one: ");
				selection = keyboard.nextByte();		//mhpws thelei to radix??
				System.out.println("You entered: " + selection);
				System.out.println("Enter application id: ");
				applicationId = keyboard.nextByte();		
				System.out.println("You entered: " + applicationId);
				System.out.println("Sending application... ");
				payload.set_typeMsg(selection);
				payload.set_appId(applicationId);
				payload.set_data(fileContents);
				moteIF.send(0, payload);

				for(i=0; i<fileContents.length; i++) {
							fileContents[i] = 0x00;
				}
			}
		}
		catch (IOException exception) {
		System.err.println("Exception thrown when sending packets. Exiting.");
		System.err.println(exception);
		}
	}

	public void messageReceived(int to, Message message) {
		//int[] data = new int[3];
		TestSerialMsg msg = (TestSerialMsg)message;
		System.out.println("Received packet...");
		//data = msg.get_data();
		//symvash epistrofhs sto lifetime to id tou query
		//System.out.println("query_id: " + msg.get_lifetime() + "packet_id: " + msg.get_period() + " data: " + data[0] + " " + data[1] + " " + data[2] );
	}
	
	private static void usage() {
		System.err.println("usage: TestSerial [-comm <source>]");
	}
	
	public static void main(String[] args) throws Exception {
		String source = null;
		if (args.length == 2) {
		if (!args[0].equals("-comm")) {
		usage();
		System.exit(1);
		}
		source = args[1];
		}
		else if (args.length != 0) {
		usage();
		System.exit(1);
		}
		
		PhoenixSource phoenix;
		
		if (source == null) {
		phoenix = BuildSource.makePhoenix(PrintStreamMessenger.err);
		}
		else {
		phoenix = BuildSource.makePhoenix(source, PrintStreamMessenger.err);
		}

		MoteIF mif = new MoteIF(phoenix);
		TestSerial serial = new TestSerial(mif);
		serial.sendPackets();
	}


	public final class BytesStreamsAndFiles {

		
		/** Read the given binary file, and return its contents as a byte array.*/ 
		byte[] read(String aInputFileName){
			log("Reading in binary file named : " + aInputFileName);
			File file = new File(aInputFileName);
			log("File size: " + file.length());
			byte[] result = new byte[(int)file.length()];
			try {
			InputStream input = null;
			try {
				int totalBytesRead = 0;
				input = new BufferedInputStream(new FileInputStream(file));
				while(totalBytesRead < result.length){
				int bytesRemaining = result.length - totalBytesRead;
				//input.read() returns -1, 0, or more :
				int bytesRead = input.read(result, totalBytesRead, bytesRemaining); 
				if (bytesRead > 0){
					totalBytesRead = totalBytesRead + bytesRead;
				}
				}
				/*
				the above style is a bit tricky: it places bytes into the 'result' array; 
				'result' is an output parameter;
				the while loop usually has a single iteration only.
				*/
				log("Num bytes read: " + totalBytesRead);
			}
			finally {
				log("Closing input stream.");
				input.close();
			}
			}
			catch (FileNotFoundException ex) {
			log("File not found.");
			}
			catch (IOException ex) {
			log(ex);
			}
			return result;
		}
		
		private void log(Object aThing){
			System.out.println(String.valueOf(aThing));
		}
	}

}
