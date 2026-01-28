ENTRY(_start)

SECTIONS {
    . = 0x80000000;

    .text :{
        *(.text.init);
        *(.text*);
    }

    .rodata : ALIGN(4) {
        *(.rodata*);
    }

    .data : ALIGN(4) {
        *(.data*);
    }

    .bss : ALIGN(4) {
        __bss_start = .;
        *(.bss*)
        *(COMMON)
        __bss_end = .;
    }

    . = ALIGN(16);
    .stack (NOLOAD) : {
        . = . + 0x4000;   /* 16KB stack */
    }
    _stack_top = .;
}
