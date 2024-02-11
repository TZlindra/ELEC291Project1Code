; Display Number with 2 Decimal Places
Display_LM335_BCD:
	Set_Cursor(1, 10)
	Display_BCD(BCD+1)
	Display_char(#'.')
	Display_BCD(BCD+0)

	RET

; Display Number with 2 Decimal Places
Display_Thermocouple_BCD:
	Set_Cursor(2, 10)
	Display_BCD(BCD+1)
	Display_char(#'.')
	Display_BCD(BCD+0)

	RET
