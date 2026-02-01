const std = @import("std");

const exe_name = "derg-clock-popup";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdls_include_path = b.option([]const u8, "sdls_include_path", "Path to directory containing SDL3, SDL3_ttf and SDL3_image include directories") orelse "/usr/include";
    const sdls_lib_path = b.option([]const u8, "sdls_lib_path", "Path to directory containing SDL3, SDL3_ttf and SDL3_image libraries") orelse "/usr/lib";

    const mod = b.addModule("derg_clock_popup", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    mod.addIncludePath(.{ .cwd_relative = sdls_include_path });

    const assets_dir = switch (target.result.os.tag) {
        .linux => b.pathJoin(&.{ "share", exe_name }),
        .windows => blk: {
            if (!std.mem.endsWith(u8, b.install_prefix, exe_name))
                b.install_prefix = b.pathJoin(&.{ b.install_prefix, exe_name });

            break :blk "assets";
        },
        else => "assets",
    };

    const assets_path = b.pathJoin(&.{ b.install_prefix, assets_dir });

    const build_options = b.addOptions();
    build_options.addOption([]const u8, "assets_path", assets_path);
    mod.addOptions("build_options", build_options);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "derg_clock_popup", .module = mod },
        },
    });

    exe_mod.addLibraryPath(.{ .cwd_relative = sdls_lib_path });
    exe_mod.linkSystemLibrary("SDL3", .{});
    exe_mod.linkSystemLibrary("SDL3_ttf", .{});
    exe_mod.linkSystemLibrary("SDL3_image", .{});

    const exe = b.addExecutable(.{
        .name = exe_name,
        .root_module = exe_mod,
    });

    b.installDirectory(.{ .source_dir = b.path("assets"), .install_subdir = ".", .install_dir = .{ .custom = assets_dir } });
    b.installArtifact(exe);

    const exe_check = b.addExecutable(.{
        .name = "exe_check",
        .root_module = exe_mod,
    });

    const check = b.step("check", "Check if the code compiles");
    check.dependOn(&exe_check.step);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
