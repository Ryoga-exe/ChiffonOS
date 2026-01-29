const csr = @import("csr.zig");
const build_options = @import("build_options");

const clint_base: usize = 0x0200_0000;
const mtimecmp_offset: usize = 0x0000_4000;
const mtime_offset: usize = if (build_options.qemu) 0x0000_BFF8 else 0x0000_7FF8;

const mie_mtie: u64 = 1 << 7;
const mstatus_mie: u64 = 1 << 3;

pub var ticks: u64 = 0;
pub var interval: u64 = 0;

pub fn init(interval_ticks: u64) void {
    interval = interval_ticks;
    scheduleNext();

    const mie = csr.readCSR("mie");
    csr.writeCSR("mie", mie | mie_mtie);

    const mstatus = csr.readCSR("mstatus");
    csr.writeCSR("mstatus", mstatus | mstatus_mie);
}

pub fn onInterrupt() void {
    ticks += 1;
    scheduleNext();
}

pub fn now() u64 {
    return readMtime();
}

fn scheduleNext() void {
    const current = readMtime();
    writeMtimecmp(current + interval);
}

fn mtimeLo() *volatile u32 {
    return @ptrFromInt(clint_base + mtime_offset);
}

fn mtimeHi() *volatile u32 {
    return @ptrFromInt(clint_base + mtime_offset + 4);
}

fn mtimecmpLo() *volatile u32 {
    return @ptrFromInt(clint_base + mtimecmp_offset);
}

fn mtimecmpHi() *volatile u32 {
    return @ptrFromInt(clint_base + mtimecmp_offset + 4);
}

fn readMtime() u64 {
    while (true) {
        const hi1: u32 = mtimeHi().*;
        const lo: u32 = mtimeLo().*;
        const hi2: u32 = mtimeHi().*;
        if (hi1 == hi2) {
            return (@as(u64, hi1) << 32) | @as(u64, lo);
        }
    }
}

fn writeMtimecmp(value: u64) void {
    const hi: u32 = @intCast(value >> 32);
    const lo: u32 = @intCast(value & 0xFFFF_FFFF);

    mtimecmpHi().* = 0xFFFF_FFFF;
    mtimecmpLo().* = lo;
    mtimecmpHi().* = hi;
}
