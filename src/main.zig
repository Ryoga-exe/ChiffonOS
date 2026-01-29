extern const __bss_start: u8;
extern const __bss_end: u8;
extern const _stack_top: u8;

pub export fn main() callconv(.c) noreturn {
    // bss clear
    const start = @intFromPtr(&__bss_start);
    const end = @intFromPtr(&__bss_end);
    const len: usize = end - start;
    const p: [*]u8 = @ptrFromInt(start);
    @memset(p[0..len], 0);

    uart.putString("booting ChiffonOS\n\n");

    const pair = mb.readFbPair();
    if (pair.fb0 == 0) {
        uart.putString("mailbox fb0=0\n");
        while (true) {}
    }

    uart.putString("[INFO] Frame buffer is OK, initialize graphics\n");

    var gfx = gfxm.Gfx.init(pair.fb0, pair.fb1);

    uart.putString("[INFO] Graphics initialized\n");

    var frame: u32 = 0;
    while (true) : (frame += 1) {
        gfx.begin();
        gfx.clear(0x0000_0000);

        const rw: u32 = 120;
        const rh: u32 = 90;
        const x0: u32 = (frame * 3) % (gfxm.width - rw);
        const y0: u32 = (frame * 2) % (gfxm.height - rh);

        gfx.fillRect(x0, y0, rw, rh, 0x00FF_0000);
        gfx.fillRect((x0 + 160) % (gfxm.width - rw), (y0 + 90) % (gfxm.height - rh), rw, rh, 0x0000_FF00);
        gfx.fillRect((x0 + 320) % (gfxm.width - rw), (y0 + 180) % (gfxm.height - rh), rw, rh, 0x0000_00FF);

        gfx.endAndPresent();
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

const mb = @import("mailbox.zig");
const gfxm = @import("gfx.zig");
const uart = @import("uart.zig");
