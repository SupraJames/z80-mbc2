; Z80-MDB2 MEMORY TEST PROGRAM
;
; TESTS THE FOLLOWING REGIONS OF MEMORY
; $8300 - $FF00			; Bit ugly but avoids this program and the stack
; $0000 - $7FFF BANK 0
; $0000 - $7FFF BANK 1
; $0000 - $7FFF BANK 2

rx_port         .equ    $01             ; IOS "serial Rx" read port address
opcode_port     .equ    $01             ; IOS opcode write port address
exec_wport      .equ    $00             ; IOS "execute opcode" write port address
tx_opcode       .equ    $01             ; IOS "serial Tx" operation opcode
sb_opcode		.equ	$0d				; IOS "switch bank" opcode
eos             .equ    $00             ; End of string
cr              .equ    $0d             ; Carriage return
lf              .equ    $0a             ; Line feed

	ORG	$0						; Force the HEX output of zasm to start at $8000
	ORG	$8000					;
	
	LD		SP, $FFFF
	ld		HL, MSGSTART
	CALL	puts
	LD		HL, $8300
	LD		DE, $7C00
	CALL	RAMTST
	CALL	CHKERROR
	
	LD		HL, MSGBANK
	CALL	puts
	LD		A, '0'
	CALL	putc
	LD		A, cr
	CALL	putc
	ld		A, lf
	CALL	putc
	LD		B, $00
	CALL	DOSWITCH
	LD		HL, $0000
	LD		DE, $7FFF
	CALL	RAMTST
	CALL	CHKERROR
	
	LD		HL, MSGBANK
	CALL	puts
	LD		A, '1'
	CALL	putc
	LD		A, cr
	CALL	putc
	ld		A, lf
	CALL	putc
	LD		B, $01
	CALL	DOSWITCH
	LD		HL, $0000
	LD		DE, $7FFF
	CALL	RAMTST
	CALL	CHKERROR
	
	LD		HL, MSGBANK
	CALL	puts
	LD		A, '2'
	CALL	putc
	LD		A, cr
	CALL	putc
	ld		A, lf
	CALL	putc
	LD		B, $02
	CALL	DOSWITCH
	LD		HL, $0000
	LD		DE, $7FFF
	CALL	RAMTST
	CALL	CHKERROR
	LD		HL, MSGALLPASS
	CALL	puts
	HALT
	
CHKERROR:
	RET		NC
	LD		B, A
	PUSH	HL
	LD		HL, MSGERROR
	CALL	puts
	POP		HL
	CALL	dispadd
	LD		HL, MSGBITS
	CALL	puts
	LD		A, B
	CALL	hexout
	HALT
	
DOSWITCH:
	PUSH AF
	LD A, sb_opcode
	OUT (opcode_port), A
	LD A, B
	OUT (exec_wport), A
	POP AF
	RET
		
MSGSTART	.BYTE	"Memory test starting", cr, lf, eos
MSGINFO		.BYTE	" bytes starting from address ", eos
MSGOK		.BYTE	"PASS", cr, lf, eos
MSGERROR	.BYTE	"Test failed at address ", eos
MSGBITS		.BYTE	" with bit pattern ", eos
MSG00		.BYTE	"Read and write 00000000 : ", eos
MSGFF 		.BYTE	"Read and write 11111111 : ", eos
MSGAA		.BYTE	"Read and write 10101010 : ", eos
MSG55		.BYTE	"Read and write 01010101 : ", eos
MSGWLK		.BYTE	"Walking bit test        : ", eos
MSGBANK		.BYTE	cr, lf, "Switching to BANK ", eos
MSGALLPASS	.BYTE	cr, lf, "All tests PASSED - HALT", cr, lf, eos

RAMTST:
	; EXIT WITH NO ERRORS IF AREA SIZE IS 0
	LD		A, D
	OR		E
	RET		Z
	PUSH	HL
	LD		HL, DE
	CALL	dispadd
	LD		HL, MSGINFO
	CALL	puts
	POP		HL
	CALL	dispadd
	LD		A, cr
	CALL	putc
	LD		A, lf
	CALL	putc
	LD		B,D
	LD		C,E
	
	;FILL MEMORY WITH 0 AND TEST
	
	PUSH	HL
	LD		HL, MSG00
	CALL	puts
	POP		HL
	SUB		A
	CALL	FILCMP
	RET		C
	
	;FILL MEMORY WITH FF HEX AND TEST
	PUSH	HL
	LD		HL, MSGFF
	CALL	puts
	POP		HL
	LD		A, $FF
	CALL	FILCMP
	RET		C
	
	; FILL MEMORY WITH AA HEX AND TEST
	PUSH	HL
	LD		HL, MSGAA
	CALL	puts
	POP		HL
	LD		A, $AA
	CALL	FILCMP
	RET		C
	
	; FILL MEMORY WITH 55 HEX AND TEST
	PUSH	HL
	LD		HL, MSG55
	CALL	puts
	POP		HL
	LD		A, $55
	CALL	FILCMP
	RET		C

	PUSH	HL
	LD		HL, MSGWLK
	CALL	puts
	POP		HL	
WLKLP:
	LD		A, $80 		; BINARY 1000000
WLKLP1:
	LD		(HL), A		; STORE TEST PATTERN IN MEMORY
	CP		(HL)		; TRY TO READ IT BACK
	SCF					; SET CARRY N CASE OF ERROR
	RET		NZ			; RETURN IF ERROR
	RRCA				; ROTATE PATTERN 1 RIGHT
	CP		$80
	JR		NZ,WLKLP1	; CONT UNTIL BINARY 10000000 AGAIN
	LD		(HL), 0		; CLEAR BYTE JUST CHECKED
	INC		HL
	DEC		BC			; DEC AND TEST 16-BIT COUNTER
	LD		A, B
	OR		C
	JR		NZ,WLKLP	; CONT UNTIL MEMORY TESTED
	PUSH	HL
	LD		HL, MSGOK
	CALL	puts
	POP 	HL
	RET					; NO ERRORS
	
FILCMP:
	PUSH	HL			; SAVE BASE ADDRESS
	PUSH	BC			; SAVE SIZE OF AREA
	LD		E, A		; SAVE TEST VALUE
	LD		(HL), A		; STORE TEST VALUE IN FIRST BYTE
	DEC		BC			; REMAINING AREA = SIZE - 1
	LD		A, B		; CHECK IF ANY AREA REMAINS
	OR		C
	LD		A, E		; RESTORE TEST VALUE
	JR		Z, COMPARE	; BRANCH IS AREA WAS ONLY 1 BYTE
	
	; FILL REST OF AREA USING BLOCK MOVE
	; EACH ITERATION MOVES TEST VALUE TO NEXT HIGHER ADDRESS
	LD		D, H		; DESTINATION IS ALWAYS SOURCE + 1
	LD		E, L
	INC		DE
	LDIR				; FILL MEMORY
	
	; NOW THAT MEMORY HAS BEEN FILLED, TEST TO SEE IF
	; EACH BYTE CAN BE READ BACK CORRECTLY
	
COMPARE:
	POP		BC			; RESTORE SIZE OF AREA
	POP		HL			; RESTORE BASE ADDRESS
	PUSH	HL			; SAVE BASE ADDRESS
	PUSH	BC			; SAVE SIZE OF VALUE
	
	; COMPARE MEMORY AND TEST VALUE
	
CMPLP:
	CPI
	JR		NZ, CMPER	; JUMP IF NOT EQUAL
	JP		PE, CMPLP	; CONTINUE THROUGH ENTIRE AREA
						; NOTE CPI CLEARS P/V FLAG IF IT
						; DECREMENTS BC TO 0
						
	; NO ERRORS FOUND, SO CLEAR CARRY
	POP		BC			; BC = SIZE OF AREA
	POP		HL			; HL = BASE ADDRESS
	OR		A			; CLEARS CARRY
	PUSH	HL
	LD		HL, MSGOK
	CALL	puts
	POP 	HL
	RET
	
	; ERROR EXIT, SET CARRY
	
CMPER:
	POP		BC
	POP		DE
	SCF
	RET

;
; Send a string to the serial line, HL contains the pointer to the string
;

puts            push    af
                push    hl
puts_loop       ld      a, (hl)
                cp      eos             ; End of string reached?
                jr      z, puts_end     ; Yes
                call    putc
                inc     hl              ; Increment character pointer
                jr      puts_loop       ; Transmit next character
puts_end        pop     hl
                pop     af
                ret

;
; Send a single character to the serial line (A contains the character)
;

putc            push    af              ; Save A
                ld      a, tx_opcode    ; A = IOS Serial Tx operation opcode
                out     (opcode_port), a; Send to IOS the Tx operation opcode
                pop     af              ; Restore the output char into A
                out     (exec_wport), a ; Write A to the serial
                ret

;; Display '[aaaa]' - address of HL
dispadd:
		LD A, '['
		CALL putc
		LD A, H
		CALL hexout
		LD A, L
		CALL hexout
		LD A, ']'
		CALL putc
		RET

; OUTPUT VALUE OF A IN HEX ONE NYBBLE AT A TIME
hexout	PUSH BC
		PUSH AF
		LD B, A
		; Upper nybble
		SRL A
		SRL A
		SRL A
		SRL A
		CALL TOHEX
		CALL putc
		
		; Lower nybble
		LD A, B
		AND 0FH
		CALL TOHEX
		CALL putc
		
		POP AF
		POP BC
		RET
		
; TRANSLATE VALUE IN A TO 2 HEX CHAR CODES FOR DISPLAY
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

; LOOKUP TABLE FOR TOHEX ROUTINE
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
	