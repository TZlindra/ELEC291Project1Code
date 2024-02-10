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

START_BUTTON equ P1.7
OUTPUT_PIN 	 equ P1.5

; Reset vector
org 0x0000
    ljmp FSM_main

; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	reti

; External interrupt 1 vector (not used in this code)
org 0x0013
	reti

; Timer/Counter 1 overflow interrupt vector (not used in this code)
org 0x001B
	reti

; Serial port receive/transmit interrupt vector (not used in this code)
org 0x0023 
	reti
	
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

dseg at 0x30
Count1ms:     ds 2 ; Used to determine when half second has passed
BCD_counter:  ds 1 ; The BCD counter incrememted in the ISR and displayed in the main loop
STATE_NUM: 	  ds 1 ;
Current_Counter: 	  ds 1 ; 
Resulting_Counter:	  ds 1 ;
timer_state:          ds 1 ;
beep_count:			  ds 1 ;
desired_PWM:		  ds 2 ;


; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
;Alarm_En_Flag:	dbit 1
;timer_state: 		dbit 1 ; is state in a timer state?

cseg
; These 'equ' must match the hardware wiring
LCD_RS equ P1.3
LCD_E  equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3


$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
;$include(timer-pwm.asm)
$LIST

pwm_main: ; called in main
    ;initial values, STARTING AT state0
    mov desired_PWM, #0x00      ;set desired PWM percent to 0
    ;setb OUTPUT_PIN             ;
    ret



Inc_PWM: ; called from fsm.asm
	mov a, Count1ms+0
    cjne a, desired_PWM+0, Inc_PWM2 
	mov a, Count1ms+1
	cjne a, desired_PWM+1, Inc_PWM2
    clr OUTPUT_PIN
Inc_PWM2:
    mov a, Count1ms+0
    cjne a, #low(999), return0 
	mov a, Count1ms+1
	cjne a, #high(999), return0
    setb OUTPUT_PIN  ;NOTE: unsure if swap power flag needed
return0:
	ret



power0: ; called from states
    clr OUTPUT_PIN
    ret
power20: ; called from states
    mov desired_PWM+0, #low(200)  ;20% power
    mov desired_PWM+1, #high(200)
    ret
power100: ; called from states
    setb OUTPUT_PIN
    ret

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
    setb TR2  ; 
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
	mov a, timer_state
	cjne a, #0x00, continue; if in timer state, jump
	lcall Inc_PWM
continue:	
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
    
    mov BCD_counter, a
	cjne a, Resulting_Counter, Timer2_ISR_done ; IF Resulting_counter is not BCD_counter, then skip
	mov a, timer_state
    cjne a, #0x01, Timer2_ISR_done; if we are NOT in a timer state, jump to ISR_done

	; IF STATE 1, then check 
	mov a, STATE_NUM
	cjne a, #0x01, OtherStates ; if STATE_NUM is NOT 1, jump
	; CHECK if temperature is LESS than 50
	mov STATE_NUM, #0x00
	mov BCD_counter, #0x00
	ljmp Timer2_ISR_done
OtherStates:
	mov BCD_counter, #0x00
	inc STATE_NUM 	; increment state
Timer2_ISR_done:


	pop psw
	pop acc
	reti

LCD:
	Set_Cursor(2,5)
	Display_BCD(Resulting_Counter)
    Set_Cursor(2,1)
    Display_BCD(BCD_counter)
    Set_Cursor(1,1)
    Display_BCD(STATE_NUM)
    ret



	; PROBLEM, 1ms uses TIMER 0
Wait50milliSec:
    mov R2, #10
W3: mov R1, #200
W2: mov R0, #104
W1: djnz R0, W1 ; 4 cycles->4*60.285ns*104=25us
    djnz R1, W2 ; 25us*200=5.0ms
    djnz R2, W3 ; 5.0ms*10=50ms (approximately)
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
    mov timer_state, #0x00
    lcall power0
	jb START_BUTTON, quit0 ; if START BUTTON is NOT PRESSED
	lcall Wait50milliSec
	jb START_BUTTON, quit0

	jnb START_BUTTON, $ ; if START BUTTON is PRESSED go to state1
	mov BCD_counter, #0x00
	mov Resulting_Counter, #0x60
	inc STATE_NUM
quit0:
	ret
state1:
    mov timer_state, #0x01
    lcall power100
	jb START_BUTTON, quit1 ; if START BUTTON is NOT PRESSED
	lcall Wait50milliSec
	jb START_BUTTON, quit1

	jnb START_BUTTON, $ ; if START BUTTON is PRESSED go to state1
	; IF TEMPERATURE is 150, 
    
	mov BCD_counter, #0x00
	mov Resulting_Counter, #0x06
	inc STATE_NUM
quit1:
	ret 
	
state2:
    lcall power20
    mov timer_state, #0x01
    jb START_BUTTON, quit2 ; if START BUTTON is NOT PRESSED
	lcall Wait50milliSec
	jb START_BUTTON, quit2

	jnb START_BUTTON, $ ; if START BUTTON is PRESSED go to state1
    mov timer_state, #0x00
quit2:
	ret

state3:
    lcall power100
    mov timer_state, #0x00
    jb START_BUTTON, quit3 ; if START BUTTON is NOT PRESSED
	lcall Wait50milliSec
	jb START_BUTTON, quit3

	jnb START_BUTTON, $ ; if START BUTTON is PRESSED go to state1
	; IF TEMPERATURE REACHES RIGHT VALUE
    mov timer_state, #0x01
	mov BCD_counter, #0x00
	mov Resulting_Counter, #0x07
	inc STATE_NUM
quit3:
	ret

state4:
    lcall power20
    mov timer_state, #0x01
    jb START_BUTTON, quit4 ; if START BUTTON is NOT PRESSED
	lcall Wait50milliSec
	jb START_BUTTON, quit4

	jnb START_BUTTON, $ ; if START BUTTON is PRESSED go to state1
	mov BCD_counter, #0x00
quit4:
	ret
state5:
    lcall power0
    mov timer_state, #0x00
    jb START_BUTTON, quit5 ; if START BUTTON is NOT PRESSED
	lcall Wait50milliSec
	jb START_BUTTON, quit5

	jnb START_BUTTON, $ ; if START BUTTON is PRESSED go to state1
	; CHECK IF TEMPERATURE REACHES VERY LOW VALUE
	mov STATE_NUM, #0x00
	mov BCD_counter, #0x00
quit5:
	ret

FSM_main:
    mov SP, #0x7F
    
    mov P0M1, #0x00
    mov P0M2, #0x00
    mov P1M1, #0x00
    mov P1M2, #0x00
    mov P3M2, #0x00
    mov P3M2, #0x00
    
    
    
    
	mov BCD_counter, #0x00
	mov STATE_NUM, #0x00
	mov Resulting_Counter, #0x00

    lcall LCD_4BIT
    lcall PWM_main
	lcall Timer2_Init
    setb EA   ; Enable Global interrupts
FSM_forever:

	lcall LCD
	lcall StateChanges
	
	
    

	ljmp FSM_forever


; 
END
