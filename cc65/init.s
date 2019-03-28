; ---------------------------------------------------------------------------
; init.s - 6502 + BASIC initializer & support code
; ---------------------------------------------------------------------------
;

.import		_acia_init
.import		_acia_tx_chr
.import		_acia_rx_chr
.import		_acia_rx_nb
.import		_video_init
.import		_video_out
.import		_spi_init
.import		_spi_txrx
.import		_ledpwm_init
.import		_cmon
.export		_input
.export		_output

.segment	"BAS_VEC"

; table of vectors used by BASIC
input_vec:	.word		$0000
output_vec:	.word		$0000
ctrl_c_vec:	.word		$0000
load_vec:	.word		$0000
save_vec:	.word		$0000

.segment	"CODE"

; ---------------------------------------------------------------------------
; Reset vector

_init:		ldx	#$28				; Initialize stack pointer to $0128
			txs
			cld						; Clear decimal mode

; ---------------------------------------------------------------------------
; Init jump tab

			ldx #$0A				; init X 
jmplp:		lda init_tab,X
			sta input_vec,X
			dex
			bpl jmplp

; ---------------------------------------------------------------------------
; Init ACIA
			jsr _acia_init
			
; ---------------------------------------------------------------------------
; Init video
			jsr _video_init

; ---------------------------------------------------------------------------
; Init spi
			jsr _spi_init

; ---------------------------------------------------------------------------
; Init led pwm
			jsr _ledpwm_init

; ---------------------------------------------------------------------------
; display boot prompt

			lda #.lobyte(bootprompt)
			ldy #.hibyte(bootprompt)
			jsr _strout
			
; ---------------------------------------------------------------------------
; Cold or Warm Start

bpdone:
			jsr _acia_rx_chr		; get char
			cmp #'C'				; C ?
			bne bp_skip_C
			jmp $BD11				; BASIC Cold Start
bp_skip_C:	cmp #'W'				; W ?
			bne bp_skip_W
			jmp $0000				; BASIC Warm Start
bp_skip_W:	cmp #'M'				; M ?
			bne bpdone
			jmp _monitor
			
; ---------------------------------------------------------------------------
; Machine-language monitor

.proc _monitor: near
			lda #.lobyte(montxt)	; display monitor text
			ldy #.hibyte(montxt)
			jsr _strout
			jsr _cmon
			jmp _init
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
; BASIC input vector 

.proc _input: near
			jsr _acia_rx_chr
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

; ---------------------------------------------------------------------------
; ctrl-c vector 

.proc _ctrl_c: near
			jsr _acia_rx_nb			; check for char
			cpx #1
			bne	ctrl_c_sk			; return if no new char
			cmp #$03				; check for ctrl-c
			bne ctrl_c_sk			; return if not ctrl-c
			jmp $A636				; ctrl-c handler
ctrl_c_sk:	rts
.endproc

; ---------------------------------------------------------------------------
; dummy for unused vectors

.proc _dummy: near
			rts
.endproc

; ---------------------------------------------------------------------------
; Non-maskable interrupt (NMI) service routine

_nmi_int:	RTI						; Return from all NMI interrupts

; ---------------------------------------------------------------------------
; Maskable interrupt (IRQ) service routine

_irq_int:	PHA						; Save accumulator contents to stack
			TXA						; Save X register contents to stack
			PHA
			TYA						; Save Y register to stack
			PHA
		   
; ---------------------------------------------------------------------------
; check for BRK instruction

			TSX						; Transfer stack pointer to X
			LDA $104,X				; Load status register contents (SP + 4)
			AND #$10				; Isolate B status bit
			BNE break				; If B = 1, BRK detected

; ---------------------------------------------------------------------------
; Restore state and exit ISR

irq_exit:	PLA						; Restore Y register contents
			TAY
			PLA						; Restore X register contents
			TAX
			PLA						; Restore accumulator contents
			RTI						; Return from all IRQ interrupts

; ---------------------------------------------------------------------------
; BRK detected, stop

break:		JMP break				; If BRK is detected, something very bad
									;   has happened, so loop here forever
									
; ---------------------------------------------------------------------------
; BASIC vector init table

init_tab:
.addr		_input					; input
.addr		_output					; output
.addr		_ctrl_c					; ctrl-c
.addr		_dummy					; load
.addr		_dummy					; save

; ---------------------------------------------------------------------------
; Boot Prompt String

bootprompt:
.byte		10, 13, "C/W/M?", 0

montxt:
.byte		10, 13, "C'MON Monitor", 10, 13
.byte		"AAAAx - examine 128 bytes @ AAAA", 10, 13
.byte		"AAAA@DD,DD,... - store DD bytes @ AAAA", 10, 13
.byte		"AAAAg - go @ AAAA", 10, 13, 0

; ---------------------------------------------------------------------------
; table of data for video driver

.segment  "VIDTAB"

.byte		$40					; $FFE0 - default starting cursor location
.byte		$1f					; $FFE1 - default width
.byte		$00					; $FFE0 - vram size: 0 for 1k, !0 for 2k


; ---------------------------------------------------------------------------
; table of vectors for BASIC

.segment  "JMPTAB"

			JMP (input_vec)			;
			JMP (output_vec)		;
			JMP (ctrl_c_vec)		;
			JMP (load_vec)			;
			JMP (save_vec)			;

; ---------------------------------------------------------------------------
; table of vectors for 6502

.segment  "VECTORS"

.addr      _nmi_int					; NMI vector
.addr      _init					; Reset vector
.addr      _irq_int					; IRQ/BRK vector
