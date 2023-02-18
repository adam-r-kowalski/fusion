const std = @import("std");
const fusion = @import("fusion");

pub fn main() !void {
    const module = fusion.wasm.Module{
        .funcs = &.{
            .{
                .name = "add",
                .params = &.{
                    .{ .name = "lhs", .type = .{ .num = .i32 } },
                    .{ .name = "rhs", .type = .{ .num = .i32 } },
                },
                .results = &.{.{ .num = .i32 }},
                .body = &.{
                    .{ .local_get = "lhs" },
                    .{ .local_get = "rhs" },
                    .i32_add,
                },
            },
            .{
                .name = "start",
                .results = &.{.{ .num = .i32 }},
                .body = &.{
                    .{ .i32_const = 5 },
                    .{ .i32_const = 10 },
                    .{ .call = "add" },
                },
            },
        },
        .exports = &.{
            .{ .name = "_start", .desc = .{ .func = "start" } },
        },
    };
	const file = try std.fs.cwd().createFile("temp/temp.wat", .{});
	const wat = try std.fmt.allocPrint(std.heap.page_allocator, "{}", .{module});
	try file.writeAll(wat);
}
