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

LCD_16x2_RS		= %00001000
LCD_16x2_RW		= %00000100
LCD_16x2_E		= %00000010

KBD_FLAG_RELEASE	= %00000001
KBD_FLAG_SHIFT		= %00000010 

;critial system variable
ticks		= $0000 	;4 bytes for ticket
toggle_time	= $0004		;4 bytes
timer		= $0008		;4 bytes
kbd_r_ptr	= $000a		;1 byte
kbd_w_ptr	= $000b		;1 byte
kbd_flags	= $000c		;1 byte
value 		= $0200		;2 bytes
mod10		= $0202		;2 bytes
buffer		= $0204		;6 bytes

number		= $020a

kbd_buffer	= $0300		;255 bytes for keyboard buffer

	.org $c000
reset:
	ldx #$ff		;init stack
	txs

	lda #0
	sta ticks		;init timer
	sta ticks + 1
	sta ticks + 2
	sta ticks + 3
	sta toggle_time
	sta timer

	sta value		;init variable for binary 2 decimal func
	sta value + 1
	sta mod10
	sta mod10 + 1
	
	sta number
	sta number + 1

	sta kbd_r_ptr
	sta kbd_w_ptr
	sta kbd_flags

	jsr setup_via
	cli
		
	jsr lcd_16x2_init	;init 16x2 lcd

.loop:		
	sei
	lda kbd_r_ptr
	cmp kbd_w_ptr
	cli
	beq .loop

	;ignore the character is received right after the release key
	lda kbd_flags
	and #KBD_FLAG_RELEASE
	beq .print_key
	
	;remove the release flag
	lda kbd_flags
	and #%11111110
	sta kbd_flags

	lda kbd_r_ptr
	tax
	lda kbd_buffer, x
	cmp #$12
	beq .release_shift
	cmp #$59
	beq .release_shift
	jmp .next_key
.release_shift:
	lda kbd_flags
	and #%11111101
	sta kbd_flags 
	jmp .next_key
	
.print_key:	
	ldx kbd_r_ptr
	lda kbd_buffer, x
	cmp #$f0
	beq .key_release
	cmp #$12
	beq .shift_down
	cmp #$59
	beq .shift_down
	cmp #$76
	beq .esc_down
	cmp #$5a
	beq .enter_down

	lda kbd_flags
	and #%00000010
	bne .capital_char
	ldx kbd_r_ptr
	lda kbd_buffer, x
	tax
	lda keymap, x	
	jsr lcd_16x2_print
	jmp .next_key
.capital_char
	ldx kbd_r_ptr
	lda kbd_buffer, x
	tax
	lda keymap_shift, x	
	jsr lcd_16x2_print
	jmp .next_key

.shift_down:
	lda kbd_flags
	ora #KBD_FLAG_SHIFT
	sta kbd_flags	
	jmp .next_key
.esc_down:
	lda #%00000001		;clear display
	jsr lcd_16x2_instruction	
	
	lda #%10000000		;set DDRAM address to 0x0000
	jsr lcd_16x2_instruction	
	jmp .next_key
.enter_down:
	lda #%11000000
	jsr lcd_16x2_instruction
	jmp .next_key
.key_release:
	lda kbd_flags
	ora #KBD_FLAG_RELEASE
	sta kbd_flags

.next_key:
	inc kbd_r_ptr
	jmp .loop

irq:
	pha
	txa
	pha
	tya
	pha

.read_t1
	lda VIA_IFR
	and #%01000000
	beq .read_ca1
	bit VIA_T1CL
	inc ticks		;increment the ticks
	bne .read_ca1
	inc ticks + 1
	bne .read_ca1
	inc ticks + 2
	bne .read_ca1
	inc ticks + 3

.read_ca1
	lda VIA_IFR
	and #%00000010
	beq .irq_end
	lda VIA_PORTA
	ldx kbd_w_ptr
	sta kbd_buffer, x
	inc kbd_w_ptr
.irq_end:
	pla
	tay
	pla
	tax
	pla
	rti

nmi:
	rti

message: 	.asciiz		"Hello, world!"

keymap:
    .byte "??????????????`?"     ; 00-0F
    .byte "?????q1???zsaw2?"     ; 10-1F
    .byte "?cxde43?? vftr5?"     ; 20-2F
    .byte "?nbhgy6???mju78?"     ; 30-3F
    .byte "?,kio09??./l;p-?"     ; 40-4F
    .byte "??'[-=?????]?\??"     ; 50-5F
    .byte "?????????1?47???"   	 ; 60-6F
    .byte "0.2568???+3-*9??"     ; 70-7F
    .byte "????????????????"     ; 80-8F
    .byte "????????????????"     ; 90-9F
    .byte "????????????????"     ; A0-AF
    .byte "????????????????"     ; B0-BF
    .byte "????????????????"     ; C0-CF
    .byte "????????????????"     ; D0-DF
    .byte "????????????????"     ; E0-EF
    .byte "????????????????"     ; F0-FF

keymap_shift:
    .byte "??????????????~?"   	 ; 00-0F
    .byte "?????Q!???ZSAW@?"     ; 10-1F
    .byte "?CXDE#$?? VFTR%?"     ; 20-2F
    .byte "?NBHGY^???MJU&*?"     ; 30-3F
    .byte "?<KIO)(??>?L:P_?"     ; 40-4F
    .byte '??\"{+?????}|???'     ; 50-5F
    .byte "?????????1?47???"     ; 60-6F
    .byte "0.2568???+3-*9??"     ; 70-7F
    .byte "????????????????"     ; 80-8F
    .byte "????????????????"     ; 90-9F
    .byte "????????????????"     ; A0-AF
    .byte "????????????????"     ; B0-BF
    .byte "????????????????"     ; C0-CF
    .byte "????????????????"     ; D0-DF
    .byte "????????????????"     ; E0-EF
    .byte "????????????????"     ; F0-FF

lcd_16x2_print_decimal:
	pha
	txa
	pha
	tya
	pha

	lda #0
	sta buffer
	sta buffer + 1
	sta buffer + 2


	;copy the value to be convert to decimal in text
	lda number
	sta value
	lda number + 1
	sta value + 1
.div:
	;initialize the remainder to zero
	lda #0
	sta mod10
	sta mod10 + 1
	
	clc
	ldx #16
.divloop:
	;rotale the quotient and remainder
	rol value
	rol value + 1
	rol mod10
	rol mod10 + 1

	sec
	lda mod10
	sbc #10
	tay		;save low bytes in y
	lda mod10 + 1
	sbc #0
	bcc .ignore	;branch if dividend <  divisor
	sty mod10
	sta mod10 + 1	
.ignore:
	dex
	bne .divloop
	rol value
	rol value + 1

	lda mod10
	clc
	adc #"0"
	jsr push_char
	
	lda value
	ora value + 1
	bne .div
	
	ldx #0
.print:
	lda buffer, x
	beq .end_convert
	jsr lcd_16x2_print  
	inx
	jmp .print
.end_convert:
	pla
	tay
	pla
	tax
	pla
	rts

push_char:
	pha
	ldy #0

.char_loop:
	lda buffer, y
	tax
	pla
	sta buffer, y
	iny
	txa
	pha
	bne .char_loop

	pla
	sta buffer, y

	rts

sleep:
	sta timer
	sei
	lda ticks
	sta toggle_time
	cli
.wait:
	sei
	sec
	lda ticks
	sbc toggle_time
	cli
	cmp timer
	bcc .wait
	rts


setup_via:
	pha
	lda #%01000000	;set timer1 at continuous interrupts mode
	sta VIA_ACR
	lda #$0e
	sta VIA_T1CL	;interupt every 10ms
	lda #$27
	sta VIA_T1CH
	
	;Setup interupt for PS2
	lda #%00000001	
	sta VIA_PCR
	
	;Setup portA input for PS2 keycode
	lda #%00000000
	sta VIA_DDRA
	
	lda #%11000010  ;enable timer 1 interupt, CA1 for PS2 keyboard
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
	and #%11110000
	ora #LCD_16x2_RS	
	sta VIA_PORTB
	rts	

lcd_16x2_init:
	lda #%11111110		;setup PORTB is all output
	sta VIA_DDRB

	lda #2			;wait for more than 15ms (20ms)
	jsr sleep
		
	lda #%00110000		;function set (interface is 8 bit long.)
	sta VIA_PORTB
	ora #LCD_16x2_E
	sta VIA_PORTB
	and #%11110000
	sta VIA_PORTB

	lda #1
	jsr sleep		;wait for more 4.1ms (10ms)

	lda #%00110000		;function set (interface is 8 bit long.)
	sta VIA_PORTB
	ora #LCD_16x2_E
	sta VIA_PORTB
	and #%11110000
	sta VIA_PORTB

	lda #1
	jsr sleep		;wait for more 100us (10ms)
	
	lda #%00110000		;function set (interface is 8 bit long.)
	sta VIA_PORTB
	ora #LCD_16x2_E
	sta VIA_PORTB
	and #%11110000
	sta VIA_PORTB
	
	lda #1
	jsr sleep		;wait for 10ms
	
	lda #%00100000		;Funtion set (Set interface to be 4 bit long) 
	sta VIA_PORTB
	ora #LCD_16x2_E
	sta VIA_PORTB
	and #%11110000
	sta VIA_PORTB

	lda #1
	jsr sleep		;wait for more 100us (10ms)
	
	lda #%00100000	
	sta VIA_PORTB
	ora #LCD_16x2_E
	sta VIA_PORTB
	and #%11110000
	sta VIA_PORTB

	lda #%10000000		
	sta VIA_PORTB
	ora #LCD_16x2_E
	sta VIA_PORTB
	and #%11110000
	sta VIA_PORTB

	lda #1
	jsr sleep		;wait for more 100us (10ms)
	
	lda #%00000000	
	sta VIA_PORTB
	ora #LCD_16x2_E
	sta VIA_PORTB
	and #%11110000
	sta VIA_PORTB

	lda #%10000000		
	sta VIA_PORTB
	ora #LCD_16x2_E
	sta VIA_PORTB
	and #%11110000
	sta VIA_PORTB

	lda #1
	jsr sleep		;wait for more 100us (10ms)
	
	lda #%00000000	
	sta VIA_PORTB
	ora #LCD_16x2_E
	sta VIA_PORTB
	and #%11110000
	sta VIA_PORTB

	lda #%00010000		
	sta VIA_PORTB
	ora #LCD_16x2_E
	sta VIA_PORTB
	and #%11110000
	sta VIA_PORTB
	
	lda #1
	jsr sleep		;wait for more 100us (10ms)
	
	lda #%00000000	
	sta VIA_PORTB
	ora #LCD_16x2_E
	sta VIA_PORTB
	and #%11110000
	sta VIA_PORTB

	lda #%01100000		
	sta VIA_PORTB
	ora #LCD_16x2_E
	sta VIA_PORTB
	and #%11110000
	sta VIA_PORTB

	lda #1
	jsr sleep

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

lcd_16x2_wait:
	pha
	lda #%00001110		;setup the PORTB to read the busy flag
	sta VIA_DDRB

.wait_bf:
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
	bne .wait_bf
	pla

	rts

	.org $fffa
	.word nmi
	.word reset
	.word irq
