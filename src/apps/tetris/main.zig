const syscall = @import("common").syscall;

const SCREEN_W: u32 = 640;
const SCREEN_H: u32 = 480;

const FIELD_W: usize = 10;
const FIELD_H: usize = 20;
const CELL: u32 = 24;
const FIELD_PX_W: u32 = CELL * @as(u32, FIELD_W);
const FIELD_PX_H: u32 = CELL * @as(u32, FIELD_H);
const FIELD_X: u32 = (SCREEN_W - FIELD_PX_W) / 2;
const FIELD_Y: u32 = (SCREEN_H - FIELD_PX_H) / 2;
const CELL_PAD: u32 = 2;
const BORDER: u32 = 2;

const BG_COLOR: u32 = 0x00101010;
const FIELD_BG_COLOR: u32 = 0x00181818;
const BORDER_COLOR: u32 = 0x00303030;
const GAMEOVER_COLOR: u32 = 0x00402020;

const COLORS: [7]u32 = .{
    0x0000_FFFF, // I
    0x00FF_FF00, // O
    0x0000_FF00, // S
    0x00FF_0000, // Z
    0x0000_00FF, // J
    0x00FF_8800, // L
    0x00AA_00FF, // T
};

const SHAPES: [7][4][4][4]u8 = .{
    // I
    .{
        .{
            .{ 0, 0, 0, 0 },
            .{ 1, 1, 1, 1 },
            .{ 0, 0, 0, 0 },
            .{ 0, 0, 0, 0 },
        },
        .{
            .{ 0, 0, 1, 0 },
            .{ 0, 0, 1, 0 },
            .{ 0, 0, 1, 0 },
            .{ 0, 0, 1, 0 },
        },
        .{
            .{ 0, 0, 0, 0 },
            .{ 0, 0, 0, 0 },
            .{ 1, 1, 1, 1 },
            .{ 0, 0, 0, 0 },
        },
        .{
            .{ 0, 1, 0, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 1, 0, 0 },
        },
    },
    // O
    .{
        .{
            .{ 0, 0, 0, 0 },
            .{ 0, 1, 1, 0 },
            .{ 0, 1, 1, 0 },
            .{ 0, 0, 0, 0 },
        },
        .{
            .{ 0, 0, 0, 0 },
            .{ 0, 1, 1, 0 },
            .{ 0, 1, 1, 0 },
            .{ 0, 0, 0, 0 },
        },
        .{
            .{ 0, 0, 0, 0 },
            .{ 0, 1, 1, 0 },
            .{ 0, 1, 1, 0 },
            .{ 0, 0, 0, 0 },
        },
        .{
            .{ 0, 0, 0, 0 },
            .{ 0, 1, 1, 0 },
            .{ 0, 1, 1, 0 },
            .{ 0, 0, 0, 0 },
        },
    },
    // S
    .{
        .{
            .{ 0, 0, 0, 0 },
            .{ 0, 1, 1, 0 },
            .{ 1, 1, 0, 0 },
            .{ 0, 0, 0, 0 },
        },
        .{
            .{ 0, 1, 0, 0 },
            .{ 0, 1, 1, 0 },
            .{ 0, 0, 1, 0 },
            .{ 0, 0, 0, 0 },
        },
        .{
            .{ 0, 0, 0, 0 },
            .{ 0, 1, 1, 0 },
            .{ 1, 1, 0, 0 },
            .{ 0, 0, 0, 0 },
        },
        .{
            .{ 1, 0, 0, 0 },
            .{ 1, 1, 0, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 0, 0, 0 },
        },
    },
    // Z
    .{
        .{
            .{ 0, 0, 0, 0 },
            .{ 1, 1, 0, 0 },
            .{ 0, 1, 1, 0 },
            .{ 0, 0, 0, 0 },
        },
        .{
            .{ 0, 0, 1, 0 },
            .{ 0, 1, 1, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 0, 0, 0 },
        },
        .{
            .{ 0, 0, 0, 0 },
            .{ 1, 1, 0, 0 },
            .{ 0, 1, 1, 0 },
            .{ 0, 0, 0, 0 },
        },
        .{
            .{ 0, 1, 0, 0 },
            .{ 1, 1, 0, 0 },
            .{ 1, 0, 0, 0 },
            .{ 0, 0, 0, 0 },
        },
    },
    // J
    .{
        .{
            .{ 1, 0, 0, 0 },
            .{ 1, 1, 1, 0 },
            .{ 0, 0, 0, 0 },
            .{ 0, 0, 0, 0 },
        },
        .{
            .{ 0, 1, 1, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 0, 0, 0 },
        },
        .{
            .{ 0, 0, 0, 0 },
            .{ 1, 1, 1, 0 },
            .{ 0, 0, 1, 0 },
            .{ 0, 0, 0, 0 },
        },
        .{
            .{ 0, 1, 0, 0 },
            .{ 0, 1, 0, 0 },
            .{ 1, 1, 0, 0 },
            .{ 0, 0, 0, 0 },
        },
    },
    // L
    .{
        .{
            .{ 0, 0, 1, 0 },
            .{ 1, 1, 1, 0 },
            .{ 0, 0, 0, 0 },
            .{ 0, 0, 0, 0 },
        },
        .{
            .{ 0, 1, 0, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 1, 1, 0 },
            .{ 0, 0, 0, 0 },
        },
        .{
            .{ 0, 0, 0, 0 },
            .{ 1, 1, 1, 0 },
            .{ 1, 0, 0, 0 },
            .{ 0, 0, 0, 0 },
        },
        .{
            .{ 1, 1, 0, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 0, 0, 0 },
        },
    },
    // T
    .{
        .{
            .{ 0, 1, 0, 0 },
            .{ 1, 1, 1, 0 },
            .{ 0, 0, 0, 0 },
            .{ 0, 0, 0, 0 },
        },
        .{
            .{ 0, 1, 0, 0 },
            .{ 0, 1, 1, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 0, 0, 0 },
        },
        .{
            .{ 0, 0, 0, 0 },
            .{ 1, 1, 1, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 0, 0, 0 },
        },
        .{
            .{ 0, 1, 0, 0 },
            .{ 1, 1, 0, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 0, 0, 0 },
        },
    },
};

const Mino = struct {
    t: u8,
    r: u8,
    x: i32,
    y: i32,
};

var stack: [4096]u8 align(16) = undefined;
var field: [FIELD_H][FIELD_W]u8 = undefined;
var rng_state: u64 = 0;
var bag: [7]u8 = .{ 0, 1, 2, 3, 4, 5, 6 };
var bag_index: usize = 7;

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

inline fn rdcycle() u64 {
    return asm volatile ("rdcycle %[out]"
        : [out] "=&r" (-> u64),
    );
}

fn busyWaitCycles(delta: u64) void {
    const start = rdcycle();
    while (rdcycle() - start < delta) {}
}

fn rngInit() void {
    rng_state = rdcycle() ^ 0x9E37_79B9_7F4A_7C15;
}

fn rngNext() u32 {
    rng_state = rng_state * 6364136223846793005 + 1;
    return @truncate(rng_state >> 32);
}

fn refillBag() void {
    bag = .{ 0, 1, 2, 3, 4, 5, 6 };
    var i: usize = bag.len;
    while (i > 1) {
        i -= 1;
        const j: usize = @intCast(rngNext() % (i + 1));
        const tmp = bag[i];
        bag[i] = bag[j];
        bag[j] = tmp;
    }
    bag_index = 0;
}

fn drawFromBag() u8 {
    if (bag_index >= bag.len) {
        refillBag();
    }
    const t = bag[bag_index];
    bag_index += 1;
    return t;
}

fn clearField() void {
    var y: usize = 0;
    while (y < FIELD_H) : (y += 1) {
        var x: usize = 0;
        while (x < FIELD_W) : (x += 1) {
            field[y][x] = 0;
        }
    }
}

fn isCollisionAt(t: u8, r: u8, x: i32, y: i32) bool {
    var sy: usize = 0;
    while (sy < 4) : (sy += 1) {
        var sx: usize = 0;
        while (sx < 4) : (sx += 1) {
            if (SHAPES[t][r][sy][sx] == 0) {
                continue;
            }
            const fx: i32 = x + @as(i32, @intCast(sx));
            const fy: i32 = y + @as(i32, @intCast(sy));
            if (fx < 0 or fy < 0) {
                return true;
            }
            if (fx >= @as(i32, @intCast(FIELD_W)) or fy >= @as(i32, @intCast(FIELD_H))) {
                return true;
            }
            if (field[@intCast(fy)][@intCast(fx)] != 0) {
                return true;
            }
        }
    }
    return false;
}

fn tryMove(mino: *Mino, dx: i32, dy: i32) bool {
    const nx = mino.x + dx;
    const ny = mino.y + dy;
    if (isCollisionAt(mino.t, mino.r, nx, ny)) {
        return false;
    }
    mino.x = nx;
    mino.y = ny;
    return true;
}

fn tryRotate(mino: *Mino) void {
    const next_r: u8 = (mino.r + 1) & 3;
    if (!isCollisionAt(mino.t, next_r, mino.x, mino.y)) {
        mino.r = next_r;
        return;
    }
    if (!isCollisionAt(mino.t, next_r, mino.x - 1, mino.y)) {
        mino.x -= 1;
        mino.r = next_r;
        return;
    }
    if (!isCollisionAt(mino.t, next_r, mino.x + 1, mino.y)) {
        mino.x += 1;
        mino.r = next_r;
        return;
    }
    if (mino.t == 0) {
        if (!isCollisionAt(mino.t, next_r, mino.x - 2, mino.y)) {
            mino.x -= 2;
            mino.r = next_r;
            return;
        }
        if (!isCollisionAt(mino.t, next_r, mino.x + 2, mino.y)) {
            mino.x += 2;
            mino.r = next_r;
            return;
        }
    }
}

fn lockMino(mino: Mino) void {
    var sy: usize = 0;
    while (sy < 4) : (sy += 1) {
        var sx: usize = 0;
        while (sx < 4) : (sx += 1) {
            if (SHAPES[mino.t][mino.r][sy][sx] == 0) {
                continue;
            }
            const fx: i32 = mino.x + @as(i32, @intCast(sx));
            const fy: i32 = mino.y + @as(i32, @intCast(sy));
            if (fx < 0 or fy < 0) {
                continue;
            }
            field[@intCast(fy)][@intCast(fx)] = mino.t + 1;
        }
    }
}

fn clearLines() void {
    var y: i32 = @as(i32, @intCast(FIELD_H)) - 1;
    while (y >= 0) {
        var x: usize = 0;
        var full = true;
        while (x < FIELD_W) : (x += 1) {
            if (field[@intCast(y)][x] == 0) {
                full = false;
                break;
            }
        }
        if (!full) {
            y -= 1;
            continue;
        }
        var yy: i32 = y;
        while (yy > 0) : (yy -= 1) {
            field[@intCast(yy)] = field[@intCast(yy - 1)];
        }
        var top_x: usize = 0;
        while (top_x < FIELD_W) : (top_x += 1) {
            field[0][top_x] = 0;
        }
    }
}

fn spawnMino(current: *Mino, next: *u8) bool {
    current.t = next.*;
    current.r = 0;
    current.x = 3;
    current.y = 0;
    next.* = drawFromBag();
    return !isCollisionAt(current.t, current.r, current.x, current.y);
}

fn drawBlock(gx: usize, gy: usize, color: u32) void {
    const px = FIELD_X + @as(u32, @intCast(gx)) * CELL + CELL_PAD;
    const py = FIELD_Y + @as(u32, @intCast(gy)) * CELL + CELL_PAD;
    const size = CELL - CELL_PAD * 2;
    _ = syscall.gfxFillRect(@intCast(px), @intCast(py), @intCast(size), @intCast(size), color);
}

fn drawScene(current: Mino, game_over: bool) void {
    _ = syscall.gfxClear(BG_COLOR);

    const border_x = if (FIELD_X >= BORDER) BORDER else FIELD_X;
    const border_y = if (FIELD_Y >= BORDER) BORDER else FIELD_Y;
    const outer_x = FIELD_X - border_x;
    const outer_y = FIELD_Y - border_y;
    const outer_w = FIELD_PX_W + border_x * 2;
    const outer_h = FIELD_PX_H + border_y * 2;
    _ = syscall.gfxFillRect(@intCast(outer_x), @intCast(outer_y), @intCast(outer_w), @intCast(outer_h), BORDER_COLOR);
    _ = syscall.gfxFillRect(@intCast(FIELD_X), @intCast(FIELD_Y), @intCast(FIELD_PX_W), @intCast(FIELD_PX_H), FIELD_BG_COLOR);

    var y: usize = 0;
    while (y < FIELD_H) : (y += 1) {
        var x: usize = 0;
        while (x < FIELD_W) : (x += 1) {
            const v = field[y][x];
            if (v != 0) {
                drawBlock(x, y, COLORS[v - 1]);
            }
        }
    }

    if (!game_over) {
        var sy: usize = 0;
        while (sy < 4) : (sy += 1) {
            var sx: usize = 0;
            while (sx < 4) : (sx += 1) {
                if (SHAPES[current.t][current.r][sy][sx] == 0) {
                    continue;
                }
                const fx: i32 = current.x + @as(i32, @intCast(sx));
                const fy: i32 = current.y + @as(i32, @intCast(sy));
                if (fx < 0 or fy < 0) {
                    continue;
                }
                if (fx >= @as(i32, @intCast(FIELD_W)) or fy >= @as(i32, @intCast(FIELD_H))) {
                    continue;
                }
                drawBlock(@intCast(fx), @intCast(fy), COLORS[current.t]);
            }
        }
    }

    if (game_over) {
        const overlay_w: u32 = 280;
        const overlay_h: u32 = 60;
        const overlay_x: u32 = (SCREEN_W - overlay_w) / 2;
        const overlay_y: u32 = (SCREEN_H - overlay_h) / 2;
        _ = syscall.gfxFillRect(@intCast(overlay_x), @intCast(overlay_y), @intCast(overlay_w), @intCast(overlay_h), GAMEOVER_COLOR);
    }
}

pub export fn main() noreturn {
    syscall.uartPuts("[tetris] app start\n");

    rngInit();
    clearField();
    refillBag();

    var current: Mino = .{ .t = 0, .r = 0, .x = 3, .y = 0 };
    var next: u8 = drawFromBag();
    var game_over = !spawnMino(&current, &next);

    var last_cycle: u64 = rdcycle();
    var drop_accum: u64 = 0;
    const drop_interval: u64 = 18_000_000;
    const frame_wait: u64 = 1_000_000;

    while (true) {
        var ch: u8 = 0;
        while (syscall.uartGetcNonblock(&ch)) {
            if (ch == 'q' or ch == 'Q') {
                syscall.uartPuts("[tetris] exit by key\n");
                syscall.exit(0);
            }
            if (game_over) {
                if (ch == 'r' or ch == 'R' or ch == ' ') {
                    clearField();
                    refillBag();
                    next = drawFromBag();
                    game_over = !spawnMino(&current, &next);
                    drop_accum = 0;
                }
                continue;
            }
            switch (ch) {
                'a', 'A', 'h', 'H' => _ = tryMove(&current, -1, 0),
                'd', 'D', 'l', 'L' => _ = tryMove(&current, 1, 0),
                's', 'S', 'j', 'J' => {
                    if (!tryMove(&current, 0, 1)) {
                        lockMino(current);
                        clearLines();
                        if (!spawnMino(&current, &next)) {
                            game_over = true;
                        }
                        drop_accum = 0;
                    }
                },
                'w', 'W', 'k', 'K' => tryRotate(&current),
                ' ' => {
                    while (tryMove(&current, 0, 1)) {}
                    lockMino(current);
                    clearLines();
                    if (!spawnMino(&current, &next)) {
                        game_over = true;
                    }
                    drop_accum = 0;
                },
                else => {},
            }
        }

        const now = rdcycle();
        const delta = now - last_cycle;
        last_cycle = now;
        if (!game_over) {
            drop_accum += delta;
            if (drop_accum >= drop_interval) {
                drop_accum -= drop_interval;
                if (!tryMove(&current, 0, 1)) {
                    lockMino(current);
                    clearLines();
                    if (!spawnMino(&current, &next)) {
                        game_over = true;
                    }
                    drop_accum = 0;
                }
            }
        }

        if (syscall.gfxBegin() != 0) {
            syscall.uartPuts("[tetris] gfx not ready; exit\n");
            syscall.exit(0);
        }
        drawScene(current, game_over);
        _ = syscall.gfxPresent();

        busyWaitCycles(frame_wait);
    }
}
