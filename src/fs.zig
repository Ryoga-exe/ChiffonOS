const std = @import("std");
const bootinfo = @import("bootinfo.zig");
const tar = @import("fs/tar.zig");

pub const FsType = bootinfo.FsType;

pub const Fs = struct {
    kind: FsType,
    tarfs: tar.TarFs,
    base: usize,
    size: usize,

    pub fn none() Fs {
        return .{ .kind = .none, .tarfs = undefined, .base = 0, .size = 0 };
    }

    pub fn initFromBootInfo(bi: bootinfo.Info) Fs {
        if (!bi.has_fs) return none();
        return switch (bi.fs_type) {
            .tar => .{
                .kind = .tar,
                .tarfs = tar.TarFs.init(bi.fs_base, bi.fs_size),
                .base = bi.fs_base,
                .size = bi.fs_size,
            },
            else => none(),
        };
    }

    pub fn list(self: *const Fs, writer: *std.Io.Writer) void {
        switch (self.kind) {
            .tar => self.tarfs.list(writer),
            else => {
                writer.writeAll("[fs] no filesystem\n") catch {};
                writer.flush() catch {};
            },
        }
    }

    pub fn stat(self: *const Fs, writer: *std.Io.Writer, path: []const u8) void {
        switch (self.kind) {
            .tar => self.tarfs.stat(writer, path),
            else => {
                writer.writeAll("[fs] no filesystem\n") catch {};
                writer.flush() catch {};
            },
        }
    }

    pub fn cat(self: *const Fs, writer: *std.Io.Writer, path: []const u8) void {
        switch (self.kind) {
            .tar => self.tarfs.cat(writer, path),
            else => {
                writer.writeAll("[fs] no filesystem\n") catch {};
                writer.flush() catch {};
            },
        }
    }

    pub fn readFile(self: *const Fs, path: []const u8) ?[]const u8 {
        return switch (self.kind) {
            .tar => self.tarfs.readFile(path),
            else => null,
        };
    }

    pub fn info(self: *const Fs, writer: *std.Io.Writer) void {
        switch (self.kind) {
            .tar => {
                writer.print("[fs] type=tar base=0x{X:0>16} size=0x{X}\n", .{ self.base, self.size }) catch {};
                writer.flush() catch {};
            },
            else => {
                writer.writeAll("[fs] type=none\n") catch {};
                writer.flush() catch {};
            },
        }
    }
};

pub var fs: Fs = Fs.none();

pub fn init(info: ?bootinfo.Info) void {
    if (info) |bi| {
        fs = Fs.initFromBootInfo(bi);
    } else {
        fs = Fs.none();
    }
}

pub fn initFromBytes(bytes: []const u8) void {
    if (bytes.len == 0) {
        fs = Fs.none();
        return;
    }
    fs = Fs{
        .kind = .tar,
        .tarfs = tar.TarFs.init(@intFromPtr(bytes.ptr), bytes.len),
        .base = @intFromPtr(bytes.ptr),
        .size = bytes.len,
    };
}
