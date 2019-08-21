include "common.s"

; Game-specfic constants
PALETTE_0_0: equ 0xFF ; white
PALETTE_0_1: equ 0x07 ; red
PALETTE_SNAKE: equ 0

SPRITE_NUM_SNAKE: equ 0
SPRITE_NUM_CHERRY: equ 1

TILE_META_SNAKE: equ 00000100b
TILE_META_CHERRY: equ 00000100b

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
    ld de, (curr_dir)
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
        ld (curr_dir), de
        ld bc, (curr_addr)
        ; Copy into hl
        ld h, b
        ld l, c
        ; The destination offset is in de. Compute the new address
        add hl, de
        ; Store it
        ld (curr_addr), hl
        ; Check if the snake head is going to be collide with the cherry
        ld de, (curr_cherry)
        ; Decent way of comparing hl and another 16 bit reg
        or a
        sbc hl, de
        add hl, de
        ; If it will then add to the score and copy the snake head, else move it
        jp nz, .do_move
        ld a, (score)
        inc a
        ld (score), a
        call copy_tile
        jp .ret
    .do_move:
        call move_tile
    .ret:
        pop iy
        pop ix
        ex af, af'
        exx
        reti

start:
    ld sp, STACK_BOTTOM_ADDR
    ; Set palette
    ld a, PALETTE_0_0
    ld bc, PALETTE_ADDR
    out (c), a
    ld a, PALETTE_0_1
    inc bc
    out (c), a

    ; Set score to 0
    ld a, 0
    ld (score), a

    ; Place initial tiles. The address calculation has to be done in place as macros are kinda broken in z80asm.
    ; Maybe I should add a z80 assembler to the long list of projects I want to work on...
    ld bc, TILE_TABLE_ADDR+(10*NUM_TILES_X+10)*TILE_ENTRY_SIZE
    ld hl, TILE_META_SNAKE | (SPRITE_NUM_SNAKE << 8)
    ld (curr_addr), bc
    call place_tile

    ld bc, TILE_TABLE_ADDR+(10*NUM_TILES_X+20)*TILE_ENTRY_SIZE
    ld hl, TILE_META_CHERRY | (SPRITE_NUM_CHERRY << 8)
    ld (curr_cherry), bc
    call place_tile

    ; Set current travel direction to 0
    ld a, 0
    ld (curr_dir), a

    jp $

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

; End of ROM and start of RAM
pad_until 0x8000
num_snakes: db 0
curr_addr: dw 0
curr_dir: dw 0
curr_cherry: dw 0
frame_counter: db 0
score: db 0
