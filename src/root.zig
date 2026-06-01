//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;

const ResourceStat = enum {
    cpu,
    memory,

    pub fn filename(self: ResourceStat) []const u8 {
        return switch (self) {
            .cpu => "cpu.stat",
            .memory => "memory.stat",
        };
    }
};

const ResourceCounters = union(enum) {
    cpu: CPUCounters,
    memory: MemoryCounters,
}

const CPUCounters = struct {
    usage_usec: usize,
    user_usec: usize,
    system_usec: usize,
    nice_usec: usize,
    nr_periods: usize,
    nr_throttled: usize,
    throttled_usec: usize,
    nr_bursts: usize,
    burst_usec: usize,
};

const MemoryCounters = struct {
}

pub fn scanCGroups(io: Io, allocator: std.mem.Allocator, root: []const u8) !([][]const u8) {
    var items = try std.ArrayList([]const u8).initCapacity(allocator, 10);
    const cgroups = try Io.Dir.openDirAbsolute(io, root, .{ .iterate = true });
    defer cgroups.close(io);

    var walker = try cgroups.walk(allocator);
    defer walker.deinit();

    while (try walker.next(io)) |item| {
        if (item.kind == .directory) {
            try items.append(allocator, try allocator.dupe(u8, item.path));
        }
    }

    return items.toOwnedSlice(allocator);
}

pub fn parseCounters(io: Io, allocator: std.mem.Allocator, cgroup: []const u8, res: ResourceStat) !std.StringHashMap(usize) {
    var counters: std.StringHashMap(usize) = .init(allocator);
    const statContents = try readStat(io, allocator, cgroup, res);
    defer allocator.free(statContents);
    // Split by line
    var lineIterator = std.mem.tokenizeScalar(u8, statContents, '\n');
    while (lineIterator.next()) |line| {
        std.debug.print("\nLine:{s}", .{line});
        if (line.len == 0) {
            continue;
        }
        const index = std.mem.find(u8, line, " ");
        if (index == null) {
            continue;
        }
        if (index.? + 1 >= line.len) {
            continue;
        }
        const key = line[0..index.?];
        const val = std.fmt.parseInt(usize, line[index.? + 1 ..], 10) catch {
            continue;
        };
        try counters.put(key, val);
    }
    return counters;
}

fn readStat(io: Io, allocator: std.mem.Allocator, cgroup: []const u8, res: ResourceStat) ![]u8 {
    const fPath = try std.fs.path.join(allocator, &[_][]const u8{ cgroup, res.filename() });
    defer allocator.free(fPath);
    const statF = try std.Io.Dir.openFileAbsolute(io, fPath, .{});
    defer statF.close(io);

    var buffer: [4096]u8 = undefined;
    var reader = statF.readerStreaming(io, &buffer);
    return reader.interface.allocRemaining(allocator, .limited(16 * 1024));
}

test "readCPUCounters" {
    var counters = try parseCounters(std.testing.io, std.testing.allocator, "/sys/fs/cgroup/user.slice/", .cpu);
    defer counters.deinit();
    var iter = counters.iterator();
    while (iter.next()) |item| {
        std.debug.print("{s}=={d}", .{ item.key_ptr.*, item.value_ptr.* });
    }
}
