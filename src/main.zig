const std = @import("std");
const Io = std.Io;

const zidle = @import("zidle");

const Command = union(enum) {
    help,
    version,
    scan_cgroups: ScanOptions,
};

const ScanOptions = struct {
    root: []const u8 = "/sys/fs/cgroup/",
};

pub fn main(init: std.process.Init) !void {
    // This is appropriate for anything that lives as long as the process.
    const arena: std.mem.Allocator = init.arena.allocator();

    // Accessing command line arguments:
    const args = try init.minimal.args.toSlice(arena);

    // In order to do I/O operations need an `Io` instance.
    const io = init.io;

    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    if (args.len < 2) {
        try printUsage(stdout_writer);
        try stdout_writer.flush();
        return;
    }

    const cmd: Command = parseCommand(args[1..]) catch |err| {
        if (err == error.InvalidScanCommand) {
            // Print Scan Usage instead
            try stdout_writer.print("invalid scan command flag\n\n", .{});
            try printScanUsage(stdout_writer);
            try stdout_writer.flush();
            return;
        }
        try stdout_writer.print("unknown command: {s}\n\n", .{args[1]});
        try printUsage(stdout_writer);
        try stdout_writer.flush();
        return;
    };

    switch (cmd) {
        .help => try printUsage(stdout_writer),
        .version => try printUsage(stdout_writer), // Wire Up Later
        .scan_cgroups => |opts| {
            const cgroups = try zidle.scanCGroups(io, arena, opts.root);
            for (cgroups) |cg| {
                try stdout_writer.print("{s}\n", .{cg});
            }
            try stdout_writer.flush();
        },
    }

    try stdout_writer.flush(); // Don't forget to flush!
}

fn parseCommand(args: []const [:0]const u8) !Command {
    if (args.len < 1) {
        return error.NoCommandProvided;
    }
    const cmdArg = args[0];
    if (std.mem.eql(u8, cmdArg, "help")) {
        return .help;
    }
    if (std.mem.eql(u8, cmdArg, "version")) {
        return .version;
    }
    if (std.mem.eql(u8, cmdArg, "scan-cgroups")) {
        // Parse Scan Options
        var i: usize = 1;
        var opts: ScanOptions = .{};
        while (i < args.len) {
            if (std.mem.eql(u8, args[i], "--root")) {
                if (args.len <= i + 1) {
                    return error.InvalidScanCommand;
                }
                // consume root
                opts.root = args[i + 1];
                i += 2;
                continue;
            } else {
                return error.InvalidScanCommand;
            }
            i += 1;
        }
        return .{ .scan_cgroups = opts };
    }
    return error.UnknownCommand;
}

fn printUsage(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.print(
        \\Usage:
        \\  zidle help
        \\  zidle version
        \\  zidle scan-cgroups
        \\
        \\Commands:
        \\  help          show this help text
        \\  version       print the zidle version
        \\  scan-cgroups  list candidate cgroup paths
        \\
    , .{});
}

fn printScanUsage(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.print(
        \\Usage:
        \\  zidle scan-cgroups [--root PATH]
        \\
        \\Options:
        \\  --root PATH   cgroup v2 mount/root to scan (default: /sys/fs/cgroup/)
        \\
    , .{});
}
