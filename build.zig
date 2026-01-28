const std = @import("std");

pub fn build(b: *std.Build) void {
    const Feature = std.Target.riscv.Feature;
    const enabled_features = std.Target.riscv.featureSet(&[_]Feature{
        .m,
    });
    const disabled_features = std.Target.riscv.featureSet(&[_]Feature{
        .a,
        .d,
        .e,
        .f,
        .c,
    });
    // RV64IM
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
        .abi = .none,
        .ofmt = .elf,
        .cpu_features_add = enabled_features,
        .cpu_features_sub = disabled_features,
    });
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSmall,
    });

    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .root_module = b.addModule("kernel", .{
            .root_source_file = b.path("src/kernel.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    kernel.entry = .{ .symbol_name = "_start" };
    kernel.setLinkerScript(b.path("src/kernel.ld"));
    b.installArtifact(kernel);

    const kernel_step = b.step("kernel", "Build the kernel");
    kernel_step.dependOn(&kernel.step);

    const qemu_cmd = b.addSystemCommand(&.{
        "qemu-system-riscv64",
        "-machine",
        "virt",
        "-bios",
        "none",
        "-nographic",
        "-serial",
        "mon:stdio",
        "--no-reboot",
        "-kernel",
        b.getInstallPath(.bin, kernel.name),
    });
    qemu_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the kernel on QEMU");
    run_step.dependOn(&qemu_cmd.step);
}
