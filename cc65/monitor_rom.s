; ---------------------------------------------------------------------------
; monitor_rom.s
; ---------------------------------------------------------------------------
;

.define		ACIA_CTRL $E000			; ACIA control register location
.define		ACIA_DATA $E001			; ACIA data register location

.export		_acia_tx_chr
.export		_acia_rx_chr

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

_init:		LDX	#$28				; Initialize stack pointer to $0128
			TXS
			CLD						; Clear decimal mode

; ---------------------------------------------------------------------------
; Init jump tab

			LDX #$0A				; init X 
jmplp:		LDA init_tab,X
			STA input_vec,X
			DEX
			BPL jmplp

; ---------------------------------------------------------------------------
; Init ACIA

			LDA #$03				; reset ACIA
			STA ACIA_CTRL
			LDA #$00				; normal operation
			STA ACIA_CTRL
			
; ---------------------------------------------------------------------------
; display boot prompt

			LDX #$00
bplp:		LDA bootprompt,X		; get char
			BEQ bpdone				; final null?
			JSR _acia_tx_chr		; send char
			INX
			BNE bplp				; back to start

; ---------------------------------------------------------------------------
; Cold or Warm Start

bpdone:
			JSR _acia_rx_chr		; get char
			CMP #$43				; C ?
			BNE bp_skip_C
			JMP $BD11				; BASIC Cold Start
bp_skip_C:	CMP #$57				; W ?
			BNE bpdone
			JMP $0000				; BASIC Warm Start
			
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
; ctrl-c vector 

.proc _ctrl_c: near
			lda	ACIA_CTRL			; check for RX full
			and	#$01
			beq	ctrl_c_sk			; return if no new char
			lda	ACIA_DATA			; receive char
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
.addr		_acia_rx_chr			; input
.addr		_acia_tx_chr			; output
.addr		_ctrl_c					; ctrl-c
.addr		_dummy					; load
.addr		_dummy					; save

; ---------------------------------------------------------------------------
; Boot Prompt String

bootprompt:
.byte		10, 13, "C/W?", 0

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
