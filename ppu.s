org 0
ld sp, stack_bottom
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
nmi:
    ; NMI routine
    ret

pad_until 0x100
stack_bottom:
    ds 0x200
stack_top:
