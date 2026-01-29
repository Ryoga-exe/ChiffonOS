const std = @import("std");

pub const ExecError = error{
    InvalidElf,
    UnsupportedElfClass,
    UnsupportedEndian,
    UnsupportedMachine,
    SegmentOutOfBounds,
    SegmentOverlapKernel,
    SegmentOutOfRange,
};

extern const __image_end: u8;
extern const __app_base: u8;
extern const __app_limit: u8;
extern const _stack_top: u8;

pub fn exec(bytes: []const u8, w: *std.Io.Writer) ExecError!noreturn {
    var reader = std.Io.Reader.fixed(bytes);
    const hdr = std.elf.Header.read(&reader) catch return error.InvalidElf;

    if (!hdr.is_64) return error.UnsupportedElfClass;
    if (hdr.endian != .little) return error.UnsupportedEndian;
    if (hdr.machine != std.elf.EM.RISCV) return error.UnsupportedMachine;

    const image_end = @intFromPtr(&__image_end);
    const app_base = @intFromPtr(&__app_base);
    const app_limit = @intFromPtr(&__app_limit);
    const min_base = if (app_base > image_end) app_base else image_end;

    var ph_it = std.elf.ProgramHeaderBufferIterator{
        .elf_header = hdr,
        .buf = bytes,
    };
    while (true) {
        const maybe = ph_it.next() catch return error.InvalidElf;
        const ph = maybe orelse break;
        if (ph.p_type != std.elf.PT_LOAD) continue;
        if (ph.p_memsz == 0) continue;

        const vaddr: usize = @intCast(ph.p_vaddr);
        const offset: usize = @intCast(ph.p_offset);
        const filesz: usize = @intCast(ph.p_filesz);
        const memsz: usize = @intCast(ph.p_memsz);

        if (vaddr < min_base) return error.SegmentOverlapKernel;
        if (offset + filesz > bytes.len) return error.SegmentOutOfBounds;
        const seg_end = std.math.add(usize, vaddr, memsz) catch return error.SegmentOutOfRange;
        if (seg_end > app_limit) return error.SegmentOutOfRange;

        const dst: [*]u8 = @ptrFromInt(vaddr);
        @memcpy(dst[0..filesz], bytes[offset .. offset + filesz]);
        if (memsz > filesz) {
            @memset(dst[filesz..memsz], 0);
        }
    }

    const entry: usize = @intCast(hdr.entry);
    if (entry < min_base) return error.SegmentOverlapKernel;
    if (entry >= app_limit) return error.SegmentOutOfRange;

    w.print("[exec] jump to 0x{X:0>16}\n", .{entry}) catch {};
    w.flush() catch {};

    jump(entry);
}

fn jump(entry: usize) noreturn {
    const entry_fn: *const fn () callconv(.c) noreturn = @ptrFromInt(entry);
    asm volatile ("mv sp, %[stack]"
        :
        : [stack] "r" (@intFromPtr(&_stack_top)),
        : .{ .memory = true });
    entry_fn();
}
