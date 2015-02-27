#!/usr/bin/tclsh
# 
# smbus.tcl - Tcl package to interface with the i2c SMBus
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

package provide smbus 	1.0

package require i2c		1.0

namespace eval ::smbus::helper {
    # Detect i2C port number and assign to i2c_bus
    proc get_smbus_id {} {
        set i2c_bus -1
		
	    set fd [open "/proc/cpuinfo" RDONLY]
		while { ![eof $fd] } {
			gets $fd line
			
			set line_list 	[split $line ":"]
			set info_name 	[string trim [lindex $line_list 0]]
			set info_value 	[string trim [lindex $line_list 1]]
			if { $info_name == "Revision" } {
				if { [string compare -length 4 $info_value "0002"] == 0 || \
					 [string compare -length 4 $info_value "0003"] == 0 } {
					set i2c_bus 0
				} else {
					set i2c_bus 1
				}
				break
			}
		}
		close $fd
		
		return $i2c_bus
	}
}

namespace eval ::smbus {
	proc setup_bus { bus address } {
		return [::i2c::initialise $bus $address]
	}
	
	proc stop_bus { smbus } {
		return [::i2c::release $smbus]
	}
	
	
	proc write_quick { smbus value } {
		return [::i2c::write_byte_quick $smbus $value]
	}
	
	
	proc read_data { smbus } {
		return [::i2c::read_byte_data $smbus]
	}
	
	proc write_data { smbus value } {
		return [::i2c::write_byte_data $smbus $value]
	}
	
	
	proc read_byte_data { smbus command } {
		return [::i2c::read_byte_data $smbus $command]
	}
	
	proc write_byte_data { smbus command value } {
		return [::i2c::write_byte_data $smbus $command $value]
	}
	
	
	proc read_word_data { smbus command } {
		return [::i2c::read_word_data $smbus $command]
	}
	
	proc write_word_data { smbus command value } {
		return [::i2c::write_word_data $smbus $command $value]
	}
	
	
	proc process_call { smbus command value } {
		return [::i2c::process_call $smbus $command $value]
	}
}
