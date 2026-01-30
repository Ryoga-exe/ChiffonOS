// Minimal Doomgeneric backend for ChiffonOS.
// Uses bootinfo to locate the framebuffer and UART for input.

#include <stddef.h>

typedef unsigned char u8;
typedef unsigned int u32;
typedef unsigned long long u64;
typedef unsigned long usize;

typedef u32 pixel_t;

// From doomgeneric.h
extern pixel_t *DG_ScreenBuffer;

// Expose framebuffer info for the stub renderer.
u32 dg_fb_width = 0;
u32 dg_fb_height = 0;
u32 dg_fb_stride = 0;

#define BOOTINFO_ADDR 0x803F1000ull
#define BOOTINFO_MAGIC 0x43424F54u /* 'CBOT' */

typedef struct {
    u32 magic;
    u32 version;
    u64 fb0_phys;
    u64 fb1_phys;
    u32 width;
    u32 height;
    u32 stride_bytes;
    u32 pixel_format;
    u64 regbus_base;
    u64 mailbox_addr;
    u64 fs_base;
    u64 fs_size;
    u32 fs_type;
    u32 has_fs;
} bootinfo_t;

static inline const volatile bootinfo_t *bootinfo(void) {
    return (const volatile bootinfo_t *)BOOTINFO_ADDR;
}

// syscalls (see src/common/syscall.zig)
enum {
    SYSCALL_EXIT = 1,
    SYSCALL_GFX_BEGIN = 2,
    SYSCALL_GFX_CLEAR = 3,
    SYSCALL_GFX_FILL_RECT = 4,
    SYSCALL_GFX_PRESENT = 5,
    SYSCALL_UART_PUTC = 6,
    SYSCALL_UART_GETC = 7,
};

static inline usize syscall0(usize num) {
    register usize a0 asm("a0");
    register usize a7 asm("a7") = num;
    asm volatile("ecall" : "=r"(a0) : "r"(a7) : "memory");
    return a0;
}

static inline usize syscall1(usize num, usize arg0) {
    register usize a0 asm("a0") = arg0;
    register usize a7 asm("a7") = num;
    asm volatile("ecall" : "+r"(a0) : "r"(a7) : "memory");
    return a0;
}

static inline void uart_putc(u8 c) {
    (void)syscall1(SYSCALL_UART_PUTC, (usize)c);
}

static inline int uart_getc_nonblock(u8 *out) {
    return (int)syscall1(SYSCALL_UART_GETC, (usize)out);
}

// CLINT
#define CLINT_BASE 0x02000000ull
#define MTIME_OFFSET 0x00007FF8ull

static inline u64 read_mtime(void) {
    volatile u32 *lo = (volatile u32 *)(CLINT_BASE + MTIME_OFFSET);
    volatile u32 *hi = (volatile u32 *)(CLINT_BASE + MTIME_OFFSET + 4);
    while (1) {
        u32 hi1 = *hi;
        u32 lo1 = *lo;
        u32 hi2 = *hi;
        if (hi1 == hi2) {
            return ((u64)hi1 << 32) | (u64)lo1;
        }
    }
}

void DG_Init(void) {
    const volatile bootinfo_t *bi = bootinfo();
    if (bi->magic != BOOTINFO_MAGIC || bi->fb0_phys == 0) {
        // Nothing we can do; leave DG_ScreenBuffer as-is.
        return;
    }

    DG_ScreenBuffer = (pixel_t *)(usize)bi->fb0_phys;
    dg_fb_width = bi->width;
    dg_fb_height = bi->height;
    dg_fb_stride = bi->stride_bytes;
}

void DG_DrawFrame(void) {
    // Framebuffer is memory-mapped; writing DG_ScreenBuffer is enough.
}

void DG_SleepMs(u32 ms) {
    // Assumes CLINT mtime ticks are ~1MHz (1 tick = 1us).
    u64 start = read_mtime();
    u64 target = start + (u64)ms * 1000ull;
    while (read_mtime() < target) {
        // busy wait
    }
}

u32 DG_GetTicksMs(void) {
    return (u32)(read_mtime() / 1000ull);
}

int DG_GetKey(int *pressed, unsigned char *key) {
    u8 ch;
    if (uart_getc_nonblock(&ch)) {
        if (pressed) *pressed = 1;
        if (key) *key = ch;
        return 1;
    }
    return 0;
}

void DG_SetWindowTitle(const char *title) {
    // no-op
    (void)title;
}

// Minimal console output helper (optional for debugging)
void DG_Putc(unsigned char c) {
    uart_putc(c);
}
