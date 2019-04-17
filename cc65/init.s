; ---------------------------------------------------------------------------
; init.s - 6502 initializer for up5k_basic project
; 2019-03-20 E. Brombaugh
; ---------------------------------------------------------------------------
;

.import		_acia_init
.import		_video_init
.import		_spi_init
.import		_ledpwm_init
.import		_ps2_init
.import		_basic_init
.import		_cmon
.import		_input
.import		_strout
.import		BAS_COLDSTART
.import		BAS_WARMSTART

; ---------------------------------------------------------------------------
; Reset vector

_init:		ldx	#$28				; Initialize stack pointer to $0128
			txs
			cld						; Clear decimal mode

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
; Init ps2 input
			jsr _ps2_init

; ---------------------------------------------------------------------------
; Init BASIC
			jsr _basic_init

; ---------------------------------------------------------------------------
; display boot prompt

			lda #.lobyte(bootprompt)
			ldy #.hibyte(bootprompt)
			jsr _strout
			
; ---------------------------------------------------------------------------
; Cold or Warm Start

bpdone:
			jsr _input				; get char
			cmp #'D'				; D ?
			bne bp_skip_D
			jmp _diags				; Diagnostic
bp_skip_D:	cmp #'C'				; C ?
			bne bp_skip_C
			jmp BAS_COLDSTART		; BASIC Cold Start
bp_skip_C:	cmp #'W'				; W ?
			bne bp_skip_W
			jmp BAS_WARMSTART		; BASIC Warm Start
bp_skip_W:	cmp #'M'				; M ?
			bne bpdone
			jmp _monitor			; C'Mon monitor
			
; ---------------------------------------------------------------------------
; Machine-language monitor

.proc _monitor: near
			; help msg
			lda #.lobyte(montxt)	; display monitor text
			ldy #.hibyte(montxt)
			jsr _strout
			
			; run the monitor
			jsr _cmon
			jmp _init
.endproc

; ---------------------------------------------------------------------------
; Diagnostics - currently unused

.proc _diags: near
eloop:		jmp eloop				; infinite loop
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
; Message Strings

bootprompt:
.byte		10, 13, "D/C/W/M?", 0

montxt:
.byte		10, 13, "C'MON Monitor", 10, 13
.byte		"AAAAx - examine 128 bytes @ AAAA", 10, 13
.byte		"AAAA@DD,DD,... - store DD bytes @ AAAA", 10, 13
.byte		"AAAAg - go @ AAAA", 10, 13, 0

; ---------------------------------------------------------------------------
; table of vectors for 6502

.segment  "VECTORS"

.addr      _nmi_int					; NMI vector
.addr      _init					; Reset vector
.addr      _irq_int					; IRQ/BRK vector
