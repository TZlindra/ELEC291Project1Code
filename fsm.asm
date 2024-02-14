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
; 2 3 4 7 9 19 18 17 16 12 11 15 10 6 5 14
;-------------------;
; Clock Frequencies ;
;-------------------;

CLK               EQU 16600000 ; Microcontroller System Frequency in Hz
BAUD              EQU 115200 ; Baud Rate for UART in BPS

TIMER0_RATE   EQU 4096     ; 2048Hz Squarewave (Peak Amplitude of CEM-1203 Speaker)
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))

TIMER1_RELOAD     EQU (0X100 - (CLK / (16 * BAUD)))

TIMER2_RATE       EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD     EQU ((65536- (CLK/TIMER2_RATE)))

;-------------------;
;- Pin Definitions -;
;-------------------;

; ToDo : Button Multiplexer
START_BUTTON 	  EQU P0.4 ; Pin 20
MODE_BUTTON       EQU P1.0 ; Pin 15

TENS_BUTTON       EQU P1.2 ; Pin 13
ONES_BUTTON       EQU P1.6 ; Pin 8

OUTPUT_PIN 	      EQU P1.5 ; Pin 10

REF_ADC           EQU P1.7 ; Pin 6
LM335_ADC		  EQU P3.0 ; Pin 5
SPEAKER_OUT       EQU P0.5 ; Pin 1
THERMOCOUPLE_ADC  EQU P1.1 ; Pin 14

; Reset vector
ORG 0x0000
    LJMP Main

; External interrupt 0 vector (not used in this code)
ORG 0x0003
	RETI

; Timer/Counter 0 overflow interrupt vector
ORG 0x000B
	ljmp Timer0_ISR

; External interrupt 1 vector (not used in this code)
ORG 0x0013
	RETI

; Timer/Counter 1 overflow interrupt vector (not used in this code)
ORG 0x001B
	RETI

; Serial port receive/transmit interrupt vector (not used in this code)
ORG 0x0023
	RETI

; Timer/Counter 2 overflow interrupt vector
ORG 0x002B
	LJMP Timer2_ISR

DSEG AT 0x30

STATE_NUM: 	          DS 1 ;

Count1ms:             DS 2 ; Used to Determine When 1s Has Passed
speaker_counter1ms:    ds 2
speaker_counts:	  	  ds 1 ;

BCD_Counter:          DS 1 ; The BCD counter incremented in the ISR and displayed in the main loop
Current_Counter: 	  DS 1 ;
Resulting_Counter:	  DS 1 ;

Timer_State:          DS 1 ;
Beep_Count:			  DS 1 ;
Desired_PWM:		  DS 2 ;

;------------------------;
;   Temperature Values   ;
;------------------------;

TEMP_ERROR: DS 1
TEMP_SOAK:  DS 1
TEMP_REFLOW: DS 1

TEMP_DONE EQU 60

TX_SIZE  EQU 5 ; Size of the Transmit Buffer
TX_BUFF: DS TX_SIZE ; Buffer for Transmit Characters

X:   DS 4
Y:   DS 4
BCD: DS 5

OVEN_BCD: DS 4

Output_Voltage: DS 4
VLED_ADC: DS 2

LM335_TEMP: DS 4 ; 2 Byte Temperature Value With 0.01 Degree Resolution
THERMOCOUPLE_TEMP: DS 4 ; 2 Byte Temperature Value With 0.01 Degree Resolution
OVEN_TEMP: DS 1 ; 1 Byte Temperature Value With 1 Degree Resolution


BSEG
MF: DBIT 1

Below_Temp_Flag: DBIT 1
Error_Triggered_Flag: DBIT 1

Speaker_En_Flag:   DBIT 1

$NOLIST
$include(LCD_4bit.INC) ; Library of LCD Related Functions and Utility Macros
$include(Serial.INC) ; Library of Serial Port Related Functions and Utility Macros
$include(math32.INC) ; Library of 32-bit Math Functions
$include(ADC.INC) ; Library of ADC and Temperature Function
$include(PWM.INC) ; Library of PWM Functions
$include(test.INC) ; Library of Test Functions
$LIST

Initial_Message1:  db 'To= xxC  Tj=xxC ', 0
Initial_Message2:  db 'sxxx.00 rxxx.00 ', 0

CSEG

To_MSG: DB 'To=', 0
Tj_MSG: DB 'C  Tj=', 0

LCD_RS EQU P1.3 ; Pin 12
LCD_E  EQU P1.4 ; Pin 11
LCD_D4 EQU P0.0 ; Pin 16
LCD_D5 EQU P0.1 ; Pin 15
LCD_D6 EQU P0.2 ; Pin 18
LCD_D7 EQU P0.3 ; Pin 19

Display_LCD:
	Set_Cursor(1,1)
    Display_BCD(STATE_NUM)
	lcall Display_LM335_Temperature
	lcall Display_Oven_Temperature
	lcall Display_Reflow_Temperature
	lcall Display_Soak_Temperature

	Set_Cursor(1, 1)
	Send_Constant_String(#To_MSG)

	Set_Cursor(1, 10)
	Send_Constant_String(#Tj_MSG)

	Set_Cursor(2, 1)
	Display_char(#'s')

	Set_Cursor(2, 5)
	Display_char(#'r')

	RET

Display_LCDFinal:
	lcall Display_LM335_Temperature
	lcall Display_Oven_Temperature

	Set_Cursor(1,1)
    Send_Constant_String(#To_MSG)

	Set_Cursor(1,7)
    Send_Constant_String(#Tj_MSG)

	Set_Cursor(1,15)
	Display_char(#'C')

	lcall Display_Reflow_Temperature
	lcall Display_Soak_Temperature

	Set_Cursor(2,1)
	Display_char(#'s')

	Set_Cursor(2,9)
	Display_char(#'r')

	Set_Cursor(2,5)
	Display_char(#'C')

	Set_Cursor(2,13)
	Display_char(#'C')

	RET

Display_LCDTest:
	lcall Display_LM335_Temperature
	; lcall Display_Thermocouple_Temperature
	lcall Display_Oven_Temperature

	Set_Cursor(1,1)
    Display_BCD(STATE_NUM)

	Set_Cursor(2,1)
    Display_BCD(BCD_Counter)
	Set_Cursor(2,5)
	Display_BCD(Resulting_Counter)

	; lcall Display_SpeakerFlag
	lcall Display_BelowFlag

	; LCALL Display_Output_Voltage

	RET

Check_Buttons:
	jb TENS_BUTTON, onesbutton
	lcall Wait30ms
	jb TENS_BUTTON, onesbutton

	jnb TENS_BUTTON, $
	jnb MODE_BUTTON, reflowaddten; if MODE BUTTON IS PRESSED, jump
	mov a, TEMP_SOAK
	add a, #0x0A
	mov TEMP_SOAK, a
	ljmp onesbutton
reflowaddten:
	mov a, TEMP_REFLOW
	add a, #0x0A
	mov TEMP_REFLOW, a
onesbutton:
	jb ONES_BUTTON, done_check_button
	lcall Wait30ms
	jb ONES_BUTTON, done_check_button

	jnb ONES_BUTTON, $
	jnb MODE_BUTTON, reflowaddone; if MODE BUTTON IS PRESSED, jump
	mov a, TEMP_SOAK
	add a, #0x01
	mov TEMP_SOAK, a
	ljmp done_check_button
reflowaddone:
	mov a, TEMP_REFLOW
	add a, #0x01
	mov TEMP_REFLOW, a
done_check_button:
	mov a, TEMP_REFLOW
	subb a, TEMP_SOAK ; if REFLOW - SOAK = + we good
	jnc done_reflow_and_soak_temp_check ;
	mov a, TEMP_REFLOW
	mov TEMP_SOAK, a
done_reflow_and_soak_temp_check:
	ret

Init_Vars:
    ; Initial Values at State 0
	MOV STATE_NUM, #0x00

	MOV TEMP_ERROR, #50
	MOV TEMP_SOAK, #145
	MOV TEMP_REFLOW, #217

	MOV VLED_ADC+0, #0
	MOV VLED_ADC+1, #0

	MOV LM335_TEMP+0, #0
	MOV LM335_TEMP+1, #0

	MOV THERMOCOUPLE_TEMP+0, #0
	MOV THERMOCOUPLE_TEMP+1, #0
Reset_Vars:
	MOV BCD_Counter, #0x00
	MOV Resulting_Counter, #0x00
    MOV Desired_PWM+0, #0x00
    MOV Desired_PWM+1, #0x00

	mov speaker_counts, #0x00
	mov speaker_counter1ms, #0x00
	mov speaker_counter1ms+1, #0x00

    clr OUTPUT_PIN
	SETB START_BUTTON
	setb TENS_BUTTON
	setb ONES_BUTTON
	setb MODE_BUTTON
	CLR Below_Temp_Flag
	CLR Error_Triggered_Flag

	RET

Timer0_ISR:
	; Save Registers to Stack.
    PUSH ACC
	PUSH PSW


	CLR TR0
	MOV TH0, #HIGH(TIMER0_RELOAD)
	MOV TL0, #LOW(TIMER0_RELOAD)
	SETB TR0

	CPL SPEAKER_OUT ; Toggle the Alarm Out Pin
	POP PSW
	POP ACC

	RETI
;-------------;
; Timer 2 ISR ;
;-------------;

Timer2_ISR:
	CLR TF2  ; Timer 2 Doesn't Clear TF2 Automatically. Do it in the ISR.  It is Bit Addressable.

	; Save Registers to Stack
	PUSH ACC
	PUSH PSW

	; Increment 16-bit 1ms Counter.
	INC Count1ms+0 ; Increment Low 8-bits
	MOV a, Count1ms+0 ; Increment High 8-bits if Lower 8-bits Overflow
	JNZ Inc_Done
	INC Count1ms+1
Inc_Done:

	MOV A, Timer_State
	CJNE A, #0x01, Continue ; Jump If Not In Timer State
	LCALL Inc_PWM
Continue:
	; Check If oNE Second Has Passed
	MOV A, Count1ms+0
	CJNE A, #LOW(1000), Timer2_ISR_Done
	MOV A, Count1ms+1
	CJNE A, #HIGH(1000), Timer2_ISR_Done

	LCALL TX_Temp_Oven
	CLR A
	MOV Count1ms+0, A
	MOV Count1ms+1, A
	; Increment the BCD counter

	cpl TR0
	MOV A, BCD_Counter
	ADD A, #0x01
	DA A
	MOV BCD_Counter, A


    MOV BCD_Counter, A
	CJNE A, Resulting_Counter, Timer2_ISR_Done ; Skip if BCD_Counter != Resulting_Counter
	MOV A, Timer_State
    CJNE A, #0x01, Timer2_ISR_Done; Skip If We're Not In Timer State

	MOV A, STATE_NUM
	CJNE A, #0x01, OtherStates ; Skip If Not State 1

Check_Error_State:
	; Check If Oven Temperature < 50
	LCALL Check_Temp_Error
	JNB Error_Triggered_Flag, Timer2_ISR_Done ; Skip If Oven Temperature <= 50
Error_State_Triggered:
	;CLR Error_Triggered_Flag
	MOV STATE_NUM, #0x00
	MOV BCD_Counter, #0x00

	LJMP Timer2_ISR_Done
OtherStates:
	MOV BCD_Counter, #0x00
	INC STATE_NUM ; Increment State Number
Timer2_ISR_Done:
	POP PSW
	POP ACC
	RETI



Wait30ms:
    MOV R2, #6
W3: MOV R1, #200
W2: MOV R0, #104
W1: djnz R0, W1 ; 4 cycles-> 4 * 60.285ns * 104 = 25us
    djnz R1, W2 ; 25us * 200 = 5.0ms
    djnz R2, W3 ; 5.0ms * 6 = 30ms (Approximately)
    RET

StateChanges: ; Check What Counter Number Will Be For Each State
	MOV A, STATE_NUM
	CJNE A, #0x00, Next1 ; Jump to Next1 if STATE_NUM is NOT 0

	LCALL State0
	LJMP Done_State_Counter
Next1:
	MOV A, STATE_NUM
	CJNE A, #0x01, Next2 ; Jump to Next2 if STATE_NUM is NOT 1

	LCALL State1
	LJMP Done_State_Counter
Next2:
	MOV A, STATE_NUM
	CJNE A, #0x02, Next3 ; Jump to Next3 if STATE_NUM is NOT 2

	LCALL State2
	LJMP Done_State_Counter
Next3:
	MOV a, STATE_NUM
	CJNE a, #0x03, Next4 ; Jump to Next4 if STATE_NUM is NOT 3

	LCALL State3
	LJMP Done_State_Counter
Next4:
	MOV A, STATE_NUM
	CJNE A, #0x04, Next5 ; Jump to Next5 if STATE_NUM is NOT 4

	LCALL State4
	LJMP Done_State_Counter
Next5:
	LCALL State5
	LJMP Done_State_Counter

Done_State_Counter:
	RET

State0:

    MOV Timer_State, #0x00
    LCALL Power0
	LCALL Check_Buttons

	JB START_BUTTON, Quit0 ; Go to Quit0 If Start Button is NOT Pressed
	LCALL Wait30ms
	JB START_BUTTON, Quit0


	JNB START_BUTTON, $ ; Go to State1 If Start Button is Pressed
	MOV BCD_Counter, #0x00
	MOV Resulting_Counter, #0x60
	INC STATE_NUM
	;setb TR0
Quit0:
	RET

State1:
    MOV Timer_State, #0x01
    LCALL Power100

	MOV R1, TEMP_SOAK
	LCALL Check_Temp_Oven ; Check If Oven Temperature Reaches 150
	JB Below_Temp_Flag, Quit1 ; If Temperature Below then jump to quit1

	;CLR Below_Temp_Flag
	MOV BCD_Counter, #0x00
	MOV Resulting_Counter, #0x90
	INC STATE_NUM
Quit1:
	RET

State2:
    LCALL Power20 ; Set Power to 20%
    MOV Timer_State, #0x01

Quit2:
	RET

State3:
    LCALL Power100 ; Set Power to 100%
    MOV Timer_State, #0x00

	MOV R1, TEMP_REFLOW
	LCALL Check_Temp_Oven
	JB Below_Temp_Flag, Quit3

	;CLR Below_Temp_Flag
    MOV Timer_State, #0x01
	MOV BCD_Counter, #0x00
	MOV Resulting_Counter, #0x60
	INC STATE_NUM
Quit3:
	RET

State4:
    LCALL Power20
    MOV Timer_State, #0x01
    ;JB START_BUTTON, Quit4 ; if START BUTTON is NOT PRESSED
	;LCALL Wait30ms
	;JB START_BUTTON, Quit4

	;JNB START_BUTTON, $ ; if START BUTTON is PRESSED go to State1
	;MOV BCD_Counter, #0x00
Quit4:
	RET

State5:
    LCALL Power0
    MOV Timer_State, #0x00

	MOV R1, #TEMP_DONE
	LCALL Check_Temp_Oven ; Check If Oven Temperature Reaches 60
	JNB Below_Temp_Flag, Quit5  ; IF temperature >= 60, continue in state 5 (0 is above value)

	CLR Below_Temp_Flag
	MOV STATE_NUM, #0x00
	MOV BCD_Counter, #0x00
Quit5:
	RET

;----------------;
; Initialization ;
;----------------;
Init_All:
	MOV	P3M1, #0X00
	MOV	P3M2, #0X00

	MOV	P1M1, #0X00
	MOV	P1M2, #0X00

	MOV	P0M1, #0X00
	MOV	P0M2, #0X00

	Set_Cursor(1,1)
	Send_Constant_String(#Initial_Message1)
	Set_Cursor(2,1)
	Send_Constant_String(#Initial_Message2)

	LCALL Init_Vars
Init_SerialPort:
    ; Configure Serial Port and Baud Rate

    ; Since Reset Button Bounces, Wait a Bit Before Sending Messages.
    ; Otherwise, We Risk Sending Garbage to the Serial Port.
    MOV R1, #200
    MOV R0, #104
    DJNZ R0, $ ; 4 Cycles-> 4 * 60.285 ns * 104 = 25 us
    DJNZ R1, $-4 ; 25us * 200 = 5 ms

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
	setb TR0
Init_Timer1:
	ORL	CKCON, #0X10 ; CLK is Input for Timer 1.
	ORL	PCON, #0X80 ; Bit SMOD = 1, Double Baud Rate
	MOV	SCON, #0X52
	ANL	T3CON, #0B1101_1111
	ANL	TMOD, #0X0F ; Clear Configuration Bits for Timer 1
	ORL	TMOD, #0X20 ; Timer 1 Mode 2
	MOV	TH1, #TIMER1_RELOAD ; TH1 = TIMER1_RELOAD;
	SETB TR1
Init_ADC:
	; Initialize the pins used by the ADC (P1.1, P1.7, P3.0) as Analog Inputs
	ORL	P1M1, #0B1000_0010
	ANL	P1M2, #0B0111_1101
	ORL	P3M1, #0B0000_0010
	ANL P3M2, #0B1111_1101

	; AINDIDS Select if Some Pins are Analog Inputs or Digital I/O
	MOV AINDIDS, #0X00 ; Disable All Analog Inputs
	ORL AINDIDS, #0B1000_0011 ; Activate AIN0, AIN1, AIN7

	ORL ADCCON1, #0X01 ; Enable ADC
Init_Timer2:
	MOV T2CON, #0 ; Stop Timer. Autoreload Mode.
	MOV TH2, #HIGH(TIMER2_RELOAD)
	MOV TL2, #LOW(TIMER2_RELOAD)

	; Set Reload Value
	ORL T2MOD, #0X80 ; Enable Timer 2 Autoreload Mode
	MOV RCMP2H, #HIGH(TIMER2_RELOAD)
	MOV RCMP2L, #LOW(TIMER2_RELOAD)

	; Init 1ms Interrupt Counter. 16-bit Variable with Two 8-bit Parts.
	CLR A
	MOV Count1ms+0, A
	MOV Count1ms+1, A

	; Enable the Timer and Interrupts.
	ORL EIE, #0X80 ; Enable Timer 2 Interrupt ET2=1
    SETB TR2  ; Enable Timer 2
    RET

Main:
	; Initialization
	MOV SP, #0X7F
    SETB EA   ; Enable Global interrupts
	LCALL Init_All
	LCALL LCD_4BIT
Forever:
	LCALL Get_and_Transmit_Temp
	LCALL Display_LCDTest
	;LCALL Display_LCD
	; lcall Display_LCDFinal
	LCALL StateChanges
	LCALL TX_StateNumber

	LJMP Forever

END