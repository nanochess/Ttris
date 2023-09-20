        ;
        ; TTris for TRS-80 Model 1
        ;
        ; by Oscar Toledo G.
        ; https://nanochess.org/
        ;
        ; Creation date: Aug/30/2023.
        ; Revision date: Aug/31/2023. First working version. Added speed up,
        ;                             title screen, game over, and scoring.
        ; Revision date: Sep/01/2023. Relocated to $5200 and changed control
        ;                             scheme per George Phillips suggestion.
        ; Revision date: Sep/03/2023. Avoid cleaning screen with $00 (now
        ;                             uses $20), and now has lowercase for
        ;                             text (per George Phillips suggestion).
        ; Revision date: Sep/04/2023, Corrected Game over and Press space for
        ;                             game over display.
        ;

	; Assemble with tniASM v0.44

        fname "ttris.bin"

        org $5200

CONTROL_SCHEME: EQU 1           ; 0 for WASD, 1 for arrows.

BOARD_WIDTH:    EQU 10		; Board width.
BOARD_HEIGHT:   EQU 20		; Board height.
BOARD_TOP:      EQU 6		; Board top coordinate.
BOARD_LEFT:     EQU 26		; Board left coordinate.
BOARD_RIGHT:    EQU BOARD_LEFT+BOARD_WIDTH-1	; Board right coordinate.

	;
	; Start of the game.
	; 
start:
        ld hl,title_screen	; Pointer to title screen data.
        call build_screen	; Display it.

restart_game:
        ld a,($3840)		; Read keyboard.
        and $80         	; Wait for space key.
        jr z,$-5

        ld hl,game_screen	; Pointer to game screen data.
        call build_screen	; Display it.

        ld hl,0		
        ld (total_lines),hl	; Reset total lines completed.
        ld (score),hl		; Reset score.
        ld (score+2),hl

        ;
        ; Build the borders.
        ;
        ld h,BOARD_TOP
        ld b,20
.1:     ld l,BOARD_LEFT-1
        call set_pixel		; Draw left border.
        ld l,BOARD_RIGHT+1
        call set_pixel		; Draw right border.
        inc h
        djnz .1
        ld b,BOARD_WIDTH+2
.2:     call set_pixel		; Draw bottom border.
        dec l
        djnz .2

        call random_shape	; Generate the next shape.
        ld hl,(current_shape)
        ld (next_shape),hl	; Save as next shape to use.
        ld a,(rotation_mask)
        ld (next_rotation_mask),a

        ;
        ; Check if a line is built.
        ;
check_for_lines:
        ld a,$10		; BCD score for the next completed line.
        ld (line_score),a
        ld ix,lines		; Pointer to status of each line.
        ld h,BOARD_TOP
        ld bc,BOARD_HEIGHT*256
.3:     push bc
        ld bc,BOARD_WIDTH*256
        ld l,BOARD_LEFT
.4:     call test_pixel		; Test block in this line.
        jr z,$+3		; Empty? Yes, jump.
        inc c			; Filled? Count it.
        inc l
        djnz .4
        ld a,c
        pop bc
        cp BOARD_WIDTH          ; Completed line?
        jp nz,.5		; No, jump.
        ld (ix+0),1		; Save status.
        push hl
        ld hl,(total_lines)
        inc hl			; Increase total lines made.
        ld (total_lines),hl
        ld a,(line_score)
        call add_score		; Add score.
        pop hl
        ld a,(line_score)
        add a,$11		; +11 BCD score for next line.
        daa
        ld (line_score),a
        ld c,1			; At least one line made!
        jr .6

.5:     ld (ix+0),0		; Save status.
.6:
        inc ix
        inc h
        djnz .3

        ;
        ; Make lines to blink.
        ;
        ld a,c
        or a			; Completed a line?
        jp z,.7			; No, jump.
        ld b,10			; Blink 10 times.
.8:
        ld ix,lines
        ld h,BOARD_TOP
.10:
        ld a,(ix+0)
        or a			; Completed line?
        jr z,.9			; No, jump.
        ld l,BOARD_LEFT
        ld c,BOARD_WIDTH
.11:    
        call set_pixel		; Illuminate line.
        inc l
        dec c
        jp nz,.11
.9:     inc ix
        inc h
        ld a,h
        cp BOARD_TOP+BOARD_HEIGHT
        jp nz,.10

        push bc
        call delay_blink	; Delay.
        pop bc

        ld ix,lines
        ld h,BOARD_TOP
.12:
        ld a,(ix+0)
        or a			; Completed line?
        jr z,.15		; No, jump.
        ld l,BOARD_LEFT
        ld c,BOARD_WIDTH
.14:    
        call reset_pixel	; Clear line.
        inc l
        dec c
        jp nz,.14
.15:    inc ix
        inc h
        ld a,h
        cp BOARD_TOP+BOARD_HEIGHT
        jp nz,.12

        push bc
        call delay_blink	; Delay.
        pop bc

        djnz .8

        ;
        ; Displace board
        ;
        ld ix,lines+BOARD_HEIGHT-1
        ld h,BOARD_TOP+BOARD_HEIGHT-1
        ld c,h			; Target line for updating.
        ld b,BOARD_HEIGHT	; For the full board height.
.16:    ld a,(ix+0)
        or a			; Completed line?
        jr z,.20		; No, jump.
        dec h			; Yes, origin line goes back one line.
        dec ix	
        djnz .16
        jp .7
.20:
        push bc
        ld l,BOARD_LEFT
        ld b,BOARD_WIDTH
.17:    push hl
        ld a,h			; Origin row is negative?
        or a
        jp m,.18		; Yes, jump.
        call test_pixel		; Test origin block.
        jr z,.18
        ld h,c
        call set_pixel		; Set block.
        jr .19

.18:    ld h,c
        call reset_pixel	; Reset block.
.19:    pop hl
        inc l
        djnz .17

        pop bc
        dec h
        dec c
        dec ix
        djnz .16

.7:
        call update_score	; Update current score.

        ld hl,(next_shape)	; Get next shape.
        ld a,(next_rotation_mask)
        push hl
        push af
        call random_shape	; Generate random shape.
        call update_next	; Update next shape.
        ld hl,(current_shape)
        ld (next_shape),hl
        ld a,(rotation_mask)
        ld (next_rotation_mask),a
        pop af
        pop hl
        ld (current_shape),hl
        ld (rotation_mask),a

        xor a
        ld (current_rotation),a
        ld a,BOARD_TOP		; Put piece at top.
        ld (current_y),a
        ld a,BOARD_LEFT+(BOARD_WIDTH-4)/2	; Center piece.
        ld (current_x),a
        call get_speed		; Get movement speed.
main_loop:
        ld a,0			
        call shape_draw		; Test shape against board.
        or a			; Shape can fit?
        jp z,.1			; Yes, jump.
        ld a,(current_y)
        ld b,1
        cp BOARD_TOP		; At top of board?
        jr z,$+4		; Yes, jump.
        dec b			; Move piece upward.
        dec a
        ld (current_y),a
        push bc
        ld a,1
        call shape_draw		; Draw shape in final place.
        ld a,$05
        call add_score		; Add score.
        pop bc
        ld a,b
        or a			; Game over condition (top of board)?
        jp z,check_for_lines	; No, jump to check for completed lines.

        ;
        ; Game Over
        ;
        ld hl,.00
        ld de,$3f17
        ld b,17
        call show_message

        ld hl,press_space
        ld de,$3f9a
        ld b,11
        call show_message

        jp restart_game

.00:    db "G A M E   O V E R"

.1:
        ld a,1			; Draw shape on the screen.
        call shape_draw

.3:
        ;
        ; Standard delay
        ;
        ld bc,500
        call delay

        ;
        ; Debounce keyboard
        ;
        ld a,(debounce)
        or a
        jr z,$+6
        dec a
        ld (debounce),a

        ld a,(time_counter)
        dec a			; Decrease time counter.
        ld (time_counter),a
        jp z,.2			; Jump if time completed.
        ld a,(debounce)
        or a
        jp nz,.3
    if CONTROL_SCHEME=0
        ld a,($3801)
        and $02			; A key?
        call nz,move_left
        ld a,($3801)
        and $10			; D key?
        call nz,move_right
        ld a,($3804)
        and $80			; W key?
        call nz,rotate
        ld a,($3804)
        and $08			; S key?
        call nz,fast_drop
    endif
    if CONTROL_SCHEME=1
        ld a,($3840)
        and $20			; Left arrow?
        call nz,move_left
        ld a,($3840)
        and $40			; Right arrow?
        call nz,move_right
        ld a,($3840)
        and $08			; Up arrow?
        call nz,rotate
        ld a,($3840)
        and $10			; Down arrow?
        call nz,fast_drop
    endif
        jp .3

.2:     call get_speed		; Get speed for next advance.
        ld a,-1
        call shape_draw		; Erase shape.
        ld a,(current_y)
        inc a			; Move to next line.
        ld (current_y),a
        jp main_loop		; Repeat main loop.

	;
	; Generate a random shape.
	;
random_shape:
        ld a,r		; Refresh register to get a random number.
        rrca
        rrca
        rrca
        sub 7
        jr nc,$-2
        add a,7         ; A = 0-6 (one of the shapes)
        add a,a         ; x2
        add a,a         ; x4
        add a,a         ; x8
        ld b,$07

        cp 48
        jr c,$+4
        add a,8

        cp 40           ; Shape 5 is ahead because extra rotation.
        jr c,$+4
        add a,8

        cp 32
        jr c,$+4
        ld b,$0f        ; Shape 4 and 5 have four rotations.

        ld e,a
        ld d,0
        ld hl,shapes
        add hl,de
        ld (current_shape),hl
        ld a,b
        ld (rotation_mask),a
        ret

	;
	; Update next shape.
	;
update_next:
        ld hl,$3dc4		; Erase area.
        ld (hl),$80
        inc hl
        ld (hl),$80
        inc hl
        ld (hl),$80
        inc hl
        ld (hl),$80
        ld hl,$3e04
        ld (hl),$80
        inc hl
        ld (hl),$80
        inc hl
        ld (hl),$80
        inc hl
        ld (hl),$80
        ld a,4			; Setup X.
        ld (current_x),a
        ld a,7*3		; Setup Y.
        ld (current_y),a
        xor a			; Current rotation.
        ld (current_rotation),a
        ld a,1
        call shape_draw		; Draw shape.
        ret

	;
	; Add BCD score in A to 32-bit score.
	;
add_score:
        ld hl,(score)
        ld de,(score+2)
        add a,l
        daa
        ld l,a
        ld a,h
        adc a,0
        daa
        ld h,a
        ld a,e
        adc a,0
        daa
        ld e,a
        ld a,d
        adc a,0
        daa
        ld d,a
        ld (score),hl
        ld (score+2),de
        ret

	;
	; Update score on the screen.
	;
update_score:
        ld hl,$3d0b
        ld a,(score+3)
        call .1
        ld a,(score+2)
        call .1
        ld a,(score+1)
        call .1
        ld a,(score)
.1:     push af
        rrca
        rrca
        rrca
        rrca			; Display high-nibble.
        call .2
        pop af
.2:     and $0f			; Display low-nibble.
        add a,$30		; Convert to ASCII numbers.
        ld (hl),a
        inc hl
        ret
        
	;
	; Speed for piece fall.
	;
get_speed:
        ld hl,(total_lines)
        ld b,5          ; Divide by 32.
        srl h
        rr l
        djnz $-4
        ld a,l
        cp 9		; Limit to maximum 9.
        jr c,$+4
        ld a,9
        push af
        ld b,a
        add a,a 	; x2
        add a,a 	; x4
        add a,b 	; x6
        neg
        add a,60
        ld (time_counter),a
        ld hl,$3c8b	; Update level on the screen.
        pop af
        inc a
        cp 10  
        jr c,$+6
        ld (hl),$31
        inc hl
        xor a
        add a,$30
        ld (hl),a
        ret

	;
	; Move piece to left.
	;
move_left:
        ld a,15			; Keyboard debounce time.
        ld (debounce),a
        ld a,-1
        call shape_draw		; Erase shape on the screen.
        ld a,(current_x)
        dec a			; Move to left.
        ld (current_x),a
        ld a,0
        call shape_draw		; Verify if the shape can fit.
        or a			; Can the piece fit?
        jp z,.1			; Yes, jump.
        ld a,(current_x)
        inc a			; No, restore original position.
.0:     ld (current_x),a
.1:     ld a,1			; Draw shape on the screen.
        jp shape_draw

	;
	; Move piece to right.
	;
move_right:
        ld a,15			; Keyboard debounce time.
        ld (debounce),a
        ld a,-1
        call shape_draw		; Erase shape on the screen.
        ld a,(current_x)
        inc a			; Move to right.
        ld (current_x),a
        ld a,0
        call shape_draw		; Verify if the shape can fit.
        or a			; Can the piece fit?
        jr z,move_left.1	; Yes, jump.
        ld a,(current_x)
        dec a			; No, restore original position.
        jr move_left.0

	;
	; Rotate piece.
	;
rotate:
        ld a,15			; Keyboard debounce time.
        ld (debounce),a
        ld a,-1
        call shape_draw		; Erase shape on the screen.
        ld a,(rotation_mask)
        ld b,a
        ld a,(current_rotation)
        add a,4			; Rotate.
        and b			; Limit to rotations available.
        ld (current_rotation),a
        ld a,0
        call shape_draw		; Verify if the shape can fit.
        or a			; Can the piece fit?
        jp z,.1			; Yes, jump.
        ld a,(rotation_mask)
        ld b,a
        ld a,(current_rotation)
        sub 4			; Undo rotation.
        and b
        ld (current_rotation),a
.1:     ld a,1			; Draw shape on the screen.
        jp shape_draw

	;
	; Fast drop for piece.
	;
fast_drop:
        ld a,15			; Keyboard debounce time.
        ld (debounce),a
        ld a,(time_counter)
        cp 5			; Accelerate time counter.
        ret c			; Already low enough? Yes, return.
        ld a,5
        ld (time_counter),a
        ret

	;
	; Draw, erase, or test shape.
	;
shape_draw:
        or a			; Save flag.
        ex af,af'
        exx
        ld c,0
        exx
        ld hl,(current_shape)
        ld a,(current_rotation)
        ld e,a
        ld d,0
        add hl,de
        push hl
        pop ix
        ld bc,$0400		; 4 lines, reset counter to zero.
        ld a,(current_y)	; Current Y-coordinate.
        ld h,a
.1:     push bc
        ld a,(current_x)	; Current X-coordinate.
        ld l,a
        ld a,(ix+0)		; Get X offset.
        srl a
        srl a
        srl a
        add a,l
        ld l,a
        ld a,(ix+0)		; Get width.
        and 7
        jr z,.7
        ld b,a
.5:
        call test_pixel		; Test block?
        jr z,.2			; Jump if nothing.
        exx
        inc c			; Increase hit counter.
        exx
.2:     ex af,af'
        jr z,.3
        jp m,.4
        ex af,af'
        call set_pixel		; Set block.
        jr .6

.4:     ex af,af'
        call reset_pixel	; Erase block.
        jr .6

.3:     ex af,af'
.6:     inc l
        djnz .5			; Loop to make horizontal span.
.7:     pop bc
        inc ix
        inc h
        djnz .1			; Loop to make the four lines of the shape.
        exx
        ld a,c			; Hit counter in A.
        exx
        ret

	;
	; Game shapes.
	;
shapes:
        db $02,$0a,$00,$00
        db $11,$0a,$09,$00

        db $0a,$02,$00,$00
        db $09,$0a,$11,$00

        db $09,$09,$09,$09
        db $00,$04,$00,$00

        db $0a,$0a,$00,$00
        db $0a,$0a,$00,$00

        db $11,$11,$0a,$00
        db $01,$03,$00,$00
        db $0a,$09,$09,$00
        db $03,$11,$00,$00

        db $09,$09,$0a,$00
        db $03,$01,$00,$00
        db $0a,$11,$11,$00
        db $11,$03,$00,$00

        db $09,$03,$00,$00
        db $09,$0a,$09,$00
        db $03,$09,$00,$00
        db $09,$02,$09,$00

	;
	; Delay for blink.
	;
delay_blink:
        ld bc,$0600
delay:
        dec bc
        ld a,b
        or c
        jr nz,$-3
        ret

        ;
	; Set pixel on TRS-80 screen.
        ; H = Y-coordinate (0-47)
        ; L = X-coordinate (0-63)
        ;
set_pixel:
        call pixel_addr
        bit 7,(hl)      ; Not a valid graphic?
        jr z,$+3        ; Invalid graphic, jump and put pixel directly.
        or (hl)
.1:
        and $3f
        or $80
        ld (hl),a
        ex de,hl
        ret

        ;
	; Reset pixel on TRS-80 screen.
        ; H = Y-coordinate (0-47)
        ; L = X-coordinate (0-63)
        ;
reset_pixel:
        call pixel_addr 
        bit 7,(hl)      ; Valid graphic?
        jr nz,$+4       ; Valid graphic, jump.
        ld (hl),$80     ; Reset to graphic block.
        cpl
        and (hl)
        jr set_pixel.1

        ;
	; Test pixel on TRS-80 screen.
        ; H = Y-coordinate (0-47)
        ; L = X-coordinate (0-63)
        ;
test_pixel:
        call pixel_addr
        bit 7,(hl)      ; Valid graphic?
        jr z,$+3        ; No, return as pixel unset.
        and (hl)        ; Yes, check if pixel is set.
        ex de,hl
        ret

        ;
        ; Input:
        ;   H = Y-coordinate (0-47).
        ;   L = X-coordinate (0-63).
        ; Output:
        ;   HL = Address for pixel.
        ;   A = Mask.
        ;
pixel_addr:
        ld d,$ef
        ld a,l
        add a,a
        add a,a
        ld e,a
        ld a,h
.1:
        inc d
        sub 3
        jr nc,.1
        srl d
        rr e
        srl d
        rr e
        ex de,hl
        add a,2
        ld a,$03
        ret m
        ld a,$0c
        ret z
        ld a,$30
        ret

	;
	; Erase completely the screen,
	; and build data using the HL pointer.
	;
build_screen:
        ld de,$3c00
        ld a,$20
        ld (de),a
        inc de
        bit 6,d
        jr z,$-4

.1:     ld e,(hl)	; Get target address.
        inc hl
        ld d,(hl)
        inc hl
        ld a,d		; Is it zero?
        or e
        ret z		; Yes, return.
        ld b,(hl)	; Get length of message.
        inc hl
        call show_message	; Display.
        jr .1

	;
	; Show message.
	; DE = Pointer to message.
	; HL = Pointer to video screen.
	; B = Length in characters.
	;
show_message:
        ex de,hl
.2:     
        ld a,(de)
        ld (hl),a
        cp (hl)         ; For model 1 without lowercase support.
        jr z,.3
        res 5,(hl)
.3:     inc de
        inc hl
        djnz .2
        ex de,hl
        ret

	;
	; Title screen.
	;
title_screen:
        dw $3c4e
        db $23
        db $bf,$bf,$bf,$bf,$bf,$bf,$bf,$20
        db $bf,$bf,$bf,$bf,$bf,$bf,$bf,$20
        db $a0,$be,$bf,$bf,$bf,$bf,$bf,$20
        db $bf,$bf,$bf,$20
        db $a0,$be,$bf,$bf,$bf,$bf,$bf

        dw $3c91
        db $1b
        db             $bf,$20,$20,$20,$20
        db $20,$20,$20,$bf,$20,$20,$20,$20
        db $af,$91,$20,$20,$20,$20,$bf,$20
        db $20,$bf,$20,$20
        db $bf,$81

        dw $3cd1
        db $1b
        db             $bf,$20,$20,$20,$20
        db $20,$20,$20,$bf,$20,$20,$20,$20
        db $82,$bf,$90,$20,$20,$20,$bf,$20
        db $20,$bf,$20,$20
        db $bf,$90

        dw $3d11
        db $20
        db             $bf,$20,$20,$20,$20
        db $20,$20,$20,$bf,$20,$20,$20,$20
        db $20,$a2,$bf,$bf,$bf,$bf,$bf,$20
        db $20,$bf,$20,$20
        db $82,$af,$bf,$bf,$bf,$bd,$90

        dw $3d51
        db $20
        db             $bf,$20,$20,$20,$20
        db $20,$20,$20,$bf,$20,$20,$20,$20
        db $a8,$bf,$81,$20,$20,$20,$bf,$20
        db $20,$bf,$20,$20
        db $20,$20,$20,$20,$20,$82,$bf

        dw $3d91
        db $20
        db             $bf,$20,$20,$20,$20
        db $20,$20,$20,$bf,$20,$20,$20,$20
        db $bf,$85,$20,$20,$20,$20,$bf,$20
        db $20,$bf,$20,$20
        db $20,$20,$20,$20,$20,$a0,$bf

        dw $3dd1
        db $20
        db             $bf,$20,$20,$20,$20
        db $20,$20,$20,$bf,$20,$20,$20,$20
        db $bf,$20,$20,$20,$20,$20,$bf,$20
        db $bf,$bf,$bf,$20
        db $bf,$bf,$bf,$bf,$bf,$9f,$81

        dw $3e97
        db $12
        db "by Oscar Toledo G."

        dw $3ed6
        db $14
        db "http://nanochess.org"

        dw $3f1c
        db $08
        db "Aug/2023"

        dw $3f9a
        db $0b
press_space:
        db "Press Space"

        dw $0000

	;
	; Game screen.	
	;
game_screen:
        dw $3c84
        db $06
        db "Level:"
        dw $3d04
        db $06
        db "Score:"
        dw $3d84
        db $05
        db "Next:"
        dw $0000

lines:                  rb BOARD_HEIGHT	; To mark lines completed.
total_lines:            rb 2		; Total lines completed.
line_score:             rb 1		; Score for next line completed.
score:                  rb 4		; Current score (32-bit).
current_x:              rb 1		; Current X coordinate.
current_y:              rb 1		; Current Y coordinate.
current_shape:          rb 2		; Pointer to current shape.
next_shape:             rb 2		; Pointer to next shape.
current_rotation:       rb 1		; Current rotation.
rotation_mask:          rb 1		; Mask for rotation.
next_rotation_mask:     rb 1		; Mask for rotation of next shape.
debounce:               rb 1		; Debounce timer.
time_counter:           rb 1		; Time counter.

ram_end:

