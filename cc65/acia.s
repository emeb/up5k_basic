; ---------------------------------------------------------------------------
; acia.s - ACIA	interface routines
; 2019-03-20 E. Brombaugh
; ---------------------------------------------------------------------------
;

.define		ACIA_CTRL $F000			; ACIA control register location
.define		ACIA_DATA $F001			; ACIA data register location

.export		_acia_init
.export		_acia_tx_chr
.export		_acia_rx_chr
.export		_acia_rx_nb

; ---------------------------------------------------------------------------
; ACIA initializer

.proc _acia_init: near
			lda #$03				; reset ACIA
			sta ACIA_CTRL
			lda #$00				; normal operation
			sta ACIA_CTRL
			rts
.endproc

; ---------------------------------------------------------------------------
; wait for TX empty and send single character to ACIA

.proc _acia_tx_chr: near
			pha						; temp save char to send
txw:		lda	ACIA_CTRL			; wait for TX empty
			and	#$02
			beq	txw
			pla						; restore char
			sta	ACIA_DATA			; send
			rts
.endproc

; ---------------------------------------------------------------------------
; wait for RX full and get single character from ACIA

.proc _acia_rx_chr: near
rxw:		lda	ACIA_CTRL			; wait for RX full
			and	#$01
			beq	rxw
			lda	ACIA_DATA			; receive
			rts
.endproc

; ---------------------------------------------------------------------------
; non-blocking RX - returns 1 in X if char in A and 0 in X if none

.proc _acia_rx_nb: near
			ldx #0
			lda	ACIA_CTRL			; wait for RX full
			and	#$01
			beq	nb_no_chr
			ldx #1
			lda	ACIA_DATA			; receive
nb_no_chr:	rts
.endproc
