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
    uart.putString("next line\n");

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

const uart = struct {
    const base = 0x10000000;
    const rbr: *volatile u8 = @ptrFromInt(base + 0x00); // read
    const thr: *volatile u8 = @ptrFromInt(base + 0x00); // write
    const lsr: *volatile u8 = @ptrFromInt(base + 0x05); // status

    pub fn init() void {}

    pub fn putChar(c: u8) void {
        if (c == '\n') {
            putChar('\r');
        }
        while ((lsr.* & 0x20) == 0) {}
        thr.* = c;
    }

    pub fn putString(s: []const u8) void {
        for (s) |c| {
            putChar(c);
        }
    }
};
