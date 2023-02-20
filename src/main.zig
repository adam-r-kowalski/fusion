const std = @import("std");
const fusion = @import("fusion");
const importFunc = fusion.web_assembly.importFunc;
const func = fusion.web_assembly.func;
const start = fusion.web_assembly.start;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const module = &.{
        importFunc(.{ "console", "log" }, "log", &.{.i32}, &.{}),
        func("main", &.{}, &.{}, &.{
            .{ .i32_const = 10 },
            .{ .i32_const = 20 },
            .drop,
            .{ .call = "log" },
        }),
        start("main"),
    };
    const file = try std.fs.cwd().createFile("temp/temp.wat", .{});
    try fusion.web_assembly.wat(module, file.writer());
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
