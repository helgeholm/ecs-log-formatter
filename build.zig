const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ecs = b.addModule("ecs-log-formatter", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const zeit = b.dependency("zig_zeit", .{
        .target = target,
        .optimize = optimize,
    });
    ecs.addImport("zeit", zeit.module("zeit"));

    const exe = b.addExecutable(.{
        .name = "ecs-log-formatter",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("ecs-log-formatter", ecs);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the example code from README.md");
    run_step.dependOn(&run_cmd.step);
}
