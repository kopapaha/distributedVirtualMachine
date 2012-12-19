#ifndef TEST_SERIAL_H
#define TEST_SERIAL_H

#define DATASIZE 250

typedef nx_struct test_serial_msg {

	nx_uint8_t typeMsg; //1 upload, 0 terminate
	nx_uint8_t appId; //application identifier (unique)
	nx_uint8_t data[DATASIZE]; //application binary

} test_serial_msg_t;

enum {
  AM_TEST_SERIAL_MSG = 0x89,
};

#endif
