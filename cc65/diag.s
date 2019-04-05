; ---------------------------------------------------------------------------
; diag.s - diagnostic routines
; ---------------------------------------------------------------------------
;

.import		_hexout
.import		_output
.import		_acia_rx_chr
.import		_spi_txrx_block
.import		_spi_flash_read
.import		_ps2_rx_nb

.export		_diag1
.export		_diag2

.segment	"CODE"

; ---------------------------------------------------------------------------
; PS/2 test
.proc _diag1: near

dg_kchk:	jsr _ps2_rx_nb			; check for key
			cpx #1
			bne	dg_kchk				; loop if no new key
			jsr _hexout				; send hex value
			lda #$0a				; send crlf
			jsr _output
			lda #$0d
			jsr _output
			rts
.endproc

; ---------------------------------------------------------------------------
; SPI test

.proc _diag2: near
dg_kchk:	lda #$AB				; Read ID instr
			sta $0213
			lda #$00				; dummy data
			sta $0214
			lda #$00				; dummy data
			sta $0215
			lda #$00				; dummy data
			sta $0216
			lda #$00				; dummy data
			sta $0217
			lda #.lobyte($0213)		; display diag text
			ldy #.hibyte($0213)		;
			ldx #5					; 5 bytes - cmd, 3 tx dummy, 1 rx dummy
			jsr _spi_txrx_block
			lda $0217				; ID byte
			jsr _hexout
			lda #$0a				; send crlf
			jsr _output
			lda #$0d
			jsr _output
			lda #$00				; Addr 23:16
			sta $0214
			lda #$00				; Addr 15:8
			sta $0215
			lda #$00				; Addr 7:0
			sta $0216
			lda #.lobyte($0213)		; display diag text
			ldy #.hibyte($0213)		;
			ldx #$00				; 256 bytes
			jsr _spi_flash_read
			lda $0213
			jsr _hexout
			lda $0214
			jsr _hexout
			lda $0215
			jsr _hexout
			lda $0216
			jsr _hexout
			lda $0217
			jsr _hexout
			lda $0218
			jsr _hexout
			lda $0219
			jsr _hexout
			lda $021A
			jsr _hexout
			lda #$0a				; send crlf
			jsr _output
			lda #$0d
			jsr _output
			jsr _acia_rx_chr		; wait for serial rx
			rts
.endproc

