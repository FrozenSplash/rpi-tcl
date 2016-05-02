#!/usr/bin/tclsh
# ======================================================
# ABElectronics ServoPi 16-Channel PWM Servo Tcl Package
# ======================================================
# 
# servopi.tcl - Tcl package to interface with the ServoPi
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

package provide servopi 1.0

package require smbus 1.0

namespace eval ::servopi {
    # Define registers values from datasheet
    set MODE1           0x00
    set MODE2           0x01
    set SUBADR1         0x02
    set SUBADR2         0x03
    set SUBADR3         0x04
    set ALLCALLADR      0x05
    set LED0_ON_L       0x06
    set LED0_ON_H       0x07
    set LED0_OFF_L      0x08
    set LED0_OFF_H      0x09
    set ALL_LED_ON_L    0xFA
    set ALL_LED_ON_H    0xFB
    set ALL_LED_OFF_L   0xFC
    set ALL_LED_OFF_H   0xFD
    set PRE_SCALE       0xFE
    
	# Variables
	set address 		0x40	;# I2C address
	
    # Define PWM package global variables
    set use_gpio        false
    
    # Setup i2c address, default is 0x40 for ServoPi board
    proc setup_bus { bus_id { address $::servopi::address } { gpio false }} {
        
        set smbus [::smbus::setup_bus $bus_id $address]
        
        if { $smbus < 0 } { return $smbus }
        
        ::servopi::write $smbus $::servopi::MODE1 0x00
        
        if { $gpio == true } {
            package require gpio 1.0
            set ::servopi::use_gpio true
        }
        
        return $smbus
    }

    # Set the PWM frequency
    proc set_pwm_freq { smbus freq } {
        
        set scale_val 2500000.0;                        # 2.5MHz
        set scale_val [expr $scale_val / 4096.0];       # 12-bit
        set scale_val [expr $scale_val / double($freq)]
        set scale_val [expr $scale_val - 1.0]
        set pre_scale [expr floor(${scale_val} + 0.5)]
        
		if { $pre_scale < 0.0 } {
			set pre_scale 0.0
			puts "Warning: Calculated PRE_SCALE value is negative, defaulting to 0.0"
		}
		
        set old_mode [::servopi::read $smbus $::servopi::MODE1]
        if { $old_mode == -1 } { return false }
        
        set new_mode [expr ($old_mode & 0x7F) | 0x10]
        
        ::servopi::write $smbus $::servopi::MODE1      $new_mode
        ::servopi::write $smbus $::servopi::PRE_SCALE  [expr int(floor($pre_scale))]
        ::servopi::write $smbus $::servopi::MODE1      $old_mode
        after 5
        ::servopi::write $smbus $::servopi::MODE1      [expr $old_mode | 0x80]
        
        return true
    }
    
    # Set the output on a single channel
    proc set_pwm { smbus channel on off } {
        
        ::servopi::write $smbus [expr $::servopi::LED0_ON_L  + 4 * $channel] [expr $on  & 0xFF]
        ::servopi::write $smbus [expr $::servopi::LED0_ON_H  + 4 * $channel] [expr $on  >> 8]
        ::servopi::write $smbus [expr $::servopi::LED0_OFF_L + 4 * $channel] [expr $off & 0xFF]
        ::servopi::write $smbus [expr $::servopi::LED0_OFF_H + 4 * $channel] [expr $off >> 8]
    }
    
    # Get the output on a single channel
    proc get_pwm { smbus channel } {
        
		set on [expr \
			 ::servopi::read $smbus [expr $::servopi::LED0_ON_L  + 4 * $channel] + \
			(::servopi::read $smbus [expr $::servopi::LED0_ON_H  + 4 * $channel] << 8)]
		set off [expr \
			::servopi::read $smbus [expr $::servopi::LED0_OFF_L + 4 * $channel] + \
			(::servopi::read $smbus [expr $::servopi::LED0_OFF_H + 4 * $channel] << 8)]
		
		return [list on off]
    }
    
    # Set the output on all channels
    proc set_all_pwm { smbus on off } {
        
        ::servopi::write $smbus $::servopi::ALL_LED_ON_L  [expr $on  & 0xFF]
        ::servopi::write $smbus $::servopi::ALL_LED_ON_H  [expr $on  >> 8]
        ::servopi::write $smbus $::servopi::ALL_LED_OFF_L [expr $off & 0xFF]
        ::servopi::write $smbus $::servopi::ALL_LED_OFF_H [expr $off >> 8]
    }
    
    # Disable output via OE pin
    proc output_disable {} {
        if { $::servopi::use_gpio == true } {
            ::gpio::output 7 true
        } else {
            error "Use ::servopi::setup_bus ?bus_id? ?address? ?true? to enable GPIO capability"
        }
     }
    
    # Enable output via OE pin
    proc output_enable {} {
        if { $::servopi::use_gpio == true } {
            ::gpio::output 7 false
        } else {
            error "Use ::servopi::setup_bus ?bus_id? ?address? ?true? to enable GPIO capability"
        }
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
