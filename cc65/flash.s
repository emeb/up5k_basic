; ---------------------------------------------------------------------------
; flash.s - flash memory commands
; 2019/04/17 E. Brombaugh
; ---------------------------------------------------------------------------
;

; Flash commands
.define		FLASH_WRPG	#$02		; write page
.define		FLASH_READ	#$03		; read data
.define		FLASH_RSR1	#$05		; read status reg 1
.define		FLASH_WEN	#$06		; write enable
.define		FLASH_EB32	#$52		; erase block 32k
.define		FLASH_GBUL	#$98		; global unlock
.define		FLASH_WKUP	#$AB		; wakeup
