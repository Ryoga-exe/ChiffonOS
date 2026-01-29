const rb = @import("../drivers/regbus.zig");

const offset = struct {
    const ctrl: u32 = 0x2000;
    const stat: u32 = 0x2004;
    const cmd: u32 = 0x200c;
};

const opc = struct {
    const setframe: u32 = 0x2000_0000;
    const setdrawarea: u32 = 0x2100_0000;
    const setfcolor: u32 = 0x2300_0000;
    const patblt: u32 = 0x8100_0000;
    const eodl: u32 = 0x0F00_0000;
};

pub fn cmd(v: u32) void {
    rb.w(offset.cmd, v);
}

pub fn beginFrame(dst_fb: u32, w: u32, h: u32) void {
    cmd(opc.setframe);
    cmd(dst_fb);
    cmd(rb.pack2(w, h));

    cmd(opc.setdrawarea);
    cmd(0);
    cmd(rb.pack2(w, h));
}

pub fn setColor(rgb: u32) void {
    cmd(opc.setfcolor);
    cmd(rgb); // 0x00RRGGBB
}

pub fn patblt(x: u32, y: u32, w: u32, h: u32) void {
    cmd(opc.patblt);
    cmd(rb.pack2(x, y));
    cmd(rb.pack2(w, h));
}

pub fn execAndWait() void {
    cmd(opc.eodl);
    rb.w(offset.ctrl, 1); // EXE
    while ((rb.r(offset.stat) & 1) != 0) {}
    rb.w(offset.ctrl, 2); // RST
}
