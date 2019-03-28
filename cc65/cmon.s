; C'mon, the Compact MONitor
; written by Bruce Clark and placed in the public domain
;
; minor tweaks and porting by Ed Spittles
;
; To the extent possible under law, the owners have waived all
; copyright and related or neighboring rights to this work. 
;
; retrieved from http://www.lowkey.comuf.com/cmon.htm
; archived documentation at http://biged.github.io/6502-website-archives/lowkey.comuf.com/cmon.htm
;
; ported to ca65 from dev65 assembler
; /opt/cc65/bin/ca65 --listing -DSINGLESTEP cmon.a65 
; /opt/cc65/bin/ld65 -t none -o cmon.bin cmon.o
;
; define SINGLESTEP to include the single-stepping plugin
;     (modified to display registers in AXYS order)
;
; ported to 6502 from 65Org16
; ported to a6502 emulator
;
; 03-27-19 E. Brombaugh - modified for up5k 6502 project

.feature labels_without_colons

.import		_input
.import		_output
.export		_cmon

WIDTH  = 8         ;must be a power of 2
HEIGHT = 16


.macro putc
       JSR _output	; EMEB - modified for up5k ROM
.endmacro

.macro getc
       JSR _input	; EMEB - modified for up5k ROM
.endmacro

; cmon zero page usage
; EMEB - modified for OSI mapping
ADRESS = $FE
NUMBER = $FC

.ifdef SINGLESTEP
AREG   = 4
PREG   = 5
SREG   = 6
XREG   = 7
YREG   = 8
STBUF  = 9 ;uses 9 bytes
.endif

.segment	"CODE"

_cmon:
.ifdef SINGLESTEP
       TSX
       STX SREG
       PHP
       PLA
       STA PREG
.endif

MON    CLD
M1     JSR OUTCR
       LDA #$2D       ;output dash prompt
       putc
M2     LDA #0
       STA NUMBER+1
       STA NUMBER
M3     AND #$0F
M4     LDY #4         ;accumulate digit
M5     ASL NUMBER
       ROL NUMBER+1
       DEY
       BNE M5
       ORA NUMBER
       STA NUMBER
M6     getc
       CMP #$0D
       BEQ M1         ;branch if cr
;
; Insert additional commands for characters (e.g. control characters)
; outside the range $20 (space) to $7E (tilde) here
;

       CMP #$20       ;don't output if outside $20-$7E
       BCC M6
       CMP #$7F
       BCS M6
       putc
       CMP #$2C
       BEQ COMMA
       CMP #$40
       BEQ AT
;
; Insert additional commands for non-letter characters (or case-sensitive
; letters) here
;
.ifdef SINGLESTEP
       CMP #$24		; $ is single step
       BNE NSSTEP
       JMP SSTEP
NSSTEP
.endif

; now dealing with letters
       EOR #$30
       CMP #$0A
       BCC M4         ;branch if digit
       ORA #$20       ;convert to upper case
       SBC #$77
;
; mapping:
;   A-F -> $FFFA-$FFFF
;   G-O -> $0000-$0008
;   P-Z -> $FFE9-$FFF3
;
       BEQ GO
       CMP #$FA	; EMEB - why doesn't ca65 support negatives?
       BCS M3
;
; Insert additional commands for (case-insensitive) letters here
;

       CMP #$F1	; EMEB - why doesn't ca65 support negatives?
       BNE M6
DUMP   JSR OUTCR
       TYA
       PHA
       CLC            ;output address
       ADC NUMBER
       PHA
       LDA #0
       ADC NUMBER+1
       JSR OUTHEX
       PLA
       JSR OUTHSP
D1     LDA (NUMBER),Y ;output hex bytes
       JSR OUTHSP
       INY
       TYA
       AND #WIDTH-1
       BNE D1
       PLA
       TAY
D2     LDA (NUMBER),Y ;output characters
       CMP #$20
       BCC D3
       CMP #$7F
       BCC D4
D3     LDA #$2E		; EMEB - convert non-printables to '.'
D4     putc
       INY
       TYA
       AND #WIDTH-1
       BNE D2
       CPY #WIDTH*HEIGHT
       BCC DUMP
	   JMP M1		; EMEB - added to return to prompt
M2J
       JMP M2		; branches out of range for 6502 when putc is 3 bytes
COMMA  LDA NUMBER
       STA (ADRESS),Y
       INC ADRESS
       BNE M2J
       INC ADRESS+1
       BCS M2J
AT     LDA NUMBER
       STA ADRESS
       LDA NUMBER+1
       STA ADRESS+1
       BCS M2J
GO     JSR G1
       JMP M2		; returning after a 'go'
G1     JMP (NUMBER)
OUTHEX ;JSR OH1		; for 16-bit bytes
OH1    JSR OH2
OH2    ASL
       ADC #0
       ASL
       ADC #0
       ASL
       ADC #0
       ASL
       ADC #0
       PHA
       AND #$0F
       CMP #$0A
       BCC OH3
       ADC #$66
OH3    EOR #$30
       putc
       PLA
       RTS
OUTHSP JSR OUTHEX
       LDA #$20
OA1    putc
       RTS
OUTCR  LDA #$0D
       putc
       LDA #$0A
       BNE OA1        ;always

.ifdef SINGLESTEP
SSTEP  LDX #7
STEP1  LDA STEP4,X
       STA STBUF+1,X
       DEX
       BPL STEP1
       LDX SREG
       TXS
       LDA (ADRESS),Y
       BEQ STBRK
       JSR GETLEN
       TYA
       PHA
STEP2  LDA (ADRESS),Y
       STA STBUF,Y
       DEY
       BPL STEP2
       EOR #$20
       CMP #1
       PLA
       JSR STADR
       LDA STBUF
       CMP #$20
       BEQ STJSR
       CMP #$4C
       BEQ STJMP
       CMP #$40
       BEQ STRTI
       CMP #$60
       BEQ STRTS
       CMP #$6C
       BEQ STJMPI
       AND #$1F
       CMP #$10
       BNE STEP3
       LDA #4
       STA STBUF+1
STEP3  LDA PREG
       PHA
       LDA AREG
       LDX XREG
       LDY YREG
       PLP
       JMP STBUF
STEP4  NOP
       NOP
       JMP STNB
       JMP STBR
STJSR  LDA ADRESS+1
       PHA
       LDA ADRESS
       PHA        ;fall thru
STJMP  LDY STBUF+1
       LDA STBUF+2
STJMP1 STY ADRESS
STJMP2 STA ADRESS+1
       JMP STNB1
STJMPI INY
       LDA (STBUF+1),Y
       STA ADRESS
       INY
       LDA (STBUF+1),Y
       JMP STJMP2
STRTI  PLA
       STA PREG
       PLA
       STA ADRESS
       PLA
       JMP STJMP2
STRTS  PLA
       STA ADRESS
       PLA
       STA ADRESS+1
       LDA #0
       JSR STADR
       JMP STNB1
STBRK  LDA ADRESS+1
       PHA
       LDA ADRESS
       PHA
       LDA PREG
       PHA
       ORA #$04 ; set i flag
       AND #$F7 ; clear d flag
       STA PREG
       LDY a:-2 ; $FFFFFFFE
       LDA a:-1 ; $FFFFFFFF
       JMP STJMP1
STNB   PHP
       STA AREG
       STX XREG
       STY YREG
       PLA
       STA PREG
       CLD
STNB1  TSX
       STX SREG
STNB2  JSR STOUT
       JMP M2
STBR   DEC ADRESS+1
       LDY #-1  ; #$FFFF
       LDA (ADRESS),Y
       BMI STBR1
       INC ADRESS+1
STBR1  CLC
       JSR STADR
       JMP STNB2
STADR  ADC ADRESS
       STA ADRESS
       BCC STADR1
       INC ADRESS+1
STADR1 RTS
OUTPC  LDA ADRESS+1
       JSR OUTHEX
       LDA ADRESS
       JMP OUTHSP
STOUT  JSR OUTCR
       JSR OUTPC ; fall thru
OUTREG LDA AREG
       JSR OUTHSP
       LDA XREG
       JSR OUTHSP
       LDA YREG
       JSR OUTHSP
       LDA SREG
       JSR OUTHSP
       LDA PREG
       JSR OUTHSP
       LDA PREG   ;fall thru
OUTBIN SEC
       ROL
OUTB1  PHA
       LDA #$18
       ROL
       putc
       PLA
       ASL
       BNE OUTB1
       RTS
;
;    0123456789ABCDEF
;
; 00 22...22.121..33.
; 10 22...22.13...33.
; 20 32..222.121.333.
; 30 22...22.13...33.
; 40 12...22.121.333.
; 50 22...22.13...33.
; 60 12...22.121.333.
; 70 22...22.13...33.
; 80 .2..222.1.1.333.
; 90 22..222.131..3..
; A0 222.222.121.333.
; B0 22..222.131.333.
; C0 22..222.121.333.
; D0 22...22.13...33.
; E0 22..222.121.333.
; F0 22...22.13...33.
;
; Return instruction length - 1 (note that BRK is considered to be a 2 byte
; instruction and returns 1)
;
GETLEN LDY #1
       CMP #$20  ; if opcode = $20, then length = 3
       BEQ GETL3
       AND #$DF
       CMP #$40
       BEQ GETL1 ; if (opcode & $DF) = $40, then length = 1
       AND #$1F
       CMP #$19
       BEQ GETL3 ; if (opcode & $1F) = $19, then length = 3
       AND #$0D
       CMP #$08
       BNE GETL2 ; if (opcode & $0D) = $08, then length = 1
GETL1  DEY
GETL2  CMP #$0C
       BCC GETL4 ; if (opcode & $0D) >= $0C, then length = 3
GETL3  INY
GETL4  RTS

BREAK  STA AREG
       STX XREG
       STY YREG
       PLA
       STA PREG
       PLA
       STA ADRESS
       PLA
       STA ADRESS+1
       TSX
       STX SREG
       CLD
       JSR STOUT
       JMP M1
.endif

.ifdef VECTORS
Lnmi:
        .byte 1,2
 
Lreset:
        .word init

Lirqbrk:
.ifdef SINGLESTEP
        .word BREAK
.else
        .byte 5,6
.endif

Lend:
.endif
