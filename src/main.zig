const std = @import("std");
const zengine = @import("zengine");
const zrender = @import("zrender");

pub fn main() !void {
    var allocatorObj = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = allocatorObj.deinit();
    const allocator = allocatorObj.allocator();

    const ZEngine = zengine.ZEngine(.{
        .globalSystems = &[_]type{zrender.ZRenderSystem, ExampleSystem},
        .localSystems = &[_]type{},
    });
    var engine = try ZEngine.init(allocator);
    defer engine.deinit();
    var zrenderSystem = engine.registries.globalRegistry.getRegister(zrender.ZRenderSystem).?;
    zrenderSystem.run();
}
pub const ExampleSystem = extern struct {
    pub const name: []const u8 = "example";
    pub const components = [_]type{};
    pub fn comptimeVerification(comptime options: zengine.ZEngineComptimeOptions) bool {
        _ = options;
        return true;
    }

    pub fn init(staticAllocator: std.mem.Allocator, heapAllocator: std.mem.Allocator) @This() {
        _ = heapAllocator;
        _ = staticAllocator;
        return .{};
    }

    pub fn systemInitGlobal(this: *@This(), registries: *zengine.RegistrySet) !void {
        _ = this;
        var renderSystem = registries.globalRegistry.getRegister(zrender.ZRenderSystem).?;
        const entity = registries.globalEcsRegistry.create();
        registries.globalEcsRegistry.add(entity, zrender.RenderComponent{
            .mesh = try renderSystem.loadMesh(&[_]zrender.Vertex{
                .{.x = -1, .y = -1, .z = 0.5, .texX = 0, .texY = 1, .color = 0xFFFF0000, .blend = 0},
                .{.x = -1, .y =  1, .z = 0.5, .texX = 0, .texY = 0, .color = 0xFFFF0000, .blend = 0},
                .{.x =  1, .y = -1, .z = 0.5, .texX = 1, .texY = 1, .color = 0xFFFF0000, .blend = 0},
                .{.x =  1, .y =  1, .z = 0.5, .texX = 1, .texY = 0, .color = 0xFFFF0000, .blend = 0},
            }, &[_]u16{0, 1, 2, 1, 3, 2}),
            .texture = try renderSystem.loadTexture(@embedFile("parrot.png")),
            .transform = zrender.Mat4.identity,
        });
        renderSystem.onUpdate.sink().connect(&update);
    }

    fn update(args: zrender.OnUpdateEventArgs) void {
        _ = args;
    }

    pub fn systemDeinitGlobal(this: *@This(), registries: *zengine.RegistrySet) void {
        _ = registries;
        _ = this;
    }

    pub fn deinit(this: *@This()) void {
        _ = this;

    }
};
