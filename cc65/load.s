; ---------------------------------------------------------------------------
; load.s - BASIC LOAD routine
; ---------------------------------------------------------------------------
;

.import		_hexout
.import		_output
.import		BAS_NXT_INTARG
.import		BAS_GET_INTARG
.importzp	BAS_INTLO
.importzp	BAS_INTHI

.export		_load

.segment	"CODE"

; ---------------------------------------------------------------------------
; LOAD vector - sets up to inject text from flash

.proc _load: near

			jsr BAS_NXT_INTARG	; fetch next arg on BASIC line
			jsr	BAS_GET_INTARG	; Convert arg to 16-bit signed integer
			lda BAS_INTHI		; send high byte as hex
			jsr _hexout
			lda BAS_INTLO		; send low byte as hex
			jsr _hexout
			lda #$0A			; send CR/LF
			jsr _output
			lda #$0D
			jsr _output
			rts
.endproc

