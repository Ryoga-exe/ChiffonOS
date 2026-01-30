const uart = @import("common").Uart;
const syscall = @import("common").syscall;

const BOOTINFO_ADDR: usize = 0x803F_1000;
const MAGIC: u32 = 0x4342_4f54; // 'CBOT'

const Info = struct {
    version: u32,
    fb0_phys: u64,
    fb1_phys: u64,
    width: u32,
    height: u32,
    stride_bytes: u32,
    pixel_format: u32,
    regbus_base: u64,
    mailbox_addr: u64,
};

inline fn read32(addr: usize) u32 {
    return @as(*volatile u32, @ptrFromInt(addr)).*;
}

inline fn read64(addr: usize) u64 {
    return @as(*volatile u64, @ptrFromInt(addr)).*;
}

fn readBootInfo() ?Info {
    const magic = read32(BOOTINFO_ADDR + 0x00);
    if (magic != MAGIC) return null;
    return .{
        .version = read32(BOOTINFO_ADDR + 0x04),
        .fb0_phys = read64(BOOTINFO_ADDR + 0x08),
        .fb1_phys = read64(BOOTINFO_ADDR + 0x10),
        .width = read32(BOOTINFO_ADDR + 0x18),
        .height = read32(BOOTINFO_ADDR + 0x1C),
        .stride_bytes = read32(BOOTINFO_ADDR + 0x20),
        .pixel_format = read32(BOOTINFO_ADDR + 0x24),
        .regbus_base = read64(BOOTINFO_ADDR + 0x28),
        .mailbox_addr = read64(BOOTINFO_ADDR + 0x30),
    };
}

inline fn rb_w(base: usize, off: u32, val: u32) void {
    @as(*volatile u32, @ptrFromInt(base + off)).* = val;
}

inline fn rb_r(base: usize, off: u32) u32 {
    return @as(*volatile u32, @ptrFromInt(base + off)).*;
}

inline fn pack2(hi: u32, lo: u32) u32 {
    return (hi << 16) | (lo & 0xFFFF);
}

const disp_off = struct {
    const addr: u32 = 0x0000;
    const ctrl: u32 = 0x0004;
    const fifo: u32 = 0x000c;
};

const draw_off = struct {
    const ctrl: u32 = 0x2000;
    const stat: u32 = 0x2004;
    const cmd: u32 = 0x200c;
};

const draw_opc = struct {
    const setframe: u32 = 0x2000_0000;
    const setdrawarea: u32 = 0x2100_0000;
    const setfcolor: u32 = 0x2300_0000;
    const patblt: u32 = 0x8100_0000;
    const eodl: u32 = 0x0F00_0000;
};

inline fn draw_cmd(base: usize, v: u32) void {
    rb_w(base, draw_off.cmd, v);
}

fn beginFrame(base: usize, dst_fb: u32, w: u32, h: u32) void {
    draw_cmd(base, draw_opc.setframe);
    draw_cmd(base, dst_fb);
    draw_cmd(base, pack2(w, h));

    draw_cmd(base, draw_opc.setdrawarea);
    draw_cmd(base, 0);
    draw_cmd(base, pack2(w, h));
}

fn setColor(base: usize, rgb: u32) void {
    draw_cmd(base, draw_opc.setfcolor);
    draw_cmd(base, rgb);
}

fn patblt(base: usize, x: u32, y: u32, w: u32, h: u32) void {
    draw_cmd(base, draw_opc.patblt);
    draw_cmd(base, pack2(x, y));
    draw_cmd(base, pack2(w, h));
}

fn execAndWait(base: usize) void {
    draw_cmd(base, draw_opc.eodl);
    rb_w(base, draw_off.ctrl, 1); // EXE
    while ((rb_r(base, draw_off.stat) & 1) != 0) {}
    rb_w(base, draw_off.ctrl, 2); // RST
}

fn waitVblank(base: usize) void {
    rb_w(base, disp_off.ctrl, 3);
    while (rb_r(base, disp_off.ctrl) != 3) {}
}

fn displayInit(base: usize, front_fb: u32) void {
    waitVblank(base);
    rb_w(base, disp_off.fifo, 3);
    rb_w(base, disp_off.addr, front_fb);
    rb_w(base, disp_off.ctrl, 1);
}

fn displayPresent(base: usize, next_fb: u32) void {
    waitVblank(base);
    rb_w(base, disp_off.addr, next_fb);
    rb_w(base, disp_off.ctrl, 1);
}

inline fn rdcycle() u64 {
    return asm volatile ("rdcycle %[out]"
        : [out] "=&r" (-> u64),
    );
}

fn busyWaitCycles(delta: u64) void {
    const start = rdcycle();
    while (rdcycle() - start < delta) {}
}

fn nextColor(idx: *u32) u32 {
    const palette = [_]u32{
        0x00FF_0000,
        0x0000_FF00,
        0x0000_00FF,
        0x00FF_FF00,
        0x00FF_00FF,
        0x0000_FFFF,
        0x00FF_FFFF,
    };
    const i = idx.* % palette.len;
    idx.* = idx.* + 1;
    return palette[i];
}

var stack: [4096]u8 align(16) = undefined;

pub export fn _start() callconv(.naked) noreturn {
    asm volatile (
        \\ lui gp, %hi(__global_pointer$)
        \\ addi gp, gp, %lo(__global_pointer$)
        \\ mv sp, %[stack]
        \\ j main
        :
        : [stack] "r" (@intFromPtr(&stack) + stack.len),
        : .{ .memory = true });
}

pub export fn main() noreturn {
    uart.puts("[dvd] app start\n");

    const info = readBootInfo() orelse {
        uart.puts("[dvd] bootinfo not found; exit\n");
        syscall.exit(0);
    };
    if (info.fb0_phys == 0 or info.regbus_base == 0) {
        uart.puts("[dvd] framebuffer/regbus unavailable; exit\n");
        syscall.exit(0);
    }

    const w: u32 = if (info.width == 0) 640 else info.width;
    const h: u32 = if (info.height == 0) 480 else info.height;
    const regbus: usize = @intCast(info.regbus_base);

    var front: u32 = @intCast(info.fb0_phys);
    var back: u32 = @intCast(if (info.fb1_phys != 0) info.fb1_phys else info.fb0_phys);

    displayInit(regbus, front);

    var x: i32 = 40;
    var y: i32 = 30;
    var dx: i32 = 3;
    var dy: i32 = 2;
    const rw: i32 = 120;
    const rh: i32 = 90;
    var color_idx: u32 = 0;
    var color: u32 = nextColor(&color_idx);

    while (true) {
        beginFrame(regbus, back, w, h);
        setColor(regbus, 0x0000_0000);
        patblt(regbus, 0, 0, w, h);

        setColor(regbus, color);
        patblt(regbus, @intCast(x), @intCast(y), @intCast(rw), @intCast(rh));
        execAndWait(regbus);
        displayPresent(regbus, back);

        const tmp = front;
        front = back;
        back = tmp;

        x += dx;
        y += dy;
        if (x <= 0) {
            x = 0;
            dx = -dx;
            color = nextColor(&color_idx);
        } else if (x + rw >= @as(i32, @intCast(w))) {
            x = @as(i32, @intCast(w)) - rw;
            dx = -dx;
            color = nextColor(&color_idx);
        }
        if (y <= 0) {
            y = 0;
            dy = -dy;
            color = nextColor(&color_idx);
        } else if (y + rh >= @as(i32, @intCast(h))) {
            y = @as(i32, @intCast(h)) - rh;
            dy = -dy;
            color = nextColor(&color_idx);
        }

        busyWaitCycles(2_000_000);
    }
}
