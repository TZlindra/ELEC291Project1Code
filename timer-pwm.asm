;INCOMPELTE CODE, INCOMPLETE SETUP & INITIALIZATIONS
$NOLIST                 
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$include(math32.inc)
$include(main.asm)
$LIST

CLK           EQU 16600000
TIMER0_RATE   EQU 500   ;0.5 ms
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))
;...

;...
dseg at 0x30                ;modify initial dseg position so no OVERLAP with other asm files
cycle_counter:     ds 2
TH0_temp            ds 2
desired_PWM:        ds 2    ;variable to hold the power percentage expressed as a whole number
                            ;ex. 50 = 50%, need to express as decimal somehow?
                            ;NOTE: refer to above comment
;
OUTPUT_PIN  equ P1.5
;...
org 0x0000
    ljmp main

; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR
;...
bseg
power_flag: dbit 1          ;possibly useless
;...

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
	;setb TR0   ;NOTE: commented out bcuz want manual start, not auto start
    ret

Timer0_ISR: ;runs ISR every 0.5ms (0->100)
    clr TR0
	mov TH0, #high(TIMER0_RELOAD)   ;NOTE: to be changed to achieve 1ms
	mov TL0, #low(TIMER0_RELOAD)    ;NOTE: to be changed to achieve 1ms
    setb TR0
	
    mov a, cycle_counter
    lcall reset_count
    add a, #0x01
    mov cycle_counter, a

    cjne cycle_counter, desired_PWM, return0    ;if current_cycle != desired pwm, continue putting 1
    cpl power_flag  ;NOTE: unsure if swap power flag needed

return0:
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
    mov desired_PWM, #0x00      ;set desired PWM percent to 0
    setb power_flag             ;
    ;jmp to power0
    ;NOTE: transition to be modified, if transition is even correct

power0:
    cjne STATE_NUM, #0x00, power1_transition
    mov desired_PWM, #0x00  ;set desired PWM to 0%, full cycle, 1000 ticks
power1_transition:
    mov cycle_counter, #0x00
    setb power_flag


power1:
    cjne STATE_NUM, #0x01, power2_transition
    mov desired_PWM, #0x64  ;100% power
power2_transition:
    mov cycle_counter, #0x00
    setb power_flag

power2:
    cjne STATE_NUM, #0x01, power3_transition
    mov desired_PWM, #0x14  ;20% power
power3_transition:
    mov cycle_counter, #0x00
    setb power_flag

power3:
    cjne STATE_NUM, #0x01, power4_transition
    mov desired_PWM, #0x64  ;100% power
power4_transition:
    mov cycle_counter, #0x00
    setb power_flag

power4:
    cjne STATE_NUM, #0x01, power5_transition
    mov desired_PWM, #0x14  ;20% power
power5_transition:
    mov cycle_counter, #0x00
    setb power_flag

power5:
    cjne STATE_NUM, #0x01, power0_transition
    mov desired_PWM, #0x00  ;0% power
power0_transition:
    mov cycle_counter, #0x00
    setb power_flag
    ljmp power0




reset_count:
    mov a, cycle_counter
    cjne a, #0x64, back ;if 10ms/100 cycles have passed, reset the duty cycle
    mov a, #0x00
    mov cycle_counter, a
    cpl power_flag
back:
    ret