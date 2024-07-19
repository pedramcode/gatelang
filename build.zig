const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "my_app",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.addLibraryPath(std.Build.LazyPath{ .src_path = .{ .owner = b, .sub_path = "libs/mecha" } });
    exe.addIncludePath(std.Build.LazyPath{ .src_path = .{ .owner = b, .sub_path = "libs/mecha" } });
    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);
}
