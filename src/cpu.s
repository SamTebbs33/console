include "common.s"

; Game-specfic constants
PALETTE_0_0: equ 0xFF ; white
PALETTE_0_1: equ 0x07 ; red
PALETTE_SNAKE: equ 0

SPRITE_NUM_SNAKE: equ 0
SPRITE_NUM_CHERRY: equ 1

TILE_META_SNAKE: equ 00000100b
TILE_META_CHERRY: equ 00000100b

MAX_NUM_SNAKES: equ 16
SNAKE_BUFF_END: equ snake_buffer + (MAX_NUM_SNAKES - 1) * 2

org 0
entry:
    jp start

pad_until 0x66
; Frame sync. It's here that the CPU can update VRAM
frame_nmi:
    ; Save BC, DE, HL, AF, IX and IY
    ; TODO: Optimise so that only the registers used are saved and restored.
    ; Also only save the registers used before frame count check, then save the rest if the check passes
    exx
    ex af, af'
    push ix
    push iy
    ; Update the frame counter
    ld a, (frame_counter)
    inc a
    ld (frame_counter), a
    ; Don't check for input other than on every 60th frame
    cp 16
    jp nz, .ret
    ; Clear the frame counter as we only update on the 60th frame
    xor a
    ld (frame_counter), a
    ; Get current controller status
    ld bc, CONTROLLER_ADDR
    in a, (c)
    ; TODO Hmm, perhaps I can just re-use de instead of storing it to memory every frame. Only if it doesn't get overwritten.
    ld de, (direction)
    .check_right:
        bit CONTROLLER_BIT_RIGHT, a
        jp nz, .check_left
        ld de, TILE_ENTRY_SIZE
        jp .move
    .check_left:
        bit CONTROLLER_BIT_LEFT, a
        jp nz, .check_up
        ld de, -TILE_ENTRY_SIZE
        jp .move
    .check_up:
        bit CONTROLLER_BIT_UP, a
        jp nz, .check_down
        ld de, -TILE_ENTRY_SIZE*NUM_TILES_X
        jp .move
    .check_down:
        bit CONTROLLER_BIT_DOWN, a
        jp nz, .move
        ld de, TILE_ENTRY_SIZE*NUM_TILES_X
    .move:
        ; Save the direction chosen
        ld (direction), de
        ; Load the head address
        ld hl, (head_addr)
        ; The destination offset is in de. Compute the new address
        add hl, de
        ld (head_addr), hl
        ; Check if the snake head is going to be collide with the cherry
        ld b, h
        ld c, l
        inc bc
        in a, (c)
        cp SPRITE_NUM_CHERRY
        ; If the head will hit the cherry then try to add another snake part, else move the tail
        jp nz, .do_move
        ; Add another snake part if we haven't reached the maximum, else just move
        ld a, (num_snakes)
        cp MAX_NUM_SNAKES
        jp nc, .do_move
        ; Add an element to the buffer before the start
        ld ix, (snake_buffer_start)
        dec ix
        dec ix
        ld (ix+0), l
        ld (ix+1), h
        ld (snake_buffer_start), ix
        inc a
        ld (num_snakes), a
        ld a, SPRITE_NUM_SNAKE
        out (c), a
        dec bc
        ld a, TILE_META_SNAKE
        out (c), a
        jp .ret
    .do_move:
        ; Put a snake at the new head
        ld a, SPRITE_NUM_SNAKE
        out (c), a
        dec bc
        ld a, TILE_META_SNAKE
        out (c), a
        ; Load the tail address
        ld ix, (tail_ptr)
        ld c, (ix+0)
        ld b, (ix+1)
        ; Store the new head address into current tail ptr
        ld (ix+0), l
        ld (ix+1), h
        ; Clear the tail
        ld a, 0
        out (c), a
        inc bc
        out (c), a
        ld h, ixh
        ld l, ixl
        ld de, SNAKE_BUFF_END
        or a
        sbc hl, de
        add hl, de
        jp nc, .set_to_start
        inc hl
        inc hl
        ld (tail_ptr), hl
        jp .ret
    .set_to_start:
        ld bc, (snake_buffer_start)
        ld (tail_ptr), bc
    .ret:
        pop iy
        pop ix
        ex af, af'
        exx
        reti

; Place a tile
;   bc: tile address
;   l: tile metadata
;   h: sprite num
;
;   bc: final tile address
;   a: sprite num
place_tile:
    ; Set the entry
    ld a, l
    out (c), a
    inc bc
    ld a, h
    out (c), a
    ret

; Copy a tile entry from one address to another. Like move_tile but doesn't clear
;   bc: address to move from
;   hl: address to move to
;
;   bc: new location's final address
;   e: tile metadata
;   d: sprite num
copy_tile:
    ; Get the metadata
    in e, (c)
    ; Get the sprite num
    inc bc
    in d, (c)
    ld b, h
    ld c, l
    ; Write metadata
    out (c), e
    inc bc
    out (c), d
    ret

; Move a tile entry from one address to another. Clears the initial tile to 0
;   bc: address to move from
;   hl: address to move to
;
;   bc: new location's final address
;   e: tile metadata
;   d: sprite num
;   a: 0
move_tile:
    ; Get and clear the metadata
    in e, (c)
    ld a, 0
    out (c), a
    ; Get and clear the sprite num
    inc bc
    in d, (c)
    out (c), a
    ld b, h
    ld c, l
    ; Write metadata
    out (c), e
    inc bc
    out (c), d
    ret

start:
    ld sp, STACK_BOTTOM_ADDR
    ; Set palette
    ld a, PALETTE_0_0
    ld bc, PALETTE_ADDR
    out (c), a
    ld a, PALETTE_0_1
    inc bc
    out (c), a

    ; Place initial tiles. The address calculation has to be done in place as macros are kinda broken in z80asm.
    ; Maybe I should add a z80 assembler to the long list of projects I want to work on...
    ld bc, TILE_TABLE_ADDR+(10*NUM_TILES_X+10)*TILE_ENTRY_SIZE
    ld hl, TILE_META_SNAKE | (SPRITE_NUM_SNAKE << 8)
    ; Set head and tail pointers to point to first element of snake buffer
    ld de, SNAKE_BUFF_END
    ld (tail_ptr), de
    ld (snake_buffer_start), de
    ld (SNAKE_BUFF_END), bc
    ld (head_addr), bc
    ld a, 1
    ld (num_snakes), a
    call place_tile

    ld bc, TILE_TABLE_ADDR+(10*NUM_TILES_X+20)*TILE_ENTRY_SIZE
    ld hl, TILE_META_CHERRY | (SPRITE_NUM_CHERRY << 8)
    ld (cherry_addr), bc
    call place_tile

    ; Set current travel direction to 0
    ld a, TILE_ENTRY_SIZE
    ld (direction), a

    jp $

; End of ROM and start of RAM
pad_until 0x8000
num_snakes: db 0
snake_buffer: ds MAX_NUM_SNAKES * 2
snake_buffer_start: dw 0
tail_ptr: dw 0
head_addr: dw 0
direction: dw 0
cherry_addr: dw 0
frame_counter: db 0
score: db 0
