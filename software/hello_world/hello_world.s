VIA_PORTB	= $a000
VIA_PORTA	= $a001
VIA_DDRB	= $a002
VIA_DDRA	= $a003
VIA_T1CL	= $a004
VIA_T1CH	= $a005
VIA_T1LL	= $a006
VIA_T1LH	= $a007
VIA_T2CL	= $a008
VIA_T2CH	= $a009
VIA_SR		= $a00a
VIA_ACR		= $a00b
VIA_PCR		= $a00c
VIA_IFR		= $a00d
VIA_IER		= $a00e

LCD_16x2_RS	= %00001000
LCD_16x2_RW	= %00000100
LCD_16x2_E	= %00000010

	.org $c000
reset:
	ldx #$ff		;init stack
	txs

	jsr lcd_16x2_init	;init 16x2 lcd

	ldx #0
continue_print:
	lda message, x
	beq loop
	jsr lcd_16x2_print
	inx
	jmp continue_print

loop:
	jmp loop

message: .asciiz "Hello, world!"

lcd_16x2_print:
	jsr lcd_16x2_wait
	
	pha
	lda #%11111110
	sta VIA_DDRB
	pla

	pha
	and #%11110000
	ora #LCD_16x2_RS
	sta VIA_PORTB
	ora #(LCD_16x2_RS | LCD_16x2_E)
	sta VIA_PORTB
	and #LCD_16x2_RS
	sta VIA_PORTB

	pla
	asl a
	asl a
	asl a
	asl a
	and #%11110000
	ora #LCD_16x2_RS
	sta VIA_PORTB
	ora #(LCD_16x2_RS | LCD_16x2_E)
	sta VIA_PORTB
	and #LCD_16x2_RS	
	sta VIA_PORTB

	rts	

lcd_16x2_init:
	pha
	
	lda #%00101000		;4 bits mode, 2 line, 5x8 dots
	jsr lcd_16x2_instruction
	
	lda #%00000001		;clear display
	jsr lcd_16x2_instruction
	
	lda #%00000010		;return home
	jsr lcd_16x2_instruction
	
	lda #%00001111		;display on, cursor on, blink on
	jsr lcd_16x2_instruction
	
	lda #%00010100		;cursor shift, shift to right
	jsr lcd_16x2_instruction

	lda #%10000000		;set DDRAM address to 0x0000
	jsr lcd_16x2_instruction
	
	pla	

	rts

lcd_16x2_instruction:
	jsr lcd_16x2_wait
	
	pha	
	lda #%11111110		;setup PORTB is all output
	sta VIA_DDRB
	pla

	pha			;write highest 4 bits first
	and #%11110000
	sta VIA_PORTB
	ora #LCD_16x2_E
	sta VIA_PORTB
	and #%11110000
	sta VIA_PORTB
	
	pla			;write lowest 4 bits, must be shift-left first
	asl a
	asl a
	asl a
	asl a
	and #%11110000
	sta VIA_PORTB
	ora #LCD_16x2_E
	sta VIA_PORTB
	and #%11110000
	sta VIA_PORTB

	rts

lcd_16x2_wait:
	pha
	lda #%00001110		;setup the PORTB to read the busy flag
	sta VIA_DDRB
	lda #LCD_16x2_RW
	sta VIA_PORTB
	lda #(LCD_16x2_RW | LCD_16x2_E)
	sta VIA_PORTB
lcd_16x2_wait_bf:
	lda VIA_PORTB
	and #%10000000
	bne lcd_16x2_wait_bf
	lda #LCD_16x2_RW
	sta VIA_PORTB

	lda #LCD_16x2_RW
	sta VIA_PORTB
	lda #(LCD_16x2_RW | LCD_16x2_E)
	sta VIA_PORTB
	lda #LCD_16x2_RW
	sta VIA_PORTB

	pla

	rts

	.org $fffc
	.word reset
