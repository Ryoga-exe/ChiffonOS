const syscall = @import("common").syscall;

extern fn doomgeneric_Create(argc: c_int, argv: [*]const ?[*:0]const u8) void;
extern fn doomgeneric_Tick() void;

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
    const arg0: [11:0]u8 = "doomgeneric".*;
    const arg0_ptr: [*:0]const u8 = @ptrCast(&arg0);
    var argv = [_]?[*:0]const u8{ arg0_ptr, null };

    doomgeneric_Create(1, &argv);

    while (true) {
        doomgeneric_Tick();
    }

    // Unreachable, but keep the compiler happy if it ever changes.
    syscall.exit(0);
}
