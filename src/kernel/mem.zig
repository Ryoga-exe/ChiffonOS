const std = @import("std");
pub const BumpAllocator = @import("mem/BumpAllocator.zig");

pub var bump = BumpAllocator.newUninit();

pub fn init() void {
    bump.initFromLinker();
}

pub fn allocator() std.mem.Allocator {
    return bump.allocator();
}
