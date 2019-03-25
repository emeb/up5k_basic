; ---------------------------------------------------------------------------
; ledpwm.s - led pwm routines
; ---------------------------------------------------------------------------
;

.define		LEDPWM_BASE	$F300		; Offset of LED PWM IP core
.define		LEDDCR0		$08			; Control reg 0
.define		LEDDBR		$09			; Clock Prescale reg 
.define		LEDDONR		$0A			; Blink On time
.define		LEDDOFR		$0B			; Blink Off time
.define		LEDDBCRR	$05			; Breathe On reg
.define		LEDDBCFR	$06			; Breathe Off reg
.define		LEDDPWRR	$01			; Red PWM reg
.define		LEDDPWRG	$02			; Green PWM reg
.define		LEDDPWRB	$03			; Blue PWM reg
.define		MYCR		$0F			; Custom control reg

.export		_ledpwm_init

; ---------------------------------------------------------------------------
; led pwm initializer

.proc _ledpwm_init: near
			ldy #0					; initialize index
li_lp:		ldx led_init_tab,y		; get reg
			beq	li_done
			iny
			lda led_init_tab,y		; get data
			sta LEDPWM_BASE, x		; save to IP core
			iny
			bne	li_lp				; max 128 regs
li_done:	rts
.endproc

led_init_tab:
.byte	MYCR,		$f0		; auto, all on
.byte	LEDDCR0,	$C0		; enable, 250Hz, active high
.byte	LEDDBR,		$f9		; prescale 16MHz/64kHz-1 = 249
.byte	LEDDONR,	$20		; blink on - 8s max
.byte	LEDDOFR,	$20		; blink off - 8s max
.byte	LEDDBCRR,	$8f		; breathe on - 2s max
.byte	LEDDBCFR,	$8f		; breathe off - 2s max
.byte	LEDDPWRR,	$ff		; red pwm
.byte	LEDDPWRG,	$ff		; green pwm
.byte	LEDDPWRB,	$ff		; blue pwm
.byte	0					; end of table

