/*
||
|| @file Keypad_MC17.h
|| @version 1.0
|| @author G. D. (Joe) Young
|| @contact "G. D. (Joe) Young" <gdyoung@telus.net>
||
|| @description
|| | Keypad_MC17 provides an interface for using matrix keypads that
|| | are attached with Microchip MCP23017 I2C port expanders. It 
|| | supports multiple keypads, user selectable pins, and user
|| | defined keymaps.
|| | The MCP23017 is somewhat similar to the MCP23016 which is supported
|| | by the earlier library Keypad_MC16. The difference most useful for
|| | use with Keypad is the provision of internal pullup resistors on the
|| | pins used as inputs, eliminating the need to provide 16 external 
|| | resistors. The 23017 also has more comprehensive support for separate
|| | 8-bit ports instead of a single 16-bit port. However, this library
|| | assumes configuration as 16-bit port--IOCON.BANK = 0.
|| | JP: THIS VERSION USES IOCON.BANK = 1 TO USE ONLY GPIOA
|| #
||
|| @license
|| | This library is free software; you can redistribute it and/or
|| | modify it under the terms of the GNU Lesser General Public
|| | License as published by the Free Software Foundation; version
|| | 2.1 of the License.
|| |
|| | This library is distributed in the hope that it will be useful,
|| | but WITHOUT ANY WARRANTY; without even the implied warranty of
|| | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
|| | Lesser General Public License for more details.
|| |
|| | You should have received a copy of the GNU Lesser General Public
|| | License along with this library; if not, write to the Free Software
|| | Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
|| #
||
*/

#include "Keypad_MC17.h"

#define GPIOA 0x09		//MCP23017 GPIO reg
#define GPIOB 0x19		//MCP23017 GPIO reg
#define IODIRA 0x00		//MCP23017 I/O direction register
#define IODIRB 0x10		//MCP23017 I/O direction register
#define IOCON 0x0a		//MCP23017 I/O configuration register
#define GPPUA 0x06		//MCP23017 pullup resistors control

//#define GPIOA 0x12		//MCP23017 GPIO reg
//#define GPIOB 0x13		//MCP23017 GPIO reg
//#define IODIRA 0x00		//MCP23017 I/O direction register
//#define IODIRB 0x01		//MCP23017 I/O direction register
//#define IOCON 0x0a		//MCP23017 I/O configuration register
//#define GPPUA 0x0c		//MCP23017 pullup resistors control

/////// Extended Keypad library functions. ////////////////////////////


// Let the user define a keymap - assume the same row/column count as defined in constructor
void Keypad_MC17::begin(char *userKeymap) {
	TwoWire::begin();
    Keypad::begin(userKeymap);
	_begin( );
	pinState = pinState_set( );
}


/////// Extended Keypad_MC17 library functions. ////////////////////////

// Initialize MC17
void Keypad_MC17::begin(void) {
	TwoWire::begin();
	_begin( );
//	pinState = 0xff;
	pinState = pinState_set( );
}

// Initialize MC17
void Keypad_MC17::begin(byte address) {
	i2caddr = address;
	TwoWire::begin(address);
	_begin( );
//	pinState = 0xff;
	pinState = pinState_set( );
}

void Keypad_MC17::begin(int address) {
	i2caddr = address;
	TwoWire::begin(address);
	_begin( );
//	pinState = 0xff;
	pinState = pinState_set( );
} // begin( int )

//word iodirec = 0xffff;            //direction of each bit - reset state = all inputs.
byte iodirec = 0xff;
//byte iocon = 0x10;                // reset state for bank, disable slew control
byte iocon = 0x90;                // reset state for bank, disable slew control

// Initialize MCP23017
// MCP23017 byte registers act in word pairs

void Keypad_MC17::_begin( void ) {
	iodir_state = iodirec;
	TwoWire::beginTransmission( (int)i2caddr );
	TwoWire::write( IOCON ); // same as when reset
	TwoWire::write( iocon );
	TwoWire::endTransmission( );
	TwoWire::beginTransmission( (int)i2caddr );
	TwoWire::write( GPPUA ); // enable pullups on all inputs
	TwoWire::write( 0xff );
//	TwoWire::write( 0xff );
	TwoWire::endTransmission( );
	TwoWire::beginTransmission( (int)i2caddr );
	TwoWire::write( IODIRA ); // setup port direction - all inputs to start
	TwoWire::write( iodirec );
//	TwoWire::write( highByte( iodirec ) );
	TwoWire::endTransmission( );
	TwoWire::beginTransmission( (int)i2caddr );
	TwoWire::write( GPIOA );	//point register pointer to gpio reg
	TwoWire::write( iodirec ); // make o/p latch agree with pulled-up pins
//	TwoWire::write( highByte(iodirec) );
	TwoWire::endTransmission( );
} // _begin( )

// individual pin setup - modify pin bit in IODIR reg.
void Keypad_MC17::pin_mode(byte pinNum, byte mode) {
	byte mask = 0b00000001 << pinNum;
	if( mode == OUTPUT ) {
		iodir_state &= ~mask;
	} else {
		iodir_state |= mask;
	} // if mode
	TwoWire::beginTransmission((int)i2caddr);
	TwoWire::write( IODIRA );
	TwoWire::write(  iodir_state );
//	TwoWire::write( highByte( iodir_state ) );
	TwoWire::endTransmission();
} // pin_mode( )

void Keypad_MC17::pin_write(byte pinNum, boolean level) {
	byte mask = 1<<pinNum;
	if( level == HIGH ) {
		pinState |= mask;
	} else {
		pinState &= ~mask;
	}
	port_write( pinState );
} // MC17xWrite( )


int Keypad_MC17::pin_read(byte pinNum) {
	TwoWire::beginTransmission((int)i2caddr);
	TwoWire::write( GPIOA );
	TwoWire::endTransmission( );
	byte mask = 0x1<<pinNum;
	TwoWire::requestFrom((int)i2caddr, 1);
	byte pinVal = 0;
	pinVal = TwoWire::read( );
	pinVal |= ( TwoWire::read( )<<8 );
	pinVal &= mask;
	if( pinVal == mask ) {
		return 1;
	} else {
		return 0;
	}
}

void Keypad_MC17::port_write( byte i2cportval ) {
// MCP23017 requires a register address on each write
	TwoWire::beginTransmission((int)i2caddr);
	TwoWire::write( GPIOA );
	TwoWire::write( i2cportval );
//	TwoWire::write( highByte( i2cportval ) );
	TwoWire::endTransmission();
	pinState = i2cportval;
} // port_write( )

byte Keypad_MC17::pinState_set( ) {
	TwoWire::beginTransmission((int)i2caddr);
	TwoWire::write( GPIOA );
	TwoWire::endTransmission( );
	TwoWire::requestFrom( (int)i2caddr, 1 );
	pinState = 0;
	pinState = TwoWire::read( );
	pinState |= (TwoWire::read( )<<8);
	return pinState;
} // set_pinState( )

// access functions for IODIR state copy
byte Keypad_MC17::iodir_read( ) {
	return iodir_state;  // local copy is always same as chip's register
} // iodir_read( )

void Keypad_MC17::iodir_write( byte iodir ) {
	iodir_state = iodir;
	TwoWire::beginTransmission((int)i2caddr);   // read current IODIR reg 
	TwoWire::write( IODIRA );
	TwoWire::write( iodir_state );
//	TwoWire::write( highByte( iodir_state ) );
	TwoWire::endTransmission();
} // iodir_write( )


/*
|| @changelog
|| |
|| | 1.0 2014-05-18 - Joe Young : Derived from Keypad_MC16
|| #
*/
