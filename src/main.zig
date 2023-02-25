const std = @import("std");
const fusion = @import("fusion");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const module = &.{
        .{ .table = .{ .name = "table", .initial = 2 } },
        .{
            .func = .{
                .name = "f",
                .params = &.{},
                .results = &.{.i32},
                .ops = &.{.{ .i32_const = 42 }},
            },
        },
        .{
            .func = .{
                .name = "g",
                .params = &.{},
                .results = &.{.i32},
                .ops = &.{.{ .i32_const = 13 }},
            },
        },
        .{ .elem = .{ .offset = 0, .name = "f" } },
        .{ .elem = .{ .offset = 1, .name = "g" } },
        .{ .functype = .{ .name = "return_i32", .params = &.{}, .results = &.{.i32} } },
        .{
            .func = .{
                .name = "callByIndex",
                .params = &.{.{ .name = "i", .type = .i32 }},
                .results = &.{.i32},
                .ops = &.{
                    .{ .local_get = "i" },
                    .{ .call_indirect = "return_i32" },
                },
            },
        },
        .{ .export_ = .{ .name = "table", .kind = .{ .table = "table" } } },
        .{ .export_ = .{ .name = "callByIndex", .kind = .{ .func = "callByIndex" } } },
    };
    const file = try std.fs.cwd().createFile("temp/temp.wat", .{});
    defer file.close();
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
