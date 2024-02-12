$NOLIST

cseg 

Display_BelowFlag:
	Set_Cursor(1, 15)
	JB Below_Temp_Flag, Display_BelowFlag_True
	SJMP Display_BelowFlag_False
Display_BelowFlag_True:
	Display_Char(#'1')
	RET	
Display_BelowFlag_False:
	Display_Char(#'0')
	RET

Display_Error:
	Set_Cursor(1, 16)
	JB Error_Triggered_Flag, Display_Error_True
	SJMP Display_Error_False
Display_Error_True:
	Display_Char(#'1')
	RET
Display_Error_False:
	Display_Char(#'0')
    RET

Display_SpeakerFlag:
	Set_Cursor(2, 15)
	JB Speaker_En_Flag, Display_SpeakerFlag_True
	SJMP Display_SpeakerFlag_False
Display_SpeakerFlag_True:
	Display_Char(#'1')
	RET
Display_SpeakerFlag_False:
	Display_Char(#'0')
	RET
END

$LIST