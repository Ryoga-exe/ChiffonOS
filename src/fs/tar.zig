const std = @import("std");
const mem = @import("../mem.zig");

pub const TarFs = struct {
    base: [*]const u8,
    size: usize,

    pub fn init(base_addr: usize, size: usize) TarFs {
        _ = base_addr; // autofix
        _ = size; // autofix
    }

    pub fn list(self: *const TarFs, w: *std.Io.Writer) void {
        _ = self; // autofix
        _ = w; // autofix
    }

    pub fn stat(self: *const TarFs, w: *std.Io.Writer, path: []const u8) void {
        _ = self; // autofix
        _ = w; // autofix
        _ = path; // autofix
    }

    pub fn cat(self: *const TarFs, w: *std.Io.Writer, path: []const u8) void {
        _ = self; // autofix
        _ = w; // autofix
        _ = path; // autofix
    }

    pub fn readFile(self: *const TarFs, path: []const u8) ?[]const u8 {
        _ = self; // autofix
        _ = path; // autofix
    }

    fn bytes(self: *const TarFs) []const u8 {
        _ = self; // autofix
    }
};

fn pathEquals(path: []const u8, name: []const u8) bool {
    _ = path; // autofix
    _ = name; // autofix
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
