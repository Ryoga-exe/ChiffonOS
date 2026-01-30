const std = @import("std");

extern const __bss_start: u8;
extern const __bss_end: u8;
extern const _stack_top: u8;

pub const std_options = @import("sys/log.zig").default_log_options;
pub const panic = @import("sys/panic.zig").panic_fn;

pub export fn main() callconv(.c) noreturn {
    // bss clear
    const start = @intFromPtr(&__bss_start);
    const end = @intFromPtr(&__bss_end);
    const len: usize = end - start;
    const p: [*]u8 = @ptrFromInt(start);
    @memset(p[0..len], 0);

    var uart_buf: [64]u8 = undefined;
    var writer = Uart.writer(&uart_buf);
    const w = &writer.interface;

    w.print("booting ChiffonOS...\n", .{}) catch {};
    w.flush() catch {};

    w.writeAll(
        \\   _____ _     _  __  __             ____   _____
        \\  / ____| |   (_)/ _|/ _|           / __ \ / ____|
        \\ | |    | |__  _| |_| |_ ___  _ __ | |  | | (___
        \\ | |    | '_ \| |  _|  _/ _ \| '_ \| |  | |\___ \
        \\ | |____| | | | | | | || (_) | | | | |__| |____) |
        \\  \_____|_| |_|_|_| |_| \___/|_| |_|\____/|_____/
        \\
        \\
    ) catch {};
    w.flush() catch {};

    w.writeAll("[INFO] Initialize memory allocator\n") catch {};
    w.writeAll("[INFO] Initialize trap handler\n") catch {};
    w.writeAll("[INFO] Initialize timer\n") catch {};
    w.flush() catch {};
    mem.init();
    trap.init();
    timer.init(1_000_000);

    w.writeAll("[INFO] Initialize file system\n") catch {};
    w.flush() catch {};
    const bi = bootinfo.read();
    if (bi) |info| {
        fs.init(info);
    } else {
        fs.initFromBytes(rootfs_bytes);
    }

    if (build_options.qemu) {
        // QEMU
        w.writeAll("[INFO] Running on QEMU virt\n") catch {};
        w.writeAll("[INFO] Graphics are not supported on QEMU virt\n") catch {};
        w.flush() catch {};
    } else {
        w.writeAll("[INFO] Initialize frame buffer\n") catch {};
        w.flush() catch {};

        const pair = mb.readFbPair();
        if (pair.fb0 == 0) {
            w.writeAll("[ERROR] mailbox fb0=0\n") catch {};
            w.flush() catch {};
            while (true) {}
        }

        w.writeAll("[INFO] Frame buffer is OK, initialize graphics\n") catch {};
        w.flush() catch {};

        const gfx = gfxm.Gfx.init(pair.fb0, pair.fb1);
        _ = gfx; // TODO: 画面に絵を出す

        w.writeAll("[INFO] Graphics initialized successfully\n") catch {};
        w.flush() catch {};
    }

    shell.run(w);

    // var frame: u32 = 0;
    // while (true) : (frame += 1) {
    //     gfx.begin();
    //     gfx.clear(0x0000_0000);
    //
    //     const rw: u32 = 120;
    //     const rh: u32 = 90;
    //     const x0: u32 = (frame * 3) % (gfxm.width - rw);
    //     const y0: u32 = (frame * 2) % (gfxm.height - rh);
    //
    //     gfx.fillRect(x0, y0, rw, rh, 0x00FF_0000);
    //     gfx.fillRect((x0 + 160) % (gfxm.width - rw), (y0 + 90) % (gfxm.height - rh), rw, rh, 0x0000_FF00);
    //     gfx.fillRect((x0 + 320) % (gfxm.width - rw), (y0 + 180) % (gfxm.height - rh), rw, rh, 0x0000_00FF);
    //
    //     gfx.endAndPresent();
    // }
}

pub export fn _start() linksection(".text.init") callconv(.naked) noreturn {
    asm volatile (
        \\ lui gp, %hi(__global_pointer$)
        \\ addi gp, gp, %lo(__global_pointer$)
        \\ mv sp, %[stack]
        \\ j main
        :
        : [stack] "r" (@intFromPtr(&_stack_top)),
        : .{ .memory = true });
}

const mb = @import("drivers/mailbox.zig");
const gfxm = @import("gfx/gfx.zig");
const Uart = @import("common").Uart;
const trap = @import("sys/trap.zig");
const timer = @import("sys/timer.zig");
const mem = @import("mem.zig");
const shell = @import("shell.zig");
const bootinfo = @import("bootinfo.zig");
const fs = @import("fs.zig");
const build_options = @import("build_options");
const rootfs_bytes = if (build_options.qemu) @import("rootfs").data else &[_]u8{};
