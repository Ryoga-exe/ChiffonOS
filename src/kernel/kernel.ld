ENTRY(_start)

__ram_base      = 0x80000000;
__ram_size      = 0x01000000; /* 16 MiB (keep in sync with pynq/boot.ipynb RAM_BYTES) */
__ram_end       = __ram_base + __ram_size;
__rsvd_size     = 0x00004000; /* 16 KiB reserved window */
__mailbox_addr  = 0x80002000;
__heap_size     = 0x00010000; /* 64 KiB heap */
__app_base      = 0x80400000; /* app load base */
__app_limit     = __ram_end;  /* app load limit */

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
    .heap (NOLOAD) : {
        . = . + __heap_size;
    }
    __heap_end = .;

    . = ALIGN(16);
    .stack (NOLOAD) : {
        . = . + 0x4000;   /* 16 KiB stack */
    }
    _stack_top = .;

    __image_end = .;
}
