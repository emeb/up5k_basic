; ---------------------------------------------------------------------------
; spi.s - spi routines
; ---------------------------------------------------------------------------
;

.define		SPI0_BASE	$F100		; Offset of SPI0 IP core 
.define		SPI1_BASE	$F110		; Offset of SPI1 IP core 
.define		SPICR0		$08			; Control reg 0
.define		SPICR1		$09			; Control reg 1
.define		SPICR2		$0a			; Control reg 2
.define		SPIBR		$0b			; Baud rate reg
.define		SPISR		$0c			; Status reg
.define		SPITXDR		$0d			; TX data reg (r/w)
.define		SPIRXDR		$0e			; RX data reg (ro)
.define		SPICSR		$0f			; Chip Select reg

.export		_spi_init
.export		_spi_txrx_block
.export		_spi_flash_read

.segment	"CODE"

; ---------------------------------------------------------------------------
; spi initializer

.proc _spi_init: near
			ldy #0					; initialize index
si_lp:		ldx spi_init_tab,y		; get reg
			beq	si_done
			iny
			lda spi_init_tab,y		; get data
			sta SPI0_BASE, x		; save to IP core
			iny
			bne	si_lp				; max 128 regs
si_done:	rts
.endproc

; ---------------------------------------------------------------------------
; spi send/receive routine - block, with CS
; low addr in A, high addr in Y, count in X

.proc _spi_txrx_block: near
			sta $fe
			sty $ff
			ldy #0
			lda #$fe				; lower cs0
			sta SPI0_BASE+SPICSR
ssb_twt:	lda SPI0_BASE+SPISR		; get tx status on first pass
			and #$10				; test trdy
			beq	ssb_twt				; loop until ready
ssb_lp:		lda ($fe),y				; get tx byte
			sta SPI0_BASE+SPITXDR	; send tx
ssb_rwt:	lda SPI0_BASE+SPISR		; get rx status		
			and #$08				; test rrdy
			beq	ssb_rwt				; loop until ready
			lda SPI0_BASE+SPIRXDR	; get rx
			sta ($fe),y				; save rx byte			
			iny
			dex
			bne ssb_lp				; back to tx - assume ready
			lda #$ff				; raise cs0
			sta SPI0_BASE+SPICSR
			rts
.endproc

.if 0
; ---------------------------------------------------------------------------
; spi flash read - 256 byte max
; low addr in A, high addr in Y, count in X
; assumes 3-bit address at buffer locations 1,2,3 - msByte 1st

.proc _spi_flash_read: near
			sta $fe					; set up buffer pointer
			sty $ff
			txa						; save count
			pha
			
; send header
			ldx #4					; header count
			ldy #0
			lda #$03				; read cmd
			sta ($fe),y
			lda #$fe				; lower cs0
			sta SPI0_BASE+SPICSR
sfr_twt:	lda SPI0_BASE+SPISR		; get tx status
			and #$10				; test trdy
			beq	sfr_twt				; loop until tx ready
			lda ($fe),y				; get tx byte
			sta SPI0_BASE+SPITXDR	; send tx
			iny
			dex
			bne sfr_twt				; back to tx wait
			
; wait for tx ready before starting rx
sfr_twt2:	lda SPI0_BASE+SPISR
			and #$10
			beq	sfr_twt2
			lda SPI0_BASE+SPIRXDR	; dummy reads to clear RX
			lda SPI0_BASE+SPIRXDR
			
; receive data
			pla						; restore count
			tax
			ldy #0
sfr_rdm:	sta SPI0_BASE+SPITXDR	; send dummy data
sfr_rwt:	lda SPI0_BASE+SPISR		; get rx status		
			and #$08				; test rrdy
			beq	sfr_rwt				; loop until ready
			lda SPI0_BASE+SPIRXDR	; get rx
			sta ($fe),y				; save rx byte			
			iny
			dex
			bne sfr_rdm				; back to dummy tx - assume ready
			
; finish
			lda #$ff				; raise cs0
			sta SPI0_BASE+SPICSR
			rts
.endproc
.else
; ---------------------------------------------------------------------------
; spi flash read - 64kB max
; low dest addr in $fe, high dest addr in $ff
; low count in $fc, hight count in $fd
; low source addr in $f9, mid source addr in $fa, high source addr i $fb

.proc _spi_flash_read: near
; invert count to avoid slow 16-bit decrement
			clc
			lda $fc
			eor #$ff
			adc #$01
			sta $fc
			lda $fd
			eor #$ff
			adc #$00
			sta $fd

; lower cs0
			lda #$fe
			sta SPI0_BASE+SPICSR
			
; send header w/ read cmd + source addr
			ldx #$00				; point to source addr
			ldy #$04				; four byte read header
			lda #$03				; read command
sfr_tlp:	pha						; temp save data
sfr_twt:	lda SPI0_BASE+SPISR		; get tx status
			and #$10				; test trdy
			beq	sfr_twt				; loop until tx ready
			pla
			sta SPI0_BASE+SPITXDR	; send tx
			lda $f8,x				; get next tx byte
			inx
			dey
			bne sfr_tlp				; back to tx loop
			
; wait for tx ready before starting rx
sfr_twt2:	lda SPI0_BASE+SPISR
			and #$10
			beq	sfr_twt2
			lda SPI0_BASE+SPIRXDR	; dummy reads to clear RX
			lda SPI0_BASE+SPIRXDR
			
; read data into dest addr
			ldy #$00				; no offset
sfr_rdm:	sty SPI0_BASE+SPITXDR	; send dummy data
sfr_rwt:	lda SPI0_BASE+SPISR		; get rx status		
			and #$08				; test rrdy
			beq	sfr_rwt				; loop until ready
			lda SPI0_BASE+SPIRXDR	; get rx
			sta ($fe),y				; save rx byte
			inc $fe					; inc dest ptr
			bne sfr_skp0
			inc $ff
sfr_skp0:	inc $fc					; inc count
			bne sfr_rdm
			inc $fd
			bne sfr_rdm				; back to dummy tx - assume ready
			
; finish
			lda #$ff				; raise cs0
			sta SPI0_BASE+SPICSR
			rts
.endproc
.endif

spi_init_tab:
.byte	SPICR0,	$ff		; max delay counts on all auto CS timing
.byte	SPICR1,	$84		; enable spi, disable scsni(undocumented!)
.byte	SPICR2,	$c0		; master, hold cs low while busy
.byte	SPIBR,	$02		; divide clk by 3 for spi clk
.byte	SPICSR,	$0f		; all CS outs high
.byte	0				; end of table

