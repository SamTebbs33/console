; Palette is at SPR_ROM_SIZE + PALETTE_ADDR
start:
    org 0
    ld sp, stack_bottom
    ld bc, 0x3518
    ld e, 60
    jp $

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
