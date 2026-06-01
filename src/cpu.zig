const std = @import("std");

pub const Counters = struct {
    usage_usec: ?u64,
    user_usec: ?u64,
    system_usec: ?u64,
    nice_usec: ?u64,
    nr_periods: ?u64,
    nr_throttled: ?u64,
    throttled_usec: ?u64,
    nr_bursts: ?u64,
    burst_usec: ?u64,
};

pub fn fromMap(map: *const std.StringHashMap(u64)) Counters {
    return .{
        .usage_usec = map.get("usage_usec"),
        .user_usec = map.get("user_usec"),
        .burst_usec = map.get("burst_usec"),
        .nice_usec = map.get("nice_usec"),
        .nr_bursts = map.get("nr_bursts"),
        .nr_periods = map.get("nr_periods"),
        .nr_throttled = map.get("nr_throttled"),
        .system_usec = map.get("system_usec"),
        .throttled_usec = map.get("throttled_usec"),
    };
}
