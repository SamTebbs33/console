include "common.s"

start:
    org 0
    ld sp, stack_bottom
    ld bc, 0x0 + 0x0100
    ld e, 60
    jp $

pad_until 0x66
; Frame sync. It's here that the CPU can update VRAM
frame_nmi:
    ret

pad_until 0x100
stack_bottom:
    ds 0x200
stack_top:
