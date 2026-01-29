const std = @import("std");
const Uart = @import("Uart.zig");
const alloc = @import("alloc.zig");

pub fn run(w: *std.Io.Writer) noreturn {
    var line_buf: [128]u8 = undefined;

    w.writeAll("\n[Shell] type 'help' for commands\n") catch {};
    w.flush() catch {};

    while (true) {
        prompt(w);
        const line = readLine(&line_buf);
        if (line.len == 0) continue;
        handleCommand(w, line);
    }
}

fn prompt(w: *std.Io.Writer) void {
    w.writeAll("> ") catch {};
    w.flush() catch {};
}

fn readLine(buf: []u8) []u8 {
    var len: usize = 0;
    while (true) {
        const c = Uart.getChar();
        switch (c) {
            '\r', '\n' => {
                Uart.putChar('\n');
                break;
            },
            0x08, 0x7f => { // backspace / delete
                if (len > 0) {
                    len -= 1;
                    Uart.putChar(0x08);
                    Uart.putChar(' ');
                    Uart.putChar(0x08);
                }
            },
            else => {
                if (len + 1 < buf.len) {
                    buf[len] = c;
                    len += 1;
                    Uart.putChar(c);
                }
            },
        }
    }
    return buf[0..len];
}

fn handleCommand(w: *std.Io.Writer, line: []const u8) void {
    var it = std.mem.tokenizeScalar(u8, line, ' ');
    const cmd = it.next() orelse return;

    if (std.mem.eql(u8, cmd, "help")) {
        w.writeAll(
            \\commands:
            \\  help            show this help
            \\  mem             show heap usage
            \\  alloc [n]       allocate n bytes (default 16)
            \\  reset           reset bump allocator
            \\  panic           trigger panic
            \\  trap            trigger ebreak
            \\
        ) catch {};
        w.flush() catch {};
        return;
    }

    if (std.mem.eql(u8, cmd, "mem")) {
        const start = alloc.heap.start;
        const end = alloc.heap.end;
        const used = alloc.heap.usedBytes();
        const remaining = alloc.heap.remainingBytes();
        w.print("[mem] heap 0x{X:0>16}..0x{X:0>16} used={d} remaining={d}\n", .{ start, end, used, remaining }) catch {};
        w.flush() catch {};
        return;
    }

    if (std.mem.eql(u8, cmd, "alloc")) {
        const size = if (it.next()) |s| parseUsize(s) orelse 0 else 16;
        if (size == 0) {
            w.writeAll("[alloc] invalid size\n") catch {};
            w.flush() catch {};
            return;
        }
        const a = alloc.heap.allocator();
        const buf = a.alloc(u8, size) catch {
            w.writeAll("[alloc] out of memory\n") catch {};
            w.flush() catch {};
            return;
        };
        w.print("[alloc] {d} bytes @ 0x{X:0>16}\n", .{ size, @intFromPtr(buf.ptr) }) catch {};
        w.flush() catch {};
        return;
    }

    if (std.mem.eql(u8, cmd, "reset")) {
        alloc.heap.reset();
        w.writeAll("[alloc] reset\n") catch {};
        w.flush() catch {};
        return;
    }

    if (std.mem.eql(u8, cmd, "panic")) {
        @panic("panic from shell");
    }

    if (std.mem.eql(u8, cmd, "trap")) {
        asm volatile ("ebreak");
        return;
    }

    w.print("unknown command: {s}\n", .{cmd}) catch {};
    w.flush() catch {};
}

fn parseUsize(s: []const u8) ?usize {
    return std.fmt.parseInt(usize, s, 0) catch null;
}
