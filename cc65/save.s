; ---------------------------------------------------------------------------
; save.s - BASIC SAVE routine
; ---------------------------------------------------------------------------
;

.import		_hexout
.import		_output
.import		BAS_NXT_INTARG
.import		BAS_GET_INTARG
.importzp	BAS_INTLO
.importzp	BAS_INTHI
.import		output_vec

.export		_save

.segment	"CODE"

; ---------------------------------------------------------------------------
; SAVE vector - sets up to inject text from flash

.proc _save: near
			jsr BAS_NXT_INTARG	; fetch next arg on BASIC line
			jsr	BAS_GET_INTARG	; Convert arg to 16-bit signed integer
			lda BAS_INTHI		; send high byte as hex
			jsr _hexout
			lda BAS_INTLO		; send low byte as hex
			jsr _hexout
			lda #$0A			; send CR/LF
			jsr _output
			lda #$0D
			jsr _output
			
			; redirect output to special routine
			lda #.lobyte(sv_chrout)
			sta output_vec
			lda #.hibyte(sv_chrout)
			sta output_vec+1
			
			; list all
			jsr sv_list
			
			; restore
			lda #.lobyte(_output)
			sta output_vec
			lda #.hibyte(_output)
			sta output_vec+1
			
			rts
.endproc

; ---------------------------------------------------------------------------
; list BASIC program - ganked from ROM & MS source

.proc sv_list: near
sv_GOLST:   LDA #$0				; FORCE MIN LINE # = 0
			STA $11				; LINNUM
			STA $12				; LINNUM+1
			JSR $A432			; FNDLIN - GET LOW LINE # IN LOWTR
sv_LSTEND:	LDA #$FF			; FORCE MAX LINE # = 65535
			STA $11
			STA $12
sv_LIST4:	LDY #$01
			STY $60				; DORES - 
			LDA ($AA),Y			; LOWTR
			BEQ sv_GORDY
			JSR $A629			; CHECK FOR CTRL-C
			JSR $A86C			; PRINT CRLF
			INY
			LDA ($AA),Y
			TAX
			INY
			LDA ($AA),Y
			CMP $12
			BNE sv_TSTDUN
			CPX $11
			BEQ sv_TYPLIN
sv_TSTDUN:	BCS sv_GORDY
sv_TYPLIN:	STY $97
			JSR $B95E
			LDA #$20
sv_PRIT4:	LDY $97
			AND #$7F
sv_PLOOP:	JSR sv_chrout
			CMP #$22
			BNE sv_PLOOP1
			LDA $60
			EOR #$FF
			STA $60
sv_PLOOP1:	INY
			LDA ($AA),Y
			BNE sv_QPLOP
			TAY
			LDA ($AA),Y
			TAX
			INY
			LDA ($AA),Y
			STX $AA
			STA $AB
			BNE sv_LIST4
sv_GORDY:	RTS
sv_QPLOP:	BPL sv_PLOOP
			CMP #$FF
			BEQ sv_PLOOP
			BIT $60
			BMI sv_PLOOP
			SEC
			SBC #$7F
			TAX
			STY $97
			LDY #$FF
sv_RESRCH:	DEX
			BEQ sv_PRIT3
sv_RESCR1:	INY
			LDA $A084,Y			; RESLST - RESERVED WORD LIST
			BPL sv_RESCR1
			BMI sv_RESRCH
sv_PRIT3:	INY
			LDA $A084,Y
			BMI sv_PRIT4
			JSR sv_chrout
			BNE sv_PRIT3
.endproc

; ---------------------------------------------------------------------------
; send char to... (serial / flash / etc)

.proc sv_chrout: near
			adc #$01			; just to differentiate
			jsr _output
			rts
.endproc