; ---------------------------------------------------------------------------
; video.s - video interface routines
; ---------------------------------------------------------------------------
;

.export		_video_init
.export		_video_out

; ---------------------------------------------------------------------------
; video initializer

.proc _video_init: near
			lda $FFE0				; initial cursor location
			sta $0200
			lda #0
			sta $0203
			sta $0205
			sta $0206				; no video delay
			lda #$20				; space
			ldx #0
vi_loop:	sta $D000,X
			sta $D100,X
			sta $D200,X
			sta $D300,X
			inx
			bne vi_loop
			rts
.endproc

; ---------------------------------------------------------------------------
; video character output routine

.proc _video_out: near
			jsr $BF2D				; Video output routine is in BASIC ROM
			rts
.endproc

