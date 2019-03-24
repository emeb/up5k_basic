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
.export		_spi_txrx

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
; spi send/receive routine

.proc _spi_txrx: near
			pha						; temp save data
			lda #$fe				; lower cs0
			sta SPI0_BASE+SPICSR
ss_twt:		lda SPI0_BASE+SPISR		; get status
			and #$10				; test trdy
			beq	ss_twt				; loop until ready
			pla						; restore data
			sta SPI0_BASE+SPITXDR	; send tx
ss_rwt:		lda SPI0_BASE+SPISR		; get status		
			and #$08				; test rrdy
			beq	ss_rwt				; loop until ready
			lda #$ff				; raise cs0
			sta SPI0_BASE+SPICSR
			lda SPI0_BASE+SPIRXDR	; get rx
			rts
.endproc

spi_init_tab:
.byte	SPICR0,	$ff		; max delay counts on all auto CS timing
.byte	SPICR1,	$80		; enable spi
.byte	SPICR2,	$c0		; master, hold cs low while busy
.byte	SPIBR,	$03		; divide clk by 4 for spi clk
.byte	SPICSR,	$0f		; all CS outs high
.byte	0				; end of table

