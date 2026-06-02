const std = @import("std");
const Io = std.Io;

const zidle = @import("zidle");
const clap = @import("clap");

const SubCommand = enum { help, scan };

const main_parsers = .{
    .command = clap.parsers.enumeration(SubCommand),
};

const main_params = clap.parseParamsComptime(
    \\-h, --help Display this help and exit.
    \\<command>
    \\
);

const MainArgs = clap.ResultEx(clap.Help, &main_params, main_parsers);

pub fn main(init: std.process.Init) !void {
    // This is appropriate for anything that lives as long as the process.
    const arena: std.mem.Allocator = init.arena.allocator();
    _ = arena;
    const gpa: std.mem.Allocator = init.gpa;
    // In order to do I/O operations need an `Io` instance.
    const io = init.io;

    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    // Accessing command line arguments:
    var iter = try init.minimal.args.iterateAllocator(gpa);
    defer iter.deinit();

    var diag = clap.Diagnostic{};
    var res = clap.parseEx(clap.Help, &main_params, main_parsers, &iter, .{
        .diagnostic = &diag,
        .allocator = gpa,
        .terminating_positional = 0,
    }) catch |err| {
        try diag.reportToFile(io, .stderr(), err);
        return;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try clap.helpToFile(io, .stderr(), clap.Help, &main_params, .{});
    }

    const command: SubCommand = res.positionals[0] orelse return error.NoCommandProvided;

    switch (command) {
        .help => try clap.helpToFile(io, .stderr(), clap.Help, &main_params, .{}),
        .scan => try scanMain(io, gpa, &iter, res),
    }

    try stdout_writer.flush(); // Don't forget to flush!
}

fn scanMain(io: std.Io, allocator: std.mem.Allocator, iter: *std.process.Args.Iterator, main_args: MainArgs) !void {
    _ = io;
    _ = allocator;
    _ = iter;
    _ = main_args;
}
