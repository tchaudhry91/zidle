const std = @import("std");

pub const Counters = struct {
    anon: ?u64, // Anonymous memory such as heap, stack, and private writable mappings.
    file: ?u64, // File-backed memory and page cache charged to the cgroup.
    kernel: ?u64, // Kernel memory charged to the cgroup.
    pgmajfault: ?u64, // Major page faults; useful as a disk/swap pressure delta.
    pgscan: ?u64, // Pages scanned for reclaim; useful as a memory pressure delta.
    pgsteal: ?u64, // Pages reclaimed; pairs with pgscan to show reclaim effectiveness.
};

pub fn fromMap(map: *const std.StringHashMap(u64)) Counters {
    return .{
        .anon = map.get("anon"),
        .file = map.get("file"),
        .kernel = map.get("kernel"),
        .pgmajfault = map.get("pgmajfault"),
        .pgscan = map.get("pgscan"),
        .pgsteal = map.get("pgsteal"),
    };
}
