const rb = @import("regbus.zig");

const offset = struct {
    const addr: u32 = 0x0000;
    const ctrl: u32 = 0x0004;
    const fifo: u32 = 0x000c;
};

pub fn waitVblank() void {
    rb.w(offset.ctrl, 3);
    while (rb.r(offset.ctrl) != 3) {}
}

pub fn init(front_fb: u32) void {
    waitVblank();
    rb.w(offset.fifo, 3);
    rb.w(offset.addr, front_fb);
    rb.w(offset.ctrl, 1);
}

pub fn present(next_fb: u32) void {
    waitVblank();
    rb.w(offset.addr, next_fb);
    rb.w(offset.ctrl, 1);
}
