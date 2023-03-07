const std = @import("std");
const fusion = @import("fusion");

fn outputWat() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const module = &.{
        .{
            .func = .{
                .name = "add",
                .params = &.{ .{ "lhs", .i32 }, .{ "rhs", .i32 } },
                .results = &.{.i32},
                .ops = &.{
                    .{ .local_get = "lhs" },
                    .{ .local_get = "rhs" },
                    .i32_add,
                },
            },
        },
    };
    const file = try std.fs.cwd().createFile("temp/temp.wat", .{});
    defer file.close();
    try fusion.write.wat.wat(file.writer(), module);
    const result = try std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &.{ "wat2wasm", "temp.wat" },
        .cwd = "temp",
    });
    if (result.stdout.len > 0) {
        std.debug.print("\nstdout: {s}\n", .{result.stdout});
    }
    if (result.stderr.len > 0) {
        std.debug.print("\nstderr: {s}\n", .{result.stderr});
    }
}

fn printTime(label: []const u8, start: u64, stop: u64) void {
    std.debug.print("\n{s} {d:0.07}s", .{
        label,
        @intToFloat(f64, stop - start) / std.time.ns_per_s,
    });
}

fn printAst() !void {
    var timer = try std.time.Timer.start();
    const t0 = timer.read();
    const allocator = std.heap.page_allocator;
    const t1 = timer.read();
    if (std.os.argv.len < 2) {
        std.debug.panic(
            \\
            \\ERROR - No input file specified
            \\
            \\Correct usage: fusion <input file>
        , .{});
    }
    const fileName = std.mem.span(std.os.argv[1]);
    const maxSize = std.math.maxInt(usize);
    const file = try std.fs.cwd().readFileAlloc(allocator, fileName, maxSize);
    defer allocator.free(file);
    const t2 = timer.read();
    var tokens = fusion.tokenize.tokenize(file);
    const t3 = timer.read();
    const ast = try fusion.parse(&tokens, allocator);
    defer ast.deinit();
    const t4 = timer.read();
    const writer = std.io.getStdOut().writer();
    try fusion.write.ast.ast(writer, ast);
    const t5 = timer.read();
    printTime("read file", t1, t2);
    printTime("parse", t3, t4);
    printTime("total", t0, t5);
    std.debug.print("\n", .{});
}

pub fn main() !void {
    try printAst();
}
