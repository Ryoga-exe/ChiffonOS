const std = @import("std");
const BumpAllocator = @This();
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;

start: usize,
end: usize,
next: usize,

const vtable = Allocator.VTable{
    .alloc = allocate,
    .resize = Allocator.noResize,
    .remap = Allocator.noRemap,
    .free = Allocator.noFree,
};

fn allocate(
    ctx: *anyopaque,
    len: usize,
    alignment: std.mem.Alignment,
    _: usize,
) ?[*]u8 {
    const self: *BumpAllocator = @ptrCast(@alignCast(ctx));
    const alignment_value = alignment.toByteUnits();
    const aligned = std.mem.alignForward(usize, self.next, alignment_value);
    const new_next = aligned + len;
    if (new_next > self.end) {
        return null;
    }
    self.next = new_next;
    return @ptrFromInt(aligned);
}

pub fn newUninit() BumpAllocator {
    return BumpAllocator{
        .next_paddr = undefined,
        .paddr_end = undefined,
    };
}
