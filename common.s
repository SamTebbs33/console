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

