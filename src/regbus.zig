const mmio = @import("mmio.zig");

const base: usize = 0x1001_0000;

pub inline fn w(off: u32, val: u32) void {
    mmio.write32(base + off, val);
}

pub inline fn r(off: u32) u32 {
    return mmio.read32(base + off);
}

pub inline fn pack2(hi: u32, lo: u32) u32 {
    return (hi << 16) | (lo & 0xFFFF);
}
