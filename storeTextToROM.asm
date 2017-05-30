; ;:-* 8052 Bluetooth Controlled Rolling DotMatrix Display *-:; ;
; EEE212 - Section 1 - Group 15 ;
;=========================================================
; ;;VARIABLES;; ;
TI_ BIT 00
CMODE BIT 01
CMODE_SPEED BIT 02
CMODE_BRIGHTNESS BIT 03
DISPLAY_TEXT BIT 04
STORE_CHAR BIT 05
SPEED EQU 30H
BRIGHTNESS EQU 31H


;EEPROM
eeprom_scl_pin  EQU P2.4  ;scl p2.4    a4h
eeprom_sda_pin  EQU P2.5  ;sda p2.5    a5h
memory_address1 EQU 38H
eeprom_data     EQU 39H   ;Input when writing
EEPROM_BUFF     EQU 3BH   ;Output when reading



ORG 0
LJMP MAIN
ORG 23H
LJMP SERIAL


; ---------main program, initialization ---
MAIN: 
CLR CMODE
CLR CMODE_SPEED
CLR CMODE_BRIGHTNESS
CLR DISPLAY_TEXT

MOV P1, #0FFH;	make P1 an input port
MOV TMOD, #21H;	timer 1, mode 2(auto reload)
MOV TH1, #0FDH;	9600 baud rate
MOV SCON, #50H;	8-bit, 1 stop, REN enabled
MOV IE, #10010000B;	enable serial interrupt
SETB TR1;	 start timer 1


;-------ready message-----------------
MOV DPTR,#MYDATA ;load pointer for message
MESSAGE_AGAIN:
CLR A
MOVC A,@A+DPTR ;get the character
JZ MESSAGE_DONE ;if last character get out

CLR TI_
MOV SBUF, A
JNB TI_,$; waits for the TI signal from the interrupt

INC DPTR
SJMP MESSAGE_AGAIN ;next character
MESSAGE_DONE:



;----------INITIALIZE THE RAM WITH THE EEPROM DATA-------
MOV R1, #40H
MOV R7, #00H
EEPROM_INITIALIZE_NEXT:
MOV memory_address1, R7
LCALL read_data
MOV A, EEPROM_BUFF
MOV @R1, A
INC R7
INC R1
CJNE R1, #0A4H, EEPROM_INITIALIZE_SKIP
SJMP EEPROM_INITIALIZE_EXIT;	resets if not reached the max character limit(100)
EEPROM_INITIALIZE_SKIP:
CJNE @R1, #5CH, EEPROM_INITIALIZE_NEXT;	if reaches escape character \
MOV @R1, A
MOV R7, #00H;	resets the character pointer
EEPROM_INITIALIZE_EXIT:



MOV R0, #40H;	starting ram location for the characters in ram
;-------stay in loop indefinitely-------
MAIN_BACK:
MOV P1, BRIGHTNESS


; updates the data in eeprom with ram
MOV R1, #40H
MOV R7, #00H
EEPROM_UPDATE_NEXT:
MOV  eeprom_data, @R1
MOV memory_address1, R7
LCAll write_data
LCALL eeprom_delay
INC R7
INC R1
CJNE R1, #0A4H, EEPROM_UPDATE_SKIP
SJMP EEPROM_UPDATE_EXIT;	resets if not reached the max character limit(100)
EEPROM_UPDATE_SKIP:
CJNE @R1, #5CH, EEPROM_UPDATE_NEXT;	if reaches escape character \
; ADDED LATER
MOV  eeprom_data, @R1
MOV memory_address1, R7
LCAll write_data
LCALL eeprom_delay
MOV R7, #00H;	resets the character pointer
EEPROM_UPDATE_EXIT:


; displays the string in the eeprom
MOV R1, #40H
JNB DISPLAY_TEXT, MAIN_BACK
DISPLAY_TEXT_NEXT:
MOV A, @R1
CLR TI_
MOV SBUF, A
JNB TI_,$; waits for the TI signal from the interrupt
INC R1
CJNE A, #5CH, DISPLAY_TEXT_NEXT ; shows characters upto \
CLR DISPLAY_TEXT
SJMP MAIN_BACK




;------serial communication ISR---------
SERIAL:
PUSH ACC
JB TI, TRANS
MOV A, SBUF
CLR RI

CJNE A, #2AH, PROCESS_CHAR;	changes the command mode if sees *
CPL CMODE
CLR CMODE_SPEED
CLR CMODE_BRIGHTNESS
POP ACC
RETI

PROCESS_CHAR:
; process the command
JB CMODE, COMMAND_MODE

; else process the text
MOV @R0, A
CJNE A, #5CH, PROCESS_TEXT_SKIP1;	if reaches escape character \
MOV R0, #40H;	resets the charater pointer
PROCESS_TEXT_SKIP1:
CJNE R0, #0A4H, PROCESS_TEXT_SKIP2
MOV R0, #40H;	resets if not reached the max character limit(100)
PROCESS_TEXT_SKIP2:
INC R0
POP ACC
RETI


COMMAND_MODE:
CJNE A, #73H, PROCESS_COMMAND1;	if 's'
SETB CMODE_SPEED;	sets the speed mode if sees s after *
POP ACC
RETI

PROCESS_COMMAND1:
CJNE A, #62H, PROCESS_COMMAND2;	if 'b'
SETB CMODE_BRIGHTNESS;	sets the speed mode if sees s after *
POP ACC
RETI

PROCESS_COMMAND2:
CJNE A, #64H, PROCESS_COMMAND3;	if 'd'
SETB DISPLAY_TEXT;	sets the display mode if sees d after *
POP ACC
RETI

PROCESS_COMMAND3:
JB CMODE_SPEED, SET_SPEED_MODE; if it is in speed mode goes to set the value
JB CMODE_BRIGHTNESS, SET_BRIGHTNESS_MODE; if it is in brightness mode goes to set the value

; otherwise do nothing
POP ACC
RETI


SET_SPEED_MODE:
SUBB A, #2FH;	subtracts to convert from ascii
MOV SPEED, A
POP ACC
RETI

SET_BRIGHTNESS_MODE:
SUBB A, #2FH;	subtracts to convert from ascii
MOV BRIGHTNESS, A
POP ACC
RETI


TRANS:
SETB TI_
CLR TI
POP ACC
RETI

;---------------The message to send
MYDATA:DB 'We Are Ready',0



;=========================================================
;EEPROM METHODS
;=========================================================
write_data:     push acc ;;;;;;;;;;;;;;;;;;;;;;;;;;   PROTECT DATA 
    call eeprom_start
                mov a, #0A0H
                call send_data
                mov a,memory_address1          ;location address
                call send_data
                mov a,eeprom_data              ;data to be send
                call send_data
                call eeprom_stop
                pop acc ;;;;;;;;;;;;;;;;;;;;;;;;;;   PROTECT DATA
                ret   
;=========================================================
read_data:      push acc ;;;;;;;;;;;;;;;;;;;;;;;;;;   PROTECT DATA
    call eeprom_start

                mov a, #0A0H
                call send_data
                mov a,memory_address1          ;location address
                call send_data
                call eeprom_start
                mov a, #0A1H
                call send_data
                call get_data
                call eeprom_stop
                pop acc ;;;;;;;;;;;;;;;;;;;;;;;;;;   PROTECT DATA
                ret
;=========================================================
eeprom_start:    setb eeprom_sda_pin
                nop
                setb eeprom_scl_pin
                nop
                nop
                clr eeprom_sda_pin
                nop
                clr eeprom_scl_pin
                ret
;=========================================================
eeprom_stop:     clr eeprom_sda_pin
                nop
                setb eeprom_scl_pin
                nop
                nop
                setb eeprom_sda_pin
                nop
                clr eeprom_scl_pin
                ret
;=========================================================
send_data:      push 7 ;;;;;;;;;;;;;;;;;;;;;;;;;;   PROTECT DATA
    mov r7,#00h
send:           rlc a
               mov eeprom_sda_pin,c
               call clock
               inc r7
               cjne r7,#08,send
               setb eeprom_sda_pin
               jb eeprom_sda_pin,$
              call eeprom_delay
               call clock
               pop 7 ;;;;;;;;;;;;;;;;;;;;;;;;;;   PROTECT DATA
               ret
;=========================================================
get_data:      push 7;;;;;;;;;;;;;;;;;;;;;;;;;   PROTECT DATA
               mov r7,#00h
               setb eeprom_sda_pin
get:            mov c,eeprom_sda_pin
               call clock
               rlc a
               inc r7
               cjne r7,#08,get
               setb eeprom_sda_pin
               call clock
               mov EEPROM_BUFF,a
               pop 7;;;;;;;;;;;;;;;;;;;;;;;;;;   PROTECT DATA
               ret
;=========================================================
clock:         setb eeprom_scl_pin
               nop
               nop
               clr eeprom_scl_pin
               ret
;=========================================================
eeprom_delay:      mov 33h,#11      ;delay of 3 mili seconds 
eeprom_delay_1:    mov 32h,#0ffh
                   djnz 32h,$
                   djnz 33h,eeprom_delay_1
                   ret

;=========================================================

END


