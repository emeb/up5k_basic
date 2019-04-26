; ---------------------------------------------------------------------------
; spi.s - spi routines
; 2019-03-24  E. Brombaugh
; ---------------------------------------------------------------------------
;

; SPI IP registers
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
.export		_spi_tx_byte
.export		_spi_flash_read
.export		_spi_flash_rdreg
.export		_spi_flash_status
.export		_spi_flash_busy_wait
.export		_spi_flash_eraseblk
.export		_spi_flash_writepg

; Flash commands
.define		FLASH_WRPG	#$02		; write page
.define		FLASH_READ	#$03		; read data
.define		FLASH_RSR1	#$05		; read status reg 1
.define		FLASH_RSR2	#$35		; read status reg 2
.define		FLASH_RSR3	#$15		; read status reg 3
.define		FLASH_WSR1	#$01		; write status reg 1
.define		FLASH_WSR2	#$31		; write status reg 2
.define		FLASH_WSR3	#$11		; write status reg 3
.define		FLASH_WEN	#$06		; write enable
.define		FLASH_EB32	#$52		; erase block 32k
.define		FLASH_GBUL	#$98		; global unlock
.define		FLASH_WKUP	#$AB		; wakeup
.define		FLASH_ERST	#$66		; enable reset
.define		FLASH_RST	#$99		; reset

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
			
si_done:	
			jsr _spi_flash_init		; initialize the SPI Flash chip
			
			rts
.endproc

; ---------------------------------------------------------------------------
; wait for spi tx

.proc spi_tx_wait
			lda SPI0_BASE+SPISR		; get tx status on first pass
			and #$10				; test trdy
			beq	spi_tx_wait			; loop until ready
			rts
.endproc

; ---------------------------------------------------------------------------
; wait for spi rx

.proc spi_rx_wait
			lda SPI0_BASE+SPISR		; get rx status		
			and #$08				; test rrdy
			beq	spi_rx_wait			; loop until ready
			rts
.endproc

; ---------------------------------------------------------------------------
; spi send routine - single byte, with CS
; data in A

.proc _spi_tx_byte: near
			tax
			lda #$fe				; lower cs0
			sta SPI0_BASE+SPICSR
			jsr spi_tx_wait			; wait for tx ready
			stx SPI0_BASE+SPITXDR	; send tx
			jsr spi_rx_wait			; wait for rx ready
			lda #$ff				; raise cs0
			sta SPI0_BASE+SPICSR
			rts			
.endproc

; ---------------------------------------------------------------------------
; spi flash init - wakeup

.proc _spi_flash_init: near
; set up the flash memory
			; send wake up cmd to flash (FPGA init may power it down)
			lda FLASH_WKUP			; Wake up
			jsr _spi_tx_byte
			rts
.endproc

; ---------------------------------------------------------------------------
; send header - used for read, write and erase
; expects cmd in A, addr in f9-fb

.proc _spi_flash_hdr: near
			ldx #$00				; point to source addr
			ldy #$04				; four byte read header
hdr_lp:		pha						; temp save data
			jsr spi_tx_wait			; wait for tx ready
			pla
			sta SPI0_BASE+SPITXDR	; send tx
			lda $f9,x				; get next tx byte
			inx
			dey
			bne hdr_lp				; loop over all 4 bytes
			rts
.endproc

; ---------------------------------------------------------------------------
; spi flash read - 64kB max
; low dest addr in $fe, high dest addr in $ff
; low count in $fc, hight count in $fd
; low source addr in A, mid source addr in Y, high source addr in X

.proc _spi_flash_read: near
; save source addr
			stx $f9					; high byte
			sty $fa					; mid byte
			sta $fb					; low byte
			
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
			lda FLASH_READ			; read command
			jsr _spi_flash_hdr
			
; wait for tx ready before starting rx
			jsr spi_tx_wait			; wait for tx ready
			lda SPI0_BASE+SPIRXDR	; dummy reads to clear RX
			lda SPI0_BASE+SPIRXDR
			
; read data into dest addr
			ldy #$00				; no offset
sfr_rdm:	sty SPI0_BASE+SPITXDR	; send dummy data
			jsr spi_rx_wait			; wait for rx ready
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

; ---------------------------------------------------------------------------
; spi flash read reg - expects cmd in A

.proc _spi_flash_rdreg: near
			pha						; save cmd
			lda #$fe				; lower cs0
			sta SPI0_BASE+SPICSR
			jsr spi_tx_wait			; wait for tx ready
			pla						; restore cmd
			sta SPI0_BASE+SPITXDR
			jsr spi_rx_wait			; wait for rx ready
			lda SPI0_BASE+SPIRXDR	; dummy read to clear RX 
			lda #$00				; send dummy byte
			sta SPI0_BASE+SPITXDR
			jsr spi_rx_wait			; wait for rx ready
			lda #$ff				; raise cs0
			sta SPI0_BASE+SPICSR
			lda SPI0_BASE+SPIRXDR	; get rx
			rts			
.endproc

; ---------------------------------------------------------------------------
; spi flash get status

.proc _spi_flash_status: near
			lda FLASH_RSR1			; status 1 read cmd
			jmp _spi_flash_rdreg	; send and get data - let sub return
.endproc

; ---------------------------------------------------------------------------
; spi flash busy wait

.proc _spi_flash_busy_wait
			jsr _spi_flash_status		; get flash status byte
			and #$01					; test busy
			bne	_spi_flash_busy_wait	; loop until not busy
			rts
.endproc

; ---------------------------------------------------------------------------
; spi flash erase 32k blk - 32k sector # in A
; block addr in $f9-$fb (low/mid/hi)

.proc _spi_flash_eraseblk: near
; write enable for erase
			lda FLASH_WEN
			jsr _spi_tx_byte

; send erase command
			lda #$fe				; lower cs0
			sta SPI0_BASE+SPICSR
			lda FLASH_EB32			; send 32k erase cmd
			jsr _spi_flash_hdr
			jsr spi_rx_wait			; wait for rx ready
			lda #$ff				; raise cs0
			sta SPI0_BASE+SPICSR
			rts
.endproc

; ---------------------------------------------------------------------------
; spi flash write page
; low src addr in $fe, high src addr in $ff
; count in $fc
; low dest addr in $fb, mid dest addr in $fa, high dest addr in $f9

.proc _spi_flash_writepg: near
; write enable for write
			lda FLASH_WEN
			jsr _spi_tx_byte
			
; lower cs0
			lda #$fe
			sta SPI0_BASE+SPICSR
			
; send header w/ write cmd + dest addr
			lda FLASH_WRPG			; page write command
			jsr _spi_flash_hdr

; write data from src addr
			ldy #$00				; beginning offset
			ldx	$fc					; get count
sfr_wdm:	jsr spi_tx_wait			; wait for tx ready
			lda ($fe),y				; send tx data
			sta SPI0_BASE+SPITXDR
			iny						; inc src ptr
			dex						; dec count
			bne sfr_wdm
			
; finish
			jsr spi_rx_wait			; wait for rx ready
			lda #$ff				; raise cs0
			sta SPI0_BASE+SPICSR
			rts
.endproc

spi_init_tab:
.byte	SPICR0,	$ff		; max delay counts on all auto CS timing
.byte	SPICR1,	$84		; enable spi, disable scsni(undocumented!)
.byte	SPICR2,	$c0		; master, hold cs low while busy
.byte	SPIBR,	$02		; divide clk by 3 for spi clk
.byte	SPICSR,	$0f		; all CS outs high
.byte	0				; end of table

