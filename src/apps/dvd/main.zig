const syscall = @import("common").syscall;

inline fn rdcycle() u64 {
    return asm volatile ("rdcycle %[out]"
        : [out] "=&r" (-> u64),
    );
}

fn busyWaitCycles(delta: u64) void {
    const start = rdcycle();
    while (rdcycle() - start < delta) {}
}

fn nextColor(idx: *u32) u32 {
    const palette = [_]u32{
        0x00FF_0000,
        0x0000_FF00,
        0x0000_00FF,
        0x00FF_FF00,
        0x00FF_00FF,
        0x0000_FFFF,
        0x00FF_FFFF,
    };
    const i = idx.* % palette.len;
    idx.* = idx.* + 1;
    return palette[i];
}

var stack: [4096]u8 align(16) = undefined;

pub export fn _start() callconv(.naked) noreturn {
    asm volatile (
        \\ lui gp, %hi(__global_pointer$)
        \\ addi gp, gp, %lo(__global_pointer$)
        \\ mv sp, %[stack]
        \\ j main
        :
        : [stack] "r" (@intFromPtr(&stack) + stack.len),
        : .{ .memory = true });
}

pub export fn main() noreturn {
    syscall.uartPuts("[dvd] app start\n");
    const w: u32 = 640;
    const h: u32 = 480;

    var x: i32 = 40;
    var y: i32 = 30;
    var dx: i32 = 3;
    var dy: i32 = 2;
    const rw: i32 = 120;
    const rh: i32 = 90;
    var color_idx: u32 = 0;
    var color: u32 = nextColor(&color_idx);

    while (true) {
        if (syscall.gfxBegin() != 0) {
            syscall.uartPuts("[dvd] gfx not ready; exit\n");
            syscall.exit(0);
        }
        _ = syscall.gfxClear(0x0000_0000);
        _ = syscall.gfxFillRect(@intCast(x), @intCast(y), @intCast(rw), @intCast(rh), color);
        _ = syscall.gfxPresent();

        x += dx;
        y += dy;
        if (x <= 0) {
            x = 0;
            dx = -dx;
            color = nextColor(&color_idx);
        } else if (x + rw >= @as(i32, @intCast(w))) {
            x = @as(i32, @intCast(w)) - rw;
            dx = -dx;
            color = nextColor(&color_idx);
        }
        if (y <= 0) {
            y = 0;
            dy = -dy;
            color = nextColor(&color_idx);
        } else if (y + rh >= @as(i32, @intCast(h))) {
            y = @as(i32, @intCast(h)) - rh;
            dy = -dy;
            color = nextColor(&color_idx);
        }

        busyWaitCycles(2_000_000);

        var ch: u8 = 0;
        if (syscall.uartGetcNonblock(&ch)) {
            if (ch == 'q' or ch == 'Q') {
                syscall.uartPuts("[dvd] exit by key\n");
                syscall.exit(0);
            }
        }
    }
}
