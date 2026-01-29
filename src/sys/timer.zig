const csr = @import("csr.zig");

const mtimecmp0: *volatile u64 = @ptrFromInt(0x0200_4000);
const mtime: *volatile u64 = @ptrFromInt(0x0200_7ff8);

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
    return mtime.*;
}

fn scheduleNext() void {
    const current = mtime.*;
    mtimecmp0.* = current + interval;
}
