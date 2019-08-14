include "common.s"

STACK_BOTTOM_ADDR: equ 0xFFFF-0x2000
CONTROLLER_ADDR: equ 0x2000
PALETTE_ADDR: equ 0x0100
TILE_TABLE_ADDR: equ 0x0140

CONTROLLER_A: equ 4

PALETTE_1_1: equ 0x00
TILE_TABLE_1_LOW: equ 00000100b
TILE_TABLE_1_HIGH: equ 00000000b

org 0
start:
    ld sp, STACK_BOTTOM_ADDR
    jp $

pad_until 0x66
; Frame sync. It's here that the CPU can update VRAM
frame_nmi:
    ret
