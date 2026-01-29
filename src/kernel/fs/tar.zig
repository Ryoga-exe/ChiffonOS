const std = @import("std");
const mem = @import("../mem.zig");

pub const TarFs = struct {
    base: [*]const u8,
    size: usize,

    pub fn init(base_addr: usize, size: usize) TarFs {
        return .{ .base = @ptrFromInt(base_addr), .size = size };
    }

    pub fn list(self: *const TarFs, writer: *std.Io.Writer) void {
        var name_buf: [256]u8 = undefined;
        var link_buf: [256]u8 = undefined;

        var reader = std.Io.Reader.fixed(self.bytes());
        var it = std.tar.Iterator.init(&reader, .{
            .file_name_buffer = &name_buf,
            .link_name_buffer = &link_buf,
        });

        var count: usize = 0;
        while (true) {
            const file = it.next() catch |err| {
                writer.print("[fs] tar error: {s}\n", .{@errorName(err)}) catch {};
                writer.flush() catch {};
                return;
            } orelse break;

            if (!isPrintable(file.kind)) continue;
            count += 1;
            writer.print("{d:>6}  {s}\n", .{ file.size, file.name }) catch {};
        }
        if (count == 0) {
            writer.writeAll("[fs] empty\n") catch {};
        }
        writer.flush() catch {};
    }

    pub fn stat(self: *const TarFs, writer: *std.Io.Writer, path: []const u8) void {
        var name_buf: [256]u8 = undefined;
        var link_buf: [256]u8 = undefined;

        var reader = std.Io.Reader.fixed(self.bytes());
        var it = std.tar.Iterator.init(&reader, .{
            .file_name_buffer = &name_buf,
            .link_name_buffer = &link_buf,
        });

        while (true) {
            const file = it.next() catch |err| {
                writer.print("[fs] tar error: {s}\n", .{@errorName(err)}) catch {};
                writer.flush() catch {};
                return;
            } orelse break;

            if (!isRegularOrDir(file.kind)) continue;
            if (pathEquals(path, file.name)) {
                writer.print("size={d} type={s}\n", .{ file.size, kindName(file.kind) }) catch {};
                writer.flush() catch {};
                return;
            }
        }
        writer.writeAll("[fs] not found\n") catch {};
        writer.flush() catch {};
    }

    pub fn cat(self: *const TarFs, writer: *std.Io.Writer, path: []const u8) void {
        var name_buf: [256]u8 = undefined;
        var link_buf: [256]u8 = undefined;

        var reader = std.Io.Reader.fixed(self.bytes());
        var it = std.tar.Iterator.init(&reader, .{
            .file_name_buffer = &name_buf,
            .link_name_buffer = &link_buf,
        });

        while (true) {
            const file = it.next() catch |err| {
                writer.print("[fs] tar error: {s}\n", .{@errorName(err)}) catch {};
                writer.flush() catch {};
                return;
            } orelse break;

            if (file.kind != .file) continue;
            if (pathEquals(path, file.name)) {
                std.tar.Iterator.streamRemaining(&it, file, writer) catch |err| {
                    writer.print("\n[fs] tar stream error: {s}\n", .{@errorName(err)}) catch {};
                    writer.flush() catch {};
                    return;
                };
                writer.flush() catch {};
                return;
            }
        }
        writer.writeAll("[fs] not found\n") catch {};
        writer.flush() catch {};
    }

    pub fn readFile(self: *const TarFs, path: []const u8) ?[]const u8 {
        var name_buf: [256]u8 = undefined;
        var link_buf: [256]u8 = undefined;

        var reader = std.Io.Reader.fixed(self.bytes());
        var it = std.tar.Iterator.init(&reader, .{
            .file_name_buffer = &name_buf,
            .link_name_buffer = &link_buf,
        });

        while (true) {
            const maybe = it.next() catch return null;
            const file = maybe orelse break;
            if (file.kind != .file) continue;
            if (!pathEquals(path, file.name)) continue;
            if (file.size > std.math.maxInt(usize)) return null;
            const size: usize = @intCast(file.size);
            const a = mem.allocator();
            const buf = a.alloc(u8, size) catch return null;
            var writer = std.Io.Writer.fixed(buf);
            std.tar.Iterator.streamRemaining(&it, file, &writer) catch return null;
            return buf;
        }
        return null;
    }

    fn bytes(self: *const TarFs) []const u8 {
        return self.base[0..self.size];
    }
};

fn pathEquals(path: []const u8, name: []const u8) bool {
    if (std.mem.eql(u8, path, name)) return true;
    if (std.mem.startsWith(u8, name, "./") and std.mem.eql(u8, path, name[2..])) return true;
    if (std.mem.startsWith(u8, path, "./") and std.mem.eql(u8, path[2..], name)) return true;
    return false;
}

fn isPrintable(kind: std.tar.FileKind) bool {
    return kind == .file or kind == .directory;
}

fn isRegularOrDir(kind: std.tar.FileKind) bool {
    return kind == .file or kind == .directory;
}

fn kindName(kind: std.tar.FileKind) []const u8 {
    return switch (kind) {
        .file => "file",
        .directory => "dir",
        .sym_link => "symlink",
    };
}
