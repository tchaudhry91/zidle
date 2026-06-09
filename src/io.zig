const std = @import("std");
const cgroup = @import("cgroup.zig");

pub const Stats = struct {
    rbytes: ?u64 = null,
    wbytes: ?u64 = null,
    dbytes: ?u64 = null,
    rios: ?u64 = null,
    wios: ?u64 = null,
    dios: ?u64 = null,
};

pub fn getIOStats(io: std.Io, allocator: std.mem.Allocator, cgroup_path: []const u8) !Stats {
    const ioStatContents = try cgroup.readFile(io, allocator, cgroup_path, "io.stat");
    defer allocator.free(ioStatContents);
    return fromIOStatContents(ioStatContents);
}

pub fn fromIOStatContents(statContents: []const u8) Stats {
    var stats: Stats = .{};
    var lineIterator = std.mem.tokenizeScalar(u8, statContents, '\n');

    while (lineIterator.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        var wordIterator = std.mem.tokenizeScalar(u8, line, ' ');
        while (wordIterator.next()) |word| {
            const index = std.mem.find(u8, word, "=") orelse continue;
            if (index + 1 >= word.len) {
                continue;
            }
            const key = word[0..index];
            const val: u64 = std.fmt.parseInt(u64, word[index + 1 ..], 10) catch
                {
                    continue;
                };

            if (std.mem.eql(u8, "rbytes", key)) {
                if (stats.rbytes != null) {
                    stats.rbytes.? += val;
                } else {
                    stats.rbytes = val;
                }
                continue;
            }

            if (std.mem.eql(u8, "wbytes", key)) {
                if (stats.wbytes != null) {
                    stats.wbytes.? += val;
                } else {
                    stats.wbytes = val;
                }
                continue;
            }

            if (std.mem.eql(u8, "dbytes", key)) {
                if (stats.dbytes != null) {
                    stats.dbytes.? += val;
                } else {
                    stats.dbytes = val;
                }
                continue;
            }

            if (std.mem.eql(u8, "rios", key)) {
                if (stats.rios != null) {
                    stats.rios.? += val;
                } else {
                    stats.rios = val;
                }
                continue;
            }

            if (std.mem.eql(u8, "wios", key)) {
                if (stats.wios != null) {
                    stats.wios.? += val;
                } else {
                    stats.wios = val;
                }
                continue;
            }

            if (std.mem.eql(u8, "dios", key)) {
                if (stats.dios != null) {
                    stats.dios.? += val;
                } else {
                    stats.dios = val;
                }
                continue;
            }
        }
    }
    return stats;
}

test "fromIOStatContents parses and sums io.stat sample" {
    const contents =
        \\251:0 rbytes=8192 wbytes=20480 rios=2 wios=5 dbytes=0 dios=0
        \\253:0 rbytes=1019441152 wbytes=2251751424 rios=20099 wios=52647 dbytes=0 dios=0
        \\
    ;

    const stats = fromIOStatContents(contents);

    try std.testing.expectEqual(@as(?u64, 1019449344), stats.rbytes);
    try std.testing.expectEqual(@as(?u64, 2251771904), stats.wbytes);
    try std.testing.expectEqual(@as(?u64, 20101), stats.rios);
    try std.testing.expectEqual(@as(?u64, 52652), stats.wios);
    try std.testing.expectEqual(@as(?u64, 0), stats.dbytes);
    try std.testing.expectEqual(@as(?u64, 0), stats.dios);
}
