pub const number = struct {
    pub const exit: usize = 1;
    pub const gfx_begin: usize = 2;
    pub const gfx_clear: usize = 3;
    pub const gfx_fill_rect: usize = 4;
    pub const gfx_present: usize = 5;
    pub const uart_putc: usize = 6;
    pub const uart_getc: usize = 7;
};

fn syscall0(num: usize) usize {
    return asm volatile (
        \\ ecall
        : [ret] "={a0}" (-> usize)
        : [num] "{a7}" (num)
        : .{ .memory = true });
}

fn syscall1(num: usize, a0_in: usize) usize {
    return asm volatile (
        \\ ecall
        : [ret] "={a0}" (-> usize)
        : [a0] "{a0}" (a0_in),
          [num] "{a7}" (num)
        : .{ .memory = true });
}

fn syscall5(num: usize, a0_in: usize, a1_in: usize, a2_in: usize, a3_in: usize, a4_in: usize) usize {
    return asm volatile (
        \\ ecall
        : [ret] "={a0}" (-> usize)
        : [a0] "{a0}" (a0_in),
          [a1] "{a1}" (a1_in),
          [a2] "{a2}" (a2_in),
          [a3] "{a3}" (a3_in),
          [a4] "{a4}" (a4_in),
          [num] "{a7}" (num)
        : .{ .memory = true });
}

pub inline fn exit(code: usize) noreturn {
    asm volatile (
        \\ ecall
        :
        : [code] "{a0}" (code),
          [num] "{a7}" (number.exit)
        : .{ .memory = true });
    unreachable;
}

pub inline fn gfxBegin() usize {
    return syscall0(number.gfx_begin);
}

pub inline fn gfxClear(rgb: usize) usize {
    return syscall1(number.gfx_clear, rgb);
}

pub inline fn gfxFillRect(x: usize, y: usize, w: usize, h: usize, rgb: usize) usize {
    return syscall5(number.gfx_fill_rect, x, y, w, h, rgb);
}

pub inline fn gfxPresent() usize {
    return syscall0(number.gfx_present);
}

pub inline fn uartPutc(c: u8) void {
    _ = syscall1(number.uart_putc, @intCast(c));
}

pub inline fn uartPuts(s: []const u8) void {
    for (s) |c| uartPutc(c);
}

pub inline fn uartGetcNonblock(out: *u8) bool {
    return syscall1(number.uart_getc, @intFromPtr(out)) != 0;
}
