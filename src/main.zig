const std = @import("std");
const fusion = @import("fusion");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const module = fusion.wasm.Module{
        .imports = &.{
            .{
                .module = "js",
                .name = "log",
                .desc = .{
                    .func = .{ .name = "log", .params = &.{.i32} },
                },
            },
        },
        .funcs = &.{
            .{
                .name = "add",
                .params = &.{
                    .{ .name = "lhs", .type = .i32 },
                    .{ .name = "rhs", .type = .i32 },
                },
                .results = &.{.i32},
                .body = &.{
                    .{ .local_get = "lhs" },
                    .{ .local_get = "rhs" },
                    .i32_add,
                },
            },
            .{
                .name = "on_load",
                .body = &.{
                    .{ .i32_const = 10 },
                    .{ .i32_const = 15 },
                    .{ .call = "add" },
                    .{ .call = "log" },
                },
            },
        },
        .exports = &.{
            .{ .name = "on_load", .desc = .{ .func = "on_load" } },
        },
    };
    const file = try std.fs.cwd().createFile("temp/temp.wat", .{});
    try std.fmt.format(file.writer(), "{}", .{module});
    _ = try std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &.{ "wat2wasm", "temp.wat" },
        .cwd = "temp",
    });
}
