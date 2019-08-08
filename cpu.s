include "common.s"

CONTROLLER_ADDR: equ 0x2000
PALETTE_ADDR: equ 0x0100
TILE_TABLE_ADDR: equ 0x0140

CONTROLLER_A: equ 4

PALETTE_1_1: equ 0xFF
TILE_TABLE_1_LOW: equ 00000100b
TILE_TABLE_1_HIGH: equ 00000000b

start:
    org 0
    ld sp, stack_bottom
    ld bc, PALETTE_ADDR
    ; Set up graphics

    ; Set palette
    ld a, PALETTE_1_1
    out (c), a
    ; Set tile table
    ld bc, TILE_TABLE_ADDR
    ld a, TILE_TABLE_1_LOW
    out (c), a
    ld a, TILE_TABLE_1_HIGH
    inc bc
    out (c), a

    ld bc, CONTROLLER_ADDR
    jp $

pad_until 0x66
; Frame sync. It's here that the CPU can update VRAM
frame_nmi:
    ; Check if A button is down
    in a, (c)
    bit CONTROLLER_A, a
    jp z, toggle
    ret
toggle:
    ld bc, PALETTE_ADDR
    in a, (c)
    cpl
    out (c), a
    ld bc, CONTROLLER_ADDR
    ret

pad_until 0x100
stack_bottom:
    ds 0x200
stack_top:
