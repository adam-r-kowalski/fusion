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
                    .func = .{ .name = "log", .params = &.{ .i32, .i32 } },
                },
            },
            .{ .module = "js", .name = "mem", .desc = .{ .memory = .{ .min = 1 } } },
        },
        .datas = &.{
            .{ .offset = 0, .bytes = "Hi" },
        },
        .funcs = &.{
            .{
                .name = "writeHi",
                .body = &.{
                    .{ .i32_const = 0 },
                    .{ .i32_const = 2 },
                    .{ .call = "log" },
                },
            },
        },
        .exports = &.{
            .{ .name = "writeHi", .desc = .{ .func = "writeHi" } },
        },
    };
    const file = try std.fs.cwd().createFile("temp/temp.wat", .{});
    try std.fmt.format(file.writer(), "{}", .{module});
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
