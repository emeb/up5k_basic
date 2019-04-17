; ---------------------------------------------------------------------------
; ps2.s - ps2 interface routines
; 2019/04/01 E. Brombaugh
; ---------------------------------------------------------------------------
;

.define		PS2_CTRL $F400			; PS2 control register location
.define		PS2_DATA $F401			; PS2 data register location

.export		_ps2_init
.export		_ps2_rx_nb

.segment	"KEY_DAT"

; storage for key processing
input_vec:	.byte		$00

.segment	"CODE"
; ---------------------------------------------------------------------------
; PS2 initializer

.proc _ps2_init: near
			lda #$01				; reset PS2
			sta PS2_CTRL
			lda #$00				; normal operation
			sta PS2_CTRL
			rts
.endproc

; ---------------------------------------------------------------------------
; non-blocking raw RX - returns 1 in X if code in A and 0 in X if none

.proc _ps2_rx_nb: near
			ldx #0
			lda	PS2_CTRL			; wait for RX full
			and	#$01
			beq	nb_no_chr
			ldx #1
			lda	PS2_DATA			; receive
nb_no_chr:	rts
.endproc
