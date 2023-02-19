const std = @import("std");
const fusion = @import("fusion");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const module = fusion.web_assembly.Module{
        .imports = &.{
            .{
                .module = "console",
                .name = "log",
                .kind = .{
                    .function = .{ .name = "log", .parameters = &.{.i32} },
                },
            },
        },
        .functions = &.{
            .{
                .name = "log_if_not_100",
                .parameters = &.{.{ .name = "num", .type = .i32 }},
                .body = &.{
                    .{
                        .block = .{
                            .name = "my_block",
                            .body = &.{
                                .{ .local_get = "num" },
                                .{ .i32_const = 100 },
                                .i32_eq,
                                .{
                                    .if_ = .{
                                        .then = &.{
                                            .{ .br = "my_block" },
                                        },
                                    },
                                },
                                .{ .local_get = "num" },
                                .{ .call = "log" },
                            },
                        },
                    },
                },
            },
        },
        .exports = &.{
            .{ .name = "log_if_not_100", .kind = .{ .function = "log_if_not_100" } },
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
