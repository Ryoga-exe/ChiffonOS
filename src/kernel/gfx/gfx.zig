const display = @import("display.zig");
const draw = @import("draw.zig");

pub const width: u32 = 640;
pub const height: u32 = 480;

pub const Gfx = struct {
    front: u32,
    back: u32,

    pub fn init(fb0: u32, fb1: u32) Gfx {
        display.init(fb0);
        return .{ .front = fb0, .back = fb1 };
    }

    pub fn begin(self: *Gfx) void {
        draw.beginFrame(self.back, width, height);
    }

    pub fn clear(self: *Gfx, rgb: u32) void {
        _ = self;
        draw.setColor(rgb);
        draw.patblt(0, 0, width, height);
    }

    pub fn fillRect(self: *Gfx, x: u32, y: u32, w: u32, h: u32, rgb: u32) void {
        _ = self;
        draw.setColor(rgb);
        draw.patblt(x, y, w, h);
    }

    pub fn endAndPresent(self: *Gfx) void {
        draw.execAndWait();
        display.present(self.back);

        const tmp = self.front;
        self.front = self.back;
        self.back = tmp;
    }
};

var global: ?Gfx = null;

pub fn initGlobal(fb0: u32, fb1: u32) void {
    global = Gfx.init(fb0, fb1);
}

pub fn isReady() bool {
    return global != null;
}

pub fn beginGlobal() bool {
    if (global) |*g| {
        g.begin();
        return true;
    }
    return false;
}

pub fn clearGlobal(rgb: u32) bool {
    if (global) |*g| {
        g.clear(rgb);
        return true;
    }
    return false;
}

pub fn fillRectGlobal(x: u32, y: u32, w: u32, h: u32, rgb: u32) bool {
    if (global) |*g| {
        g.fillRect(x, y, w, h, rgb);
        return true;
    }
    return false;
}

pub fn presentGlobal() bool {
    if (global) |*g| {
        g.endAndPresent();
        return true;
    }
    return false;
}
