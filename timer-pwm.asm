;INCOMPELTE CODE, INCOMPLETE SETUP & INITIALIZATIONS
CLK           EQU 16600000
TIMER0_RATE   EQU 1000
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))
;...
$NOLIST                 
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$include(math32.inc)
$include(main.asm)
$LIST
;...
dseg at 0x30                ;modify initial dseg position so no OVERLAP with other asm files
cycle_counter:      ds 2
desired_PWM:        ds 2    ;variable to hold the power percentage expressed as a whole number
                            ;ex. 50 = 50%, need to express as decimal somehow?
                            ;NOTE: refer to above comment
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

Timer0_ISR: ;runs ISR every 1ms to RESET the cycle (100->0)
	;Timer 0 doesn't have 16-bit auto-reload
	;jb power_flag, return0   ;if flag = 0, supply power. otherwise don't
	clr TR0
	mov TH0, #high(TIMER0_RELOAD)   ;NOTE: to be changed to achieve 1ms
	mov TL0, #low(TIMER0_RELOAD)    ;NOTE: to be changed to achieve 1ms
	setb TR0
	;cpl power_flag  ;NOTE: unsure if swap power flag needed
;return0:
	;reti

main:
    mov cycle_counter, #0x00    ;set cycle counter to 0
    mov desired_PWM, #0x00      ;set desired PWM percent to 0
    setb power_flag             ;
    ;jmp to power0
    ;NOTE: transition to be modified, if transition is even correct

power0:
    cjne STATE_NUM, #0x00, power1_transition    ;INCOMPLETE, reference to go to ANOTHER power state
                                     ;STATE_NUM defined in fsm.asm to determine which state we're in
    mov desired_PWM, #0x00  ;set desired PWM to 0%
    clr a
    mov a, cycle_counter
    clr c                   ;clear the carry
    subb a, desired_PWM     ;if current counter <=  desired_PWM, set carry flag to 1, meaning high(1)
    mov P0.0, c             ;outputs the square duty cycle
                            ;otherwise display low(0)
                            
    ;increments cycle_counter for next calculation
    ;NOTE: want to use timer0 value IN PLACE OF cycle_counter so that an increment here isnt necessary
    ;       this would resolve the issue of knowing if we want to lcall or branch to power0 and others like it
    mov a, cycle_counter
    add a, #0x01
    da a
    mov a, cycle_counter

                         ;NOTE: DONT USE sjmp to loop, otherwise infinite loop!

power1_transition:              ;branch to reset values before entering a new power state
    mov cycle_counter, #0x00    ;set cycle counter to 0
    mov desired_PWM, #0x00      ;set desired PWM percent to 0
    setb power_flag             
    
power1:
    cjne STATE_NUM, #0x01, power2_transition

    mov desired_PWM, #0x100  ;set desired PWM to 100%
    clr a
    mov a, cycle_counter
    clr c                  
    subb a, desired_PWM     
    mov P0.0, c

    ;inc??

power2_transition:             
    mov cycle_counter, #0x00
    mov desired_PWM, #0x00     
    setb power_flag

power2:
    cjne STATE_NUM, #0x02, power3_transition

    mov desired_PWM, #0x20  ;set desired PWM to 20%
    clr a
    mov a, cycle_counter
    clr c                  
    subb a, desired_PWM     
    mov P0.0, c

    ;inc??

power3_transition:             
    mov cycle_counter, #0x00
    mov desired_PWM, #0x00     
    setb power_flag  

power3:
    cjne STATE_NUM, #0x03, power4_transition

    mov desired_PWM, #0x100  ;set desired PWM to 20%
    clr a
    mov a, cycle_counter
    clr c                  
    subb a, desired_PWM     
    mov P0.0, c

    ;inc??

power4_transition:             
    mov cycle_counter, #0x00
    mov desired_PWM, #0x00     
    setb power_flag  

power4:
    cjne STATE_NUM, #0x04, power5_transition

    mov desired_PWM, #0x20  ;set desired PWM to 20%
    clr a
    mov a, cycle_counter
    clr c                  
    subb a, desired_PWM     
    mov P0.0, c

    ;inc??

power5_transition:             
    mov cycle_counter, #0x00
    mov desired_PWM, #0x00     
    setb power_flag  

power5:
    cjne STATE_NUM, #0x05, power0_transition

    mov desired_PWM, #0x00  ;set desired PWM to 20%
    clr a
    mov a, cycle_counter
    clr c                  
    subb a, desired_PWM     
    mov P0.0, c

    ;inc??

power0_transition:             
    mov cycle_counter, #0x00
    mov desired_PWM, #0x00     
    setb power_flag 
    ljmp power0             ;NOTE: jump may be incorrect, to be modified
