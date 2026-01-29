const std = @import("std");
const Uart = @import("common").Uart;
const mem = @import("mem.zig");
const timer = @import("sys/timer.zig");
const fs = @import("fs.zig");
const exec = @import("exec.zig");

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
                Uart.putc('\n');
                break;
            },
            0x08, 0x7f => { // backspace / delete
                if (len > 0) {
                    len -= 1;
                    Uart.putc(0x08);
                    Uart.putc(' ');
                    Uart.putc(0x08);
                }
            },
            else => {
                if (len + 1 < buf.len) {
                    buf[len] = c;
                    len += 1;
                    Uart.putc(c);
                }
            },
        }
    }
    return buf[0..len];
}

fn handleCommand(w: *std.Io.Writer, line: []const u8) void {
    var it = std.mem.tokenizeScalar(u8, line, ' ');
    const cmd = it.next() orelse return;

    // NOTE: std.StaticStringMap とかのほうが良さそう

    if (std.mem.eql(u8, cmd, "help")) {
        w.writeAll(
            \\commands:
            \\  help            show this help
            \\  mem             show heap usage
            \\  alloc [n]       allocate n bytes (default 16)
            \\  reset           reset bump allocator
            \\  fs              show filesystem info
            \\  ls              list files
            \\  stat <path>     show file info
            \\  cat <path>      print file contents
            \\  exec <path>     load ELF and jump
            \\  panic           trigger panic
            \\  trap            trigger ebreak
            \\  ticks           show timer ticks
            \\  sleep <ticks>   wait for N timer ticks
            \\
        ) catch {};
        w.flush() catch {};
        return;
    }

    if (std.mem.eql(u8, cmd, "mem")) {
        const start = mem.bump.start;
        const end = mem.bump.end;
        const used = mem.bump.usedBytes();
        const remaining = mem.bump.remainingBytes();
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
        const a = mem.bump.allocator();
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
        mem.bump.reset();
        w.writeAll("[alloc] reset\n") catch {};
        w.flush() catch {};
        return;
    }

    if (std.mem.eql(u8, cmd, "fs")) {
        fs.fs.info(w);
        return;
    }

    if (std.mem.eql(u8, cmd, "ls")) {
        fs.fs.list(w);
        return;
    }

    if (std.mem.eql(u8, cmd, "stat")) {
        const path = it.next() orelse {
            w.writeAll("usage: stat <path>\n") catch {};
            w.flush() catch {};
            return;
        };
        fs.fs.stat(w, path);
        return;
    }

    if (std.mem.eql(u8, cmd, "cat")) {
        const path = it.next() orelse {
            w.writeAll("usage: cat <path>\n") catch {};
            w.flush() catch {};
            return;
        };
        fs.fs.cat(w, path);
        return;
    }

    if (std.mem.eql(u8, cmd, "exec")) {
        const path = it.next() orelse {
            w.writeAll("usage: exec <path>\n") catch {};
            w.flush() catch {};
            return;
        };
        const data = fs.fs.readFile(path) orelse {
            w.writeAll("[exec] not found\n") catch {};
            w.flush() catch {};
            return;
        };
        exec.exec(data, w) catch |err| {
            w.print("[exec] error: {s}\n", .{@errorName(err)}) catch {};
            w.flush() catch {};
            return;
        };
    }

    if (std.mem.eql(u8, cmd, "panic")) {
        @panic("panic from shell");
    }

    if (std.mem.eql(u8, cmd, "ticks")) {
        w.print("[timer] ticks={d} now={d} interval={d}\n", .{ timer.ticks, timer.now(), timer.interval }) catch {};
        w.flush() catch {};
        return;
    }

    if (std.mem.eql(u8, cmd, "sleep")) {
        const arg = it.next() orelse {
            w.writeAll("usage: sleep <ticks>\n") catch {};
            w.flush() catch {};
            return;
        };
        const duration = parseUsize(arg) orelse 0;
        if (duration == 0) {
            w.writeAll("usage: sleep <ticks>\n") catch {};
            w.flush() catch {};
            return;
        }
        const start = timer.ticks;
        while (timer.ticks - start < duration) {
            asm volatile ("wfi");
        }
        return;
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
