const std = @import("std");
const csr = @import("sys/csr.zig");

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

const ExecContext = extern struct {
    saved_sp: usize = 0,
    saved_pc: usize = 0,
    saved_gp: usize = 0,
    saved_tp: usize = 0,
    saved_s0: usize = 0,
    saved_s1: usize = 0,
    saved_s2: usize = 0,
    saved_s3: usize = 0,
    saved_s4: usize = 0,
    saved_s5: usize = 0,
    saved_s6: usize = 0,
    saved_s7: usize = 0,
    saved_s8: usize = 0,
    saved_s9: usize = 0,
    saved_s10: usize = 0,
    saved_s11: usize = 0,

    // NOTE: We "longjmp" back into the middle of exec() via saved_pc.
    // The compiler isn't aware that control can re-enter at label `1:` inside
    // the inline asm, so in optimized builds it may keep live values in
    // caller-saved registers across the asm. In practice, it sometimes keeps
    // a base pointer in a0 and reuses it right after returning.
    // We snapshot a0 before jumping to the app and restore it in the return
    // trampoline so the resumed code sees the expected value.
    saved_a0: usize = 0,
    exit_code: usize = 0,
    exit_called: usize = 0,
    active: usize = 0,
};

pub export var exec_ctx: ExecContext = .{};

pub fn handleExit(code: usize) bool {
    if (exec_ctx.active == 0) return false;
    exec_ctx.exit_code = code;
    exec_ctx.exit_called = 1;
    return true;
}

pub fn exitTrampoline() usize {
    return @intFromPtr(&execReturnTrampoline);
}

pub fn exec(bytes: []const u8, w: *std.Io.Writer) ExecError!void {
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

    exec_ctx.exit_code = 0;
    exec_ctx.exit_called = 0;
    exec_ctx.active = 1;
    _ = csr.readCSR("mepc");
    asm volatile (
        \\ la t0, exec_ctx
        \\ sd a0, %[off_saved_a0](t0)
        \\ la t1, 1f
        \\ sd t1, %[off_pc](t0)
        \\ sd sp, %[off_sp](t0)
        \\ sd gp, %[off_gp](t0)
        \\ sd tp, %[off_tp](t0)
        \\ sd s0, %[off_s0](t0)
        \\ sd s1, %[off_s1](t0)
        \\ sd s2, %[off_s2](t0)
        \\ sd s3, %[off_s3](t0)
        \\ sd s4, %[off_s4](t0)
        \\ sd s5, %[off_s5](t0)
        \\ sd s6, %[off_s6](t0)
        \\ sd s7, %[off_s7](t0)
        \\ sd s8, %[off_s8](t0)
        \\ sd s9, %[off_s9](t0)
        \\ sd s10, %[off_s10](t0)
        \\ sd s11, %[off_s11](t0)
        \\ la sp, _stack_top
        \\ jr %[entry]
        \\1:
        :
        : [entry] "r" (entry),
          [off_saved_a0] "i" (@offsetOf(ExecContext, "saved_a0")),
          [off_pc] "i" (@offsetOf(ExecContext, "saved_pc")),
          [off_sp] "i" (@offsetOf(ExecContext, "saved_sp")),
          [off_gp] "i" (@offsetOf(ExecContext, "saved_gp")),
          [off_tp] "i" (@offsetOf(ExecContext, "saved_tp")),
          [off_s0] "i" (@offsetOf(ExecContext, "saved_s0")),
          [off_s1] "i" (@offsetOf(ExecContext, "saved_s1")),
          [off_s2] "i" (@offsetOf(ExecContext, "saved_s2")),
          [off_s3] "i" (@offsetOf(ExecContext, "saved_s3")),
          [off_s4] "i" (@offsetOf(ExecContext, "saved_s4")),
          [off_s5] "i" (@offsetOf(ExecContext, "saved_s5")),
          [off_s6] "i" (@offsetOf(ExecContext, "saved_s6")),
          [off_s7] "i" (@offsetOf(ExecContext, "saved_s7")),
          [off_s8] "i" (@offsetOf(ExecContext, "saved_s8")),
          [off_s9] "i" (@offsetOf(ExecContext, "saved_s9")),
          [off_s10] "i" (@offsetOf(ExecContext, "saved_s10")),
          [off_s11] "i" (@offsetOf(ExecContext, "saved_s11")),
        : .{ .memory = true });
    exec_ctx.active = 0;

    if (exec_ctx.exit_called != 0) {
        w.print("[exec] exit code={d}\n", .{exec_ctx.exit_code}) catch {};
        w.flush() catch {};
    } else {
        w.writeAll("[exec] returned\n") catch {};
        w.flush() catch {};
    }
}

pub export fn execReturnTrampoline() callconv(.naked) void {
    asm volatile (
        \\ la t0, exec_ctx
        \\ ld sp, %[off_sp](t0)
        \\ ld gp, %[off_gp](t0)
        \\ ld tp, %[off_tp](t0)
        \\ ld s0, %[off_s0](t0)
        \\ ld s1, %[off_s1](t0)
        \\ ld s2, %[off_s2](t0)
        \\ ld s3, %[off_s3](t0)
        \\ ld s4, %[off_s4](t0)
        \\ ld s5, %[off_s5](t0)
        \\ ld s6, %[off_s6](t0)
        \\ ld s7, %[off_s7](t0)
        \\ ld s8, %[off_s8](t0)
        \\ ld s9, %[off_s9](t0)
        \\ ld s10, %[off_s10](t0)
        \\ ld s11, %[off_s11](t0)
        \\ ld a0, %[off_saved_a0](t0)
        \\ ld t0, %[off_pc](t0)
        \\ jr t0
        :
        : [off_sp] "i" (@offsetOf(ExecContext, "saved_sp")),
          [off_saved_a0] "i" (@offsetOf(ExecContext, "saved_a0")),
          [off_pc] "i" (@offsetOf(ExecContext, "saved_pc")),
          [off_gp] "i" (@offsetOf(ExecContext, "saved_gp")),
          [off_tp] "i" (@offsetOf(ExecContext, "saved_tp")),
          [off_s0] "i" (@offsetOf(ExecContext, "saved_s0")),
          [off_s1] "i" (@offsetOf(ExecContext, "saved_s1")),
          [off_s2] "i" (@offsetOf(ExecContext, "saved_s2")),
          [off_s3] "i" (@offsetOf(ExecContext, "saved_s3")),
          [off_s4] "i" (@offsetOf(ExecContext, "saved_s4")),
          [off_s5] "i" (@offsetOf(ExecContext, "saved_s5")),
          [off_s6] "i" (@offsetOf(ExecContext, "saved_s6")),
          [off_s7] "i" (@offsetOf(ExecContext, "saved_s7")),
          [off_s8] "i" (@offsetOf(ExecContext, "saved_s8")),
          [off_s9] "i" (@offsetOf(ExecContext, "saved_s9")),
          [off_s10] "i" (@offsetOf(ExecContext, "saved_s10")),
          [off_s11] "i" (@offsetOf(ExecContext, "saved_s11")),
        : .{ .memory = true });
}
