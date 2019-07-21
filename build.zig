const std = @import("std");
const builtin = @import("builtin");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const build_mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(null);

    var exe = b.addExecutable("console", "main.zig");
    exe.install();
    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("z80");
    exe.linkSystemLibrary("c");
    exe.setBuildMode(build_mode);
    exe.setMainPkgPath(".");

    b.default_step.dependOn(&exe.step);
}
