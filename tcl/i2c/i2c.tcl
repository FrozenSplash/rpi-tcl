#!/usr/bin/tclsh
# 
# i2c.tcl - Tcl package to interface with the i2c SMBus
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

package provide i2c 1.0

if { [catch {
	load "$::env(HOME)/rpi-tcl/tcl/i2c/i2c.so" "i2c"
} error_msg]} {
	error "Unable to load i2c.so file. Error message:\n$error_msg"
}
