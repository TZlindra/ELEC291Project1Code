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

CLK               EQU 16600000 ; Microcontroller System FrEQUency in Hz
BAUD              EQU 115200 ; Baud Rate for UART in BPS

TIMER1_RELOAD     EQU (0X100 - (CLK / (16 * BAUD)))

TIMER2_RATE       EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD     EQU ((65536- (CLK/TIMER2_RATE)))

;-------------------;
;- Pin Definitions -;
;-------------------;

START_BUTTON      EQU P1.7 ;ToDo : Button Multiplexer
OUTPUT_PIN 	      EQU P1.5

REF_ADC           EQU P1.7
LM335_ADC		  EQU P3.0
THERMOCOUPLE_ADC  EQU P1.1

; Reset vector
ORG 0x0000
    LJMP Main

; External interrupt 0 vector (not used in this code)
ORG 0x0003
	RETI

; Timer/Counter 0 overflow interrupt vector
ORG 0x000B
	RETI

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

BCD_Counter:          DS 1 ; The BCD counter incremented in the ISR and displayed in the main loop
Current_Counter: 	  DS 1 ;
Resulting_Counter:	  DS 1 ;

Timer_State:          DS 1 ;
Beep_Count:			  DS 1 ;
Desired_PWM:		  DS 2 ;

;------------------------;
;   Temperature Values   ;
;------------------------;

;ToDo : Determine If We Can Access ADC Functions With E.G. #Temp_Error
TEMP_ERROR: DS 1
TEMP_SOAK:  DS 1
TEMP_REFLOW: DS 1

TX_SIZE  EQU 5 ; Size of the Transmit Buffer
TX_BUFF: DS TX_SIZE ; Buffer for Transmit Characters

X:   DS 4
Y:   DS 4
BCD: DS 5

VLED_ADC: DS 2

LM335_TEMP: DS 2 ; 2 Byte Temperature Value With 0.01 Degree Resolution
THERMOCOUPLE_TEMP: DS 2 ; 2 Byte Temperature Value With 0.01 Degree Resolution
OVEN_TEMP: DS 1 ; 1 Byte Temperature Value With 1 Degree Resolution

BSEG
MF: DBIT 1

Below_Temp_Flag: DBIT 1
Error_Triggered_Flag: DBIT 1

; Alarm_En_Flag:	DBIT 1
; Timer_State: 		DBIT 1 ; Is State in a Timer State?

$NOLIST
$include(LCD_4bit.INC) ; Library of LCD Related Functions and Utility Macros
$include(Serial.INC) ; Library of Serial Port Related Functions and Utility Macros
$include(math32.INC) ; Library of 32-bit Math Functions
$include(ADC.INC) ; Library of ADC and Temperature Function
$include(PWM.INC) ; Library of PWM Functions
$LIST

CSEG

LCD_RS EQU P1.3 ; Pin 12
LCD_E  EQU P1.4 ; Pin 11
LCD_D4 EQU P0.0 ; Pin 16
LCD_D5 EQU P0.1 ; Pin 15
LCD_D6 EQU P0.2 ; Pin 18
LCD_D7 EQU P0.3 ; Pin 19

Init_Vars:
    ; Initial Values at State 0
	MOV STATE_NUM, #0x00

	MOV BCD_Counter, #0x00
	MOV Resulting_Counter, #0x00
    MOV Desired_PWM, #0x00
    ; SETB OUTPUT_PIN

	MOV VLED_ADC+0, #0
	MOV VLED_ADC+1, #0

	MOV LM335_TEMP+0, #0
	MOV LM335_TEMP+1, #0

	MOV THERMOCOUPLE_TEMP+0, #0
	MOV THERMOCOUPLE_TEMP+1, #0

	MOV TEMP_ERROR, #50
	MOV TEMP_SOAK, #150
	MOV TEMP_REFLOW, #217

	RET

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

	CLR A
	MOV Count1ms+0, A
	MOV Count1ms+1, A
	; Increment the BCD counter
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

	; Check At 60 Seconds
	MOV A, BCD_Counter
	SUBB A, #60
	JZ Check_Error_State
	LJMP Timer2_ISR_Done
Check_Error_State:
	; Check If Oven Temperature < 50
	LCALL Check_Temp_Error
	;ToDO JNB Below_Temp_Flag, Timer2_ISR_Done ; Skip If Oven Temperature >= 50
Error_State_Triggered:
	MOV STATE_NUM, #0x00
	MOV BCD_Counter, #0x00
	;ToDo LCALL Init_Vars

	LJMP Timer2_ISR_Done
OtherStates:
	MOV BCD_Counter, #0x00
	INC STATE_NUM ; Increment State Number
Timer2_ISR_Done:
	POP PSW
	POP ACC
	RETI

Display_LCD:
	Set_Cursor(1,1)
    Display_BCD(STATE_NUM)

	Set_Cursor(2,1)
    Display_BCD(BCD_Counter)
	Set_Cursor(2,5)
	Display_BCD(Resulting_Counter)

	;ToDo : Problem -> 1ms uses TIMER 0
    RET

Wait50ms:
    MOV R2, #10
W3: MOV R1, #200
W2: MOV R0, #104
W1: djnz R0, W1 ; 4 cycles-> 4 * 60.285ns * 104 = 25us
    djnz R1, W2 ; 25us * 200 = 5.0ms
    djnz R2, W3 ; 5.0ms * 10 = 50ms (Approximately)
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
	JB START_BUTTON, Quit0 ; Go to Quit0 If Start Button is NOT Pressed
	LCALL Wait50ms
	JB START_BUTTON, Quit0

	;ToDo LCALL Init_Vars
	JNB START_BUTTON, $ ; Go to State1 If Start Button is Pressed
	MOV BCD_Counter, #0x00
	MOV Resulting_Counter, #0x60
	INC STATE_NUM
Quit0:
	RET

State1:
    MOV Timer_State, #0x01
    LCALL Power100
	JB START_BUTTON, Quit1 ; Go to Quit1 If Start Button is NOT Pressed
	LCALL Wait50ms
	JB START_BUTTON, Quit1

	JNB START_BUTTON, $ ; Go to State2 If Start Button is Pressed
	Check_Temp_Oven(#TEMP_SOAK) ; Check If Oven Temperature Reaches 150
	;ToDo : Do Something JB Below_Temp_Flag, ________

	MOV BCD_Counter, #0x00
	MOV Resulting_Counter, #0x06
	INC STATE_NUM
Quit1:
	RET

State2:
    LCALL Power20 ; Set Power to 20%
    MOV Timer_State, #0x01
    JB START_BUTTON, Quit2 ; Go to Quit2 If Start Button is NOT Pressed
	LCALL Wait50ms
	JB START_BUTTON, Quit2

	JNB START_BUTTON, $ ; Go to State3 If Start Button is Pressed
    MOV Timer_State, #0x00
Quit2:
	RET

State3:
    LCALL Power100 ; Set Power to 100%
    MOV Timer_State, #0x00
    JB START_BUTTON, Quit3 ; Go to Quit3 If Start Button is NOT Pressed
	LCALL Wait50ms
	JB START_BUTTON, Quit3

	JNB START_BUTTON, $ ; Go to State4 If Start Button is Pressed
	Check_Temp_Oven(#TEMP_REFLOW)
	;ToDo : Do Something JB Below_Temp_Flag, ________
    MOV Timer_State, #0x01
	MOV BCD_Counter, #0x00
	MOV Resulting_Counter, #0x07
	INC STATE_NUM
Quit3:
	RET

State4:
    LCALL Power20
    MOV Timer_State, #0x01
    JB START_BUTTON, Quit4 ; if START BUTTON is NOT PRESSED
	LCALL Wait50ms
	JB START_BUTTON, Quit4

	JNB START_BUTTON, $ ; if START BUTTON is PRESSED go to State1
	MOV BCD_Counter, #0x00
Quit4:
	RET

State5:
    LCALL Power0
    MOV Timer_State, #0x00
    JB START_BUTTON, Quit5 ; if START BUTTON is NOT PRESSED
	LCALL Wait50ms
	JB START_BUTTON, Quit5

	JNB START_BUTTON, $ ; if START BUTTON is PRESSED go to State1
	; CHECK IF TEMPERATURE REACHES VERY LOW VALUE
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

	LCALL Init_Vars
Init_SerialPort:
    ; Configure Serial Port and Baud Rate

    ; Since Reset Button Bounces, Wait a Bit Before Sending Messages.
    ; Otherwise, We Risk Sending Garbage to the Serial Port.
    MOV R1, #200
    MOV R0, #104
    DJNZ R0, $ ; 4 Cycles-> 4 * 60.285 ns * 104 = 25 us
    DJNZ R1, $-4 ; 25us * 200 = 5 ms
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
	LCALL Init_All
    SETB EA   ; Enable Global interrupts
	LCALL LCD_4BIT
Forever:
	LCALL Display_LCD
	LCALL StateChanges

	LJMP Forever

;ToDO LCALL Read_ADC_LED
;ToDO LCALL Get_LM335_TEMP
;ToDO LCALL Get_Thermocouple_TEMP
;ToDO LCALL Get_Temp_Oven

; LCALL Check_Temp_Error
; JB Below_Temp_Flag, Error_State

END
