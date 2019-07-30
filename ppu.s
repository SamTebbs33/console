include "common.s"

org 0
ld sp, stack_bottom
jp $

pad_until 0x66
nmi:
    ret

pad_until 0x100
stack_bottom:
    ds 0x200
stack_top:
