$NOLIST
$MODN76E003
$LIST

org 0x0000
    ljmp main

; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR





CLK           EQU 16600000
TIMER0_RATE   EQU 500   ;0.5 ms
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))



OUTPUT_PIN  equ P1.5
input_button equ P1.6



dseg at 0x30                ;modify initial dseg position so no OVERLAP with other asm files
cycle_counter:     ds 2
desired_PWM:        ds 2 

bseg
power_flag: dbit 1

cseg
; These 'equ' must match the hardware wiring
LCD_RS equ P1.3
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3






Timer0_Init:
	orl CKCON, #0b00001000 ; Input for timer 0 is sysclk/1
	mov a, TMOD
	anl a, #0xf0 ; 11110000 Clear the bits for timer 0
	orl a, #0x01 ; 00000001 Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
	setb TR0   ;NOTE: commented out bcuz want manual start, not auto start
    ret

Timer0_ISR: ;runs ISR every 0.5ms (0->100)
    clr TR0
	mov TH0, #high(TIMER0_RELOAD)   ;NOTE: to be changed to achieve 1ms
	mov TL0, #low(TIMER0_RELOAD)    ;NOTE: to be changed to achieve 1ms
    setb TR0
	
    

    cjne a, desired_PWM, return0
    cpl OUTPUT_PIN  ;NOTE: unsure if swap power flag needed

return0:
	mov a, cycle_counter
    lcall reset_count
    add a, #0x01
    mov cycle_counter, a
	reti

main:
    mov SP, #0x7F
    mov P0M1, #0x00
    mov P0M2, #0x00
    mov P1M1, #0x00
    mov P1M2, #0x00
    mov P3M2, #0x00
    mov P3M2, #0x00

    lcall Timer0_Init
    setb EA

    ;initial values, STARTING AT state0
    mov cycle_counter, #0x00    ;set cycle counter to 0
    mov desired_PWM, #0x0a      ;set desired PWM percent to 20%
    setb OUTPUT_PIN             ;

loop:
    sjmp loop

reset_count:
    mov a, cycle_counter
    cjne a, #0x14, back ;if 10ms/100 cycles have passed, reset the duty cycle
    mov a, #0x00
    mov cycle_counter, a
    cpl OUTPUT_PIN
back:
    ret

