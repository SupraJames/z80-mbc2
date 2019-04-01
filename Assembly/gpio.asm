;
; GPIO read example for Z80-MBC
; 4 x tactile switches connected to GPIO B port (high 4 bits)
; Wire so that pressing the switches takes the pin HIGH
;

opcode_port     .equ    $01     ; IOS opcode write port address
exec_wport      .equ    $00     ; IOS "execute opcode" write port address
tx_opcode       .equ    $01     ; IOS "serial Tx" operation opcode
iodirb_opcode	.equ	$06		; IOS "IODIRB SET" opcode
gppub_opcode	.equ	$08		; IOS "GPPUB SET" opcode
gpiob_opcode	.equ	$82		; IOS "GPIOB READ" opcode

A_CR		.equ	0Dh		; Carriage Return ASCII
A_LF		.equ	0Ah		; Line Feed ASCII

KEY1		.equ	127
KEY2		.equ	191
KEY3		.equ	223
KEY4		.equ	239

RAMTOP		.equ	$FFFF	;	RAM ends at $FFFF
STACK		.equ	RAMTOP	; 	SP at top of RAM
	
	org 0
	LD SP,STACK

	; Configure GPIOB pins as all inputs
	LD A, iodirb_opcode
	OUT (opcode_port), A
	LD A, 255
	OUT (exec_wport), A

	; Configure all GPIOB pins with pull up resistors
	; which sets them high. Switch pulls them to GND
	LD A, gppub_opcode
	OUT (opcode_port), A
	LD A, 255
	OUT (exec_wport), A

start:
; Output the startup text
	LD DE, TEXT0
	CALL otext

loop:
	; Start of main loop
	LD A, gpiob_opcode
	OUT (opcode_port), A ; Send GPIOB READ opcode to IOS
	IN A, 0 ; Read GPIOB port into A
	CP KEY1
	CALL Z, key1_press
	CP KEY2
	CALL Z, key2_press
	CP KEY3
	CALL Z, key3_press
	CP KEY4
	CALL Z, key4_press
	JP loop ; Back to the start of the loop

key1_press:
	LD DE, key1_text
	CALL otext
	RET

key2_press:
	LD DE, key2_text
	CALL otext
	RET

key3_press:
	LD DE, key3_text
	CALL otext
	RET

key4_press:
	LD DE, key4_text
	CALL otext
	RET

; Output text pointed to by DE
;   loop through calling outchar until $80 is encountered
otext:
		PUSH AF
otloop:	LD A, (DE)
		CP A, $80		; $80 means end of text
		JP Z, otend		
		CALL outchar	; output the byte in A
		INC DE			; point to next
		JP otloop
otend:	POP AF
		RET

;; Output the byte in A to IOS
outchar:
		PUSH AF
		LD A, tx_opcode
		OUT (opcode_port), A
		POP AF
		OUT (exec_wport), a
		RET

key1_text: DEFM "You pressed KEY 1",A_CR,A_LF,$80
key2_text: DEFM "You pressed KEY 2",A_CR,A_LF,$80
key3_text: DEFM "You pressed KEY 3",A_CR,A_LF,$80
key4_text: DEFM "You pressed KEY 4",A_CR,A_LF,$80

TEXT0:
	DEFM	"GPIO Example",A_CR,A_LF
	DEFM	"4 switches connected to GPIO B",A_CR,A_LF
	DEFB	$80

	