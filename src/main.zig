const std = @import("std");
const fusion = @import("fusion");

pub fn main() !void {
    const module = fusion.wasm.Module{
        .funcs = &.{
            .{
                .name = "add",
                .params = &.{ .{ .name = "lhs", .type = .i32 }, .{ .name = "rhs", .type = .i32 } },
                .result = .i32,
                .ops = &.{
                    .{ .local_get = "lhs" },
                    .{ .local_get = "rhs" },
                    .i32_add,
                },
            },
        },
        .exports = &.{
            .{ .func = .{ .name = "add" } },
        },
    };
    std.debug.print("{}\n", .{module});
}
