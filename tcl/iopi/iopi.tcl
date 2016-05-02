#!/usr/bin/tclsh
# ======================================================
# ABElectronics IoPi 32-Channel Digital IO Tcl Package
# ======================================================
# 
# iopi.tcl - Tcl package to interface with the ServoPi
#
# Copyright (C) 2015 Rob Claxton
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#

#
# Each MCP23017 chip is split into two 8-bit ports.  Port 0 controls
# pins 1 to 8 while port 1 controls pins 9 to 16.
# When writing to or reading from a port the least significant bit represents
# the lowest numbered pin on the selected port.
#

package provide iopi 1.0

package require smbus 1.0

namespace eval ::iopi {
	# Define registers values from datasheet
	set IODIRA 			0x00	;# IO direction A - 1= input 0 = output
	set IODIRB 			0x01	;# IO direction B - 1= input 0 = output
	# Input polarity A - If a bit is set, the corresponding GPIO register bit
	# will reflect the inverted value on the pin.
	set IPOLA 			0x02
	# Input polarity B - If a bit is set, the corresponding GPIO register bit
	# will reflect the inverted value on the pin.
	set IPOLB 			0x03
	# The GPINTEN register controls the interrupt-onchange feature for each
	# pin on port A.
	set GPINTENA 		0x04
	# The GPINTEN register controls the interrupt-onchange feature for each
	# pin on port B.
	set GPINTENB 		0x05
	# Default value for port A - These bits set the compare value for pins
	# configured for interrupt-on-change. If the associated pin level is the
	# opposite from the register bit, an interrupt occurs.
	set DEFVALA 		0x06
	# Default value for port B - These bits set the compare value for pins
	# configured for interrupt-on-change. If the associated pin level is the
	# opposite from the register bit, an interrupt occurs.
	set DEFVALB 		0x07
	# Interrupt control register for port A.  If 1 interrupt is fired when the
	# pin matches the default value, if 0 the interrupt is fired on state
	# change
	set INTCONA 		0x08
	# Interrupt control register for port B.  If 1 interrupt is fired when the
	# pin matches the default value, if 0 the interrupt is fired on state
	# change
	set INTCONB 		0x09
	set IOCON 			0x0A	;# see datasheet for configuration register
	set GPPUA 			0x0C	;# pull-up resistors for port A
	set GPPUB 			0x0D	;# pull-up resistors for port B
	# The INTF register reflects the interrupt condition on the port A pins of
	# any pin that is enabled for interrupts. A set bit indicates that the
	# associated pin caused the interrupt.
	set INTFA 			0x0E
	# The INTF register reflects the interrupt condition on the port B pins of
	# any pin that is enabled for interrupts. A set bit indicates that the
	# associated pin caused the interrupt.
	set INTFB 			0x0F
	# The INTCAP register captures the GPIO port A value at the time the
	# interrupt occurred.
	set INTCAPA 		0x10
	# The INTCAP register captures the GPIO port B value at the time the
	# interrupt occurred.
	set INTCAPB 		0x11
	set GPIOA 			0x12	;# data port A
	set GPIOB 			0x13	;# data port B
	set OLATA 			0x14	;# output latches A
	set OLATB 			0x15	;# output latches B
	
	# Variables
	set address 		0x20	;# I2C address
	set port_a_dir 		0x00	;# port a direction
	set port_b_dir 		0x00	;# port b direction
	set portaval 		0x00	;# port a value
	set portbval 		0x00	;# port b value
	set porta_pullup 	0x00	;# port a pull-up resistors
	set portb_pullup 	0x00	;# port a pull-up resistors
	set porta_polarity 	0x00	;# input polarity for port a
	set portb_polarity 	0x00	;# input polarity for port b
	set intA 			0x00	;# interrupt control for port a
	set intB 			0x00	;# interrupt control for port a
	
	# Initial configuration - see IOCON page in the MCP23017 datasheet for more information.
	set config 			0x22
	
	# Define IO package global variables
	set use_gpio		false
	
	# Setup i2c address, default is 0x40 for ServoPi board
	proc setup_bus { bus_id { address $::iopi::address } { gpio false }} {
		
		set smbus [::smbus::setup_bus $bus_id $address]
		
		if { $smbus < 0 } { return $smbus }
		
		::iopi::write $smbus $::iopi::IOCON $::iopi::config
		
#		set portaval [::iopi::read $smbus $::iopi::GPIOA]
#		set portbval [::iopi::read $smbus $::iopi::GPIOB]
		
		# Init SMBus i2c address, default is 0x20, 0x21 for IOPi board,
		# Load default configuration, all pins are inputs with pull-ups disabled
		
		# Configure both IO ports as inputs
#		::iopi::write $smbus $::iopi::IODIRA 0xFF
#		::iopi::write $smbus $::iopi::IODIRB 0xFF
		
		# Disable pull-ups on both IO ports
#		::iopi::set_port_pullups $smbus A 0x00
#		::iopi::set_port_pullups $smbus B 0x00
		
		if { $gpio == true } {
			package require gpio 1.0
			set ::iopi::use_gpio true
		}
		
		return $smbus
	}
	
	# Local procedures
	proc update_byte { byte bit value } {
		# Internal procedure for setting the value of a single bit within a byte
		if { $value == 0 } {
			return [expr $byte & ~(1 << $bit)]
		} elseif { $value == 1 } {
			return [expr $byte | (1 << $bit)]
		} else {
			return
		}
	}

	proc check_bit { byte bit } {
		# Internal procedure for reading the value of a single bit within a byte
		return [expr [expr $byte & (1 << $bit)] == 0 ? 0 : 1]
	}
	
	# Public procedures
	
	# Set IO direction for an individual pin
	proc set_pin_direction { smbus pin direction } {
		# Pins 1 to 16
		# Direction 0 = Output, 1 = Input
		 
		if { $direction != 0 && $direction != 1 } {
			error "Invalid direction specified \[$direction\], should be either \[0\] (Output) or \[1\] (Input)."
		}
		
		set pin [expr $pin - 1]
		if { $pin >= 0 && $pin <= 7 } {
			set ::iopi::portaval [::iopi::update_byte $::iopi::portaval $pin $direction]
			return [::iopi::write $smbus $::iopi::IODIRA $::iopi::portaval]
		
		} elseif { $pin >= 8 && $pin <= 16 } {
			set ::iopi::portbval [::iopi::update_byte $::iopi::portbval [expr $pin - 8] $direction]
			return [::iopi::write $smbus $::iopi::IODIRB $::iopi::portbval]
		
		} else {
			error "Invalid pin specified \[$pin\], should be between \[1\] and \[16\]."
		}
		
		return
	}
	
	# Set direction for an IO port
	proc set_port_direction  { smbus port direction } {
		# Port A = Pins 1 to 8, Port B = Pins 8 to 16
		# Direction 0 = Output & 1 = Input per Pin, 0x00 - 0xFF
		
		if { $direction < 0x00 || $direction > 0xFF } {
			error "Invalid direction specified \[$direction\], should be either \[0\] (Output) or \[1\] (Input) per pin, therefore 0x00 to 0xFF."
		}
		
		switch -exact -- $port {
			A {
				set ::iopi::port_a_dir $direction
				return [::iopi::write $smbus $::iopi::IODIRA $direction]
			}
			B {
				set ::iopi::port_b_dir $direction
				return [::iopi::write $smbus $::iopi::IODIRB $direction]
			}
			default {
				error "Invalid port specified \[$port\], should be either \[A\] or \[B\]."
			}
		}
		
		return
	}
	
	# Set the internal 100K pull-up resistors for an individual pin
	proc set_pin_pullup { smbus pin value } {
		# Pins 1 to 16
		# Value 0 = disabled, 1 = enabled
		
		set pin [expr $pin - 1]
		if { $pin >= 0 && $pin <= 7 } {
			set ::iopi::porta_pullup [::iopi::update_byte $::iopi::portaval $pin $value]
			return [::iopi::write $smbus $::iopi::GPPUA $::iopi::porta_pullup]
		
		} elseif { $pin >= 8 && $pin <= 16 } {
			set ::iopi::portb_pullup [::iopi::update_byte $::iopi::portbval [expr $pin - 8] $value]
			return [::iopi::write $smbus $::iopi::GPPUB $::iopi::portb_pullup]
		
		} else {
			error "Invalid pin specified \[$pin\], should be between \[1\] and \[16\]."
		}
		
		return
	}
	
	# Set the internal 100K pull-up resistors for the selected IO port
	proc set_port_pullups { smbus port value } {
		# Port A = Pins 1 to 8, Port B = Pins 8 to 16
		# Value 0 = disabled & 1 = enabled per pin, 0x00 - 0xFF
		
		switch -exact -- $port {
			A {
				set ::iopi::porta_pullup $value
				return [::iopi::write $smbus $::iopi::GPPUA $value]
			}
			B {
				set ::iopi::portb_pullup $value
				return [::iopi::write $smbus $::iopi::GPPUB $value]
			}
			default {
				error "Invalid port specified \[$port\], should be either \[A\] or \[B\]."
			}
		}
		
		return
	}
	
	# Write to an individual pin
	proc write_pin { smbus pin value } {
		# Pins 1 to 16
		
		if { $pin >= 1 && $pin <= 8 } {
			set io_pin [expr $pin - 1]
			set ::iopi::portaval [::iopi::update_byte $::iopi::portaval $io_pin $value]
			return [::iopi::write $smbus $::iopi::GPIOA $::iopi::portaval]
		
		} elseif { $pin >= 9 && $pin <= 16 } {
			set io_pin [expr $pin - 1 - 8]
			set ::iopi::portbval [::iopi::update_byte $::iopi::portbval $io_pin $value]
			return [::iopi::write $smbus $::iopi::GPIOB $::iopi::portbval]
		
		} else {
			error "Invalid pin specified \[$pin\], should be between \[1\] and \[16\]."
		}
		
		return
	}
	
	# Write to all pins on the selected port
	proc write_port { smbus port value } {
		# Port A = Pins 1 to 8, Port B = Pins 9 to 16
		# Value = number between 0 and 255 or 0x00 and 0xFF
		
		switch -exact -- $port {
			A {
				set ::iopi::portaval $value
				return [::iopi::write $smbus $::iopi::GPIOA $value]
			}
			B {
				set ::iopi::portbval $value
				return [::iopi::write $smbus $::iopi::GPIOB $value]
			}
			default {
				error "Invalid port specified \[$port\], should be either \[A\] or \[B\]."
			}
		}
		
		return
	}
	
	# Read the value of an individual pin 1 - 16
	proc read_pin { smbus pin } {
		# Pins 1 to 16
		# Returns 0 = logic level low, 1 = logic level high
		
		if { $pin >= 1 && $pin <= 8 } {
			set io_pin [expr $pin - 1]
			set ::iopi::portaval [::iopi::read $smbus $::iopi::GPIOA]
			return [::iopi::check_bit $::iopi::portaval $io_pin]
		
		} elseif { $pin >= 9 && $pin <= 16 } {
			set io_pin [expr $pin - 1 - 8]
			set ::iopi::portbval [::iopi::read $smbus $::iopi::GPIOB]
			return [::iopi::check_bit $::iopi::portbval $io_pin]
		
		} else {
			error "Invalid pin specified \[$pin\], should be between \[1\] and \[16\]."
		}
		
		return
	}
	
	# Read all pins on the selected port
	proc read_port { smbus port } {
		# Port A = pins 1 to 8, port B = pins 8 to 16
		# Returns number between 0 and 255 or 0x00 and 0xFF
		
		switch -exact -- $port {
			A {
				set ::iopi::portaval [::iopi::read $smbus $::iopi::GPIOA]
				return $::iopi::portaval
			}
			B {
				set ::iopi::portbval [::iopi::read $smbus $::iopi::GPIOB]
				return $::iopi::portbval
			}
			default {
				error "Invalid port specified \[$port\], should be either \[A\] or \[B\]."
			}
		}
		
		return
	}
	
	# Invert the polarity of the selected pin
	proc invert_pin { smbus pin polarity } {
		# Pins 1 to 16
		# Polarity 0 = same logic state of the input pin, 1 = inverted logic state of the input pin
		
		if { $pin >= 1 && $pin <= 8 } {
			set io_pin [expr $pin - 1]
			set ::iopi::porta_polarity [::iopi::update_byte $::iopi::porta_polarity $io_pin $polarity]
			return [::iopi::write $smbus $::iopi::IPOLA $::iopi::porta_polarity]
		
		} elseif { $pin >= 9 && $pin <= 16 } {
			set io_pin [expr $pin - 1 - 8]
			set ::iopi::portb_polarity [::iopi::update_byte $::iopi::portb_polarity $io_pin $polarity]
			return [::iopi::write $smbus $::iopi::IPOLB $::iopi::portb_polarity]
		
		} else {
			error "Invalid pin specified \[$pin\], should be between \[1\] and \[16\]."
		}
		
		return
	}
	
	# invert the polarity of the pins on a selected port
	proc invert_port { smbus port polarity } {
		# Port A = pins 1 to 8, port B = pins 8 to 16
		# Polarity 0 = same logic state of the input pin, 1 = inverted logic state of the input pin
		# Polarity Value = number between 0 and 255 or 0x00 and 0xFF
		
		switch -exact -- $port {
			A {
				set ::iopi::porta_polarity $polarity
				return [::iopi::write $smbus $::iopi::IPOLA $polarity]
			}
			B {
				set ::iopi::portb_polarity $polarity
				return [::iopi::write $smbus $::iopi::IPOLB $polarity]
			}
			default {
				error "Invalid port specified \[$port\], should be either \[A\] or \[B\]."
			}
		}
		
		return
	}
	
	# Mirror the interupts
	proc mirror_interrupts { smbus value } {
		# Value 1 = The INT pins are internally connected, 0 = The INT pins are not	connected.
		# INTA is associated with PortA and INTB is associated with PortB
		
		if { $value == 0 || $value == 1 } {
			set ::iopi::config [::iopi::update_byte $::iopi::config 6 $value]
			return [::iopi::write $smbus $::iopi::IOCON $::iopi::config]
		} else {
			error "Invalid interupt value specified \[$value\], should be either \[0\] or \[1\]."
		}
		
		return
	}
	
	# Sets the polarity of the INT output pins
	proc set_interrupt_polarity { smbus value } {
		# Value 1 = Active-high, 0 = Active-low
		
		if { $value == 0 || $value == 1 } {
			set ::iopi::config [::iopi::update_byte $::iopi::config 1 $value]
			return [::iopi::write $smbus $::iopi::IOCON $::iopi::config]
		} else {
			error "Invalid interupt polarity specified \[$value\], should be either \[0\] Active Low, or \[1\] Active High."
		}
		
		return
	}
	
	# Set the type of interrupt for each pin on the selected port
	proc set_interrupt_type { smbus port value } {
		# Port A = pins 1 to 8, port B = pins 8 to 16
		# Value 1 = interrupt is fired when the pin matches the default value
		# Value 0 = the interrupt is fired on state change
		# Interrupt Value = number between 0 and 255 or 0x00 and 0xFF
		
		switch -exact -- $port {
			A {
				return [::iopi::write $smbus $::iopi::INTCONA $value]
			}
			B {
				return [::iopi::write $smbus $::iopi::INTCONB $value]
			}
			default {
				error "Invalid port specified \[$port\], should be either \[A\] or \[B\]."
			}
		}
		
		return
	}
	
	# Set interupt compare bits
	proc set_interrupt_defaults { smbus port value } {
		# Port A = pins 1 to 8, port B = pins 8 to 16
		# These bits set the compare value for pins configured for interrupt-on-change on the selected port.
		# If the associated pin level is the opposite from the register bit, an interrupt occurs.
		# Interrupt Compare Value = number between 0 and 255 or 0x00 and 0xFF
		
		switch -exact -- $port {
			A {
				return [::iopi::write $smbus $::iopi::DEFVALA $value]
			}
			B {
				return [::iopi::write $smbus $::iopi::DEFVALB $value]
			}
			default {
				error "Invalid port specified \[$port\], should be either \[A\] or \[B\]."
			}
		}
		
		return
	}
	
	# Enable interrupts for the selected pin
	proc set_interrupt_on_pin { smbus pin value } {
		# Pins 1 to 16
		# Value 0 = interrupt disabled, 1 = interrupt enabled
		
		if { $pin >= 1 && $pin <= 8 } {
			set io_pin [expr $pin - 1]
			set ::iopi::intA [::iopi::update_byte $::iopi::intA $io_pin $value]
			return [::iopi::write $smbus $::iopi::GPINTENA $::iopi::intA]
		
		} elseif { $pin >= 9 && $pin <= 16 } {
			set io_pin [expr $pin - 1 - 8]
			set ::iopi::intB [::iopi::update_byte $::iopi::intB $io_pin $value]
			return [::iopi::write $smbus $::iopi::GPINTENB $::iopi::intB]
		
		} else {
			error "Invalid pin specified \[$pin\], should be between \[1\] and \[16\]."
		}
		
		return
	}
	
	# Enable interrupts for the pins on the selected port
	proc set_interrupt_on_port { smbus port value } {
		# Port A = pins 1 to 8, port B = pins 8 to 16
		# Interupt Value = number between 0 and 255 or 0x00 and 0xFF
		
		switch -exact -- $port {
			A {
				set ::iopi::intA $value
				return [::iopi::write $smbus $::iopi::GPINTENA $value]
			}
			B {
				set ::iopi::intB $value
				return [::iopi::write $smbus $::iopi::GPINTENB $value]
			}
			default {
				error "Invalid port specified \[$port\], should be either \[A\] or \[B\]."
			}
		}
		
		return
	}
	
	# Read the interrupt status for the pins on the selected port
	proc read_interrupt_status { smbus port } {
		# Port A = pins 1 to 8, port B = pins 8 to 16
		
		switch -exact -- $port {
			A {
				return [::iopi::read $smbus $::iopi::INTFA]
			}
			B {
				return [::iopi::read $smbus $::iopi::INTFB]
			}
			default {
				error "Invalid port specified \[$port\], should be either \[A\] or \[B\]."
			}
		}
		
		return
	}
	
	# Read the value from the selected port at the time of the last interrupt trigger
	proc read_interrupt_capture { smbus port } {
		# Port A = pins 1 to 8, port B = pins 8 to 16
		
		switch -exact -- $port {
			A {
				return [::iopi::read $smbus $::iopi::INTCAPA]
			}
			B {
				return [::iopi::read $smbus $::iopi::INTCAPB]
			}
			default {
				error "Invalid port specified \[$port\], should be either \[A\] or \[B\]."
			}
		}
		
		return
	}
	
	# Set the interrupts A and B to 0
	proc reset_interrupts { smbus } {
		::iopi::read_interrupt_capture $smbus 0
		::iopi::read_interrupt_capture $smbus 1
		
		return
	}
	
	# Write data to I2C bus
	proc write { smbus reg value } {
		return [::smbus::write_byte_data $smbus $reg $value]
	}
	
	# Read data from I2C bus
	proc read { smbus reg } {
		return [::smbus::read_byte_data $smbus $reg]
	}
}
