; ---------------------------------------------------------------------------
; ps2.s - ps2 interface routines
; 2019/04/01 E. Brombaugh
; ---------------------------------------------------------------------------
;

.define		PS2_CTRL $F400			; PS2 control register location
.define		PS2_DATA $F401			; PS2 data register location
.define		PS2_RSTA $F402			; PS2 raw status register location
.define		PS2_RDAT $F403			; PS2 raw data register location

.export		_ps2_init
.export		_ps2_rx_nb

.segment	"KEY_DAT"

; storage for key processing @ $0213-$0216
cl_state:	.byte		$00
key_temp:	.byte		$00
x_temp:		.byte		$00

.segment	"CODE"
; ---------------------------------------------------------------------------
; PS2 initializer

.proc _ps2_init: near
			lda #$01				; reset PS2
			sta PS2_CTRL
			lda #$00				; normal operation
			sta PS2_CTRL
			sta cl_state			; init caps lock state
			rts
.endproc

; ---------------------------------------------------------------------------
; non-blocking raw RX - returns 1 in X if code in A and 0 in X if none

.proc _ps2_rx_nb: near
			ldx #0
			lda	PS2_CTRL			; check for RX ready
			and	#$01
			beq	nb_no_chr
			ldx #1
			lda	PS2_DATA			; receive ascii
nb_no_chr:	sta key_temp
			stx x_temp
			jsr _ps2_caps_led		; handle capslock
			lda key_temp
			ldx x_temp
			rts
.endproc

; ---------------------------------------------------------------------------
; handle caps lock LED status - enter w/ no RX 

.proc _ps2_caps_led: near
			lda	PS2_CTRL			; check if capslock changed
			eor cl_state
			and #$10
			beq no_chg				; if no change then check for new key
			lda PS2_RDAT			; clear raw ready
			lda PS2_CTRL
			sta cl_state			; update shadow copy
			ldx #$00				; code to send for caps lock off
			and #$10
			beq tx_w1
			ldx #$04				; code to send for caps lock on
tx_w1:		lda PS2_CTRL			; wait for TX ready
			and #$20				; tx_rdy
			beq tx_w1
			lda #$ED				; LED command
			sta PS2_DATA			; send
tx_w2:		lda PS2_CTRL			; wait for TX ready
			and #$20				; tx_rdy
			beq tx_w2
rx_w1:		lda PS2_RSTA			; wait for raw ready
			and #$01				; rx_rdy
			beq rx_w1
			lda PS2_RDAT			; get ACK - don't bother checking
			stx	PS2_DATA			; send capslock status
tx_w3:		lda PS2_CTRL			; wait for TX ready
			and #$20				; tx_rdy
			beq tx_w3
no_chg:		rts
.endproc
