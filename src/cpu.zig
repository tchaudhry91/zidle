const std = @import("std");

pub const Counters = struct {
    usage_usec: ?u64 = null, // Total CPU time consumed by the cgroup, in microseconds.
    user_usec: ?u64 = null, // CPU time spent in user space, in microseconds.
    system_usec: ?u64 = null, // CPU time spent in kernel space, in microseconds.
    nice_usec: ?u64 = null, // CPU time from tasks with positive nice values, in microseconds.
    nr_periods: ?u64 = null, // Number of CPU quota enforcement periods elapsed.
    nr_throttled: ?u64 = null, // Number of quota periods where the cgroup was CPU-throttled.
    throttled_usec: ?u64 = null, // Total time the cgroup spent throttled, in microseconds.
    nr_bursts: ?u64 = null, // Number of CPU burst events, if burst accounting is enabled.
    burst_usec: ?u64 = null, // Total burst CPU time used, in microseconds.
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
