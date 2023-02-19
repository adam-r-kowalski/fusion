const std = @import("std");
const fusion = @import("fusion");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const module = fusion.web_assembly.Module{
        .functions = &.{
            .{
                .name = "get_90",
                .results = &.{.i32},
                .body = &.{
                    .{ .i32_const = 10 },
                    .{ .i32_const = 90 },
                    // return the second value (90); the first is discarded
                    .return_,
                },
            },
        },
        .exports = &.{
            .{ .name = "get_90", .kind = .{ .function = "get_90" } },
        },
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
