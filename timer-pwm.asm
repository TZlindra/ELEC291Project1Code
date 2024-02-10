

;
; NOTE: all function calls here are to be moved BACK to timer-pwm.asm
; NOTE: need to figure out how to INCLUDE timer-pwm.asm and still be able to call
;
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