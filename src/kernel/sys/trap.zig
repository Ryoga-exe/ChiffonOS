const std = @import("std");
const csr = @import("csr.zig");
const timer = @import("timer.zig");
const Uart = @import("common").Uart;

pub const TrapFrame = extern struct {
    x0: usize,
    ra: usize,
    sp: usize,
    gp: usize,
    tp: usize,
    t0: usize,
    t1: usize,
    t2: usize,
    s0: usize,
    s1: usize,
    a0: usize,
    a1: usize,
    a2: usize,
    a3: usize,
    a4: usize,
    a5: usize,
    a6: usize,
    a7: usize,
    s2: usize,
    s3: usize,
    s4: usize,
    s5: usize,
    s6: usize,
    s7: usize,
    s8: usize,
    s9: usize,
    s10: usize,
    s11: usize,
    t3: usize,
    t4: usize,
    t5: usize,
    t6: usize,
};

comptime {
    if (@sizeOf(TrapFrame) != 32 * @sizeOf(usize)) {
        @compileError("TrapFrame layout mismatch");
    }
}

pub fn init() void {
    const addr = @intFromPtr(&trapEntry);
    csr.writeCSR("mtvec", addr);
}

pub export fn trapEntry() callconv(.naked) void {
    asm volatile (
        \\ addi sp, sp, -256
        \\ sd zero, 0(sp)
        \\ sd ra, 8(sp)
        \\ sd gp, 24(sp)
        \\ sd tp, 32(sp)
        \\ sd t0, 40(sp)
        \\ sd t1, 48(sp)
        \\ sd t2, 56(sp)
        \\ sd s0, 64(sp)
        \\ sd s1, 72(sp)
        \\ sd a0, 80(sp)
        \\ sd a1, 88(sp)
        \\ sd a2, 96(sp)
        \\ sd a3, 104(sp)
        \\ sd a4, 112(sp)
        \\ sd a5, 120(sp)
        \\ sd a6, 128(sp)
        \\ sd a7, 136(sp)
        \\ sd s2, 144(sp)
        \\ sd s3, 152(sp)
        \\ sd s4, 160(sp)
        \\ sd s5, 168(sp)
        \\ sd s6, 176(sp)
        \\ sd s7, 184(sp)
        \\ sd s8, 192(sp)
        \\ sd s9, 200(sp)
        \\ sd s10, 208(sp)
        \\ sd s11, 216(sp)
        \\ sd t3, 224(sp)
        \\ sd t4, 232(sp)
        \\ sd t5, 240(sp)
        \\ sd t6, 248(sp)
        \\ addi t0, sp, 256
        \\ sd t0, 16(sp)
        \\ mv a0, sp
        \\ call trapHandler
        \\ ld ra, 8(sp)
        \\ ld gp, 24(sp)
        \\ ld tp, 32(sp)
        \\ ld t0, 40(sp)
        \\ ld t1, 48(sp)
        \\ ld t2, 56(sp)
        \\ ld s0, 64(sp)
        \\ ld s1, 72(sp)
        \\ ld a0, 80(sp)
        \\ ld a1, 88(sp)
        \\ ld a2, 96(sp)
        \\ ld a3, 104(sp)
        \\ ld a4, 112(sp)
        \\ ld a5, 120(sp)
        \\ ld a6, 128(sp)
        \\ ld a7, 136(sp)
        \\ ld s2, 144(sp)
        \\ ld s3, 152(sp)
        \\ ld s4, 160(sp)
        \\ ld s5, 168(sp)
        \\ ld s6, 176(sp)
        \\ ld s7, 184(sp)
        \\ ld s8, 192(sp)
        \\ ld s9, 200(sp)
        \\ ld s10, 208(sp)
        \\ ld s11, 216(sp)
        \\ ld t3, 224(sp)
        \\ ld t4, 232(sp)
        \\ ld t5, 240(sp)
        \\ ld t6, 248(sp)
        \\ addi sp, sp, 256
        \\ mret
        ::: .{ .memory = true });
}

pub export fn trapHandler(tf: *const TrapFrame) callconv(.c) void {
    var uart_buf: [128]u8 = undefined;
    var writer = Uart.writer(&uart_buf);
    const w = &writer.interface;

    const mcause = csr.readCSR("mcause");
    const mepc = csr.readCSR("mepc");
    const mtval = csr.readCSR("mtval");
    const mstatus = csr.readCSR("mstatus");

    const bits = @bitSizeOf(usize);
    const is_interrupt = (mcause >> (bits - 1)) != 0;
    const cause = mcause & ((@as(usize, 1) << (bits - 1)) - 1);

    if (is_interrupt and cause == 7) {
        timer.onInterrupt();
        return;
    }

    w.print("\n[TRAP] {s}\n", .{if (is_interrupt) "interrupt" else "exception"}) catch {};
    w.print("  mcause = 0x{X:0>16} ({d}) {s}\n", .{ mcause, cause, causeName(cause, is_interrupt) }) catch {};
    w.print("  mepc   = 0x{X:0>16}\n", .{mepc}) catch {};
    w.print("  mtval  = 0x{X:0>16}\n", .{mtval}) catch {};
    w.print("  mstatus= 0x{X:0>16}\n", .{mstatus}) catch {};
    dumpRegs(w, tf);
    w.flush() catch {};

    while (true) {
        asm volatile ("wfi");
    }
}

fn causeName(cause: usize, is_interrupt: bool) []const u8 {
    if (is_interrupt) {
        return switch (cause) {
            3 => "Machine software interrupt",
            7 => "Machine timer interrupt",
            11 => "Machine external interrupt",
            else => "Unknown interrupt",
        };
    }

    return switch (cause) {
        0 => "Instruction address misaligned",
        1 => "Instruction access fault",
        2 => "Illegal instruction",
        3 => "Breakpoint",
        4 => "Load address misaligned",
        5 => "Load access fault",
        6 => "Store/AMO address misaligned",
        7 => "Store/AMO access fault",
        8 => "Environment call from U-mode",
        9 => "Environment call from S-mode",
        11 => "Environment call from M-mode",
        12 => "Instruction page fault",
        13 => "Load page fault",
        15 => "Store/AMO page fault",
        else => "Unknown exception",
    };
}

fn dumpRegs(w: *std.Io.Writer, tf: *const TrapFrame) void {
    w.print("  ra=0x{X:0>16} sp=0x{X:0>16} gp=0x{X:0>16} tp=0x{X:0>16}\n", .{ tf.ra, tf.sp, tf.gp, tf.tp }) catch {};
    w.print("  t0=0x{X:0>16} t1=0x{X:0>16} t2=0x{X:0>16}\n", .{ tf.t0, tf.t1, tf.t2 }) catch {};
    w.print("  s0=0x{X:0>16} s1=0x{X:0>16}\n", .{ tf.s0, tf.s1 }) catch {};
    w.print("  a0=0x{X:0>16} a1=0x{X:0>16} a2=0x{X:0>16} a3=0x{X:0>16}\n", .{ tf.a0, tf.a1, tf.a2, tf.a3 }) catch {};
    w.print("  a4=0x{X:0>16} a5=0x{X:0>16} a6=0x{X:0>16} a7=0x{X:0>16}\n", .{ tf.a4, tf.a5, tf.a6, tf.a7 }) catch {};
    w.print("  s2=0x{X:0>16} s3=0x{X:0>16} s4=0x{X:0>16} s5=0x{X:0>16}\n", .{ tf.s2, tf.s3, tf.s4, tf.s5 }) catch {};
    w.print("  s6=0x{X:0>16} s7=0x{X:0>16} s8=0x{X:0>16} s9=0x{X:0>16}\n", .{ tf.s6, tf.s7, tf.s8, tf.s9 }) catch {};
    w.print("  s10=0x{X:0>16} s11=0x{X:0>16}\n", .{ tf.s10, tf.s11 }) catch {};
    w.print("  t3=0x{X:0>16} t4=0x{X:0>16} t5=0x{X:0>16} t6=0x{X:0>16}\n", .{ tf.t3, tf.t4, tf.t5, tf.t6 }) catch {};
}
