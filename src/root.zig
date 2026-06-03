//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;

pub const cgroup = @import("cgroup.zig");
pub const cpu = @import("cpu.zig");
pub const memory = @import("memory.zig");

pub const ResourceStats = struct {
    cpu: cpu.Stats = cpu.Stats{},
    memory: memory.Stats = memory.Stats{},
};

pub fn getStats(io: Io, allocator: std.mem.Allocator, cgroup_path: []const u8) !ResourceStats {
    var stats: ResourceStats = .{};

    // CPU
    stats.cpu = try cpu.getCPUStats(io, allocator, cgroup_path);

    // Memory
    stats.memory = try memory.getMemoryStats(io, allocator, cgroup_path);

    return stats;
}

test "getStats" {
    const stats = try getStats(std.testing.io, std.testing.allocator, "/sys/fs/cgroup/system.slice/docker-294b69a239ad3697bcbfd4acbd35f130a34857a3736a68fd0790ffc7364e9723.scope");
    std.debug.print("{any}\n", .{stats});
}
