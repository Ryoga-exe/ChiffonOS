pub const number = struct {
    pub const exit: usize = 1;
};

pub inline fn exit(code: usize) noreturn {
    asm volatile (
        \\ mv a0, %[code]
        \\ li a7, %[num]
        \\ ecall
        \\ ebreak
        :
        : [code] "r" (code),
          [num] "i" (number.exit),
        : .{ .memory = true });
    unreachable;
}
