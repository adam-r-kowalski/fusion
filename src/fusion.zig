const std = @import("std");

const Type = enum {
    i32,
    i64,
    f32,
    f64,

    pub fn format(value: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (value) {
            .i32 => try writer.writeAll("i32"),
            .i64 => try writer.writeAll("i64"),
            .f32 => try writer.writeAll("f32"),
            .f64 => try writer.writeAll("f64"),
        }
    }
};

const Param = struct { name: []const u8, type: Type };

const Op = union(enum) {
    local_get: []const u8,
    i32_add,

    pub fn format(value: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (value) {
            .local_get => |name| try std.fmt.format(writer, "(local.get ${s})", .{name}),
            .i32_add => try writer.writeAll("i32.add"),
        }
    }
};

const Func = struct {
    name: []const u8,
    params: []const Param,
    result: Type,
    ops: []const Op,
    exported: bool = false,
};

const Module = struct { funcs: []const Func };

fn wat(allocator: std.mem.Allocator, module: Module) ![]u8 {
    var output = std.ArrayList(u8).init(allocator);
    const writer = output.writer();
    try writer.writeAll("(module\n");
    var exports = std.ArrayList([]const u8).init(allocator);
    defer exports.deinit();
    for (module.funcs) |func| {
        try std.fmt.format(writer, "  (func ${s}", .{func.name});
        for (func.params) |param| {
            try std.fmt.format(writer, " (param ${s} ${})", .{ param.name, param.type });
        }
        try std.fmt.format(writer, " (result {})", .{func.result});
        for (func.ops) |op| {
            try std.fmt.format(writer, "\n   {}", .{op});
        }
        try writer.writeAll(")");
        if (func.exported) {
            try exports.append(func.name);
        }
    }
    if (exports.items.len > 0) {
        try writer.writeAll("\n");
    }
    for (exports.items) |name| {
        try std.fmt.format(writer, "\n  (export \"{s}\" (func ${s}))", .{ name, name });
    }
    try writer.writeAll(")");
    return output.toOwnedSlice();
}

test "generate wat for a non exported function" {
    const allocator = std.testing.allocator;
    const module = Module{
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
    const actual = try wat(allocator, module);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\  (func $add (param $lhs $i32) (param $rhs $i32) (result i32)
        \\   (local.get $lhs)
        \\   (local.get $rhs)
        \\   i32.add))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "generate wat for a exported function" {
    const allocator = std.testing.allocator;
    const module = Module{
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
                .exported = true,
            },
        },
    };
    const actual = try wat(allocator, module);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\  (func $add (param $lhs $i32) (param $rhs $i32) (result i32)
        \\   (local.get $lhs)
        \\   (local.get $rhs)
        \\   i32.add)
        \\
        \\  (export "add" (func $add)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}
