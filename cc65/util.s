; ---------------------------------------------------------------------------
; util.s - Utility routines
; 2019-04-05 E. Brombaugh
; ---------------------------------------------------------------------------
;

.import		_output

.export		_nybout
.export		_hexout
.export		_strout

.segment	"CODE"

; ---------------------------------------------------------------------------
; hex nybble output routine - send low nybbles as ASCII hex

.proc _nybout: near
			clc						; adjust for ASCII numbers
			adc #$30
			cmp #$3a
			bmi no_skip
			adc #$06				; adjust for alpha
no_skip:	jmp _output				; send - let output routine return
.endproc
			
; ---------------------------------------------------------------------------
; hex byte output routine - just sends high/low nybbles as ASCII hex

.proc _hexout: near
			pha						; save for low nybble
			lsr						; get high nybble in low
			lsr
			lsr
			lsr
			jsr	_nybout				; output low nybble
			pla						; restore
			and #$0F				; get low nybble
			jmp	_nybout				; output low nybble - let it return
.endproc

; ---------------------------------------------------------------------------
; string output routine - low addr in A, high addr in Y, null terminated

.proc _strout: near
			sta $fe
			sty $ff
			ldy #0
solp:		lda ($fe),y
			beq sodone
			jsr _output
			iny
			bne solp
sodone:		rts
.endproc

