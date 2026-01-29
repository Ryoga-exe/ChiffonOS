const std = @import("std");

const BumpAllocator = @This();
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;

extern const __heap_start: u8;
extern const __heap_end: u8;

start: usize,
end: usize,
next: usize,

const vtable = Allocator.VTable{
    .alloc = allocate,
    .resize = Allocator.noResize,
    .remap = Allocator.noRemap,
    .free = Allocator.noFree,
};

pub fn newUninit() BumpAllocator {
    return .{ .start = 0, .end = 0, .next = 0 };
}

pub fn initFromLinker(self: *BumpAllocator) void {
    const s = @intFromPtr(&__heap_start);
    const e = @intFromPtr(&__heap_end);
    self.init(s, e);
}

pub fn init(self: *BumpAllocator, start: usize, end: usize) void {
    self.start = start;
    self.end = end;
    self.next = start;
}

pub fn reset(self: *BumpAllocator) void {
    self.next = self.start;
}

pub fn alloc(self: *BumpAllocator, size: usize, alignment: usize) ?[*]u8 {
    const alignment_value = if (alignment == 0) @alignOf(usize) else alignment;
    std.debug.assert(std.math.isPowerOfTwo(alignment_value));

    const aligned = std.mem.alignForward(usize, self.next, alignment_value);
    if (aligned > self.end) return null;
    const available = self.end - aligned;
    if (size > available) return null;

    self.next = aligned + size;
    return @ptrFromInt(aligned);
}

pub fn allocSlice(self: *BumpAllocator, size: usize, alignment: usize) ?[]u8 {
    const p = self.alloc(size, alignment) orelse return null;
    return p[0..size];
}

pub fn allocType(self: *BumpAllocator, comptime T: type) ?*T {
    const p = self.alloc(@sizeOf(T), @alignOf(T)) orelse return null;
    return @ptrCast(@alignCast(p));
}

pub fn allocSliceType(self: *BumpAllocator, comptime T: type, count: usize) ?[]T {
    const bytes = std.math.mul(usize, @sizeOf(T), count) catch return null;
    const p = self.alloc(bytes, @alignOf(T)) orelse return null;
    const tp: [*]T = @ptrCast(@alignCast(p));
    return tp[0..count];
}

pub fn usedBytes(self: *const BumpAllocator) usize {
    return self.next - self.start;
}

pub fn remainingBytes(self: *const BumpAllocator) usize {
    return self.end - self.next;
}

pub fn allocator(self: *BumpAllocator) Allocator {
    return .{
        .ptr = self,
        .vtable = &vtable,
    };
}

fn allocate(
    ctx: *anyopaque,
    len: usize,
    alignment: Alignment,
    _: usize,
) ?[*]u8 {
    const self: *BumpAllocator = @ptrCast(@alignCast(ctx));
    const alignment_value = alignment.toByteUnits();
    const aligned = std.mem.alignForward(usize, self.next, alignment_value);
    if (aligned > self.end) return null;
    const available = self.end - aligned;
    if (len > available) return null;

    self.next = aligned + len;
    return @ptrFromInt(aligned);
}
