const mmio = @import("mmio.zig");

// mailbox (written by ipynb)
pub const fb0_addr: usize = 0x8000_2000;
pub const fb1_addr: usize = 0x8000_2008;

pub const FbPair = struct { fb0: u32, fb1: u32 };

fn load32(addr: usize) u32 {
    const v: u64 = mmio.read64(addr);
    return @intCast(v & 0xFFFF_FFFF);
}

pub fn readFbPair() FbPair {
    const fb0 = load32(fb0_addr);
    var fb1 = load32(fb1_addr);
    if (fb1 == 0) {
        fb1 = fb0; // single-buffer fallback
    }
    return .{ .fb0 = fb0, .fb1 = fb1 };
}
