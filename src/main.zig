const std = @import("std");
const zengine = @import("zengine");
const zrender = @import("zrender");

pub fn main() !void {
    var allocatorObj = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = allocatorObj.allocator();

    const ZEngine = zengine.ZEngine(.{
        .globalSystems = &[_]type{zrender.ZRenderSystem},
        .localSystems = &[_]type{},
    });
    var engine = try ZEngine.init(allocator);
    var zrenderSystem = engine.registries.globalRegistry.getRegister(zrender.ZRenderSystem).?;
    try zrenderSystem.initZRender(&engine.registries);
    zrenderSystem.run();
    defer engine.deinit();
}