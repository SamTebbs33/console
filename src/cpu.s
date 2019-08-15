include "common.s"

STACK_BOTTOM_ADDR: equ 0xFFFF-0x2000
CONTROLLER_ADDR: equ 0x2000
PALETTE_ADDR: equ 0x0100
TILE_TABLE_ADDR: equ 0x0140
SPRITE_TABLE_ADDR: equ 0x0F50

CONTROLLER_A: equ 4

PALETTE_0_0: equ 0x00
PALETTE_0_1: equ 0xE0

SPRITE_NO_SNAKE: equ 0
SPRITE_NO_CHERRY: equ 1
SPRITE_ENT_SNAKE_3: equ 00000000b
SPRITE_ENT_SNAKE_4: equ 00000000b

org 0
start:
    ld sp, STACK_BOTTOM_ADDR
    ; Set palette
    ld a, PALETTE_0_0
    ld bc, PALETTE_ADDR
    out (c), a
    ld a, PALETTE_0_1
    ld bc, PALETTE_ADDR+1
    out (c), a
    ; Set sprite table
    set_sprite_ent 0, 0, 0, 0, 0, 0, 0, 0, 0
    jp $

; Set a sprite entry
set_sprite_ent: macro num x y spr spr_inc x_inc y_inc pal attr
    ; x coord
    ld bc, SPRITE_TABLE_ADDR+num*SPRITE_ENTRY_SIZE
    ld a, x
    out (c), a
    ; y coord
    ld bc, SPRITE_TABLE_ADDR+num*SPRITE_ENTRY_SIZE+1
    ld a, y
    out (c), a
    ; sprite num
    ld bc, SPRITE_TABLE_ADDR+num*SPRITE_ENTRY_SIZE+2
    ld a, spr
    out (c), a
    ; metadata
    ld bc, SPRITE_TABLE_ADDR+num*SPRITE_ENTRY_SIZE+3
    ld a, spr_inc|(spr_x_inc<<2)|(spr_y_inc<<4)|(pal<<6)
    out (c), a
    ; attribute num
    ld bc, SPRITE_TABLE_ADDR+num*SPRITE_ENTRY_SIZE+4
    ld a, attr
    out (c), a
    

pad_until 0x66
; Frame sync. It's here that the CPU can update VRAM
frame_nmi:
    ret
