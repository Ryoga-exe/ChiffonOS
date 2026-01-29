const std = @import("std");
const Uart = @import("Uart.zig");

fn log(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime fmt: []const u8,
    args: anytype,
) void {
    _ = level;
    _ = scope;

    var writer = Uart.writer(&.{});
    const w = &writer.interface;

    w.print(fmt ++ "\n", args) catch unreachable;
}

pub const default_log_options = std.Options{
    .logFn = log,
};
