$NOLIST
;----------------------------------
; ADC.inc: Reads ADC Values and
; Converts to Voltage, Temperature
;----------------------------------

CSEG

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

Read_ADC_Avg:
	; Get the Average of 5000 ADC Readings
	; Store the Result in [R1, R0]
	; R1 = High Byte
	; R0 = Low Byte

	Load_x(0)
	MOV R4, #100
Get_ADC_Sum_Loop_I:
	MOV R5, #50
Get_ADC_Sum_Loop_J:
	LCALL Read_ADC_Start

	MOV Y+3, #0
	MOV Y+2, #0
	MOV Y+1, R1 ; High Byte
	MOV Y+0, R0 ; Low Byte
	LCALL add32
	DJNZ R5, Get_ADC_Sum_Loop_J
	DJNZ R4, Get_ADC_Sum_Loop_I
Read_ADC_Avg_Done:
	load_y(5000)
	LCALL div32

	MOV R0, X+0
	MOV R1, X+1
	RET

Read_ADC_LED:
	; Read AIN0 on Pin 6
	ANL ADCCON0, #0XF0
	ORL ADCCON0, #0X00 ; Select ADC Channel 0
    ; Read the ADC Connected to AIN7 on Pin 14
	LCALL Read_ADC_Avg
	; Save Result to Use Later.
	MOV VLED_ADC+0, R0
	MOV VLED_ADC+1, R1

	RET

Convert_Voltage:
    ; Convert to Voltage
	MOV X+0, R0
	MOV X+1, R1
	MOV X+2, #0 ; Pad Other Bits with 0
	MOV X+3, #0 ; Pad Other Bits with 0

	Load_y(20740) ; Measured LED Voltage : 2.074V with 4 Decimal Places
	LCALL mul32

	; Retrieve ADC LED Value
	MOV Y+0, VLED_ADC+0
	MOV Y+1, VLED_ADC+1
	MOV Y+2, #0 ; Pad Other Bits with 0
	MOV Y+3, #0 ; Pad Other Bits with 0
	LCALL div32

	RET

Get_LM335_TEMP:
	; Read AIN1 on Pin 14
	ANL ADCCON0, #0XF0
	ORL ADCCON0, #0X01 ; Select ADC Channel 1
	LCALL Read_ADC_Avg
	LCALL Convert_Voltage
Calculate_LM335_TEMP:
    Load_y(27300)
    LCALL sub32	
    Load_y(10)
    LCALL mul32	

	; Save Result to Use Later.
	MOV LM335_TEMP+0, X+0
	MOV LM335_TEMP+1, X+1
	MOV LM335_TEMP+2, X+2
	MOV LM335_TEMP+3, X+3

	RET

Get_THERMOCOUPLE_TEMP:
	; Read AIN7 on Pin 14
	ANL ADCCON0, #0XF0
	ORL ADCCON0, #0X07 ; Select ADC Channel 7
	LCALL Read_ADC_Avg
	LCALL Convert_Voltage
Calculate_THERMOCOUPLE_TEMP:
	LCALL hex2bcd
	MOV Output_Voltage+3, BCD+3
	MOV Output_Voltage+2, BCD+2
	MOV Output_Voltage+1, BCD+1
	MOV Output_Voltage+0, BCD+0

	Load_y(1000) ; Vout * 1000 / 12424
	LCALL mul32
	Load_y(12424)
	LCALL div32
	Load_y(100) 
	LCALL mul32

	; Save Result to Use Later.
	MOV THERMOCOUPLE_TEMP+3, X+3
	MOV THERMOCOUPLE_TEMP+2, X+2
	MOV THERMOCOUPLE_TEMP+1, X+1
	MOV THERMOCOUPLE_TEMP+0, X+0

	RET

Add_Temp_Oven:
	MOV X+3, LM335_TEMP+3
	MOV X+2, LM335_TEMP+2
	MOV X+1, LM335_TEMP+1
	MOV X+0, LM335_TEMP+0

	MOV Y+3, THERMOCOUPLE_TEMP+3
	MOV Y+2, THERMOCOUPLE_TEMP+2
	MOV Y+1, THERMOCOUPLE_TEMP+1
	MOV Y+0, THERMOCOUPLE_TEMP+0

	LCALL add32

	Load_y(1000)
	LCALL div32

	MOV OVEN_TEMP, X+0

	RET

Get_LM335_Temperature_BCD:
	MOV X+0, LM335_TEMP+0
	MOV X+1, LM335_TEMP+1
	MOV X+2, LM335_TEMP+2
	MOV X+3, LM335_TEMP+3

	LCALL hex2BCD
	
	RET

Get_Thermocouple_Temperature_BCD:
	MOV X+0, THERMOCOUPLE_TEMP+0
	MOV X+1, THERMOCOUPLE_TEMP+1
	MOV X+2, THERMOCOUPLE_TEMP+2
	MOV X+3, THERMOCOUPLE_TEMP+3

	LCALL hex2BCD
	
	RET

Display_LM335_Temperature:
	LCALL Get_LM335_Temperature_BCD

	Set_Cursor(1, 10)
	Display_BCD(BCD+2)
	Display_BCD(BCD+1)
	Display_BCD(BCD+0)
	
	RET

Display_Thermocouple_Temperature:
	LCALL Get_Thermocouple_Temperature_BCD

	Set_Cursor(2, 1)
	Display_BCD(BCD+2)
	Display_BCD(BCD+1)
	
	RET

Display_Oven_Temperature:
	MOV A, OVEN_TEMP
	CLR C
	SUBB A, #100
	JC Display_Oven_Temperature_2Digits
Display_Oven_Temperature_3Digits:
	Set_Cursor(1, 4)
 	Display_BCD(OVEN_BCD+1)
 	Display_BCD(OVEN_BCD+0)
	RET
Display_Oven_Temperature_2Digits:
	Set_Cursor(1, 4)
	Display_char(#' ')
 	Display_BCD(OVEN_BCD+0)
	RET

Display_Output_Voltage:
	MOV A, Output_Voltage

	Set_Cursor(1, 1)
	Display_BCD(Output_Voltage+3)
	Display_BCD(Output_Voltage+2)
	Display_BCD(Output_Voltage+1)
	Display_BCD(Output_Voltage+0)

	RET


Display_Soak_Temperature:
	MOV X+0, TEMP_SOAK
	MOV X+1, #0
	MOV X+2, #0
	MOV X+3, #0

	LCALL hex2BCD
	Set_Cursor(2, 2)
	Display_BCD(BCD+1)
	Display_BCD(BCD+0)

	RET

Display_Reflow_Temperature:
	MOV X+0, TEMP_REFLOW
	MOV X+1, #0
	MOV X+2, #0
	MOV X+3, #0

	LCALL hex2BCD
	Set_Cursor(2, 10)
	Display_BCD(BCD+1)
	Display_BCD(BCD+0)

	RET

TX_Temp_Oven:
    Send_BCD(OVEN_BCD+1)
    Send_BCD(OVEN_BCD+0)
    Send_NewLine(#CARRIAGE_RETURN)

	RET

Write_Oven_BCD:
	MOV X+0, OVEN_TEMP
	MOV X+1, #0
	MOV X+2, #0
	MOV X+3, #0

	LCALL hex2BCD
	MOV OVEN_BCD+1, BCD+1 
	MOV OVEN_BCD+0, BCD+0 

	RET

Get_and_Transmit_Temp:
	LCALL Read_ADC_LED
	LCALL Get_LM335_TEMP
	LCALL Get_Thermocouple_TEMP
	LCALL Add_Temp_Oven
	LCALL Write_Oven_BCD
Get_and_Transmit_Temp_Done:	
	RET

Check_Temp_Oven:
	MOV A, OVEN_TEMP
	SUBB A, R1
	JC Temp_Below_Threshold
Temp_NotBelow_Threshold:
	CLR Below_Temp_Flag
	SJMP Check_Temp_Oven_Done
Temp_Below_Threshold:
	SETB Below_Temp_Flag
Check_Temp_Oven_Done:
	RET

Check_Temp_Error:
	; Check if the Temperature is Below the Error Threshold
	; If it is, Set the Error_Triggered_Flag Flag
	; Otherwise, Clear the Error_Triggered_Flag Flag
	MOV A, OVEN_TEMP
	MOV R1, TEMP_ERROR
	SUBB A, R1
	JC Temp_Error_Triggered
Temp_Error_Not_Triggered:
	CLR Error_Triggered_Flag
	SJMP Check_Temp_Error_Triggered_Done
Temp_Error_Triggered:
	SETB Error_Triggered_Flag
	SJMP Check_Temp_Error_Triggered_Done
Check_Temp_Error_Triggered_Done:
	RET

$LIST