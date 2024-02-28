const std = @import("std");
const zengine = @import("zengine");
const ecs = @import("ecs");
const zrender = @import("zrender");
// TODO: when zigified Box2D bindings exist, use that instead.
pub const box2d = @cImport({
    @cInclude("box2d/box2d.h");
});

// "where is the physics component?"
// Having a predefined component for physics would limit what the physics system is capible of.
// Allowing users to employ Box2D's objects directly in their own custom components is the way to go.

/// This physics system works as both a global and a local system
pub const PhysicsSystem = struct {
    pub const name: []const u8 = "physics";
    pub const components = [_]type{};
    pub fn comptimeVerification(comptime options: zengine.ZEngineComptimeOptions) bool {
        //TODO
        _ = options;
        return true;
    }

    pub fn init(staticAllocator: std.mem.Allocator, heapAllocator: std.mem.Allocator) @This() {
        _ = staticAllocator;
        return .{
            .allocator = heapAllocator,
            .world = undefined,
        };
    }

    // init is the same for local and global systems
    fn systemInit(this: *@This(), registries: *zengine.RegistrySet) !void {
        _ = this;
        _ = registries;

        // The only event we need is update. But it's important to note that functions may still be called on frames.

    }

    pub fn systemInitGlobal(this: *@This(), registries: *zengine.RegistrySet, settings: anytype) !void {
        _ = registries;
        _ = this;
        _ = settings;
    }

    pub fn systemInitLocal(this: *@This(), registries: *zengine.RegistrySet, handle: zengine.LocalHandle, settings: anytype) !void {
        _ = handle;
        _ = registries;
        _ = this;
        _ = settings;
    }

    pub fn systemDeinitGlobal(this: *@This(), registries: *zengine.RegistrySet) void {
        _ = registries;
        _ = this;
    }

    pub fn systemDeinitLocal(this: *@This(), registries: *zengine.RegistrySet) !void {
        _ = registries;
        _ = this;
    }

    pub fn deinit(this: *@This()) void {
        _ = this;
    }
    world: box2d.b2WorldId,
    allocator: std.mem.Allocator,
};
