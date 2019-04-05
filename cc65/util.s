; ---------------------------------------------------------------------------
; util.s - Utility routines
; ---------------------------------------------------------------------------
;

.import		_acia_tx_chr
.import		_acia_rx_chr
.import		_video_out
.import		_ps2_rx_nb
.import		_acia_rx_nb

.export		_nybout
.export		_hexout
.export		_strout
.export		_chrin
.export		_input
.export		_output

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

; ---------------------------------------------------------------------------
; combined serial & ps2 inputs

.proc _chrin: near
			jsr _acia_rx_nb			; check for serial input
			cpx #1
			beq	chrdone				; return with new char
			jsr _ps2_rx_nb			; check for ps2 input
			cpx #1
chrdone:	rts
.endproc

; ---------------------------------------------------------------------------
; BASIC input vector 

.proc _input: near
			stx $0214				; save X
in_lp:		jsr _chrin				; get character
			bne	in_lp				; if none keep waiting
			ldx $0214				; restore X
			rts
.endproc

; ---------------------------------------------------------------------------
; BASIC output vector 

.proc _output: near
			pha
			jsr _video_out
			pla
			jsr _acia_tx_chr
			rts
.endproc

