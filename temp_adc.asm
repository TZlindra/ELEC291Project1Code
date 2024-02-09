; temp_adc.asm:
; 	A) Reads Channel 0 on P1.7, Pin 6 (Green LED Voltage Reference)
; 	B) Reads Channel 1 on P3.0, Pin 14 (LM335 Temperature Sensor)
; 	B) Reads Channel 7 on P1.1, Thermo Couple (K-Type)
;   D) Sends Value to LCD and via UART to COM3 Port

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
BAUD              EQU 115200 ; Baud Rate for UART in BPS

TIMER1_RELOAD     EQU (0X100 - (CLK / (16 * BAUD)))

ORG 0x0000
	LJMP Main

TX_MSG:           db 'TX(C)           ', 0

CSEG

LCD_RS EQU P1.3 ; Pin 12
LCD_E  EQU P1.4 ; Pin 11
LCD_D4 EQU P0.0 ; Pin 16
LCD_D5 EQU P0.1 ; Pin 15
LCD_D6 EQU P0.2 ; Pin 18
LCD_D7 EQU P0.3 ; Pin 19

DSEG AT 30H

TX_SIZE  EQU 5 ; Size of the Transmit Buffer
TX_BUFF: DS TX_SIZE ; Buffer for Transmit Characters

X:   DS 4
Y:   DS 4
BCD: DS 5

VLED_ADC: DS 2
LM335_ADC: DS 2
Thermocouple_ADC: DS 2

BSEG
MF: DBIT 1

$NOLIST
$include(LCD_4bit.inc) ; Library of LCD Related Functions and Utility Macros
$include(Serial_4bit.inc) ; Library of Serial Port Related Functions and Utility Macros
$LIST

$NOLIST
$include(math32.inc) ; Library of 32-bit Math Functions
$LIST

Init_All:
	MOV	P3M1, #0X00
	MOV	P3M2, #0X00

	MOV	P1M1, #0X00
	MOV	P1M2, #0X00

	MOV	P0M1, #0X00
	MOV	P0M2, #0X00
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

	;ToDo : Figure Out if We Need Interrupt for Channel 0
	; ; Initialize and Start the ADC.
	; ANL ADCCON0, #0XF0 ; Clear the ADC Configuration Bits
	; ORL ADCCON0, #0X00 ; Select Channel 0
	; ORL ADCCON0, #0X01 ; Select Channel 1
	; ORL ADCCON0, #0X07 ; Select Channel 7

	; AINDIDS Select if Some Pins are Analog Inputs or Digital I/O
	MOV AINDIDS, #0X00 ; Disable All Analog Inputs
	ORL AINDIDS, #0B1000_0011 ; Activate AIN0, AIN1, AIN7

	ORL ADCCON1, #0X01 ; Enable ADC

	RET

CARRIAGE_RETURN:
    DB '\r', '\n', 0

Read_ADC_Start:
	CLR ADCF
	SETB ADCS ; ADC Start Trigger Signal
    JNB ADCF, $ ; Wait for Conversion to Complete
Read_ADC_Store:
    ; Read ADC Result and Store in [R1, R0]
    MOV A, ADCRL
    ANL A, #0X0F
    MOV R0, A

    MOV A, ADCRH
    SWAP A
    PUSH ACC
    ANL A, #0X0F
    MOV R1, A
    POP ACC
    ANL A, #0XF0
    ORL A, R0
    MOV R0, A

	RET

Main:
	; Initialization
	MOV SP, #0X7F
	LCALL Init_All
    LCALL LCD_4BIT
Init_LCD:
	Set_Cursor(2, 1)
    Send_Constant_String(#TX_MSG)
Forever:
	SJMP Read_ADC_LED
Read_ADC_LED:
	; Read AIN0 on Pin 6
	ANL ADCCON0, #0XF0
	ORL ADCCON0, #0X00 ; Select ADC Channel 0
    ; Read the ADC Connected to AIN7 on Pin 14
	LCALL Read_ADC_Start
	; Save Result to Use Later.
	MOV VLED_ADC+0, R0
	MOV VLED_ADC+1, R1
Read_ADC_LM335:
	; Read AIN1 on Pin 14
	ANL ADCCON0, #0XF0
	ORL ADCCON0, #0X01 ; Select ADC Channel 1

	LCALL Read_ADC_Start
	; Save Result to Use Later.
	MOV LM335_ADC+0, R0
	MOV LM335_ADC+1, R1
	LJMP Convert_Display
Read_ADC_ThermoCouple:
	; Read AIN7 on Pin 14
	ANL ADCCON0, #0XF0
	ORL ADCCON0, #0X07 ; Select ADC Channel 7
	LCALL Read_ADC_Start

	; Save Result to Use Later.
	MOV Thermocouple_ADC+0, R0
	MOV Thermocouple_ADC+1, R1
Convert_Display:
	LCALL Add_ADC
	LCALL Convert_Voltage_Analog
    LCALL Calculate_Temp

	LCALL hex2BCD
    LCALL TX_Val
	LCALL Display_Formatted_BCD

	; Convert to BCD and Display
	LJMP Forever

Convert_Voltage_Analog:
	Load_y(20740) ; Measured LED Voltage : 2.074V with 4 Decimal Places
	LCALL mul32

	; Retrieve ADC LED Value
	MOV Y+0, VLED_ADC+0
	MOV Y+1, VLED_ADC+1
	MOV Y+2, #0 ; Pad Other Bits with 0
	MOV Y+3, #0 ; Pad Other Bits with 0
	LCALL div32

    RET

Calculate_Temp:
    Load_y(27300)
    LCALL sub32
    Load_y(100)
    LCALL mul32

	RET

Add_ADC:
	MOV X+0, Thermocouple_ADC+0
	MOV X+1, Thermocouple_ADC+1
	MOV X+2, #0 ; Pad Other Bits with 0
	MOV X+3, #0 ; Pad Other Bits with 0

	; MOV Y+0, LM335_ADC+0
	; MOV Y+1, LM335_ADC+1
	MOV Y+0, #0
	MOV Y+1, #0
	MOV Y+2, #0 ; Pad Other Bits with 0
	MOV Y+3, #0 ; Pad Other Bits with 0
	; LCALL add32

	RET

TX_Val:
    Send_BCD(BCD+2)
    Send_BCD(BCD+1)
    Send_BCD(BCD+0)
    Send_NewLine(#CARRIAGE_RETURN)

    RET

; Display Number with 4 Decimal Places
Display_Formatted_BCD:
	Set_Cursor(2, 10)
	Display_BCD(BCD+2)
	Display_char(#'.')
	Display_BCD(BCD+1)
	Display_BCD(BCD+0)

	RET
END
