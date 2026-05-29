const std = @import("std");
const Io = std.Io;

const zidle = @import("zidle");

const Command = enum {
    help,
    version,
    scan_cgroups,
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

    const cmd: Command = parseCommand(args[1]) catch {
        try stdout_writer.print("unknown command: {s}\n\n", .{args[1]});
        try printUsage(stdout_writer);
        try stdout_writer.flush();
        return;
    };

    switch (cmd) {
        .help => try printUsage(stdout_writer),
        .version => try printUsage(stdout_writer), // Wire Up Later
        .scan_cgroups => {
            const cgroups = try zidle.scanCGroups(io, arena);
            for (cgroups) |cg| {
                std.debug.print("{s}\n", .{cg});
            }
        },
    }

    try stdout_writer.flush(); // Don't forget to flush!
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

fn parseCommand(arg: [:0]const u8) !Command {
    if (std.mem.eql(u8, arg, "help")) {
        return .help;
    }
    if (std.mem.eql(u8, arg, "version")) {
        return .version;
    }
    if (std.mem.eql(u8, arg, "scan-cgroups")) {
        return .scan_cgroups;
    }
    return error.UnknownCommand;
}
