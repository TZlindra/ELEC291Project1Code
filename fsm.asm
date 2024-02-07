$NOLIST
$MODN76E003
$LIST

;  N76E003 pinout:
;                               -------
;       PWM2/IC6/T0/AIN4/P0.5 -|1    20|- P0.4/AIN5/STADC/PWM3/IC3
;               TXD/AIN3/P0.6 -|2    19|- P0.3/PWM5/IC5/AIN6
;               RXD/AIN2/P0.7 -|3    18|- P0.2/ICPCK/OCDCK/RXD_1/[SCL]
;                    RST/P2.0 -|4    17|- P0.1/PWM4/IC4/MISO
;        INT0/OSCIN/AIN1/P3.0 -|5    16|- P0.0/PWM3/IC3/MOSI/T1
;              INT1/AIN0/P1.7 -|6    15|- P1.0/PWM2/IC2/SPCLK
;                         GND -|7    14|- P1.1/PWM1/IC1/AIN7/CLO
;[SDA]/TXD_1/ICPDA/OCDDA/P1.6 -|8    13|- P1.2/PWM0/IC0
;                         VDD -|9    12|- P1.3/SCL/[STADC]
;            PWM5/IC7/SS/P1.5 -|10   11|- P1.4/SDA/FB/PWM1
;                               -------
;

CLK           EQU 16600000 ; Microcontroller system frequency in Hz
TIMER2_RATE   EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/TIMER2_RATE)))

dseg at 0x30
Count1ms:     ds 2 ; Used to determine when half second has passed
BCD_counter:  ds 1 ; The BCD counter incrememted in the ISR and displayed in the main loop
STATE_NUM: 	  ds 1 ;
Current_Counter: 	  ds 1 ; 
Resulting_Counter:	  ds 1 ;

; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
timer_state: 		ds 1 ; is state in a timer state?



cseg
; These 'equ' must match the hardware wiring
LCD_RS equ P1.3
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$include(math32.inc)
$include(main.asm)
$LIST

Timer2_Init:
	mov T2CON, #0 ; Stop timer/counter.  Autoreload mode.
	mov TH2, #high(TIMER2_RELOAD)
	mov TL2, #low(TIMER2_RELOAD)
	; Set the reload value
	orl T2MOD, #0x80 ; Enable timer 2 autoreload
	mov RCMP2H, #high(TIMER2_RELOAD)
	mov RCMP2L, #low(TIMER2_RELOAD)
	; Init One millisecond interrupt counter.  It is a 16-bit variable made with two 8-bit parts
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Enable the timer and interrupts
	orl EIE, #0x80 ; Enable timer 2 interrupt ET2=1
    clr TR2  ; TIMER 2 DISABLED
	ret


;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in the ISR.  It is bit addressable.
	
	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Increment the 16-bit one mili second counter
	inc Count1ms+0    ; Increment the low 8-bits first
	mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
	jnz Inc_Done
	inc Count1ms+1

Inc_Done:
	; Check if half second has passed
	mov a, Count1ms+0
	cjne a, #low(1000), Timer2_ISR_done 
	mov a, Count1ms+1
	cjne a, #high(1000), Timer2_ISR_done
	

	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Increment the BCD counter
	mov a, BCD_counter
	add a, #0x01
	da a
	mov BCD_counter, a
	cjne a, Resulting_Counter, Timer2_ISR_done ; IF Resulting_counter is not BCD_counter, then skip

	; IF STATE 1, then check 
	mov a, STATE_NUM
	cjne a, #0x01, OtherStates ; if STATE_NUM is NOT 1, jump
	; CHECK if temperature is LESS than 50
	mov STATE_NUM, #0x00
	ljmp Timer2_ISR_done
OtherStates:
	inc STATE_NUM 	; increment state
Timer2_ISR_done:
	mov BCD_counter, #0x00
	clr TR2


	pop psw
	pop acc
	reti



	; PROBLEM, 1ms uses TIMER 0
wait_1ms:
	clr	TR0 ; Stop timer 0
	clr	TF0 ; Clear overflow flag
	mov	TH0, #high(TIMER0_RELOAD_1MS)
	mov	TL0,#low(TIMER0_RELOAD_1MS)
	setb TR0
	jnb	TF0, $ ; Wait for overflow
	ret

; Wait the number of miliseconds in R2
waitms:
	lcall wait_1ms
	djnz R2, waitms
	ret

StateChanges: ; checks what will be the counter number for each state
	mov a, STATE_NUM
	cjne a, #0x00, next1 ; if STATE_NUM is NOT 0, jump to next1
	
	lcall state0
	ljmp done_state_counter
next1:
	mov a, STATE_NUM
	cjne a, #0x01, next2 ; if STATE_NUM is NOT 1, jump to next2

	lcall state1
	ljmp done_state_counter
next2:
	mov a, STATE_NUM
	cjne a, #0x02, next3 ; if STATE_NUM is NOT 2, jump to next3
	
	lcall state2
	ljmp done_state_counter
next3:
	mov a, STATE_NUM
	cjne a, #0x03, next4 ; if STATE_NUM is NOT 3, jump to next4

	lcall state3
	ljmp done_state_counter
next4:
	mov a, STATE_NUM
	cjne a, #0x04, next5 ; if STATE_NUM is NOT 4, jump to next5

	lcall state4
	ljmp done_state_counter
next5:
	lcall state5
	; STATE 5
	
done_state_counter:
	ret





state0:
	jb START_BUTTON, quit0 ; if START BUTTON is NOT PRESSED
	mov r2, #50
	lcall waitms
	jb START_BUTTON, quit0

	jnb START_BUTTON, $ ; if START BUTTON is PRESSED go to state1
	mov a, #0x60
	mov Resulting_Counter, a
	inc STATE_NUM
	setb TR2
quit0:
	ret
state1:
	
	; IF TEMPERATURE is 150, 

	mov a, #0x90
	mov Resulting_Counter, a
	ret
	inc STATE_NUM
	setb TR2

quit1:
	ret 
	
state2:
	

state3:
	; IF TEMPERATURE REACHES RIGHT VALUE
	mov a, #0x60
	mov Resulting_Counter, a
	inc STATE_NUM
	setb TR2
	ret
state4:

	ret
state5:
	; CHECK IF TEMPERATURE REACHES VERY LOW VALUE
	mov STATE_NUM, #0x00
	ret

FSM_main:
	mov BCD_counter, #0x00
	mov STATE_NUM, #0x00
	mov Current_Counter, #0x00
	mov Resulting_Counter, #0x00
	lcall Timer2_Init
    setb EA   ; Enable Global interrupts
FSM_forever:
	lcall StateChanges


	ljmp FSM_forever


; 
END
