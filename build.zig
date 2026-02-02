const std = @import("std");

const release_win_sdls_include_path = "win_deps/include";
const release_win_sdls_lib_path = "win_deps";
const release_linux_sdls_include_path = "/usr/include";
const release_linux_sdls_lib_path = "/usr/lib";
const release_target_queries = [_]std.Target.Query{
    .{ .cpu_arch = .x86_64, .os_tag = .linux },
    .{ .cpu_arch = .x86_64, .os_tag = .windows },
};

var release_targets: [release_target_queries.len]std.Build.ResolvedTarget = undefined;

const exe_name = "derg-clock-popup";

pub fn build(b: *std.Build) !void {
    const release = b.option(bool, "release", "Build for all supported targets in release mode") orelse false;
    if (release) {
        for (release_target_queries, 0..) |query, i| {
            release_targets[i] = b.resolveTargetQuery(query);
        }
    }

    var sdls_include_path = b.option([]const u8, "sdls_include_path", "Path to directory containing SDL3, SDL3_ttf and SDL3_image include directories");
    var sdls_lib_path = b.option([]const u8, "sdls_lib_path", "Path to directory containing SDL3, SDL3_ttf and SDL3_image libraries");

    const targets = if (release) &release_targets else &[_]std.Build.ResolvedTarget{b.standardTargetOptions(.{})};
    const optimize: std.builtin.OptimizeMode = if (release) .ReleaseSafe else b.standardOptimizeOption(.{});

    for (targets) |target| {
        var target_path: []const u8 = if (target.result.os.tag == .windows) exe_name else "";

        const target_triple = try target.query.zigTriple(b.allocator);
        const name_target_triple = try std.mem.join(b.allocator, "-", &.{ exe_name, target_triple });

        if (release) {
            switch (target.result.os.tag) {
                .linux => {
                    sdls_include_path = release_linux_sdls_include_path;
                    sdls_lib_path = release_linux_sdls_lib_path;
                },
                .windows => {
                    sdls_include_path = release_win_sdls_include_path;
                    sdls_lib_path = b.pathJoin(&.{ release_win_sdls_lib_path, @tagName(target.result.cpu.arch) });
                },
                else => {},
            }

            target_path = b.pathJoin(&.{ name_target_triple, target_path });
        }

        const mod = b.addModule("derg_clock_popup", .{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
        });

        if (sdls_include_path) |inc_path| {
            mod.addIncludePath(.{ .cwd_relative = inc_path });
        }

        const assets_dir = b.pathJoin(&.{ target_path, switch (target.result.os.tag) {
            .linux => b.pathJoin(&.{ "share", exe_name }),
            else => "assets",
        } });

        const assets_path = if (target.result.os.tag == .linux) b.pathJoin(&.{ b.install_prefix, assets_dir }) else "assets";

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

        if (sdls_lib_path) |lib_path| {
            exe_mod.addLibraryPath(.{ .cwd_relative = lib_path });
            exe_mod.addRPath(.{ .cwd_relative = lib_path });
        }

        exe_mod.linkSystemLibrary("SDL3", .{});
        exe_mod.linkSystemLibrary("SDL3_ttf", .{});
        exe_mod.linkSystemLibrary("SDL3_image", .{});

        if (target.result.os.tag == .windows) {
            const sdl_dll = b.addInstallFile(b.path("win_deps/x86_64/SDL3.dll"), b.pathJoin(&.{ target_path, "SDL3.dll" }));
            b.getInstallStep().dependOn(&sdl_dll.step);
            const sdl_ttf_dll = b.addInstallFile(b.path("win_deps/x86_64/SDL3_ttf.dll"), b.pathJoin(&.{ target_path, "SDL3_ttf.dll" }));
            b.getInstallStep().dependOn(&sdl_ttf_dll.step);
            const sdl_image_dll = b.addInstallFile(b.path("win_deps/x86_64/SDL3_image.dll"), b.pathJoin(&.{ target_path, "SDL3_image.dll" }));
            b.getInstallStep().dependOn(&sdl_image_dll.step);
        }

        const exe = b.addExecutable(.{
            .name = exe_name,
            .root_module = exe_mod,
        });

        const assets_install_dir = b.addInstallDirectory(.{ .source_dir = b.path("assets/install"), .install_subdir = ".", .install_dir = .{ .custom = assets_dir } });
        b.getInstallStep().dependOn(&assets_install_dir.step);

        const target_bin_dir = if (target.result.os.tag == .windows) target_path else b.pathJoin(&.{ target_path, "bin" });

        const install_exe = b.addInstallArtifact(exe, .{ .dest_dir = .{ .override = .{ .custom = target_bin_dir } } });
        b.getInstallStep().dependOn(&install_exe.step);

        if (release and target.result.os.tag == .windows) {
            const zip_tool = b.addSystemCommand(&.{"zip"});
            const to_be_archived_path = b.pathJoin(&.{ b.install_prefix, name_target_triple });
            const zip_path = try std.mem.join(b.allocator, "", &.{ to_be_archived_path, ".zip" });
            zip_tool.addArgs(&.{ "-r", zip_path, to_be_archived_path });
            _ = zip_tool.captureStdErr();
            zip_tool.step.dependOn(&install_exe.step);
            b.getInstallStep().dependOn(&zip_tool.step);
        }

        if (!release) {
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
    }
}
