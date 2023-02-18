const std = @import("std");
const Allocator = std.mem.Allocator;

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
    global_get: []const u8,
    global_set: []const u8,
    i32_add,
    i32_const: i32,

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .call => |value| try std.fmt.format(writer, "(call ${s})", .{value}),
            .local_get => |value| try std.fmt.format(writer, "(local.get ${s})", .{value}),
            .global_get => |value| try std.fmt.format(writer, "(global.get ${s})", .{value}),
            .global_set => |value| try std.fmt.format(writer, "(global.set ${s})", .{value}),
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

pub const Global = struct {
    name: []const u8,
    path: [2][]const u8,
    type: Type,
};

pub const Module = struct {
    globals: []const Global = &.{},
    imports: []const Import = &.{},
    funcs: []const Func = &.{},
};

const Writer = std.ArrayList(u8).Writer;

fn writeGlobals(writer: Writer, module: Module) !void {
    for (module.globals) |global| {
        const fmt = "\n\n    (global ${s} (import \"{s}\" \"{s}\") (mut {}))";
        try std.fmt.format(writer, fmt, .{
            global.name,
            global.path[0],
            global.path[1],
            global.type,
        });
    }
}

fn writeImports(writer: Writer, module: Module) !void {
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
}

fn writeFuncs(allocator: Allocator, writer: Writer, module: Module) ![][]const u8 {
    var exports = std.ArrayList([]const u8).init(allocator);
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
	return exports.toOwnedSlice();
}

fn writeExports(writer: Writer, exports: [][]const u8) !void {
	for (exports) |name| {
		try std.fmt.format(writer, "\n\n    (export \"{s}\" (func ${s}))", .{ name, name });
	}
}

pub fn wat(allocator: Allocator, module: Module) ![]u8 {
    var output = std.ArrayList(u8).init(allocator);
    const writer = output.writer();
    try writer.writeAll("(module");
	try writeGlobals(writer, module);
	try writeImports(writer, module);
	const exports = try writeFuncs(allocator, writer, module);
    defer allocator.free(exports);
	try writeExports(writer, exports);
    try writer.writeAll(")");
    return output.toOwnedSlice();
}

test "non exported function" {
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

test "exported function" {
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

test "function call" {
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

test "import function" {
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

test "global variables" {
    const allocator = std.testing.allocator;
    const module = Module{
        .globals = &.{
            .{ .name = "g", .path = .{ "js", "global" }, .type = .i32 },
        },
        .funcs = &.{
            .{
                .name = "getGlobal",
                .result = .i32,
                .ops = &.{
                    .{ .global_get = "g" },
                },
                .exported = true,
            },
            .{
                .name = "incGlobal",
                .ops = &.{
                    .{ .global_get = "g" },
                    .{ .i32_const = 1 },
                    .i32_add,
                    .{ .global_set = "g" },
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
        \\    (global $g (import "js" "global") (mut i32))
        \\
        \\    (func $getGlobal (result i32)
        \\        (global.get $g))
        \\
        \\    (func $incGlobal
        \\        (global.get $g)
        \\        (i32.const 1)
        \\        i32.add
        \\        (global.set $g))
        \\
        \\    (export "getGlobal" (func $getGlobal))
		\\
        \\    (export "incGlobal" (func $incGlobal)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}
