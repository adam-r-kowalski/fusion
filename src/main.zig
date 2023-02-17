const std = @import("std");
const fusion = @import("fusion");

pub fn main() !void {
	var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
	const allocator = arena.allocator();
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
	};
	const wat = try fusion.wasm.wat(allocator, module);
	std.debug.print("{s}\n", .{wat});
}
