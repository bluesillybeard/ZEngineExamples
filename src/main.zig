const std = @import("std");
const zengine = @import("zengine");
const zrender = @import("zrender");
const zlm = @import("zlm");
const physics = @import("physics.zig");

pub const Vertex = extern struct {
    pub const attributes = [_]zrender.NamedAttribute{
        .{ .name = "pos", .type = .f32x3 },
        .{ .name = "texCoord", .type = .f32x2 },
        .{ .name = "color", .type = .u8x4normalized },
        .{ .name = "blend", .type = .f32 },
    };
    x: f32,
    y: f32,
    z: f32,
    texX: f32,
    texY: f32,
    color: u32,
    /// 0 -> texture, 1 -> color
    blend: f32,
};

pub fn main() !void {
    var allocatorObj = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = allocatorObj.deinit();
    const allocator = allocatorObj.allocator();

    const ZEngine = zengine.ZEngine(.{
        .globalSystems = &[_]type{ zrender.ZRenderSystem, ExampleSystem },
        .localSystems = &[_]type{},
    });
    var engine = try ZEngine.init(allocator, .{});
    defer engine.deinit();
    var zrenderSystem = engine.registries.globalRegistry.getRegister(zrender.ZRenderSystem).?;
    zrenderSystem.run();
}

pub const ExampleComponent = struct {
    rotation: f32,
    // rotation in the previous update
    lastRotation: f32,
};

pub const ExampleSystem = struct {
    pub const name: []const u8 = "example";
    pub const components = [_]type{ExampleComponent};
    pub fn comptimeVerification(comptime options: zengine.ZEngineComptimeOptions) bool {
        _ = options;
        return true;
    }

    pub fn init(staticAllocator: std.mem.Allocator, heapAllocator: std.mem.Allocator) @This() {
        _ = staticAllocator;
        return .{ .cameraRotation = 0, .lastCameraRotation = 0, .rand = std.rand.DefaultPrng.init(@bitCast(std.time.microTimestamp())), .allocator = heapAllocator };
    }

    pub fn systemInitGlobal(this: *@This(), registries: *zengine.RegistrySet, settings: anytype) !void {
        _ = settings;
        const ecs = &registries.globalEcsRegistry;
        var renderSystem = registries.globalRegistry.getRegister(zrender.ZRenderSystem).?;
        const entity = ecs.create();
        const pipeline = try renderSystem.createPipeline(@embedFile("shaderBin/shader.vert"), @embedFile("shaderBin/shader.frag"), .{ .attributes = &Vertex.attributes, .uniforms = &[_]zrender.NamedUniformTag{
            .{ .name = "tex", .tag = .texture },
            .{ .name = "transform", .tag = .mat4 },
        } });
        // The uniforms unfortunately have to be allocated on the heap.
        // It's a single allocation that lasts the duration of this object, so I am not concerned in the slightest.
        // In a more complex application, it would make sense to merge everything that is static in size and lasts the lifetime of the entity into a single allocation.
        const uniforms = try this.allocator.alloc(zrender.Uniform, 2);
        uniforms[0] = .{ .texture = try renderSystem.loadTexture(@embedFile("parrot.png")) };
        uniforms[1] = .{ .mat4 = zrender.Mat4.identity };
        ecs.add(entity, zrender.RenderComponent{ .mesh = try renderSystem.loadMesh(Vertex, &[_]Vertex{
            .{ .x = -1, .y = -1, .z = 0, .texX = 0, .texY = 1, .color = 0xFFFF0000, .blend = 0 },
            .{ .x = -1, .y = 1, .z = 0, .texX = 0, .texY = 0, .color = 0xFFFF0000, .blend = 0 },
            .{ .x = 1, .y = -1, .z = 0, .texX = 1, .texY = 1, .color = 0xFFFF0000, .blend = 0 },
            .{ .x = 1, .y = 1, .z = 0, .texX = 1, .texY = 0, .color = 0xFFFF0000, .blend = 0 },
        }, &[_]u16{ 0, 1, 2, 1, 3, 2 }, pipeline), .pipeline = pipeline, .uniforms = uniforms });
        ecs.add(entity, ExampleComponent{ .rotation = 0, .lastRotation = 0 });
        renderSystem.onUpdate.sink().connect(&update);
        renderSystem.onFrame.sink().connect(&frame);
        renderSystem.onType.sink().connect(&onType);
        renderSystem.onKeyDown.sink().connect(&onKeyDown);
        renderSystem.onKeyUp.sink().connect(&onKeyUp);
        renderSystem.onMousePress.sink().connect(&onClick);
    }

    fn onKeyDown(args: zrender.OnKeyDownEventArgs) void {
        std.debug.print("Key {} down\n", .{args.key});
    }

    fn onKeyUp(args: zrender.OnKeyUpEventArgs) void {
        std.debug.print("Key {} up\n", .{args.key});
    }

    fn onType(args: zrender.OnTypeEventArgs) void {
        // 4 bytes for the longest codepoint, one more for null terminator
        var buffer = [4:0]u8{ 0, 0, 0, 0 };
        // TODO: make sure the character fits in a u21
        _ = std.unicode.utf8Encode(@intCast(args.character), &buffer) catch std.debug.print("Warn: Invalid unicode point: {}", .{args.character});
        std.debug.print("Typed, {s}\n", .{buffer});
    }

    fn onClick(args: zrender.OnMousePressEventArgs) void {
        std.debug.print("click {}\n", .{args.button});
        const ecs = &args.registries.globalEcsRegistry;
        const renderSystem = args.registries.globalRegistry.getRegister(zrender.ZRenderSystem).?;
        const this = args.registries.globalRegistry.getRegister(ExampleSystem).?;
        var view = ecs.view(.{ ExampleComponent, zrender.RenderComponent }, .{});
        var iter = view.entityIterator();
        while (iter.next()) |entity| {
            // grab the mesh of the entity ahead of time
            const mesh = view.get(zrender.RenderComponent, entity).mesh;
            const random = this.rand.random();
            switch (args.button) {
                0 => {
                    // randomize vertices
                    const vertices = renderSystem.mapMeshVertices(Vertex, mesh, 0, mesh.numVertices);
                    for (vertices) |*vertex| {
                        vertex.x = random.float(f32);
                        vertex.y = random.float(f32);
                        vertex.z = random.float(f32);
                    }
                    renderSystem.unmapMeshVertices(Vertex, mesh, vertices);
                },
                1 => {
                    // shuffle indices
                    const indices = renderSystem.mapMeshIndices(mesh, 0, mesh.numIndices);
                    for (0..indices.len) |i| {
                        //swap this index with a random one
                        const ii = random.intRangeLessThan(usize, 0, indices.len);
                        const temp = indices[i];
                        indices[i] = indices[ii];
                        indices[ii] = temp;
                    }
                    renderSystem.unmapMeshIndices(mesh, indices);
                },
                else => {},
            }
        }
    }

    fn update(args: zrender.OnUpdateEventArgs) void {
        const ecs = &args.registries.globalEcsRegistry;
        var this = args.registries.globalRegistry.getRegister(ExampleSystem).?;
        const deltaSeconds = @as(f32, @floatFromInt(args.delta)) / std.time.us_per_s;
        this.lastCameraRotation = this.cameraRotation;
        this.cameraRotation += std.math.pi / 8.0 * deltaSeconds;
        var view = ecs.view(.{ ExampleComponent, zrender.RenderComponent }, .{});
        var iter = view.entityIterator();
        while (iter.next()) |entity| {
            const exampleComponent = view.get(ExampleComponent, entity);
            exampleComponent.lastRotation = exampleComponent.rotation;
            exampleComponent.rotation += std.math.pi * deltaSeconds;
        }
    }

    fn frame(args: zrender.OnFrameEventArgs) void {
        const ecs = &args.registries.globalEcsRegistry;
        const this = args.registries.globalRegistry.getRegister(ExampleSystem).?;
        const renderSystem = args.registries.globalRegistry.getRegister(zrender.ZRenderSystem).?;
        var view = ecs.view(.{ ExampleComponent, zrender.RenderComponent }, .{});
        var iter = view.entityIterator();
        // From 0 to 1 (and often >1), how far into the current update are we?
        // Holy macaroni, casting with floats in Zig is an absolute nightmare.
        // I really wish @floatFromInt and @intFromFloat took the type as an optional parameter instead having to slap '@as' everywhere
        const t = @as(f32, @floatFromInt(args.time - renderSystem.updateTime)) / @as(f32, @floatFromInt(renderSystem.updateDelta));
        while (iter.next()) |entity| {
            // TODO: lots of optimization potential here
            const exampleComponent = view.get(ExampleComponent, entity);
            const renderComponent = view.get(zrender.RenderComponent, entity);
            var lastTransform = zlm.Mat4.identity;
            var transform = zlm.Mat4.identity;
            // Object transformation
            transform = transform.mul(zlm.Mat4.createAngleAxis(zlm.Vec3.unitZ, exampleComponent.rotation));
            lastTransform = lastTransform.mul(zlm.Mat4.createAngleAxis(zlm.Vec3.unitZ, exampleComponent.lastRotation));

            // camera transformation
            transform = transform.mul(zlm.Mat4.createLookAt(zlm.Vec3{ .x = @cos(this.cameraRotation) * 5, .y = 0, .z = @sin(this.cameraRotation) * 5 }, zlm.Vec3.zero, zlm.Vec3.unitY));
            transform = transform.mul(zlm.Mat4.createPerspective(zlm.toRadians(80.0), 1, 0.0001, 10000));
            lastTransform = lastTransform.mul(zlm.Mat4.createLookAt(zlm.Vec3{ .x = @cos(this.lastCameraRotation) * 5, .y = 0, .z = @sin(this.lastCameraRotation) * 5 }, zlm.Vec3.zero, zlm.Vec3.unitY));
            lastTransform = lastTransform.mul(zlm.Mat4.createPerspective(zlm.toRadians(80.0), 1, 0.0001, 10000));

            renderComponent.uniforms[1].mat4 = zlmToZrenderMat4(matrixLerp(lastTransform, transform, t));
        }
    }

    pub fn systemDeinitGlobal(this: *@This(), registries: *zengine.RegistrySet) void {
        const ecs = &registries.globalEcsRegistry;
        var view = ecs.view(.{ ExampleComponent, zrender.RenderComponent }, .{});
        var iterator = view.entityIterator();
        while (iterator.next()) |entity| {
            const renderComponent = view.get(zrender.RenderComponent, entity);
            this.allocator.free(renderComponent.uniforms);
        }
    }

    pub fn deinit(this: *@This()) void {
        _ = this;
    }

    fn zlmToZrenderMat4(matrix: zlm.Mat4) zrender.Mat4 {
        return zrender.Mat4{
            .m00 = matrix.fields[0][0],
            .m01 = matrix.fields[1][0],
            .m02 = matrix.fields[2][0],
            .m03 = matrix.fields[3][0],
            .m10 = matrix.fields[0][1],
            .m11 = matrix.fields[1][1],
            .m12 = matrix.fields[2][1],
            .m13 = matrix.fields[3][1],
            .m20 = matrix.fields[0][2],
            .m21 = matrix.fields[1][2],
            .m22 = matrix.fields[2][2],
            .m23 = matrix.fields[3][2],
            .m30 = matrix.fields[0][3],
            .m31 = matrix.fields[1][3],
            .m32 = matrix.fields[2][3],
            .m33 = matrix.fields[3][3],
        };
    }

    fn zrenderToZlmMat4(m: zrender.Mat4) zlm.Mat4 {
        return zrender.Mat4{ .fields = [_][4]f32{
            [_]f32{ m.m00, m.m10, m.m20, m.m30 },
            [_]f32{ m.m01, m.m11, m.m21, m.m31 },
            [_]f32{ m.m02, m.m12, m.m22, m.m32 },
            [_]f32{ m.m03, m.m13, m.m23, m.m33 },
        } };
    }

    fn matrixLerp(m0: zlm.Mat4, m1: zlm.Mat4, t: f32) zlm.Mat4 {
        // TODO: vectorize?
        return zlm.Mat4{ .fields = [_][4]f32{
            [4]f32{ fLerp(m0.fields[0][0], m1.fields[0][0], t), fLerp(m0.fields[0][1], m1.fields[0][1], t), fLerp(m0.fields[0][2], m1.fields[0][2], t), fLerp(m0.fields[0][3], m1.fields[0][3], t) },
            [4]f32{ fLerp(m0.fields[1][0], m1.fields[1][0], t), fLerp(m0.fields[1][1], m1.fields[1][1], t), fLerp(m0.fields[1][2], m1.fields[1][2], t), fLerp(m0.fields[1][3], m1.fields[1][3], t) },
            [4]f32{ fLerp(m0.fields[2][0], m1.fields[2][0], t), fLerp(m0.fields[2][1], m1.fields[2][1], t), fLerp(m0.fields[2][2], m1.fields[2][2], t), fLerp(m0.fields[2][3], m1.fields[2][3], t) },
            [4]f32{ fLerp(m0.fields[3][0], m1.fields[3][0], t), fLerp(m0.fields[3][1], m1.fields[3][1], t), fLerp(m0.fields[3][2], m1.fields[3][2], t), fLerp(m0.fields[3][3], m1.fields[3][3], t) },
        } };
    }
    // Std's lerp function has asserts and other stuff.
    // So, a "fast and loose" version is used, which does not already exist in std for some reason.
    // t is not bounds checked because during lag t may be greater than 1.
    // The formula works just fine without it, honestly I don't even know why std would bother doing such a pointless check, rendering it useless for my use case.
    inline fn fLerp(a: f32, b: f32, t: f32) f32 {
        return @mulAdd(f32, b - a, t, a);
    }
    cameraRotation: f32,
    // camera rotation in the last update
    lastCameraRotation: f32,
    rand: std.rand.DefaultPrng,
    allocator: std.mem.Allocator,
};
