const std = @import("std");

extern const __heap_start: u8;
extern const __heap_end: u8;

pub const BumpAllocator = struct {
    start: usize,
    end: usize,
    next: usize,

    pub fn init() BumpAllocator {
        const s = @intFromPtr(&__heap_start);
        const e = @intFromPtr(&__heap_end);
        return .{ .start = s, .end = e, .next = s };
    }

    pub fn reset(self: *BumpAllocator) void {
        self.next = self.start;
    }

    pub fn alloc(self: *BumpAllocator, size: usize, alignment: usize) ?[*]u8 {
        const alignment_value = if (alignment == 0) @alignOf(usize) else alignment;
        std.debug.assert(isPowerOfTwo(alignment_value));

        const aligned = alignUp(self.next, alignment_value);
        const new_next = aligned + size;
        if (new_next > self.end) return null;

        self.next = new_next;
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
};

pub var heap: BumpAllocator = .{ .start = 0, .end = 0, .next = 0 };

pub fn init() void {
    heap = BumpAllocator.init();
}

fn alignUp(value: usize, alignment_value: usize) usize {
    return (value + alignment_value - 1) & ~(alignment_value - 1);
}

fn isPowerOfTwo(value: usize) bool {
    return value != 0 and (value & (value - 1)) == 0;
}
