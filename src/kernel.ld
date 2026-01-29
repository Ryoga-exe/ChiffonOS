ENTRY(_start)

__ram_base      = 0x80000000;
__rsvd_size     = 0x00004000; /* 16 KiB reserved window */
__mailbox_addr  = 0x80002000;

SECTIONS {
    . = __ram_base;

    .text.init : ALIGN(4) {
        KEEP(*(.text.init))
        KEEP(*(.text.boot))
    }

    . = __ram_base + __rsvd_size;

    .text : ALIGN(16) {
        *(.text .text.*)
    }

    .rodata : ALIGN(16) {
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
    }

    .data : ALIGN(16) {
        *(.data .data.*)
        *(.sdata .sdata.*)
    }

    .bss (NOLOAD) : ALIGN(16) {
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        __bss_end = .;
    }

    . = ALIGN(16);
    __heap_start = .;

    . = ALIGN(16);
    .stack (NOLOAD) : {
        . = . + 0x4000;   /* 16 KiB stack */
    }
    _stack_top = .;

    __heap_end = .;

    __image_end = .;
}
