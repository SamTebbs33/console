include common.s

start:
    org 0
    ld sp, stack_bottom
    ld bc, 0x3518
    ld e, 60
    jp $

pad_until 0x66
frame_nmi:
    ld a, e
    cp 128
    jp z, toggle
    inc e
    ret
toggle:
    in a, (c)
    cpl
    out (c), a
    ld e, 0
    ret

pad_until 0x100
stack_bottom:
    ds 0x200
stack_top:
