const std = @import("std");

pub const Type = enum {
    i32,
    i64,
    f32,
    f64,

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .i32 => try writer.writeAll("i32"),
            .i64 => try writer.writeAll("i64"),
            .f32 => try writer.writeAll("f32"),
            .f64 => try writer.writeAll("f64"),
        }
    }
};

pub const Param = struct {
    name: []const u8,
    type: Type,
};

pub const Op = union(enum) {
    call: []const u8,
    local_get: []const u8,
    i32_add,
    i32_const: i32,

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .call => |value| try std.fmt.format(writer, "(call ${s})", .{value}),
            .local_get => |value| try std.fmt.format(writer, "(local.get ${s})", .{value}),
            .i32_add => try writer.writeAll("i32.add"),
            .i32_const => |value| try std.fmt.format(writer, "(i32.const {})", .{value}),
        }
    }
};

pub const Func = struct {
    name: []const u8,
    params: []const Param = &.{},
    result: ?Type = null,
    ops: []const Op,
    exported: bool = false,
};

pub const Import = union(enum) {
    func: struct {
        path: [2][]const u8,
        name: []const u8,
        params: []const Type = &.{},
    },
};

pub const Module = struct {
    imports: []const Import = &.{},
    funcs: []const Func = &.{},
};

pub fn wat(allocator: std.mem.Allocator, module: Module) ![]u8 {
    var output = std.ArrayList(u8).init(allocator);
    const writer = output.writer();
    try writer.writeAll("(module");
    var exports = std.ArrayList([]const u8).init(allocator);
    defer exports.deinit();
    for (module.imports) |import| {
        switch (import) {
            .func => |func| {
                const fmt = "\n\n    (import \"{s}\" \"{s}\" (func ${s}";
                try std.fmt.format(writer, fmt, .{ func.path[0], func.path[1], func.name });
                for (func.params) |param| {
                    try std.fmt.format(writer, " (param {})", .{param});
                }
                try writer.writeAll("))");
            },
        }
    }
    for (module.funcs) |func| {
        try std.fmt.format(writer, "\n\n    (func ${s}", .{func.name});
        for (func.params) |param| {
            try std.fmt.format(writer, " (param ${s} ${})", .{ param.name, param.type });
        }
        if (func.result) |result| {
            try std.fmt.format(writer, " (result {})", .{result});
        }
        for (func.ops) |op| {
            try std.fmt.format(writer, "\n        {}", .{op});
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
        try std.fmt.format(writer, "\n    (export \"{s}\" (func ${s}))", .{ name, name });
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
        \\
        \\    (func $add (param $lhs $i32) (param $rhs $i32) (result i32)
        \\        (local.get $lhs)
        \\        (local.get $rhs)
        \\        i32.add))
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
        \\
        \\    (func $add (param $lhs $i32) (param $rhs $i32) (result i32)
        \\        (local.get $lhs)
        \\        (local.get $rhs)
        \\        i32.add)
        \\
        \\    (export "add" (func $add)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "generate wat for a function call" {
    const allocator = std.testing.allocator;
    const module = Module{
        .funcs = &.{
            .{
                .name = "getAnswer",
                .result = .i32,
                .ops = &.{
                    .{ .i32_const = 42 },
                },
            },
            .{
                .name = "getAnswerPlus1",
                .result = .i32,
                .ops = &.{
                    .{ .call = "getAnswer" },
                    .{ .i32_const = 1 },
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
        \\
        \\    (func $getAnswer (result i32)
        \\        (i32.const 42))
        \\
        \\    (func $getAnswerPlus1 (result i32)
        \\        (call $getAnswer)
        \\        (i32.const 1)
        \\        i32.add)
        \\
        \\    (export "getAnswerPlus1" (func $getAnswerPlus1)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "generate wat for a import" {
    const allocator = std.testing.allocator;
    const module = Module{
        .imports = &.{
            .{ .func = .{ .path = .{ "console", "log" }, .name = "log", .params = &.{.i32} } },
        },
        .funcs = &.{
            .{
                .name = "logIt",
                .ops = &.{
                    .{ .i32_const = 13 },
                    .{ .call = "log" },
                },
                .exported = true,
            },
        },
    };
    const actual = try wat(allocator, module);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (import "console" "log" (func $log (param i32)))
        \\
        \\    (func $logIt
        \\        (i32.const 13)
        \\        (call $log))
        \\
        \\    (export "logIt" (func $logIt)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}
