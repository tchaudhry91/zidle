//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;

pub fn scanCGroups(io: Io, allocator: std.mem.Allocator) !([][]const u8) {
    var items = try std.ArrayList([]const u8).initCapacity(allocator, 10);
    std.log.debug("Assuming cgroup2fs", .{});
    const cgroups = try Io.Dir.openDirAbsolute(io, "/sys/fs/cgroup/", .{ .iterate = true });
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
