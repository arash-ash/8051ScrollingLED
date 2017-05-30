ORG 0
CLR P3.7 ; FOR TESTING
MOV P2,#0FFH ;make P2 an input port

MOV TMOD,#20H
MOV TH1,#0FDH ;9600 baud rate
MOV SCON,#50H
SETB TR1 ;start timer 1

MOV DPTR,#MYDATA ;load pointer for message
H_1:
CLR A
MOVC A,@A+DPTR ;get the character
JZ B_1 ;if last character get out
ACALL SEND
INC DPTR
SJMP H_1 ;next character

B_1:
MOV A,P2 ;read data on P2
ACALL SEND ;transfer it serially
ACALL RECV ;get the serial data
MOV P1,A ;display it on LEDs

SJMP B_1 ;stay in loop indefinitely

;-----------serial data transfer. ACC has the data
SEND: MOV SBUF,A ;load the data
H_2:
JNB TI,H_2 ;stay here until last bit gone
CLR TI ;get ready for next char
RET

;-------------- Receive data serially in ACC
RECV: JNB RI,RECV ;wait here for char
MOV A,SBUF ;save it in ACC
CLR RI ;get ready for next char
RET

;-------------- Delay for about half a second
DELAY:
MOV  R3,#10
AGAIN_DELAY:MOV  TL1,#08
MOV  TH1,#01 
SETB TR1
BACK:  JNB  TF1,BACK
CLR  TR1
CLR  TF1
DJNZ R3,AGAIN_DELAY
RET

;---------------The message to send
MYDATA:DB 'We Are Ready',0
END
