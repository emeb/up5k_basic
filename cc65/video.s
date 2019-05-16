; ---------------------------------------------------------------------------
; video.s - video interface routines
; 2019-03-20 E. Brombaugh
; ---------------------------------------------------------------------------
;

.import		BAS_VIDTXT

.export		_video_init

; ---------------------------------------------------------------------------
; video initializer

.proc _video_init: near
			lda vidtab				; initial cursor location
			sta $0200
			lda #0
			sta $0203
			sta $0205
			sta $0206				; no video delay
			ldx #0
vi_loop:	lda #$20				; space in char data region
			sta $D000,X
			sta $D100,X
			sta $D200,X
			sta $D300,X
			lda #$F5				; default indices in color region
			sta $E000,X
			sta $E100,X
			sta $E200,X
			sta $E300,X
			inx
			bne vi_loop
			rts
.endproc

; ---------------------------------------------------------------------------
; table of data for video driver

.segment  "VIDTAB"

vidtab:
.byte		$40					; $FFE0 - default starting cursor location
.byte		$1f					; $FFE1 - default width
.byte		$00					; $FFE0 - vram size: 0 for 1k, !0 for 2k


