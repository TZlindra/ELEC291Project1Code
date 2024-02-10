; Lab2_MuntakimRahman_71065221.asm:
; 	A) Drives A 16x2 LCD Display Using 4-Bit Mode and Displays 12-Hour Clock Time
;   b) Generates A 2kHz Square Wave at Pin P1.7 Using an ISR For Timer 0.
;      Drives A Speaker When Alarm is Activated.
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

;-------------------;
; Clock Frequencies ;
;-------------------;
CLK           EQU 16600000 ; Microcontroller System Frequency in Hz

TIMER0_RATE   EQU 4096     ; 2048Hz Squarewave (Peak Amplitude of CEM-1203 Speaker)
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))

TIMER2_RATE   EQU 1000     ; 1000Hz, for Timer Tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/TIMER2_RATE)))

;-----------------;
; Pin Definitions ;
;-----------------;
SET_BUTTON           EQU P1.0 ; Pin 15
HOUR_FORMAT_BUTTON   EQU P1.1 ; Pin 14


DEC_BUTTON           EQU P0.5 ; Pin 1
HOURS_BUTTON         EQU P1.2 ; Pin 13
MINUTES_BUTTON       EQU P1.6 ; Pin 8
SECONDS_BUTTON       EQU P3.0 ; Pin 5

ALARM_OUT            EQU P1.7 ; Pin 6

;-------------------;
; Interrupt Vectors ;
;-------------------;
; Reset Vector
ORG 0X0000
    LJMP Main

; External Interrupt 0 Vector (Not Used)
ORG 0X0003
	RETI

; Timer/Counter 0 Overflow Interrupt Vector
ORG 0X000B
	LJMP Timer0_ISR

; External Interrupt 1 vector (Not Used)
ORG 0X0013
	RETI

; Timer/Counter 1 Overflow Interrupt Vector (Not Used)
ORG 0X001B
	RETI

; Serial Port Receive/Transmit Interrupt Vector (Not Used)
ORG 0X0023
	RETI

; Timer/Counter 2 Overflow Interrupt Vector
ORG 0X002B
	LJMP Timer2_ISR

; Note : Can Define Direct Access Variables Starting at 0X30 up to 0X7F in 8051.
DSEG AT 0X30

Counter_1ms:       DS 2 ; Used to Determine When 1000ms has Passed

BCD_Time_Hours: DS 1
BCD_Time_Minutes:  DS 1
BCD_Time_Seconds:  DS 1

BCD_Alarm_Hours: DS 1
BCD_Alarm_Minutes: DS 1

beep_count:		ds 1

BSEG

One_Second_Flag: DBIT 1 ; Set Bit In ISR After Every 1000ms

Init_Time_Flag: DBIT 1 ; Set Bit When Time is Being Initialized
Dec_En_Flag: DBIT 1 ; Set Bit When Decrement Button is Toggled

Alarm_En_Flag:   DBIT 1
Alarm_On_Flag:   DBIT 1

Time_PM_Flag:    DBIT 1 ; Set Bit When Time is in PM
Alarm_PM_Flag:   DBIT 1 ; Set Bit When Alarm is in PM
Hour_Format_Flag:    DBIT 1 ; Set Bit When Time is in 24-Hour Mode

CSEG

LCD_RS EQU P1.3 ; Pin 12
LCD_E  EQU P1.4 ; Pin 11
LCD_D4 EQU P0.0 ; Pin 16
LCD_D5 EQU P0.1 ; Pin 17
LCD_D6 EQU P0.2 ; Pin 18
LCD_D7 EQU P0.3 ; Pin 19

$NOLIST
$include(LCD_4bit.INC) ; Library of LCD Related Functions and Utility Macros
$LIST

TIME_INIT_MSG:     DB 'TIME xx:xx:xxxx', 0, 0
ALARM_INIT_MSG:    DB 'ALARM xx:xxxx', 0
ALARM_UPDATE_MSG:  DB 'ALARM', 0

AM_MSG: DB 'AM', 0
PM_MSG: DB 'PM', 0

BLANK_DISPLAY: DB '                ', 0
COLON: DB ':', 0

;---------------------------------------;
; Routine to Initialize ISR for Timer 0 ;
;---------------------------------------;
Timer0_Init:
	ORL CKCON, #0B0000_1000 ; Input for Timer 0 is SYSCLK/1.

	MOV A, TMOD
	ANL A, #0XF0 ; 1111_0000 Clear Bits for Timer 0
	ORL A, #0X01 ; 0000_0001 Configure Timer 0 as 16-Timer
	MOV TMOD, A

	MOV TH0, #HIGH(TIMER0_RELOAD)
	MOV TL0, #LOW(TIMER0_RELOAD)

	; Enable Timer and Interrupts
    SETB ET0  ; Enable Timer 0 Interrupt
	SETB TR0  ; Start Timer 0
	RET

;---------------------------------;
; ISR for Timer 0. Set to Execute ;
; Every 1/4096Hz to Generate a    ;
; 2048 Hz Wave at Pin ALARM_OUT   ;
;---------------------------------;
Timer0_ISR:
	; Save Registers to Stack.
    PUSH ACC
	PUSH PSW

	JNB Alarm_En_Flag, No_Sound
	JNB Alarm_On_Flag, No_Sound
Generate_Sound:
	CLR TR0 ; Stop Timer 0.
	; Timer 0 Doesn't Have 16-Bit Auto-Reload.
	MOV TH0, #HIGH(TIMER0_RELOAD)
	MOV TL0, #LOW(TIMER0_RELOAD)
	SETB TR0

	CPL ALARM_OUT ; Toggle the Alarm Out Pin
	SJMP Timer0_ISR_Done
No_Sound:
	; Timer 0 Doesn't Have 16-Bit Auto-Reload.
	MOV TH0, #HIGH(TIMER0_RELOAD)
	MOV TL0, #LOW(TIMER0_RELOAD)
Timer0_ISR_Done:
	; Restore Registers from Stack.
	POP PSW
	POP ACC

	RETI

;---------------------------------------;
; Routine to Initialize ISR for Timer 2 ;
;---------------------------------------;
Timer2_Init:
	MOV T2CON, #0 ; Stop Timer. Autoreload Mode.

	MOV TH2, #HIGH(TIMER2_RELOAD)
	MOV TL2, #LOW(TIMER2_RELOAD)

	; Set Reload Value
	ORL T2MOD, #0X80 ; Enable Timer 2 Autoreload Mode
	MOV RCMP2H, #HIGH(TIMER2_RELOAD)
	MOV RCMP2L, #LOW(TIMER2_RELOAD)

	; Init 1ms Interrupt Counter. 16-bit Variable with Two 8-bit Parts.
	CLR A
	MOV Counter_1ms+0, A
	MOV Counter_1ms+1, A

	; Enable the Timer and Interrupts.
	ORL EIE, #0X80 ; Enable Timer 2 Interrupt ET2=1
    SETB TR2  ; Enable Timer 2
	RET

;-----------------;
; ISR for Timer 2 ;
;-----------------;
Timer2_ISR:
	CLR TF2  ; Timer 2 Doesn't Clear TF2 Automatically. Do it in the ISR.  It is Bit Addressable.
	CPL P0.4 ; Interrupt Rate with Oscilloscope Must Precisely Be A 1ms Pulse.

	; Save Registers to Stack
	PUSH ACC
	PUSH PSW

	; Increment 16-bit 1ms Counter.
	INC Counter_1ms+0 ; Increment Low 8-bits
	MOV A, Counter_1ms+0 ; Increment High 8-bits if Lower 8-bits Overflow
	JNZ Update_BCD
	INC Counter_1ms+1
Update_BCD:
	; Check if 1000ms Have Passed
	MOV A, Counter_1ms+0
	CJNE A, #LOW(1000), Timer2_ISR_Done ; Note : Changes Carry Flag
	MOV A, Counter_1ms+1
	CJNE A, #HIGH(1000), Timer2_ISR_Done

	; 1000ms Have Passed. Set Flag to Inform Main Program.
	SETB One_Second_Flag
Check_Alarm:
	JNB Alarm_En_Flag, No_Alarm

	; Check if Time Hours Equals Alarm Hours
	MOV A, BCD_Time_Hours
	CJNE A, BCD_Alarm_Hours, No_Alarm

	; Check if Time Minutes Equals Alarm Minutes
	MOV A, BCD_Time_Minutes
	CJNE A, BCD_Alarm_Minutes, No_Alarm

	; Check AM/PM Flag
	CLR A
	MOV B, A
	MOV C, Time_PM_Flag
	MOV B.0, C
	MOV C, Alarm_PM_Flag
	MOV ACC.0, C
	CJNE A, B, No_Alarm
BEEP:
	SETB Alarm_On_Flag
	CPL TR0 ; Create Beep-Silence-Beep-Silence Sounds
	SJMP Continue_ISR
No_Alarm:
	CLR Alarm_On_Flag
Continue_ISR:
	; Reset 1ms Counter to 0.
	CLR A
	MOV Counter_1ms+0, A
	MOV Counter_1ms+1, A
	LCALL Update_Time_Seconds
Timer2_ISR_Done:
	POP PSW
	POP ACC
	RETI

blarg:


;----------------------------------;
; Main Program. Includes Hardware  ;
; Initialization and Forever Loop. ;
;----------------------------------;
Main:
	; Initialization
    MOV SP, #0X7F
    MOV P0M1, #0X00
    MOV P0M2, #0X00
    MOV P1M1, #0X00
    MOV P1M2, #0X00
    MOV P3M2, #0X00
    MOV P3M2, #0X00

    LCALL Timer0_Init
    LCALL Timer2_Init
    SETB EA   ; Enable Global Interrupts
    LCALL LCD_4BIT

Init_Time:
	SETB Init_Time_Flag
    SETB One_Second_Flag
	CLR Time_PM_Flag
	CLR Dec_En_Flag
	CLR Hour_Format_Flag

	CLR TR2 ; Stop Timer 2

	; Starting Display is 8:00:00 AM
	MOV A, #0X08
	MOV BCD_Time_Hours, A

	MOV A, #0X00
	MOV BCD_Time_Minutes, A

	MOV A, #0X00
	MOV BCD_Time_Seconds, A

	Set_Cursor(1, 1)
    Send_Constant_String(#TIME_INIT_MSG)
Check_Set_Time:
	JB SET_BUTTON, Init_Time_Display
	Wait_Milli_Seconds(#50)
	JB SET_BUTTON, Init_Time_Display
	JNB SET_BUTTON, $ ; Wait for Rising Edge
	LJMP Init_Time_End
Init_Time_Display:
	LCALL Check_Hour_Format
	LCALL Update_Time_Display
	LCALL Check_Dec_En
Init_Time_Seconds:
	JB SECONDS_BUTTON, Init_Time_Minutes
	Wait_Milli_Seconds(#50)
	JB SECONDS_BUTTON, Init_Time_Minutes
	JNB SECONDS_BUTTON, $ ; Wait for Rising Edge
	LCALL Update_Time_Seconds
Init_Time_Minutes:
	JB MINUTES_BUTTON, Init_Time_Hours
	Wait_Milli_Seconds(#50)
	JB MINUTES_BUTTON, Init_Time_Hours
	JNB MINUTES_BUTTON, $ ; Wait for Rising Edge
	LCALL Update_Time_Minutes
Init_Time_Hours:
	JB HOURS_BUTTON, Init_Time_Loop
	Wait_Milli_Seconds(#50)
	JB HOURS_BUTTON, Init_Time_Loop
	JNB HOURS_BUTTON, $ ; Wait for Rising Edge
	LCALL Update_Time_Hours
Init_Time_Loop:
	LJMP Check_Set_Time
Init_Time_End:
	SETB TR2 ; Set Timer 2
	CLR Init_Time_Flag
Init_Alarm:
	SETB Alarm_En_Flag
	CLR Alarm_On_Flag

	; Starting Alarm is 06:00 AM
	CLR Alarm_PM_Flag
	MOV A, #0X06
	MOV BCD_Alarm_Hours, A

	MOV A, #0X00
	MOV BCD_Alarm_Minutes, A

	LJMP Update_LCD_Display

;------------------------------------------------------;
; Forever Loop to Check Buttons and Update LCD Display ;
;------------------------------------------------------;
Check_Buttons:
	SJMP Check_Update_Alarm
Check_Update_Alarm:
	LCALL Check_Alarm_En
	LCALL Check_Dec_En
	JB Alarm_En_Flag, Check_Update_Alarm_Minutes
	LJMP Update_LCD_Display
Check_Update_Alarm_Minutes:
	JB MINUTES_BUTTON, Check_Update_Alarm_Hours
	Wait_Milli_Seconds(#50)
	JB MINUTES_BUTTON, Check_Update_Alarm_Hours
	JNB MINUTES_BUTTON, $ ; Wait for Rising Edge
	LCALL Update_Alarm_Minutes ; Increment Alarm Minutes
Check_Update_Alarm_Hours:
	JB HOURS_BUTTON, Update_LCD_Display
	Wait_Milli_Seconds(#50)
	JB HOURS_BUTTON, Update_LCD_Display
	JNB HOURS_BUTTON, $ ; Wait for Rising Edge
	LCALL Update_Alarm_Hours ; Increment Alarm Hours
	SJMP Update_LCD_Display
Update_LCD_Display:
    CLR One_Second_Flag
	LCALL Check_Hour_Format
	LCALL Update_Time_Display
	LCALL Update_Alarm_Display
	LJMP Check_Buttons

;--------------------;
; Update LCD Display ;
;--------------------;
Update_Time_Display:
	; Display Time
	Set_Cursor(1, 9)
	Display_BCD(BCD_Time_Minutes)
	Set_Cursor(1, 12)
	Display_BCD(BCD_Time_Seconds)

	JB Hour_Format_Flag, Update_Time_Hours_24
	SJMP Update_Time_Hours_12
Update_Time_Hours_12:
	Set_Cursor(1, 6)
	Display_BCD(BCD_Time_Hours)
	JB Time_PM_Flag, Update_Time_PM
Update_Time_AM:
	Set_Cursor(1, 14)
	Send_Constant_String(#AM_MSG)
	SJMP Update_Time_Display_End
Update_Time_PM:
	Set_Cursor(1, 14)
	Send_Constant_String(#PM_MSG)
	SJMP Update_Time_Display_End
Update_Time_Display_End:
	RET

Update_Time_Hours_24:
	Set_Cursor(1, 14)
	Send_Constant_String(#BLANK_DISPLAY)
	MOV A, BCD_Time_Hours
	JB Time_PM_Flag, Update_Time_Hours_24_PM
Update_Time_Hours_24_AM:
	Set_Cursor(1, 6)
	Display_BCD(A)
	CJNE A, #0X12, Update_Time_Display_End
	SJMP Update_Time_0000
Update_Time_0000:
	Set_Cursor(1, 6)
	Display_BCD(#0X00)
	SJMP Update_Time_Display_End
Update_Time_Hours_24_PM:
	ADD A, #0X12
	Set_Cursor(1, 6)
	Display_BCD(A)
	MOV A, BCD_Time_Hours
	SJMP Check_Time_2000
Check_Time_2000:
	CJNE A, #0X08, Check_Time_2100
	SJMP Update_Time_2000
Check_Time_2100:
	CJNE A, #0X09, Check_Time_1200
	SJMP Update_Time_2100
Check_Time_1200:
	CJNE A, #0X12, Update_Time_Display_End
	SJMP Update_Time_1200
Update_Time_2000:
	Set_Cursor(1, 6)
	Display_BCD(#0x20)
	LJMP Update_Time_Display_End
Update_Time_2100:
	Set_Cursor(1, 6)
	Display_BCD(#0x21)
	LJMP Update_Time_Display_End
Update_Time_1200:
	Set_Cursor(1, 6)
	Display_BCD(#0X12)
	LJMP Update_Time_Display_End

Update_Alarm_Display:
	JB Alarm_En_Flag, Update_Alarm_En_On
	LJMP Update_Alarm_En_Off
Update_Alarm_En_On:
	; Display Alarm
	Set_Cursor(2, 1)
	Send_Constant_String(#ALARM_UPDATE_MSG)
	Set_Cursor(2, 9)
	Send_Constant_String(#COLON)
	Set_Cursor(2, 10)
	Display_BCD(BCD_Alarm_Minutes)

	JB Hour_Format_Flag, Update_Alarm_Hours_24
	SJMP Update_Alarm_Hours_12
Update_Alarm_Hours_12:
	Set_Cursor(2, 7)
	Display_BCD(BCD_Alarm_Hours)
	JB Alarm_PM_Flag, Update_Alarm_PM
Update_Alarm_AM:
	Set_Cursor(2, 12)
	Send_Constant_String(#AM_MSG)
    SJMP Update_Alarm_Display_End
Update_Alarm_PM:
	Set_Cursor(2, 12)
	Send_Constant_String(#PM_MSG)
    SJMP Update_Alarm_Display_End
Update_Alarm_Display_End:
	RET

Update_Alarm_Hours_24:
	Set_Cursor(2, 12)
	Send_Constant_String(#BLANK_DISPLAY)
	MOV A, BCD_Alarm_Hours
	JB Alarm_PM_Flag, Update_Alarm_Hours_24_PM
Update_Alarm_Hours_24_AM:
	Set_Cursor(2, 7)
	Display_BCD(A)
	CJNE A, #0X12, Update_Alarm_Display_End
	SJMP Update_Alarm_0000
Update_Alarm_0000:
	Set_Cursor(2, 7)
	Display_BCD(#0X00)
	SJMP Update_Alarm_Display_End
Update_Alarm_Hours_24_PM:
	ADD A, #0X12
	Set_Cursor(2, 7)
	Display_BCD(A)
	MOV A, BCD_Alarm_Hours
	SJMP Check_Alarm_2000
Check_Alarm_2000:
	CJNE A, #0X08, Check_Alarm_2100
	SJMP Update_Alarm_2000
Check_Alarm_2100:
	CJNE A, #0X09, Check_Alarm_1200
	SJMP Update_Alarm_2100
Check_Alarm_1200:
	CJNE A, #0X12, Update_Alarm_Display_End
	SJMP Update_Alarm_1200
Update_Alarm_2000:
	Set_Cursor(2, 7)
	Display_BCD(#0x20)
	LJMP Update_Alarm_Display_End
Update_Alarm_2100:
	Set_Cursor(2, 7)
	Display_BCD(#0x021)
	LJMP Update_Alarm_Display_End
Update_Alarm_1200:
	Set_Cursor(2, 7)
	Display_BCD(#0X12)
	LJMP Update_Alarm_Display_End

Update_Alarm_En_Off:
	Set_Cursor(2, 1)
	Send_Constant_String(#BLANK_DISPLAY)
	LJMP Update_Alarm_Display_End

;-------------------------------;
; Update Time on LCD Display ;
;-------------------------------;
Update_Time_Hours:
	JNB Init_Time_Flag, Inc_Time_Hours
	JNB Dec_En_Flag, Inc_Time_Hours
	LJMP Dec_Time_Hours

Inc_Time_Hours:
	MOV A, BCD_Time_Hours
	ADD A, #1
	DA A
	MOV BCD_Time_Hours, A
	SUBB A, #0X12
	JC Update_Time_Hours_Done
	JNZ Offset_Time_Hours
Toggle_Time_AMPM:
	MOV BCD_Time_Hours, #0X12
	CPL Time_PM_Flag
	SJMP Update_Time_Hours_Done
Offset_Time_Hours:
	MOV A, BCD_Time_Hours
	SUBB A, #0X12
	DA A
	MOV BCD_Time_Hours, A
Update_Time_Hours_Done:
	RET

Dec_Time_Hours:
	MOV A, BCD_Time_Hours
	CJNE A, #0X12, Dec_Time_Hours_Continued
Rewind_Time_AMPM:
	MOV BCD_Time_Hours, #0X11
	CPL Time_PM_Flag
	SJMP Update_Time_Hours_Done
Dec_Time_Hours_Continued:
	ADD A, #0X99 ; Adding 10-Complement of -1
	DA A
	MOV BCD_Time_Hours, A
	JNZ Update_Time_Hours_Done
Rewind_Time_Hours:
	MOV BCD_Time_Hours, #0X12
	SJMP Update_Time_Hours_Done

Update_Time_Minutes:
	JNB Init_Time_Flag, Inc_Time_Minutes
	JNB Dec_En_Flag, Inc_Time_Minutes
	LJMP Dec_Time_Minutes

Inc_Time_Minutes:
	MOV A, BCD_Time_Minutes
	ADD A, #1
	DA A
	MOV BCD_Time_Minutes, A
	CJNE A, #0X60, Update_Time_Minutes_Done
	SJMP Reset_Time_Minutes
Reset_Time_Minutes:
	MOV BCD_Time_Minutes, #0X00
	LCALL Update_Time_Hours
	SJMP Update_Time_Minutes_Done
Update_Time_Minutes_Done:
	RET

Dec_Time_Minutes:
	MOV A, BCD_Time_Minutes
	JNZ Dec_Time_Minutes_Continued
Rewind_Time_Minutes:
	MOV BCD_Time_Minutes, #0X59
	LCALL Update_Time_Hours
	SJMP Update_Time_Minutes_Done
Dec_Time_Minutes_Continued:
	ADD A, #0X99 ; Adding 10-Complement of -1
	DA A
	MOV BCD_Time_Minutes, A
	SJMP Update_Time_Minutes_Done

Update_Time_Seconds:
	JNB Init_Time_Flag, Inc_Time_Seconds
	JNB Dec_En_Flag, Inc_Time_Seconds
	LJMP Dec_Time_Seconds

Inc_Time_Seconds:
	MOV A, BCD_Time_Seconds
	ADD A, #1
	DA A
	MOV BCD_Time_Seconds, A
	CJNE A, #0X60, Update_Time_Seconds_Done
	SJMP Reset_Time_Seconds
Reset_Time_Seconds:
	MOV BCD_Time_Seconds, #0X00
	LCALL Update_Time_Minutes
	SJMP Update_Time_Seconds_Done
Update_Time_Seconds_Done:
	RET

Dec_Time_Seconds:
	MOV A, BCD_Time_Seconds
	JNZ Dec_Time_Seconds_Continued
Rewind_Time_Seconds:
	MOV BCD_Time_Seconds, #0X59
	LCALL Update_Time_Minutes
	SJMP Update_Time_Seconds_Done
Dec_Time_Seconds_Continued:
	ADD A, #0X99 ; Adding 10-Complement of -1
	DA A
	MOV BCD_Time_Seconds, A
	SJMP Update_Time_Seconds_Done

Update_Alarm_Hours:
	JNB Dec_En_Flag, Inc_Alarm_Hours
	LJMP Dec_Alarm_Hours

Inc_Alarm_Hours:
	MOV A, BCD_Alarm_Hours
	ADD A, #1
	DA A
	MOV BCD_Alarm_Hours, A
	SUBB A, #0X12
	JC Update_Alarm_Hours_Done
	JNZ Offset_Alarm_Hours
Toggle_Alarm_AMPM:
	MOV BCD_Alarm_Hours, #0X12
	CPL Alarm_PM_Flag
	SJMP Update_Alarm_Hours_Done
Offset_Alarm_Hours:
	MOV A, BCD_Alarm_Hours
	SUBB A, #0X12
	DA A
	MOV BCD_Alarm_Hours, A
	SJMP Update_Alarm_Hours_Done
Update_Alarm_Hours_Done:
	RET

Dec_Alarm_Hours:
	MOV A, BCD_Alarm_Hours
	CJNE A, #0X12, Dec_Alarm_Hours_Continued
Rewind_Alarm_AMPM:
	MOV BCD_Alarm_Hours, #0X11
	CPL Alarm_PM_Flag
	SJMP Update_Alarm_Hours_Done
Dec_Alarm_Hours_Continued:
	ADD A, #0X99 ; Adding 10-Complement of -1
	DA A
	MOV BCD_Alarm_Hours, A
	JNZ Update_Alarm_Hours_Done
Rewind_Alarm_Hours:
	MOV BCD_Alarm_Hours, #0X12
	SJMP Update_Alarm_Hours_Done

Update_Alarm_Minutes:
	JNB Dec_En_Flag, Inc_Alarm_Minutes
	LJMP Dec_Alarm_Minutes

Inc_Alarm_Minutes:
	MOV A, BCD_Alarm_Minutes
	ADD A, #1
	DA A
	MOV BCD_Alarm_Minutes, A
	CJNE A, #0X60, Update_Alarm_Minutes_Done
	SJMP Reset_Alarm_Minutes
Reset_Alarm_Minutes:
	MOV BCD_Alarm_Minutes, #0X00
	LCALL Update_Alarm_Hours
	SJMP Update_Alarm_Minutes_Done
Update_Alarm_Minutes_Done:
	RET

Dec_Alarm_Minutes:
	MOV A, BCD_Alarm_Minutes
	JNZ Dec_Alarm_Minutes_Continued
Rewind_Alarm_Minutes:
	MOV BCD_Alarm_Minutes, #0X59
	LCALL Update_Alarm_Hours
	SJMP Update_Alarm_Minutes_Done
Dec_Alarm_Minutes_Continued:
	ADD A, #0X99 ; Adding 10-Complement of -1
	DA A
	MOV BCD_Alarm_Minutes, A
	SJMP Update_Alarm_Minutes_Done

;----------------;
; Enable/Disable ;
;----------------;
Check_Alarm_En:
	JB SET_BUTTON, Check_Alarm_En_Done
	Wait_Milli_Seconds(#50)
	JB SET_BUTTON, Check_Alarm_En_Done
	JNB SET_BUTTON, $ ; Wait for Rising Edge
	CPL Alarm_En_Flag ; Toggle Alarm Enable Flag
Check_Alarm_En_Done:
	RET

Check_Dec_En:
	JB DEC_BUTTON, Check_Dec_En_Done
	Wait_Milli_Seconds(#50)
	JB DEC_BUTTON, Check_Dec_En_Done
	JNB DEC_BUTTON, $ ; Wait for Rising Edge
	CPL Dec_En_Flag
Check_Dec_En_Done:
	RET

Check_Hour_Format:
	JB HOUR_FORMAT_BUTTON, Check_Hour_Format_Done
	Wait_Milli_Seconds(#50)
	JB HOUR_FORMAT_BUTTON, Check_Hour_Format_Done
	JNB HOUR_FORMAT_BUTTON, $ ; Wait for Rising Edge
	CPL Hour_Format_Flag
Check_Hour_Format_Done:
	RET
END
`
