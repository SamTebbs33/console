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

pad_until: macro addr
    if $ < addr
        ds addr - $
    else
        if $ > addr
            ; This will cause a double free error, signalling that pad_until was used on a preceeding address
            end
        endif
    endif
    org addr
endm
