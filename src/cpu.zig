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

test "fromCPUStatContents parses cpu.stat sample" {
    const contents =
        \\usage_usec 6136726436
        \\user_usec 2802966952
        \\system_usec 3333759483
        \\nice_usec 28555532
        \\core_sched.force_idle_usec 0
        \\nr_periods 0
        \\nr_throttled 0
        \\throttled_usec 0
        \\nr_bursts 0
        \\burst_usec 0
        \\
    ;

    const stats = fromCPUStatContents(contents);

    try std.testing.expectEqual(@as(?u64, 6136726436), stats.usage_usec);
    try std.testing.expectEqual(@as(?u64, 2802966952), stats.user_usec);
    try std.testing.expectEqual(@as(?u64, 3333759483), stats.system_usec);
    try std.testing.expectEqual(@as(?u64, 0), stats.throttled_usec);
    try std.testing.expectEqual(@as(?u64, 0), stats.burst_usec);
}
