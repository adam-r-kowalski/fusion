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
                .name = "g",
                .desc = .{
                    .global = .{
                        .name = "g",
                        .type = .i32,
                        .mutable = true,
                    },
                },
            },
        },
        .funcs = &.{
            .{
                .name = "getGlobal",
                .results = &.{.i32},
                .body = &.{
                    .{ .global_get = "g" },
                },
            },
            .{
                .name = "incGlobal",
                .body = &.{
                    .{ .global_get = "g" },
                    .{ .i32_const = 1 },
                    .i32_add,
                    .{ .global_set = "g" },
                },
            },
        },
        .exports = &.{
            .{ .name = "getGlobal", .desc = .{ .func = "getGlobal" } },
            .{ .name = "incGlobal", .desc = .{ .func = "incGlobal" } },
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
