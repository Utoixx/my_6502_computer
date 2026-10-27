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

ticks		= $00 		;4 byte for ticket

toggle_time	= $04
counter		= $08	

	.org $c000
reset:
	ldx #$ff		;init stack
	txs

	lda #$0
	sta toggle_time		;init time
	sta counter		;init counter

	jsr lcd_16x2_init	;init 16x2 lcd
	ldx #0
continue_print:
	lda message, x
	beq pre_loop
	jsr lcd_16x2_print
	inx
	jmp continue_print
pre_loop:
	jsr setup_timer
	cli
loop:
	sec
	lda ticks
	sbc toggle_time
	cmp #100			;have 1000ms elapsed
	bcc loop
	sei
	inc counter
	lda ticks
	sta toggle_time
	cli
	jsr my_clock
	jmp loop

my_clock:
	lda #%11000000		;set DDRAM address to 0x40
	jsr lcd_16x2_instruction
	
	sei
	clc
	lda #"0"
	adc counter
	cli
	jsr lcd_16x2_print
	rts	

irq:
	sei
	pha
	txa
	pha
	tya
	pha
	bit VIA_T1CL		;reset the timer1 interupt flag
	inc ticks
	bne irq_end
	inc ticks + 1
	bne irq_end
	inc ticks + 2
	bne irq_end
	inc ticks + 3
irq_end:
	pla
	tay
	pla
	tax
	pla
	cli
	rti

nmi:
	rti

message: .asciiz "Hello, world!"

setup_timer:
	pha
	lda #%01000000	;set timer1 at continuous interrupts mode
	sta VIA_ACR
	lda #$0e
	sta VIA_T1CL	;interupt every 10ms
	lda #$27
	sta VIA_T1CH
	lda #%11000000  ;enable timer 1 interupt
	sta VIA_IER
	pla
	
	rts

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
	lda #%00111000		;make the 16x2 lcd is stable
	jsr lcd_16x2_instruction_8bit
	
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
lcd_16x2_instruction_8bit:
	jsr lcd_16x2_wait_8bit
	
	pha	
	lda #%11111110		;setup PORTB is all output
	sta VIA_DDRB
	pla
	
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

lcd_16x2_wait_bf:
	lda #LCD_16x2_RW
	sta VIA_PORTB
	lda #(LCD_16x2_RW | LCD_16x2_E)
	sta VIA_PORTB
	lda VIA_PORTB
	pha
	lda #LCD_16x2_RW
	sta VIA_PORTB

	lda #LCD_16x2_RW
	sta VIA_PORTB
	lda #(LCD_16x2_RW | LCD_16x2_E)
	sta VIA_PORTB
	lda #LCD_16x2_RW
	sta VIA_PORTB
	pla
	and #%10000000
	bne lcd_16x2_wait_bf
	pla

	rts

lcd_16x2_wait_8bit:
	pha
	lda #%00001110		;setup the PORTB to read the busy flag
	sta VIA_DDRB

lcd_16x2_wait_bf_8bit:
	lda #LCD_16x2_RW
	sta VIA_PORTB
	lda #(LCD_16x2_RW | LCD_16x2_E)
	sta VIA_PORTB
	lda VIA_PORTB
	pha
	lda #LCD_16x2_RW
	sta VIA_PORTB

	pla
	and #%10000000
	bne lcd_16x2_wait_bf_8bit
	pla

	rts


	.org $fffa
	.word nmi
	.word reset
	.word irq
