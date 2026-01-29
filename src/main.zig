extern const __bss_start: u8;
extern const __bss_end: u8;
extern const _stack_top: u8;

// Address map
const REGBUS_BASE: usize = 0x1001_0000;

// display regs (regbus offsets)
const RA_DISPADDR: u32 = 0x0000;
const RA_DISPCTRL: u32 = 0x0004;
const RA_DISPFIFO: u32 = 0x000C;

// draw regs (regbus offsets)
const RA_DRAWCTRL: u32 = 0x2000;
const RA_DRAWSTAT: u32 = 0x2004;
const RA_DRAWCMD: u32 = 0x200C;

// draw commands
const CMD_SETFRAME: u32 = 0x2000_0000;
const CMD_SETDRAWAREA: u32 = 0x2100_0000;
const CMD_SETFCOLOR: u32 = 0x2300_0000;
const CMD_PATBLT: u32 = 0x8100_0000;
const CMD_EODL: u32 = 0x0F00_0000;

// mailbox (written by boot_draw_display_mmio.ipynb)
const CPU_RAM_BASE: usize = 0x8000_0000;
const MAILBOX_FB0_ADDR: usize = 0x8000_2000; // u64
const MAILBOX_FB1_ADDR: usize = 0x8000_2008; // u64 (you will add this)

const WIDTH: u32 = 640;
const HEIGHT: u32 = 480;

// --------------
// MMIO helpers
// --------------
inline fn regw(off: u32, val: u32) void {
    const p: *volatile u32 = @ptrFromInt(REGBUS_BASE + off);
    p.* = val;
}

inline fn regr(off: u32) u32 {
    const p: *const volatile u32 = @ptrFromInt(REGBUS_BASE + off);
    return p.*;
}

inline fn pack2(hi: u32, lo: u32) u32 {
    return (hi << 16) | (lo & 0xFFFF);
}

// -----------------
// Display control
// -----------------
fn dispWaitVblank() void {
    // same semantics as your PYNQ test:
    // write 3, then wait until readback becomes 3
    regw(RA_DISPCTRL, 0x0000_0003);
    while (regr(RA_DISPCTRL) != 0x0000_0003) {}
}

fn dispInit(front_fb_phys: u32) void {
    dispWaitVblank();
    regw(RA_DISPFIFO, 0x0000_0003);
    regw(RA_DISPADDR, front_fb_phys);
    regw(RA_DISPCTRL, 0x0000_0001);
}

fn dispPresent(next_fb_phys: u32) void {
    dispWaitVblank();
    regw(RA_DISPADDR, next_fb_phys);
    regw(RA_DISPCTRL, 0x0000_0001);
}

// -----------------
// Draw helpers
// -----------------
inline fn drawCmd(v: u32) void {
    regw(RA_DRAWCMD, v);
}

fn drawBeginFrame(dst_fb_phys: u32, w: u32, h: u32) void {
    // SETFRAME
    drawCmd(CMD_SETFRAME);
    drawCmd(dst_fb_phys);
    drawCmd(pack2(w, h));

    // SETDRAWAREA (full screen)
    drawCmd(CMD_SETDRAWAREA);
    drawCmd(0); // (x=0,y=0)
    drawCmd(pack2(w, h));
}

fn drawSetColor(rgb: u32) void {
    drawCmd(CMD_SETFCOLOR);
    drawCmd(rgb); // 0x00RRGGBB
}

fn drawPatBlt(x: u32, y: u32, w: u32, h: u32) void {
    drawCmd(CMD_PATBLT);
    drawCmd(pack2(x, y));
    drawCmd(pack2(w, h));
}

fn drawExecAndWait() void {
    drawCmd(CMD_EODL);

    regw(RA_DRAWCTRL, 0x0000_0001); // EXE
    while ((regr(RA_DRAWSTAT) & 0x0000_0001) != 0) {} // busy wait
    regw(RA_DRAWCTRL, 0x0000_0002); // RST
}

// -----------------
// mailbox helpers
// -----------------
fn loadFbPhys32(mailbox_addr: usize) u32 {
    const p: *const volatile u64 = @ptrFromInt(mailbox_addr);
    const v = p.*;
    return @intCast(v & 0xFFFF_FFFF);
}

// simple busy delay (no interrupts needed)
fn delay(iter: u32) void {
    var i: u32 = 0;
    while (i < iter) : (i += 1) {
        asm volatile ("" ::: .{ .memory = true });
    }
}

pub export fn main() callconv(.c) noreturn {
    const start = @intFromPtr(&__bss_start);
    const end = @intFromPtr(&__bss_end);
    const len: usize = end - start;
    const bss_ptr: [*]u8 = @ptrFromInt(start);
    @memset(bss_ptr[0..len], 0);

    uart.putString("hello world!\n");

    // get two framebuffer physical addresses from mailbox
    const fb0 = loadFbPhys32(MAILBOX_FB0_ADDR);
    var fb1 = loadFbPhys32(MAILBOX_FB1_ADDR);

    if (fb0 == 0) {
        uart.putString("MAILBOX fb0=0 (boot notebook did not write it)\n");
        while (true) {}
    }
    if (fb1 == 0) {
        uart.putString("MAILBOX fb1=0 -> fallback: single buffer\n");
        fb1 = fb0;
    }

    var front: u32 = fb0;
    var back: u32 = fb1;

    // start display
    dispInit(front);

    var frame: u32 = 0;
    while (true) : (frame += 1) {
        // render into back buffer
        drawBeginFrame(back, WIDTH, HEIGHT);

        // clear (black)
        drawSetColor(0x0000_0000);
        drawPatBlt(0, 0, WIDTH, HEIGHT);

        // 3 moving rectangles (RGB)
        const rw: u32 = 120;
        const rh: u32 = 90;

        const x0: u32 = (frame * 3) % (WIDTH - rw);
        const y0: u32 = (frame * 2) % (HEIGHT - rh);

        const x1: u32 = (frame * 5 + 200) % (WIDTH - rw);
        const y1: u32 = (frame * 3 + 100) % (HEIGHT - rh);

        const x2: u32 = (frame * 7 + 400) % (WIDTH - rw);
        const y2: u32 = (frame * 4 + 50) % (HEIGHT - rh);

        drawSetColor(0x00FF_0000); // red
        drawPatBlt(x0, y0, rw, rh);

        drawSetColor(0x0000_FF00); // green
        drawPatBlt(x1, y1, rw, rh);

        drawSetColor(0x0000_00FF); // blue
        drawPatBlt(x2, y2, rw, rh);

        drawExecAndWait();

        // present (vblank-synced) and swap
        dispPresent(back);

        const tmp = front;
        front = back;
        back = tmp;

        // vblank already paces you; extra delay only if you want slower animation
        // delay(2_000_00);
    }
}

pub export fn _start() linksection(".text.init") callconv(.naked) noreturn {
    asm volatile (
        \\ mv sp, %[stack]
        \\ j main
        :
        : [stack] "r" (@intFromPtr(&_stack_top)),
        : .{ .memory = true });
}

const uart = @import("uart.zig");
