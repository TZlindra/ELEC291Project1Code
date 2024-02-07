$NOLIST
;----------------------------------------------------
; Serial_4bit.asm: Sends Char Buffers to Serial Port
;----------------------------------------------------

CSEG

;---------------------------------;
; Display a BCD number in the LCD ;
;---------------------------------;

?PutChar:
    SJMP Wait_TI
Wait_TI:
    JNB TI, Wait_TI
    CLR TI
    MOV SBUF, A
    RET

Send_NewLine MAC
    MOV DPTR, %0
    LCALL ?Send_NewLine
ENDMAC

?Send_NewLine:
    CLR A
    MOVC A, @A+DPTR
    JZ ?Send_NewLine_Done

    LCALL ?PutChar
    INC DPTR
    SJMP ?Send_NewLine
?Send_NewLine_Done:
    RET

Send_BCD MAC
	PUSH AR0
	MOV R0, %0
	LCALL ?Send_BCD
	POP AR0
ENDMAC

?Send_BCD:
	PUSH ACC
Write_MostSigDig:
	; Write Most Significant Digit
	MOV A, R0
	SWAP A
	ANL A, #0FH
	ORL A, #30H
	LCALL ?PutChar
Write_LeastSigDig:
	; Write Least Significant Digit
	MOV A, R0
	ANL A, #0FH
	ORL A, #30H
	LCALL ?PutChar
	POP ACC
	RET
$LIST