const std = @import("std");
const box2d = @import("Box2D.zig/build.zig");
const sdl = @import("SDL.zig/Sdk.zig");
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const ecsModule = b.createModule(.{
        .root_source_file = .{ .path = "ZEngine/zig-ecs/src/ecs.zig" },
        .target = target,
        .optimize = optimize,
    });
    const zengineModule = b.createModule(.{
        .root_source_file = .{ .path = "ZEngine/src/zengine.zig" },
        .target = target,
        .optimize = optimize,
    });
    zengineModule.addImport("ecs", ecsModule);
    const zlmModule = b.createModule(.{
        .root_source_file = .{ .path = "zlm/src/zlm.zig" },
        .target = target,
        .optimize = optimize,
    });
    const exe = b.addExecutable(.{
        .name = "examples",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("ecs", ecsModule);
    exe.root_module.addImport("zengine", zengineModule);
    exe.root_module.addImport("zlm", zlmModule);
    var sdlSdk = sdl.init(b, null);
    sdlSdk.link(exe, .Dynamic);
    exe.root_module.addImport("sdl", sdlSdk.getWrapperModule());
    try box2d.link("Box2D.zig/box2c/", exe, .{});
    exe.addIncludePath(.{.path = "src/"});
    exe.addCSourceFile(.{
        .file = .{.path = "src/stb_image.c"},
    });
    b.installArtifact(exe);
    const run = b.addRunArtifact(exe);
    const runStep = b.step("run", "run the example");
    runStep.dependOn(&run.step);
}
