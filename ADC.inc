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

Convert_Voltage_Temp:
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

    Load_y(27300)
    LCALL sub32

    RET

Get_LM335_TEMP:
	; Read AIN1 on Pin 14
	ANL ADCCON0, #0XF0
	ORL ADCCON0, #0X01 ; Select ADC Channel 1
	LCALL Read_ADC_Avg
	LCALL Convert_Voltage_Temp

	; Save Result to Use Later.
	MOV LM335_TEMP+0, X+0
	MOV LM335_TEMP+1, X+1

	RET

Get_THERMOCOUPLE_TEMP:
	; Read AIN7 on Pin 14
	ANL ADCCON0, #0XF0
	ORL ADCCON0, #0X07 ; Select ADC Channel 7
	LCALL Read_ADC_Avg
	LCALL Convert_Voltage_Temp

	; Save Result to Use Later.
	MOV THERMOCOUPLE_TEMP+0, X+0
	MOV THERMOCOUPLE_TEMP+1, X+1

	RET

Add_Temp_Oven:
	MOV X+0, LM335_TEMP+0
	MOV X+1, LM335_TEMP+1
	MOV X+2, #0 ; Pad Other Bits with 0
	MOV X+3, #0 ; Pad Other Bits with 0

	MOV Y+0, THERMOCOUPLE_TEMP+0
	MOV Y+1, THERMOCOUPLE_TEMP+1
	MOV Y+2, #0 ; Pad Other Bits with 0
	MOV Y+3, #0 ; Pad Other Bits with 0

	LCALL add32

	Load_y(100)
	LCALL div32

	MOV OVEN_TEMP, X+0

	RET

Get_Temp_Oven:
	LCALL Add_Temp_Oven

	MOV X+3, #0
	MOV X+2, #0
	MOV X+1, #0
	MOV X+0, OVEN_TEMP

	LCALL hex2BCD
    LCALL TX_Val

	RET

	; Convert to BCD and Display

	LJMP Forever

Check_Temp_Oven MAC
    PUSH AR0
    MOV R0, %0

    LCALL ?Check_Temp_Oven

    POP AR0
ENDMAC

?Check_Temp_Oven:
	MOV A, OVEN_TEMP
	SUBB A, R0
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
	Check_Temp_Oven(#TEMP_ERROR)
	JB Below_Temp_Flag, Check_Temp_Error_Triggered
	SJMP Check_Temp_Error_Triggered_Done
Check_Temp_Error_Triggered:
	CLR Below_Temp_Flag
	SETB Error_Triggered_Flag
	SJMP Check_Temp_Error_Triggered_Done
Check_Temp_Error_Triggered_Done:
	RET

$LIST