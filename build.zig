const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    if (target.isWindows()) {
        const exe = b.addExecutable("Game", "src/win32.zig");
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.linkLibC();
        exe.linkSystemLibrary("gdi32");
        // exe.linkSystemLibrary("user32");
        // exe.linkSystemLibrary("kernel32");
        exe.install();

        const run_cmd = exe.run();
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
        return;
    }
    // if (target.cpu_arch.?.isWasm()) {
    //     const lib = b.addStaticLibrary("Game", "src/wasm.zig");
    //     lib.setBuildMode(mode);
    //     lib.install();
    //     return;
    // }

    const exe = b.addExecutable("Game", "src/linux.zig");
    if (b.is_release) {
        exe.strip = true;
    }
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.linkLibC();
    exe.linkSystemLibrary("X11");
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
