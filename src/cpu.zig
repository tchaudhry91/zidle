const std = @import("std");
const cgroup = @import("cgroup.zig");

pub const Stats = struct {
    usage_usec: ?u64 = null, // Total CPU time consumed by the cgroup, in microseconds.
    user_usec: ?u64 = null, // CPU time spent in user space, in microseconds.
    system_usec: ?u64 = null, // CPU time spent in kernel space, in microseconds.
    throttled_usec: ?u64 = null, // Total time the cgroup spent throttled, in microseconds.
    burst_usec: ?u64 = null, // Total burst CPU time used, in microseconds.
};

pub fn getCPUStats(io: std.Io, allocator: std.mem.Allocator, cgroup_path: []const u8) !Stats {
    const cpuStatContents = try cgroup.readFile(io, allocator, cgroup_path, "cpu.stat");
    defer allocator.free(cpuStatContents);
    return fromCPUStatContents(cpuStatContents);
}

fn fromCPUStatContents(statContents: []const u8) Stats {
    var stats: Stats = .{};
    var lineIterator = std.mem.tokenizeScalar(u8, statContents, '\n');
    while (lineIterator.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        const index = std.mem.find(u8, line, " ") orelse continue;
        if (index + 1 >= line.len) {
            continue;
        }

        const key = line[0..index];
        const val = std.fmt.parseInt(u64, line[index + 1 ..], 10) catch {
            continue;
        };
        if (std.mem.eql(u8, "usage_usec", key)) {
            stats.usage_usec = val;
            continue;
        }
        if (std.mem.eql(u8, "user_usec", key)) {
            stats.user_usec = val;
            continue;
        }
        if (std.mem.eql(u8, "system_usec", key)) {
            stats.system_usec = val;
            continue;
        }
        if (std.mem.eql(u8, "throttled_usec", key)) {
            stats.throttled_usec = val;
            continue;
        }
        if (std.mem.eql(u8, "burst_usec", key)) {
            stats.burst_usec = val;
            continue;
        }
    }
    return stats;
}
