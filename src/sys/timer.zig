const csr = @import("csr.zig");
const build_options = @import("build_options");

const clint_base: usize = 0x0200_0000;
const mtimecmp_offset: usize = 0x0000_4000;
const mtime_offset: usize = if (build_options.qemu) 0x0000_BFF8 else 0x0000_7FF8;

const TimeType = if (build_options.qemu) u64 else u32;

const mtimecmp0: *volatile TimeType = @ptrFromInt(clint_base + mtimecmp_offset);
const mtime: *volatile TimeType = @ptrFromInt(clint_base + mtime_offset);

const mie_mtie: u64 = 1 << 7;
const mstatus_mie: u64 = 1 << 3;

pub var ticks: u64 = 0;
pub var interval: TimeType = 0;

pub fn init(interval_ticks: TimeType) void {
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

pub fn now() TimeType {
    return mtime.*;
}

fn scheduleNext() void {
    const current = mtime.*;
    mtimecmp0.* = current +% interval;
}
