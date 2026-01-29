pub inline fn write32(addr: usize, val: u32) void {
    const p: *volatile u32 = @ptrFromInt(addr);
    p.* = val;
}

pub inline fn read32(addr: usize) u32 {
    const p: *const volatile u32 = @ptrFromInt(addr);
    return p.*;
}

pub inline fn read64(addr: usize) u64 {
    const p: *const volatile u64 = @ptrFromInt(addr);
    return p.*;
}
