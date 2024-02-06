const std = @import("std");
const zrender = @import("ZRender/build.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const ecsModule = b.createModule(.{
        .root_source_file = .{.path = "ZEngine/zig-ecs/src/ecs.zig"},
        .target = target,
        .optimize = optimize,
    });
    const zengineModule = b.createModule(.{
        .root_source_file = .{.path = "ZEngine/src/zengine.zig"},
        .target = target,
        .optimize = optimize,
    });
    zengineModule.addImport("ecs", ecsModule);
    const exe = b.addExecutable(.{
        .name = "examples",
        .root_source_file = .{.path = "src/main.zig"},
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("ecs", ecsModule);
    exe.root_module.addImport("zengine", zengineModule);
    try zrender.link("ZRender", exe, zengineModule, ecsModule);
    b.installArtifact(exe);
    const run = b.addRunArtifact(exe);
    const runStep = b.step("run", "run the example");
    runStep.dependOn(&run.step);
}