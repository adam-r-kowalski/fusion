const std = @import("std");
const fusion = @import("fusion");
const importFunc = fusion.web_assembly.importFunc;
const func = fusion.web_assembly.func;
const start = fusion.web_assembly.start;
const table = fusion.web_assembly.table;
const elem = fusion.web_assembly.elem;
const functype = fusion.web_assembly.functype;
const p = fusion.web_assembly.param;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const module = &.{
        table("table", 2),
        func("f", &.{}, &.{.i32}, &.{
            .{ .i32_const = 42 },
        }),
        func("g", &.{}, &.{.i32}, &.{
            .{ .i32_const = 13 },
        }),
        elem(0, "f"),
        elem(1, "g"),
        functype("return_i32", &.{}, &.{.i32}),
        func("callByIndex", &.{p("i", .i32)}, &.{.i32}, &.{
            .{ .local_get = "i" },
            .{ .call_indirect = "return_i32" },
        }),
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
