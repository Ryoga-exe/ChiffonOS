const std = @import("std");

extern const __bss_start: u8;
extern const __bss_end: u8;
extern const _stack_top: u8;

pub const std_options = @import("log.zig").default_log_options;
pub const panic = @import("panic.zig").panic_fn;

pub export fn main() callconv(.c) noreturn {
    // bss clear
    const start = @intFromPtr(&__bss_start);
    const end = @intFromPtr(&__bss_end);
    const len: usize = end - start;
    const p: [*]u8 = @ptrFromInt(start);
    @memset(p[0..len], 0);

    alloc.init();
    trap.init();

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
    ) catch {};
    w.flush() catch {};

    allocatorSmokeTest(w);

    asm volatile ("ebreak");

    while (true) {}

    // const pair = mb.readFbPair();
    // if (pair.fb0 == 0) {
    //     uart.putString("mailbox fb0=0\n");
    //     while (true) {}
    // }
    //
    // uart.putString("[INFO] Frame buffer is OK, initialize graphics\n");
    //
    // var gfx = gfxm.Gfx.init(pair.fb0, pair.fb1);
    //
    // uart.putString("[INFO] Graphics initialized\n");
    //
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
        \\ mv sp, %[stack]
        \\ j main
        :
        : [stack] "r" (@intFromPtr(&_stack_top)),
        : .{ .memory = true });
}

const mb = @import("mailbox.zig");
const gfxm = @import("gfx.zig");
const Uart = @import("Uart.zig");
const trap = @import("trap.zig");
const alloc = @import("alloc.zig");

fn allocatorSmokeTest(w: *std.Io.Writer) void {
    const heap_start = alloc.heap.start;
    const heap_end = alloc.heap.end;
    const heap_size = heap_end - heap_start;

    w.print("[ALLOC] heap 0x{X:0>16}..0x{X:0>16} ({d} bytes)\n", .{ heap_start, heap_end, heap_size }) catch {};

    const a = alloc.heap.allocator();
    const buf1 = a.alloc(u8, 64) catch {
        w.print("[ALLOC] alloc 64 bytes failed\n", .{}) catch {};
        return;
    };
    w.print("[ALLOC] alloc 64 @ 0x{X:0>16}\n", .{@intFromPtr(buf1.ptr)}) catch {};

    const buf2 = a.alloc(u32, 16) catch {
        w.print("[ALLOC] alloc 16 u32 failed\n", .{}) catch {};
        return;
    };
    w.print("[ALLOC] alloc 16 u32 @ 0x{X:0>16}\n", .{@intFromPtr(buf2.ptr)}) catch {};

    w.print("[ALLOC] used={d} remaining={d}\n", .{ alloc.heap.usedBytes(), alloc.heap.remainingBytes() }) catch {};
    w.flush() catch {};
}
