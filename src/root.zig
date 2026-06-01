//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;

const ResourceStat = enum {
    cpu_stat,
    memory_stat,

    pub fn filename(self: ResourceStat) []const u8 {
        return switch (self) {
            .cpu_stat => "cpu.stat",
            .memory_stat => "memory.stat",
        };
    }
};

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

pub fn parseCounters(io: Io, allocator: std.mem.Allocator, cgroup: []const u8, res: ResourceStat) !std.AutoHashMap([]const u8, usize) {
    var counters: std.AutoHashMap([]const u8, usize) = .init(allocator);
    defer counters.deinit();
    const statContents = try readStat(io, allocator, cgroup, res);
    defer allocator.free(statContents);
    // Split by line
    var lineIterator = std.mem.tokenizeScalar(u8, statContents, '\n');
    while (lineIterator.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        const index = std.mem.find(u8, line, " ");
        if (index == null) {
            continue;
        }
        const key = line[0..index.?];
        const val = try std.fmt.parseInt(usize, line[index.?..], 10) catch {
            continue;
        };

        counters.put(key, val);
    }
    std.debug.print("{any}", counters);
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
    const contents = try parseCounters(std.testing.io, std.testing.allocator, "/sys/fs/cgroup/user.slice/", .cpu_stat);
    defer std.testing.allocator.free(contents);
    std.debug.print("\n\n{d}\n\n", .{contents.len});
}
