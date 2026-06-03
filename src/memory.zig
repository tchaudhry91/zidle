const std = @import("std");
const cgroup = @import("cgroup.zig");

pub const Stats = struct {
    current: ?u64 = null,
    max: ?u64 = null,
    high: ?u64 = null,
    peak: ?u64 = null,
};

pub fn getMemoryStats(io: std.Io, allocator: std.mem.Allocator, cgroup_path: []const u8) !Stats {
    var stats: Stats = .{};
    const current = try cgroup.readFile(io, allocator, cgroup_path, "memory.current");
    stats.current = std.fmt.parseInt(u64, std.mem.trim(u8, current, "\n\t "), 10) catch null;
    allocator.free(current);

    const max = try cgroup.readFile(io, allocator, cgroup_path, "memory.max");
    stats.max = std.fmt.parseInt(u64, std.mem.trim(u8, max, "\n\t "), 10) catch null;
    allocator.free(max);

    const high = try cgroup.readFile(io, allocator, cgroup_path, "memory.high");
    stats.high = std.fmt.parseInt(u64, std.mem.trim(u8, high, "\n\t "), 10) catch null;
    allocator.free(high);

    const peak = try cgroup.readFile(io, allocator, cgroup_path, "memory.peak");
    stats.peak = std.fmt.parseInt(u64, std.mem.trim(u8, peak, "\n\t "), 10) catch null;
    allocator.free(peak);

    return stats;
}
