;
; Simple monitor for Z80-MBC
;
;  Current address is in HL
;  Display [nnnn] bb (A)
;          nnnn is current address, bb is hex byte, A is ASCII char
;  Input:
; <space> displays current byte
; [0-9,A-F] enters current address
; <enter> increments current address (loops through FFFF)
; <backspace> decrements current address (loops through 0000)
; l lists 16 locations, update current
; d dumps a grid of memory from current until keypress
; c copies memory: requesting from, to and length
; S (capital) enters set mode: hex input fills memory until <enter> or <ESC>
; X (capital) executes from current
; h <enter> display this help
; any errors dislpays '?'",$0A,$0D
;
; Memory Map is
; 0000-7FFF 32K switchable bank 1,2,3
; 8000-FFFF 32K fixed bank 0, best to load this monitor here!
; No 'ROM' as such

rx_port         .equ    $01             ; IOS "serial Rx" read port address
opcode_port     .equ    $01             ; IOS opcode write port address
exec_wport      .equ    $00             ; IOS "execute opcode" write port address
tx_opcode       .equ    $01             ; IOS "serial Tx" operation opcode
usrLED_opcode   .equ    $00             ; IOS "user LED" operation opcode
sb_opcode	    .equ	$0d	           	; IOS "Switch Bank" opcode
;eos             .equ    $00             ; End of string
;cr              .equ    $0d             ; Carriage return
;lf              .equ    $0a             ; Line feed

A_CR		equ	0Dh		; Carriage Return ASCII
A_LF		equ 0Ah		; Line Feed ASCII
A_BS		equ	08h		; Backspace
A_FF		equ	0Ch
A_ESC		equ 1Bh
A_DEL		equ 7Fh

RAMTOP		equ	$FFFF	;	RAM ends at $FFFF
TEMP		equ RAMTOP	; 	Temporary storage byte
KDATA1		equ TEMP-1	;	keyed input for addresses
KDATA2		equ KDATA1-1
BUFFER		equ	KDATA2-256	; for building strings - 256 bytes
STACK		equ BUFFER-1	; then we have the stack
	
	org 0
	org $8000	; Start address - bottom of fixed bank 
	
	LD SP,STACK

init:
	LD HL,8000h

start:
; Output the startup text
	LD DE, TEXT0
	CALL otext
	
; Output the current location [nnnn] bb (A)
display:
; Turn on LED1 to show display loop
	CALL on1		; turn on LED1 to show busy
	CALL dispadd	; Display [nnnn]
	LD A, ' '
	CALL outchar
	CALL outchar
	LD A, (HL)
	CALL hexout
	LD A, ' '
	CALL outchar
	LD A, '('
	CALL outchar
	LD A, (HL)
	CALL outchar
	LD A, ')'
	CALL outchar
	CALL OUTCRLF
	
inloop:
	;JP inloop
	CALL inchar			; wait for input
	LD BC, 0			; C is used

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SELECT BASED ON INPUT CHAR
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	CP ' '			; <space>: display
	JP Z, display
	CP A_CR			; <CR>: increment and display
	JP NZ, L1
	INC HL
	JP display
L1:	CP A_DEL		; backspace: decrement and display
	JP NZ, L2
	DEC HL
	JP display
L2:	CP 'h'			; h: show help then display
	JP Z, start
	CP 'c'			; c: copy memory
	JP Z, copy
	CP 'd'			; d: dump until keypress
	JP Z, dump
	CP 'l'			; l: list 16 locations
	JP Z, list
	CP 'S'			; S: enter write mode (set)
	JP Z, set
	CP 'k'			; k: bulk set memory
	JP Z, bulkset
	CP 't'			; t: type ascii to memory
	JP Z, typemem
	CP 'X'			; X: execute from current
	JP Z, exec
	CP 'v'			; v: HALT
	JP Z, halt
	CP 'B'			; B: Switch bank
	JP Z, switchbank
	CP 30h			; test for hex digit
	JP C, notdig	; < $30
	CP 47h			
	JP NC, notdig	; >= $47
	CP 3Ah
	JP NC, T1		; >= $3A
	JP digit
T1:	CP 41h			; AND
	JR C, notdig	; < $41
digit:
	CALL fourcar	; <hexdigit>: address entry
	JP display
notdig:
	LD A, '?'		; no other commands, output '?'
	CALL outchar
	CALL OUTCRLF
	JP display

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SET
;;   output SET [aaaa] [nn] where nn is current contents
;;   call two character input to set (HL)
;;   increment HL
;;   repeat until <esc>
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
set:
	LD DE, SETTXT
	CALL otext
	CALL dispadd
	LD A, ' '
	CALL outchar
	
	CALL twocar		; two character input and set (HL)
	CALL OUTCRLF	; new line
	LD A, B			; B contains $FF if we aborted
	CP $FF
	JP NZ, setend	; abort - go to display
	JP display	
setend:
	INC HL			; else next address and loops
	JP set

; switchbank
switchbank:
	PUSH AF
	LD DE, SWTXT
	CALL otext
	CALL inchar
	CP '1'
	JP Z, bank1
	CP '2'
	JP Z, bank2
	LD B, $00
	JP doswitch
bank1:
	LD B, $01
	JP doswitch
bank2:
	LD B, $02
doswitch:
	LD A, sb_opcode
	OUT (opcode_port), A
	LD A, B
	OUT (exec_wport), A
	POP AF
	JP display
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; EXECUTE
;;    execute from HL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
exec:
	LD DE, EXTXT	; confirmation text
	CALL otext
	CALL dispadd
	CALL OUTCRLF
	
	CALL inchar
	CP A_CR			; <ret> we continue, else abort
	JP NZ, xabort	
	PUSH HL
	RET
xabort:
	JP display

halt:
	HALT
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; LIST - LIST 16 LOCATIONS, SETTING HL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
list:
	LD C, $FF		; Use C=$FF to do one cycle of dump

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DUMP - dump memory from current location until keypress
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
dump:
	LD A, H
	CALL hexout
	LD A, L
	CALL hexout
	
	LD A, ' '
	CALL outchar
	CALL outchar

	LD B, 16
	LD IX, BUFFER		; Build string of ASCII values at TEMP
loop16:	
	LD A, (HL)
	CALL hexout
	LD (IX), '.'		; set it to dot and we'll overwrite if it's displayable
	CP 20h				; displayable is >$19 and <$7f
	JP M, skip
	CP 7Fh
	JP P, skip
	LD (IX), A			; replace with the ASCII code otherwise
skip:
	LD A, ' '
	CALL outchar
	INC HL
	INC IX
	DEC B
	LD A, 0
	CP B
	JP NZ, loop16
	
	; Output the 8 ASCII chars at BUFFER
	; Add a $80 on the end and use otext routine
	LD A, 80h
	LD (BUFFER+16), A
	LD DE, BUFFER
	CALL otext
	CALL OUTCRLF
	
	LD A, C				; check if we were only doing one line
	CP $FF
	JP Z, display		; C was $FF so stop at one cycle
	
	CALL chkchar		; check if a key was pressed
	CP $FF
	JP NZ, display		; a keypress: abort
	
	JP dump
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; COPY from, to, length (all in hex)
;;    use BUFFER to store 'to' and 'from'
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
copy:
	PUSH HL
	PUSH DE
	PUSH BC
	LD DE, CPTXT1	; Copy: From
	CALL otext
	
	LD A, $30		; start fourcar with [0000]
	CALL fourcar
	LD (BUFFER), HL
	LD DE, CPTXT2	; To:
	CALL otext
	LD A, $30		; start fourcar with [0000]
	CALL fourcar
	LD (BUFFER+2), HL
	LD DE, CPTXT3	; Length:
	CALL otext
	LD A, $30		; start fourcar with [0000]
	CALL fourcar
	LD BC, HL		; set up for eLDIR
	LD DE, (BUFFER+2)
	LD HL, (BUFFER)
	CALL eLDIR
	
	LD DE, DONETXT	; Done
	CALL otext
	POP BC
	POP DE
	POP HL
	JP display

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Four hex digit rotating input starting with contents of A
;;   exits on <ret> or <esc>
;;   HL contains the address input on return
;;   or HL remains unchanged on abort
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
fourcar:
		PUSH AF
		PUSH BC
		LD BC, HL		; save original HL
		; First set HL to [000(digit)] to display
		CALL ATOHEX
		LD L, A
		LD H, 00h
		LD (KDATA2), A	; start with the digit we were given
		LD A, 0
		LD (KDATA1), A
		; Output [nnnn] then one backspace
		CALL dispadd
		LD A, A_BS
		CALL outchar
fcloop:
		; Output 4 backspaces
		LD A, A_BS
		CALL outchar
		CALL outchar
		CALL outchar
		CALL outchar
		
		CALL inchar
		CP A_CR			; <return>: end
		JP Z, fcend
		CP A_ESC		; <escape>: abort
		JP NZ, fccont
		LD HL, BC		; Abort - restore old value
		JP fcabort
fccont:	CALL ATOHEX
		LD HL, KDATA2
		RLD
		LD HL, KDATA1
		RLD
		LD A, (KDATA1)
		CALL hexout
		LD A, (KDATA2)
		CALL hexout
		JP fcloop
		
fcend:	LD HL, (KDATA2)		;Loads L then H
fcabort:
		CALL OUTCRLF
		POP BC
		POP AF
		RET	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; TWO CHARACTER ROLLING INPUT ROUTINE, exits on <esc> or <ret>
;;   sets (HL) to A and returns
;;   on <esc> set (HL) to original value, write FF to A and return
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
twocar:
		PUSH HL
		; Output [00] then one backspace
		LD A, '['
		CALL outchar
		LD A, '0'
		CALL outchar
		CALL outchar
		LD A, ']'
		CALL outchar
		LD A, A_BS
		CALL outchar
		LD B, (HL)		; save the old contents for <esc>
		LD HL, KDATA1
		LD (HL), 0
tcloop:
		; Output 2 backspaces
		LD A, A_BS
		CALL outchar
		CALL outchar

		CALL inchar
		CP A_CR
		JP Z, tcend
		CP A_ESC
		JP Z, tcabort
		
		CALL ATOHEX
		RLD
		LD A, (HL)
		CALL hexout
		JP tcloop
		
tcabort:
		LD A, B		; <esc>: so restore A
		LD (KDATA1), A
		LD B, $FF	; Use $FF in B to indicate an abort
tcend:	POP HL
		LD A, (KDATA1)
		LD (HL), A	; set (HL) to KDATA1
		RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
;; Display '[aaaa]' - address of HL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
dispadd:
		LD A, '['
		CALL outchar
		LD A, H
		CALL hexout
		LD A, L
		CALL hexout
		LD A, ']'
		CALL outchar
		RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
; OUTPUT VALUE OF A IN HEX ONE NYBBLE AT A TIME
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
hexout	PUSH BC
		PUSH AF
		LD B, A
		; Upper nybble
		SRL A
		SRL A
		SRL A
		SRL A
		CALL TOHEX
		CALL outchar
		
		; Lower nybble
		LD A, B
		AND 0FH
		CALL TOHEX
		CALL outchar
		
		POP AF
		POP BC
		RET
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
; TRANSLATE value in lower A TO 2 HEX CHAR CODES FOR DISPLAY
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
TOHEX:
		PUSH HL
		PUSH DE
		LD D, 0
		LD E, A
		LD HL, DATA
		ADD HL, DE
		LD A, (HL)
		POP DE
		POP HL
		RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 	ASCII char code for 0-9,A-F in A to single hex digit
;;    subtract $30, if result > 9 then subtract $7 more
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ATOHEX:
		SUB $30
		CP 10
		RET M		; If result negative it was 0-9 so we're done
		SUB $7		; otherwise, subtract $7 more to get to $0A-$0F
		RET		

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; eLDIR - LDIR but with confirmed writes
;;   HL=from, DE=to, BC=length
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
eLDIR:
		PUSH AF
ldlp:	LD A, B			; test BC for zero first
		OR C			; stupid z80 doesn't flag after DEC xy
		JP Z, ldend
		LD A, (HL)
		PUSH HL
		LD HL, DE
		CALL CONFWR		; uses HL
		POP HL
		INC HL
		INC DE
		DEC BC
		JP ldlp
ldend:	POP AF
		RET		
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CONFWR - Write to address with confirm, returns when complete
;;          used for writign to EEPROM
;;  This will hang the computer if write does not succeed
;; byte to write is in A
;; address to write is HL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CONFWR:
		PUSH BC
		LD B, A
		LD (HL), A		; write the byte
eeloop:	LD A, (HL)		; read the byte
		CP B			; the EEPROM puts inverse of the value
		JP NZ, eeloop	; while it is writing
		POP BC
		RET	
				
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Wait until IOS Serial has a byte, store it in A
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
inchar:
		IN A, (rx_port)	; read LSR
		CP $FF
		JP Z, inchar
		RET
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; If IOS Serial has a byte, store it in A else return $FF
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
chkchar:
		IN A, (rx_port)
		RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Output the byte in A to IOS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
outchar:
		PUSH AF
		LD A, tx_opcode
		OUT (opcode_port), A
		POP AF
		OUT (exec_wport), a
		RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
; Output text pointed to by DE
;   loop through calling outchar until $80 is encountered
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
;; OUTCRLF - output a CR and an LF
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
OUTCRLF:
		PUSH AF
		LD A, A_CR
		CALL outchar
		LD A, A_LF
		CALL outchar
		POP AF
		RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
;; Turn on or off USER led
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
on1:
		PUSH AF
		LD A, usrLED_opcode
		OUT (opcode_port), A
        LD A, $01
        OUT (exec_wport), A
		POP AF
		RET
off1:	
		PUSH AF
		LD A, usrLED_opcode
		OUT (opcode_port), A
        LD A, $00
        OUT (exec_wport), A
		POP AF
		RET

DATA:
		DEFB	30h	; 0
		DEFB	31h	; 1
		DEFB	32h	; 2
		DEFB	33h	; 3
		DEFB	34h	; 4
		DEFB	35h	; 5
		DEFB	36h	; 6
		DEFB	37h	; 7
		DEFB	38h	; 8
		DEFB	39h	; 9
		DEFB	41h	; A
		DEFB	42h	; B
		DEFB	43h	; C
		DEFB	44h	; D
		DEFB	45h	; E
		DEFB	46h	; F
	
TEXT0:
	DEFM	"Simple Z80-MBC2 Monitor v0.1",$0A,$0A,$0D
	DEFM	"<spc>: display address",$0A,$0D
	DEFM	"[0-9A-F]: enter address (<esc> abort)",$0A,$0D
	DEFM	"<ent>: inc address, <bs>:dec address",$0A,$0D
	DEFM	"l: list+inc 16",$0A,$0D
	DEFM	"d: dump at address (any key ends)",$0A,$0D
	DEFM	"S: set at address (<ent>:set+inc <esc>:end)",$0A,$0D
	DEFM	"X: exec address (caution!)",$0A,$0D
	DEFM	"B: Switch lower 32k bank",$0A,$0D
	DEFM	"c: copy... (length=0 to abort)",$0A,$0D
	DEFM	"k: bulk set...",$0A,$0D
	DEFM	"t: type ascii to mem...",$0A,$0D
	DEFM	"h: this help",$0A,$0D
	DEFM	"v: execute HALT",$0A,$0A,$0D
	DEFB	$80

SETTXT:
	DEFM	"SET ",$80
	
EXTXT:
	DEFM	"exec ",$80
SWTXT:
	DEFM	"bank (0-2):",$80
	
CPTXT1:
	DEFM	"copy from:",$80
CPTXT2:
	DEFM	"to:", $80
CPTXT3:
	DEFM	"length:",$80

DONETXT:
	DEFM	"Done.",$0A,$0D,$80
	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Additional routines
;; April 2015
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Call address in HL
;; Works by putting 'display' on the stack
;; destroys DE
callhl:
	LD DE, EXTXT	; confirmation text
	CALL otext
	CALL dispadd
	CALL OUTCRLF
	CALL inchar
	CP A_CR			; <ret> we continue, else abort
	JP NZ, xabort	; xabort jumps to display
	
	LD DE, display
	PUSH DE
	PUSH HL
	RET


;; Bulk memory set, continuous entry
;; designed to take paste from clipboard
;; of continual hex stream
;; starts from HL until <esc>
bulkset:
	PUSH DE
	LD DE, bstxt
	CALL otext
	
	; ask for address -> HL
	XOR A
	CALL fourcar
	
	LD DE, bstxt1
	CALL otext
	
bkdigit:	
	; Digit 1
	CALL inchar
	CP A_ESC
	JR Z, bsabort
	CALL outchar	; echo the character
	CALL ATOHEX		; convert to binary
	RLD				; move into (HL) lower nybble

	; Digit 2
	CALL inchar
	CALL outchar	; echo the character
	CALL ATOHEX		; convert to binary
	RLD				; shift (HL) and move into lower nybble
	
	INC HL
	JR 	bkdigit
	
bsabort:
	LD DE, DONETXT
	CALL otext
	POP DE
	JP	display
bstxt:
	DEFM "Bulk load to: ",$80
bstxt1:
	DEFM "Ready (<esc> to end): ",$80
	
	
;; Type ascii values to memory, <esc> exits
typemem:
	PUSH DE
	LD DE, tmtxt
	CALL otext

	; ask for address -> HL
	XOR A			; zero A as first digit of fourchar
	CALL fourcar	; set HL as per user entry

	LD DE, bstxt1
	CALL otext

tmloop:
	CALL inchar
	LD (HL), A
	INC HL
	CALL outchar
	CP A_ESC		; escape
	JR NZ, tmloop

	LD HL, DE
	POP DE
	JP display
tmtxt:
	DEFM "Type ascii to: ",$80
	

;; Set memory range to value in A
;; From HL, length in BC
SETMEM:
	PUSH DE
	LD D, A
smloop:
	LD A, B		; Test BC for zero first
	OR C
	JR Z, smend		
	LD A, D
	CALL CONFWR
	INC HL
	DEC BC
	JR smloop
smend:	
	LD DE, DONETXT
	CALL otext
	POP DE
	JP display

txt:	DEFM "Fin.",$0D,$0A,$80
