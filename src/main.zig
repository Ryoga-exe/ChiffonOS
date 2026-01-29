extern const __bss_start: u8;
extern const __bss_end: u8;
extern const _stack_top: u8;

pub export fn main() callconv(.c) noreturn {
    const start = @intFromPtr(&__bss_start);
    const end = @intFromPtr(&__bss_end);
    const len: usize = end - start;

    const bss_ptr: [*]u8 = @ptrFromInt(start);
    @memset(bss_ptr[0..len], 0);

    uart.putString("hello world!\n");
    uart.putString("enter char: ");

    const c = uart.getChar();

    uart.putString("\n");
    uart.putString("You entered: ");
    uart.putChar(c);
    uart.putString("\n");

    while (true) {
        asm volatile ("wfi");
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
