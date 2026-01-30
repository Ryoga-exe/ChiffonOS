const mmio = @import("drivers/mmio.zig");

pub const BOOTINFO_ADDR: usize = 0x803F_1000;
pub const MAGIC: u32 = 0x4342_4f54; // 'CBOT'

pub const FsType = enum(u32) {
    none = 0,
    tar = 1,
};

pub const Info = struct {
    version: u32,
    fb0_phys: u64,
    fb1_phys: u64,
    width: u32,
    height: u32,
    stride_bytes: u32,
    pixel_format: u32,
    regbus_base: u64,
    mailbox_addr: u64,
    fs_base: usize,
    fs_size: usize,
    fs_type: FsType,
    has_fs: bool,
};

pub fn read() ?Info {
    const magic = mmio.read32(BOOTINFO_ADDR + 0x00);
    if (magic != MAGIC) return null;

    const version = mmio.read32(BOOTINFO_ADDR + 0x04);

    const fb0 = mmio.read64(BOOTINFO_ADDR + 0x08);
    const fb1 = mmio.read64(BOOTINFO_ADDR + 0x10);
    const width = mmio.read32(BOOTINFO_ADDR + 0x18);
    const height = mmio.read32(BOOTINFO_ADDR + 0x1C);
    const stride = mmio.read32(BOOTINFO_ADDR + 0x20);
    const pixfmt = mmio.read32(BOOTINFO_ADDR + 0x24);
    const regbus_base = mmio.read64(BOOTINFO_ADDR + 0x28);
    const mailbox_addr = mmio.read64(BOOTINFO_ADDR + 0x30);

    var info = Info{
        .version = version,
        .fb0_phys = fb0,
        .fb1_phys = fb1,
        .width = width,
        .height = height,
        .stride_bytes = stride,
        .pixel_format = pixfmt,
        .regbus_base = regbus_base,
        .mailbox_addr = mailbox_addr,
        .fs_base = 0,
        .fs_size = 0,
        .fs_type = .none,
        .has_fs = false,
    };

    if (version >= 2) {
        const fs_base = mmio.read64(BOOTINFO_ADDR + 0x38);
        const fs_size = mmio.read64(BOOTINFO_ADDR + 0x40);
        const fs_type_raw = mmio.read32(BOOTINFO_ADDR + 0x48);
        const fs_type = switch (fs_type_raw) {
            1 => FsType.tar,
            else => FsType.none,
        };
        if (fs_base != 0 and fs_size != 0 and fs_type != .none) {
            info.fs_base = @intCast(fs_base);
            info.fs_size = @intCast(fs_size);
            info.fs_type = fs_type;
            info.has_fs = true;
        }
    }

    return info;
}
