const std = @import("std");

const base: usize = 0x1000_0000;
const rbr: *volatile u8 = @ptrFromInt(base + 0x00); // read
const thr: *volatile u8 = @ptrFromInt(base + 0x00); // write
const lsr: *volatile u8 = @ptrFromInt(base + 0x05); // status

pub fn init() void {}

inline fn rawPut(c: u8) void {
    while ((lsr.* & 0x20) == 0) {}
    thr.* = c;
}

pub fn putc(c: u8) void {
    if (c == '\n') rawPut('\r');
    rawPut(c);
}

pub fn puts(s: []const u8) void {
    for (s) |c| putc(c);
}

pub fn getChar() u8 {
    while ((lsr.* & 0x01) == 0) {}
    return rbr.*;
}

pub const Writer = struct {
    interface: std.Io.Writer,

    pub fn init(buffer: []u8) Writer {
        return .{
            .interface = .{
                .vtable = &.{
                    .drain = drain,
                },
                .buffer = buffer,
                .end = 0,
            },
        };
    }

    fn writeSlice(bytes: []const u8) void {
        for (bytes) |b| putc(b);
    }

    fn drain(io_w: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
        if (io_w.end != 0) {
            writeSlice(io_w.buffer[0..io_w.end]);
            io_w.end = 0;
        }

        var consumed: usize = 0;

        if (data.len > 1) {
            for (data[0 .. data.len - 1]) |chunk| {
                writeSlice(chunk);
                consumed += chunk.len;
            }
        }

        const pattern = data[data.len - 1];
        switch (pattern.len) {
            0 => {},
            1 => {
                var i: usize = 0;
                while (i < splat) : (i += 1) putc(pattern[0]);
                consumed += splat;
            },
            else => {
                var i: usize = 0;
                while (i < splat) : (i += 1) {
                    writeSlice(pattern);
                    consumed += pattern.len;
                }
            },
        }

        return consumed;
    }
};

pub fn writer(buffer: []u8) Writer {
    return Writer.init(buffer);
}
