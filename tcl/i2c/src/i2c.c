/*
    i2c.c - i2c-bus driver wrapper for interfacing with Tcl

    Copyright (C) 2015 Rob Claxton

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include <sys/ioctl.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include "i2c-dev.h"

#define MAXFILELEN 	20
#define MAXBOARDS	4

typedef struct smbus
{
	int		bus;	/* Bus Id */
	int 	fd;		/* Open file descriptor: /dev/i2c-?, or -1 */
	int 	addr;	/* Current client SMBus address */
	int 	pec;	/* I0 => Packet Error Codes enabled */
} SMBus;

SMBus smbus[MAXBOARDS] = {{-1, -1, -1, 0}, {-1, -1, -1, 0}, {-1, -1, -1, 0}, {-1, -1, -1, 0}};

// Initialise the i2c device
int initialise(int i2cbus, int addr)
{
	char 	filename[MAXFILELEN];
	int		size		= sizeof(filename);
	int		quiet		= 0;
	int		fd			= -1;
	int		id 			= 0;
	int		avail_id 	= -1;
	
	// Check that board has not already been initialised
	for (id = 0; id < MAXBOARDS; id++)
	{
		// Return SMBus ID if board has been initialised
		if ((smbus[id].bus == i2cbus) && (smbus[id].addr == addr)) { return id; }
		
		// Check for first available SMBus ID
		if ((avail_id == -1) && (smbus[id].bus == -1)) { avail_id = id; }
	}
	
	// Return error if no more SMBus IDs are available
	if (avail_id == -1)
	{
		printf("All i2c busses allocated.\n");
		return -1;
	}
	
	id = avail_id;
	
	// Construct filename for i2c device
	snprintf(filename, size, "/dev/i2c/%d", i2cbus);
	filename[size - 1] = '\0';
	fd = open(filename, O_RDWR);
	
	// Check if i2c device failed to open due to filename
	if (fd < 0 && (errno == ENOENT || errno == ENOTDIR))
	{
		// Attempt to open i2c device again but with different filename
		sprintf(filename, "/dev/i2c-%d", i2cbus);
		fd = open(filename, O_RDWR);
	}
	
	// Check for error opening i2c device
	if (fd < 0)
	{
		if (!quiet)
		{
			if (errno == ENOENT)
			{
				fprintf(stderr, "Error: Could not open file `/dev/i2c-%d' or `/dev/i2c/%d': %s\n", i2cbus, i2cbus, strerror(ENOENT));
			} else {
				fprintf(stderr, "Error: Could not open file `%s': %s\n", filename, strerror(errno));
				if (errno == EACCES)
				{
					fprintf(stderr, "Run as root?\n");
				}
			}
		}
		
		return fd;
	}

	smbus[id].fd 	= fd;
	smbus[id].addr 	= addr;
	smbus[id].bus	= i2cbus;

	return id;
}

// Close the i2c device and reset the status
void release(int id)
{
	// Check SMBus ID is valid
	if ((id < 0) || (id > MAXBOARDS - 1))
	{
		printf("Invalid i2c bus ID to release.\n");;
		return;
	}
	
	// Check SMBus ID has been initialised
	if ((smbus[id].fd != -1) && (close(smbus[id].fd) == -1))
	{
		printf("Error releasing i2c bus.\n");;
		return;
	}
	
	// Reset SMBus
	smbus[id].bus 	= -1;
	smbus[id].fd 	= -1;
	smbus[id].addr 	= -1;
	smbus[id].pec 	= 0;
	
	return;
}

// Set the address of the i2c device to use for the next operation
int set_address(int id)
{
	int ret = 0;
	
	ret = ioctl(smbus[id].fd, I2C_SLAVE_FORCE, smbus[id].addr);
	if (ret != 0) { printf("Failed to send address command to i2c bus [%d].\n", id); }
	
	return ret;
}

// Perform a quick write operation on the i2c device
int write_quick(int id, unsigned char value)
{
	int ret = 0;
	
	if (set_address(id) == 0) { ret = (int)i2c_smbus_write_quick(smbus[id].fd, (__u8)value); }
	
	return ret;
}

// Read data from the i2c device
int read_byte(int id)
{
	int ret = 0;
	
	if (set_address(id) == 0) { ret = (int)i2c_smbus_read_byte(smbus[id].fd); }
	
	return ret;
}

// Write data to the i2c device
int write_byte(int id, unsigned char value)
{
	int ret = 0;
	
	if (set_address(id) == 0) { ret = (int)i2c_smbus_write_byte(smbus[id].fd, (__u8)value); }
	
	return ret;
}

// Read a byte of data from the i2c device
int read_byte_data(int id, unsigned char command)
{
	int ret = 0;
	
	if (set_address(id) == 0) { ret = (int)i2c_smbus_read_byte_data(smbus[id].fd, (__u8)command); }
	
	return ret;
}

// Write a byte of data to the i2c device
int write_byte_data(int id, unsigned char command, unsigned char value)
{
	int ret = 0;
	
	if (set_address(id) == 0) { ret = (int)i2c_smbus_write_byte_data(smbus[id].fd, (__u8)command, (__u8)value); }
	
	return ret;
}

// Read a word of data from the i2c device
int read_word_data(int id, unsigned char command)
{
	int ret = 0;
	
	if (set_address(id) == 0)
	{
		ret = (int)i2c_smbus_read_word_data(smbus[id].fd, (__u8)command);
		printf("internal retval = %d, smbus[id].fd = %d, command = %d\n", ret, smbus[id].fd, command);
	}
	
	return ret;
}

// Write a word of data to the i2c device
int write_word_data(int id, unsigned char command, unsigned char value)
{
	int ret = 0;
	
	if (set_address(id) == 0)
	{
		ret = (int)i2c_smbus_write_word_data(smbus[id].fd, (__u8)command, (__u8)value);
		printf("internal retval = %d, smbus[id].fd = %d, command = %d, value = %d\n", ret, smbus[id].fd, command, value);
	}
	
	return ret;
}

// Process a call on the i2c device
int process_call(int id, unsigned char command, unsigned char value)
{
	int ret = 0;
	
	if (set_address(id) == 0) { ret = (int)i2c_smbus_process_call(smbus[id].fd, (__u8)command, (__u8)value); }
	
	return ret;
}
/*
int main() {
	int id = -2;
    int retval = -9999;
	int old_mode = -1;
	int new_mode = -1;
    
//	::pwm::setup_bus $bus_id $address
    id = initialise(1, 0x40);
    printf("id=%d, fd=%d, addr=%d\n", id, smbus[0].fd, smbus[0].addr);
	usleep(10000);
	
//	::pwm::set_pwm_freq $smbus 1000
    old_mode = read_byte_data(id, 0x00);
    printf("read old_mode = %d\n", old_mode);
	usleep(10000);
	
	new_mode = (old_mode & 0x7F) | 0x10;
	
    retval = write_byte_data(id, 0x00, new_mode);
    printf("write new_mode = %d\n", retval);
	usleep(10000);
	
    retval = write_byte_data(id, 0xFE, 5);
    printf("write pre-scale = %d\n", retval);
	usleep(10000);
	
    retval = write_byte_data(id, 0x00, old_mode);
    printf("write old_mode = %d\n", retval);
	usleep(10000);
	
	old_mode = old_mode | 0x80;
	
    retval = write_byte_data(id, 0x00, old_mode);
    printf("write old_mode = %d\n", retval);
	usleep(10000);
	
//	::pwm::set_pwm $smbus $channel 0 $speed	
    retval = write_byte_data(id, (0x06 + (4 * 15)), (0 & 0xFF));
    printf("write LED0_ON_L = %d\n", retval);
	usleep(10000);
	
    retval = write_byte_data(id, (0x07 + (4 * 15)), (0 >> 8));
    printf("write LED0_ON_H = %d\n", retval);
	usleep(10000);
	
    retval = write_byte_data(id, (0x08 + (4 * 15)), (2048 & 0xFF));
    printf("write LED0_OFF_L = %d\n", retval);
	usleep(10000);
	
    retval = write_byte_data(id, (0x09 + (4 * 15)), (2048 >> 8));
    printf("write LED0_OFF_H = %d\n", retval);
	usleep(10000);
	
	
	
//    retval = read_word_data(id, 0x02);
//    printf("read retval = %d\n", retval);
//	usleep(10000);
//	
//    retval = read_word_data(id, 0x03);
//    printf("read retval = %d\n", retval);
//	usleep(10000);
	
//	release(id);
	
	return 0;
}
*/
