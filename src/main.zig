const std = @import("std");
const zengine = @import("zengine");
const sdl = @import("sdl");
const zlm = @import("zlm");
const gl = @import("gl.zig");
const ecs = @import("ecs");
const stbi = @cImport(@cInclude("stb_image.h"));

pub fn main() !void {
    // Initialize ZEngine
    var allocatorObj = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = allocatorObj.deinit();
    const allocator = allocatorObj.allocator();

    var engine = zengine.ZEngine.init(allocator);
    defer engine.deinit();
    var renderSystem: RenderSystem = undefined;
    try renderSystem.init(allocator, "ZRender Example", 800, 600, &engine);
    defer renderSystem.systemDeinit();
    try engine.registerGlobalSystem(RenderSystem, &renderSystem);
    var exampleSystem: ExampleSystem = undefined;
    try exampleSystem.init(allocator, &engine);
    // Get the render system and run the game
    // const renderSystem = engine.registries.globalRegistry.getRegister(RenderSystem).?;
    try renderSystem.run();
}

// RenderSystem is simply being used as a place to store data.
// In a larger project, it would make sense for this system to also provide rendering functions as well,
// but for now we're just directly calling OpenGL functions.
pub const RenderSystem = struct {
    pub const OnFrameEventArgs = struct {
        engine: *zengine.ZEngine,
    };

    pub fn init(this: *RenderSystem, heapAllocator: std.mem.Allocator, title: [:0]const u8, width: usize, height: usize, engine: *zengine.ZEngine) !void {
        this.* = .{
            // publics
            .frame = ecs.Signal(OnFrameEventArgs).init(heapAllocator),
            .engine = engine,
            // privates
            ._allocator = heapAllocator,
            ._running = true,
            ._window = undefined,
            ._context = undefined,
        };
        try sdl.init(sdl.InitFlags.everything);
        this._window = try sdl.createWindow(title, .default, .default, width, height, .{
            .resizable = true,
            .context = .opengl,
        });
        try sdl.gl.setAttribute(.{.context_major_version = 4});
        try sdl.gl.setAttribute(.{.context_minor_version = 6});
        try sdl.gl.setAttribute(.{.doublebuffer = true});
        try sdl.gl.setAttribute(.{.red_size = 8});
        try sdl.gl.setAttribute(.{.green_size = 8});
        try sdl.gl.setAttribute(.{.blue_size = 8});
        try sdl.gl.setAttribute(.{.depth_size = 24});
        try sdl.gl.setAttribute(.{.context_flags = .{.debug = true}});
        this._context = try sdl.gl.createContext(this._window);
        try gl.load(void{}, loadProc);
    }

    // This function exists because SDL's getProcAddress does not have the correct signature.
    fn loadProc(context: void, function: [:0]const u8) ?gl.FunctionPointer {
        _ = context;
        return @ptrCast(sdl.gl.getProcAddress(function));
    }

    pub fn run(this: *@This()) !void {
        // Main loop
        while (this._running) {
            sdl.pumpEvents();
            while (sdl.pollEvent()) |event| {
                if(event == .quit) {
                    this._running = false;
                }
            }
            try sdl.gl.makeCurrent(this._context, this._window);
            gl.clearColor(0, 0, 0, 1);
            gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
            this.frame.publish(.{
                .engine = this.engine,
            });
            try sdl.gl.setSwapInterval(.adaptive_vsync);
            sdl.gl.swapWindow(this._window);
        }
    }

    // Other systems rely on this system's memory being valid throughout deinit
    // So just to be safe we deinit very last in a separate function
    pub fn systemDeinit(this: *@This()) void {
        sdl.gl.deleteContext(this._context);
        this._window.destroy();
        this.frame.deinit();
    }

    // This is a required function for all ZEngine systems
    pub fn deinit(this: *@This()) void {
        _ = this;
    }
    // Public things
    engine: *zengine.ZEngine,
    frame: ecs.Signal(OnFrameEventArgs),
    // Private things
    _allocator: std.mem.Allocator,
    _window: sdl.Window,
    _context: sdl.gl.Context,
    _running: bool,
};

pub const ExampleComponent = struct {
    rotation: f32,
    // rotation in the previous update
    lastRotation: f32,
};

pub const ExampleSystem = struct {
    pub fn init(this: *ExampleSystem, heapAllocator: std.mem.Allocator, engine: *zengine.ZEngine) !void {
        this.* = .{
            .cameraRotation = 0, 
            .lastCameraRotation = 0,
            .rand = std.rand.DefaultPrng.init(@bitCast(std.time.microTimestamp())),
            .allocator = heapAllocator,
            .program = undefined,
            .vertexBuffer = undefined,
            .indexBuffer = undefined,
            .vao = undefined,
            .texture = undefined,
        };
        const entities = engine.getGlobalEcs();
        const entity = entities.create();
        entities.add(entity, ExampleComponent{ .rotation = 0, .lastRotation = 0 });
        // hook into required events
        const renderSystem = try engine.getGlobalSystem(RenderSystem);
        renderSystem.frame.sink().connectBound(this, "frame");
        // Load all of the things we need
        // shaders 
        {
            const vertexShader = gl.createShader(gl.VERTEX_SHADER);
            const vertexShaderSource = @embedFile("shader.vert.glsl");
            gl.shaderSource(vertexShader, 1, &[1][*:0]const u8{vertexShaderSource.ptr}, &[1]gl.GLint{vertexShaderSource.len});
            gl.compileShader(vertexShader);
            var status: gl.GLint = 0;
            gl.getShaderiv(vertexShader, gl.COMPILE_STATUS, &status);
            if(status == gl.FALSE) {
                // The shader failed to compile, panic!
                // TODO: return error instead of panicking
                var buffer: [8191:0]u8 = undefined;
                gl.getShaderInfoLog(vertexShader, buffer.len+1, null, &buffer);
                const string: [*:0]const u8 = &buffer;
                std.debug.print("Failed to compile vertex shader: {s}\n", .{string});
                std.debug.panic("Failed to compile shaders.", .{});
            }
            const fragmentShader = gl.createShader(gl.FRAGMENT_SHADER);
            const fragmentShaderSource = @embedFile("shader.frag.glsl");
            gl.shaderSource(fragmentShader, 1, &[1][*:0]const u8{fragmentShaderSource}, &[1]gl.GLint{fragmentShaderSource.len});
            gl.compileShader(fragmentShader);
            gl.getShaderiv(fragmentShader, gl.COMPILE_STATUS, &status);
            if(status == gl.FALSE) {
                // The shader failed to compile, panic!
                // TODO: return error instead of panicking
                var buffer: [8191:0]u8 = undefined;
                gl.getShaderInfoLog(fragmentShader, buffer.len+1, null, &buffer);
                const string: [*:0]const u8 = &buffer;
                std.debug.print("Failed to compile fragment shader: {s}\n", .{string});
                std.debug.panic("Failed to compile shaders.", .{});
            }

            this.program = gl.createProgram();
            gl.attachShader(this.program, vertexShader);
            gl.attachShader(this.program, fragmentShader);
            gl.linkProgram(this.program);
            gl.getProgramiv(this.program,gl.LINK_STATUS, &status);
            if(status == gl.FALSE) {
                var buffer: [8191:0]u8 = undefined;
                gl.getProgramInfoLog(this.program, buffer.len + 1, null, &buffer);
                const string: [*:0]const u8 = &buffer;
                std.debug.print("Failed to link program: {s}\n", .{string});
                std.debug.panic("Failed to compile shaders.", .{});
            }
            gl.detachShader(this.program, vertexShader);
            gl.detachShader(this.program, fragmentShader);
            gl.deleteShader(vertexShader);
            gl.deleteShader(fragmentShader);
        }
        // quad mesh
        {
            const meshData = [_]f32 {
                //x, y, z, tx, ty
                -1, -1, 0, 0, 1,
                -1,  1, 0, 0, 0,
                 1, -1, 0, 1, 1,
                 1,  1, 0, 1, 0,
            };
            const indices = [_]u16 {
                 0, 1, 2, 1, 3, 2,
            };
            var buffers: [2]gl.GLuint = undefined;
            gl.createBuffers(buffers.len, &buffers);
            this.vertexBuffer = buffers[0];
            this.indexBuffer = buffers[1];
            gl.namedBufferStorage(this.vertexBuffer, meshData.len * @sizeOf(f32), &meshData, 0);
            gl.namedBufferStorage(this.indexBuffer, indices.len * @sizeOf(u16), &indices, 0);
            gl.createVertexArrays(1, &this.vao);
            gl.enableVertexArrayAttrib(this.vao, 0);
            gl.enableVertexArrayAttrib(this.vao, 1);
            gl.vertexArrayAttribFormat(this.vao, 0, 3, gl.FLOAT, gl.FALSE, 0);
            gl.vertexArrayAttribFormat(this.vao, 1, 2, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32));
        }
        // bird texture
        {
            // Load the texture
            const imageSource = @embedFile("parrot.png");
            var width: c_int = undefined;
            var height: c_int = undefined;
            const imageData: [*]u8 = stbi.stbi_load_from_memory(imageSource.ptr, imageSource.len, &width, &height, null, 4);
            defer stbi.stbi_image_free(imageData);
            // Now we have the data, load it into opengl
            gl.genTextures(1, &this.texture);
            gl.activeTexture(gl.TEXTURE0);
            gl.bindTexture(gl.TEXTURE_2D, this.texture);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
            gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, @intCast(width), @intCast(height), 0, gl.RGBA, gl.UNSIGNED_BYTE, imageData);
            gl.generateMipmap(gl.TEXTURE_2D);
        }
    }

    pub fn frame(this: *@This(), args: RenderSystem.OnFrameEventArgs) void {
        const entities = args.engine.getGlobalEcs();
        // TODO: update at fixed step
        this.update(entities);
        var view = entities.view(.{ ExampleComponent}, .{});
        var iter = view.entityIterator();
        // From 0 to 1 (and often >1), how far into the current update are we?
        // Holy macaroni, casting with floats in Zig is an absolute nightmare.
        // I really wish @floatFromInt and @intFromFloat took the type as an optional parameter instead having to slap '@as' everywhere
        const t = 0;//@as(f32, @floatFromInt(args.time - renderSystem.updateTime)) / @as(f32, @floatFromInt(renderSystem.updateDelta));
        // Draw all of our entities
        gl.useProgram(this.program);
        gl.bindVertexArray(this.vao);
        gl.bindVertexBuffer(0, this.vertexBuffer, 0, 5 * @sizeOf(f32));
        gl.vertexArrayAttribBinding(this.vao, 0, 0);
        gl.vertexArrayAttribBinding(this.vao, 1, 0);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.indexBuffer);
        gl.bindTexture(gl.TEXTURE_2D, this.texture);
        while (iter.next()) |entity| {
            // TODO: lots of optimization potential here
            const exampleComponent = view.get(entity);
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

            // the final transformation to send to OpenGL
            var finalTransform = matrixLerp(lastTransform, transform, t);
            // Zlm Mat4 is fortunately compatible with OpenGL. The transform matrix is ALWAYS bound to location 0.
            gl.uniformMatrix4fv(0, 1, 0, @ptrCast(&finalTransform));
            gl.drawElements(gl.TRIANGLES, 6, gl.UNSIGNED_SHORT, null);
        }
    }

    fn update(this: *@This(), entities: *ecs.Registry) void {
        const deltaSeconds  = 1.0 / 60.0;
        this.lastCameraRotation = this.cameraRotation;
        this.cameraRotation += std.math.pi / 8.0 * deltaSeconds;
        var view = entities.view(.{ ExampleComponent}, .{});
        var iter = view.entityIterator();
        while (iter.next()) |entity| {
            const exampleComponent = view.get(entity);
            exampleComponent.lastRotation = exampleComponent.rotation;
            exampleComponent.rotation += std.math.pi * deltaSeconds;
        }
    }

    pub fn deinit(this: *@This()) void {
        _ = this;
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
    program: gl.GLuint,
    vertexBuffer: gl.GLuint,
    indexBuffer: gl.GLuint,
    vao: gl.GLuint,
    texture: gl.GLuint,
};
