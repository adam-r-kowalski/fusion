const std = @import("std");
const fusion = @import("fusion");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const module = fusion.web_assembly.Module{
        .imports = &.{
            .{
                .module = "js",
                .name = "log",
                .kind = .{
                    .function = .{ .name = "log", .parameters = &.{ .i32, .i32 } },
                },
            },
        },
        .memories = &.{
            .{ .name = "mem", .initial = 1 },
        },
        .datas = &.{
            .{ .offset = 0, .bytes = "Hi" },
        },
        .functions = &.{
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
            .{ .name = "writeHi", .kind = .{ .function = "writeHi" } },
            .{ .name = "mem", .kind = .{ .memory = "mem" } },
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
