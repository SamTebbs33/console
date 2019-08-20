include "common.s"

; Generic constants
VRAM_ADDR: equ 0x0
STACK_BOTTOM_ADDR: equ 0xFFFF-0x2000
CONTROLLER_ADDR: equ 0x2000
PALETTE_ADDR: equ VRAM_ADDR+0x0100
TILE_TABLE_ADDR: equ VRAM_ADDR+0x0140
SPRITE_TABLE_ADDR: equ VRAM_ADDR+0x0F50
ATTR_ADDR: equ VRAM_ADDR+0x0

SPRITE_ENT_SIZE: equ 5
ATTR_SIZE: equ 1
TILE_ENTRY_SIZE: equ 2

CONTROLLER_BIT_UP: equ 0
CONTROLLER_BIT_DOWN: equ 1
CONTROLLER_BIT_LEFT: equ 2
CONTROLLER_BIT_RIGHT: equ 3
CONTROLLER_BIT_A: equ 4
CONTROLLER_BIT_B: equ 5
CONTROLLER_BIT_C: equ 6
CONTROLLER_BIT_S: equ 7

NUM_TILES_X: equ 30

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
    exx
    ex af, af'
    push ix
    push iy
    ; Update the frame counter
    ld a, (frame_counter)
    inc a
    ld (frame_counter), a
    ; Don't check for input other than on every 255th frame
    cp 60
    jp nz, .ret
    xor a
    ld (frame_counter), a
    ; Check if each direction is pressed
    ld bc, CONTROLLER_ADDR
    in a, (c)
    .check_right:
        bit CONTROLLER_BIT_RIGHT, a
        jp nz, .check_left
        ld ix, (curr_coords)
        call move_tile_right
        ; Add to coords
        ld ix, (curr_coords)
        inc ix
        ld (curr_coords), ix
        jp .ret
    .check_left:
        bit CONTROLLER_BIT_RIGHT, a
        jp nz, .check_up
        ld ix, (curr_coords)
        call move_tile_left
        ; Subtract from coords
        ld ix, (curr_coords)
        dec ix
        ld (curr_coords), ix
        jp .ret
    .check_up:
        bit CONTROLLER_BIT_UP, a
        jp nz, .check_down
        ld ix, (curr_coords)
        call move_tile_up
        ld ix, (curr_coords)
        ld bc, -NUM_TILES_X
        add ix, bc
        ld (curr_coords), ix
        jp .ret
    .check_down:
        bit CONTROLLER_BIT_DOWN, a
        jp nz, .check_up
        ld ix, (curr_coords)
        call move_tile_down
        ld ix, (curr_coords)
        ld bc, NUM_TILES_X
        add ix, bc
        ld (curr_coords), ix
        jp .ret
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
    ld bc, PALETTE_ADDR+1
    out (c), a

    ; Place initial tiles
    ld ix, 10 | (10 << 8)
    ld hl, TILE_META_SNAKE | (SPRITE_NUM_SNAKE << 8)
    call place_tile
    ld ix, 10 | (10 << 8)
    ld (curr_coords), ix

    ld ix, 20 | (10 << 8)
    ld hl, TILE_META_CHERRY | (SPRITE_NUM_CHERRY << 8)
    call place_tile

    jp $

; Place a tile
;   ixl: x coord
;   ixh: y coord
;   l: tile metadata
;   h: sprite num
;
;   see get_tile_addr
;   bc: final tile address
;   a: sprite num
place_tile:
    call get_tile_addr
    ; Set the entry
    push ix
    pop bc
    ld a, l
    out (c), a
    inc bc
    ld a, h
    out (c), a
    ret

; Convert a tile's coords to a VRAM address
;   ixl: x coord
;   ixh: y coord
;
;   ix: final tile address
;   de: TILE_TABLE_ADDR
;   a: TILE_ENTRY_SIZE - 1
get_tile_addr:
    ; addr = TILE_TABLE_ADDR + ((y * width + x) * TILE_ENTRY_SIZE)
    ; TODO: Optimise repeat_add to shifts when possible
    ld d, 0
    ld e, ixh
    ld ixh, 0
    ld a, NUM_TILES_X
    call repeat_add16
    push ix
    pop de
    ; TODO: Optimise the repeat_add16 to a left shift as TILE_ENTRY_SIZE is 2
    ld a, TILE_ENTRY_SIZE - 1
    call repeat_add16
    ld de, TILE_TABLE_ADDR
    add ix, de
    ret

; Move a tile one space to the right. No bounds checking is done
;   ixl: x coord
;   ixh: y coord
;
;   bc: new location's final address
;   de: TILE_ENTRY_SIZE
;   l: tile metadata
;   h: sprite num
;   ix: new location's initial address
;   a: 0
move_tile_right:
    call get_tile_addr
    push ix
    pop bc
    ; Get and clear the metadata
    in l, (c)
    ld a, 0
    out (c), a
    ; Get and clear the sprite num
    inc bc
    in h, (c)
    out (c), a
    ; The next tile on the x axis is just TILE_ENTRY_SIZE away
    ld de, TILE_ENTRY_SIZE
    add ix, de
    push ix
    pop bc
    ; Write metadata
    out (c), l
    inc bc
    out (c), h
    ret

move_tile_left:
    ; TODO: Implement
    ret

move_tile_up:
    ; TODO: Implement
    ret

move_tile_down:
    ; TODO: Implement
    ret


; Do ix += de until a is 0
repeat_add16:
    cp 0
    ret z
    .loop:
        add ix, de
        dec a
        jp nz, .loop
        ret

; End of ROM and start of RAM
pad_until 0x8000
num_snakes: db 0
curr_coords: dw 0
frame_counter: db 0
