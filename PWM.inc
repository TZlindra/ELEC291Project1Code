$NOLIST
;----------------------------------
; PWM.inc: Sets PWM Values
;----------------------------------

CSEG

Inc_PWM:
	MOV A, Count1ms+0
    CJNE A, Desired_PWM+0, Inc_PWM2
	MOV A, Count1ms+1
	CJNE A, Desired_PWM+1, Inc_PWM2
    CLR OUTPUT_PIN
Inc_PWM2:
    MOV A, Count1ms+0
    CJNE A, #LOW(999), Return0
	MOV A, Count1ms+1
	CJNE A, #HIGH(999), Return0
    SETB OUTPUT_PIN  ;ToDo : Do We Need Swap Power Flag?
Return0:
	RET

Power0: ; Called From States
    CLR OUTPUT_PIN
    RET

Power100: ; Called From States
    SETB OUTPUT_PIN
    RET

Power20: ; called from states
    MOV Desired_PWM+0, #LOW(200) ; 20% Power
    MOV Desired_PWM+1, #HIGH(200)

    RET

$LIST