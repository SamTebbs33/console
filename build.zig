const std = @import("std");
const builtin = @import("builtin");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const build_mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(null);

    var cpu_asm = b.addSystemCommand([_][]const u8{
        "z80asm",
        "cpu.s",
        "-o",
        "cpu.bin"
    });
    var ppu_asm = b.addSystemCommand([_][]const u8{
        "z80asm",
        "ppu.s",
        "-o",
        "ppu.bin"
    });
    var exe = b.addExecutable("console", "main.zig");
    exe.install();
    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("z80");
    exe.linkSystemLibrary("c");
    exe.setBuildMode(build_mode);
    exe.setMainPkgPath(".");

    exe.step.dependOn(&cpu_asm.step);
    exe.step.dependOn(&ppu_asm.step);

    b.default_step.dependOn(&exe.step);
}
