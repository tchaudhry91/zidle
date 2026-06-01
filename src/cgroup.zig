const std = @import("std");
const Io = std.Io;

pub fn scanCGroups(io: Io, allocator: std.mem.Allocator, root: []const u8) ![][]const u8 {
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

pub fn readFile(io: Io, allocator: std.mem.Allocator, cgroup_path: []const u8, filename: []const u8) ![]u8 {
    const path = try std.fs.path.join(allocator, &[_][]const u8{ cgroup_path, filename });
    defer allocator.free(path);

    const file = try std.Io.Dir.openFileAbsolute(io, path, .{});
    defer file.close(io);

    var buffer: [4096]u8 = undefined;
    var reader = file.readerStreaming(io, &buffer);
    return reader.interface.allocRemaining(allocator, .limited(16 * 1024));
}
