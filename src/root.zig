//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;

pub const cgroup = @import("cgroup.zig");
pub const cpu = @import("cpu.zig");
pub const memory = @import("memory.zig");

pub const ResourceKind = enum {
    cpu,
    memory,

    pub fn filename(self: ResourceKind) []const u8 {
        return switch (self) {
            .cpu => "cpu.stat",
            .memory => "memory.stat",
        };
    }
};

pub const ResourceCounters = struct {
    cpu: cpu.Counters = cpu.Counters{},
    memory: memory.Counters = memory.Counters{},
};

pub fn parseCounters(io: Io, allocator: std.mem.Allocator, cgroup_path: []const u8) !ResourceCounters {
    var counters: ResourceCounters = .{};
    inline for (std.enums.values(ResourceKind)) |res| {
        var map: std.StringHashMap(u64) = .init(allocator);
        const statContents = try cgroup.readFile(io, allocator, cgroup_path, res.filename());
        defer allocator.free(statContents);

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
            try map.put(key, val);
        }
        switch (res) {
            .cpu => {
                const cpu_counters = cpu.fromMap(&map);
                counters.cpu = cpu_counters;
            },
            .memory => {
                const memory_counters = memory.fromMap(&map);
                counters.memory = memory_counters;
            },
        }
        map.deinit();
    }
    return counters;
}

// Keep this as an integration smoke test for now. Later, prefer a fixture-based
// parser test so it does not depend on the host's /sys/fs/cgroup layout.
test "readCounters" {
    const counters = try parseCounters(std.testing.io, std.testing.allocator, "/sys/fs/cgroup/user.slice/");
    std.debug.print("{any}", .{counters});
}
