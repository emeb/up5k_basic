; ---------------------------------------------------------------------------
; basic.s - BASIC interface routines
; ---------------------------------------------------------------------------
;

.export		BAS_COLDSTART
.export		BAS_WARMSTART
.export		BAS_NXT_INTARG
.export		BAS_GET_INTARG
.export		BAS_HNDL_CTRLC

.exportzp	BAS_INTLO
.exportzp	BAS_INTHI

; routines
BAS_WARMSTART	= $A274		; Warm start BASIC
BAS_COLDSTART	= $BD11		; Cold start BASIC
BAS_NXT_INTARG	= $AAAD		; fetch next integer argument on BASIC line
BAS_GET_INTARG	= $AE05		; get integer argument into BAS_INTLO/BAS_INTHI
BAS_HNDL_CTRLC	= $A636		; handle Control-C

; variables
BAS_INTLO		= $AF		; low byte of converted integer
BAS_INTHI		= $AE		; high byte of converted integer