const std = @import("std");
const zengine = @import("zengine");
const zrender = @import("zrender");
const zlm = @import("zlm");

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

pub const ExampleComponent = extern struct {
    rotation: f32,
};

pub const ExampleSystem = extern struct {
    pub const name: []const u8 = "example";
    pub const components = [_]type{ExampleComponent};
    pub fn comptimeVerification(comptime options: zengine.ZEngineComptimeOptions) bool {
        _ = options;
        return true;
    }

    pub fn init(staticAllocator: std.mem.Allocator, heapAllocator: std.mem.Allocator) @This() {
        _ = heapAllocator;
        _ = staticAllocator;
        return .{.cameraRotation = 0};
    }

    pub fn systemInitGlobal(this: *@This(), registries: *zengine.RegistrySet) !void {
        _ = this;
        var renderSystem = registries.globalRegistry.getRegister(zrender.ZRenderSystem).?;
        const entity = registries.globalEcsRegistry.create();
        registries.globalEcsRegistry.add(entity, zrender.RenderComponent{
            .mesh = try renderSystem.loadMesh(&[_]zrender.Vertex{
                .{.x = -1, .y = -1, .z = 0, .texX = 0, .texY = 1, .color = 0xFFFF0000, .blend = 0},
                .{.x = -1, .y =  1, .z = 0, .texX = 0, .texY = 0, .color = 0xFFFF0000, .blend = 0},
                .{.x =  1, .y = -1, .z = 0, .texX = 1, .texY = 1, .color = 0xFFFF0000, .blend = 0},
                .{.x =  1, .y =  1, .z = 0, .texX = 1, .texY = 0, .color = 0xFFFF0000, .blend = 0},
            }, &[_]u16{0, 1, 2, 1, 3, 2}),
            .texture = try renderSystem.loadTexture(@embedFile("parrot.png")),
            .transform = zrender.Mat4.identity,
        });
        registries.globalEcsRegistry.add(entity, ExampleComponent{.rotation = 0});
        renderSystem.onUpdate.sink().connect(&update);
        renderSystem.onType.sink().connect(&onType);
    }

    fn onType(args: zrender.OnTypeEventArgs) void {
        var buffer = [5]u8{0, 0, 0, 0, 0};
        // TODO: make sure the character fits in a u21
        _ = std.unicode.utf8Encode(@intCast(args.character), &buffer) catch std.debug.print("Warn: Invalid unicode point: {}", .{args.character});
        std.debug.print("Typed, {s}\n", .{buffer});
    }

    fn update(args: zrender.OnUpdateEventArgs) void {
        var ecs = args.registries.globalEcsRegistry;
        var self = args.registries.globalRegistry.getRegister(ExampleSystem).?;
        self.cameraRotation += 0.01;
        var view = ecs.view(.{ExampleComponent, zrender.RenderComponent}, .{});
        var iter = view.entityIterator();
        while(iter.next()) |entity| {
            const exampleComponent = view.get(ExampleComponent, entity);
            const renderComponent = view.get(zrender.RenderComponent, entity);
            exampleComponent.rotation += 0.3;
            var transform = zlm.Mat4.identity;
            // Object transformation
            transform = transform.mul(zlm.Mat4.createAngleAxis(zlm.Vec3.unitZ, exampleComponent.rotation));
            // camera transformation
            transform = transform.mul(zlm.Mat4.createLookAt(zlm.Vec3{.x = @cos(self.cameraRotation)*5, .y = 0, .z = @sin(self.cameraRotation)*5}, zlm.Vec3.zero, zlm.Vec3.unitY));
            transform = transform.mul(zlm.Mat4.createPerspective(zlm.toRadians(80.0), 1, 0.0001, 10000));

            renderComponent.transform = zrender.Mat4{
                .m00 = transform.fields[0][0], .m01 = transform.fields[1][0], .m02 = transform.fields[2][0], .m03 = transform.fields[3][0],
                .m10 = transform.fields[0][1], .m11 = transform.fields[1][1], .m12 = transform.fields[2][1], .m13 = transform.fields[3][1],
                .m20 = transform.fields[0][2], .m21 = transform.fields[1][2], .m22 = transform.fields[2][2], .m23 = transform.fields[3][2],
                .m30 = transform.fields[0][3], .m31 = transform.fields[1][3], .m32 = transform.fields[2][3], .m33 = transform.fields[3][3],
            };
        }
    }

    pub fn systemDeinitGlobal(this: *@This(), registries: *zengine.RegistrySet) void {
        _ = registries;
        _ = this;
    }

    pub fn deinit(this: *@This()) void {
        _ = this;

    }
    cameraRotation: f32,
};
