const uart = @import("common").Uart;

var stack: [4096]u8 align(16) = undefined;

pub export fn _start() callconv(.naked) noreturn {
    asm volatile (
        \\ mv sp, %[stack]
        \\ j main
        :
        : [stack] "r" (@intFromPtr(&stack) + stack.len),
        : .{ .memory = true });
}

pub export fn main() noreturn {
    uart.puts("[hello] exec OK\n");
    uart.puts("[hello] running in app\n");
    while (true) {
        asm volatile ("wfi");
    }
}
