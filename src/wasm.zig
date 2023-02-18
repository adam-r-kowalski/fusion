const std = @import("std");
const Allocator = std.mem.Allocator;
const str = []const u8;
const Opts = std.fmt.FormatOptions;

pub const Number = enum {
    i32,
    i64,
    f32,
    f64,

    pub fn format(self: @This(), comptime _: str, _: Opts, writer: anytype) !void {
        switch (self) {
            .i32 => try writer.writeAll("i32"),
            .i64 => try writer.writeAll("i64"),
            .f32 => try writer.writeAll("f32"),
            .f64 => try writer.writeAll("f64"),
        }
    }
};

pub const Value = union(enum) {
    num: Number,
    v128,

    pub fn format(self: @This(), comptime _: str, _: Opts, writer: anytype) !void {
        switch (self) {
            .num => |num| try std.fmt.format(writer, "{}", .{num}),
            .v128 => try writer.writeAll("v128"),
        }
    }
};

pub const Limit = struct {
    min: u32,
    max: u32,
};

pub const Param = struct {
    name: str,
    type: Value,

    pub fn format(self: @This(), comptime _: str, _: Opts, writer: anytype) !void {
		try std.fmt.format(writer, "(param ${s} {})", .{self.name, self.type});
    }
};

pub const Op = union(enum) {
    call: str,
    local_get: str,
    global_get: str,
    global_set: str,
    i32_add,
    i32_const: i32,

    pub fn format(self: @This(), comptime _: str, _: Opts, writer: anytype) !void {
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
    name: str,
    params: []const Param = &.{},
    results: []const Value = &.{},
    body: []const Op,
};

pub const Import = struct { module: str, name: str, desc: union(enum) { func: struct {
    name: str,
    params: []const Number = &.{},
} } };

pub const Global = struct {
    name: str,
    path: [2]str,
    type: Number,
};

pub const Data = struct {
    offset: u32,
    bytes: str,
};

pub const Export = struct {
    name: str,
    desc: union(enum) {
        func: str,

        pub fn format(self: @This(), comptime _: str, _: Opts, writer: anytype) !void {
            switch (self) {
                .func => |name| try std.fmt.format(writer, "(func ${s})", .{name}),
            }
        }
    },

    pub fn format(self: @This(), comptime _: str, _: Opts, writer: anytype) !void {
        try std.fmt.format(writer, "(export \"{s}\" {})", .{ self.name, self.desc });
    }
};

pub const Module = struct {
    // imports: []const Import = &.{},
    // data: []const Data = &.{},
    funcs: []const Func = &.{},
    exports: []const Export = &.{},

    pub fn format(self: @This(), comptime _: str, _: Opts, writer: anytype) !void {
        try writer.writeAll("(module");
        // try writeImports(writer, self);
        // try writeData(writer, self);
        try writeFuncs(writer, self);
        try writeExports(writer, self);
        try writer.writeAll(")");
    }
};

fn writeImports(writer: anytype, module: Module) !void {
    for (module.imports) |import| {
        switch (import) {
            .func => |func| {
                const fmt = "\n\n    (import \"{s}\" \"{s}\" (func ${s}";
                try std.fmt.format(writer, fmt, .{ func.path[0], func.path[1], func.name });
                if (func.params.len > 0) {
                    try writer.writeAll(" (param");
                    for (func.params) |param| {
                        try std.fmt.format(writer, " {}", .{param});
                    }
                    try writer.writeAll(")");
                }
                try writer.writeAll("))");
            },
            .memory => |memory| {
                const fmt = "\n\n    (import \"{s}\" \"{s}\" (memory {}))";
                try std.fmt.format(writer, fmt, .{ memory.path[0], memory.path[1], memory.size });
            },
        }
    }
}

fn writeData(writer: anytype, module: Module) !void {
    for (module.data) |data| {
        const fmt = "\n\n    (data (i32.const {}) \"{s}\")";
        try std.fmt.format(writer, fmt, .{ data.offset, data.bytes });
    }
}

fn writeFuncs(writer: anytype, module: Module) !void {
    for (module.funcs) |func| {
        try std.fmt.format(writer, "\n\n    (func ${s}", .{func.name});
        for (func.params) |param| {
            try std.fmt.format(writer, " {}", .{ param });
        }
        for (func.results) |result| {
            try std.fmt.format(writer, " (result {})", .{result});
        }
        for (func.body) |op| {
            try std.fmt.format(writer, "\n        {}", .{op});
        }
        try writer.writeAll(")");
    }
}

fn writeExports(writer: anytype, module: Module) !void {
    for (module.exports) |e| {
        try std.fmt.format(writer, "\n\n    {}", .{e});
    }
}

test "non exported function" {
    const allocator = std.testing.allocator;
    const module = Module{
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
        },
    };
    const actual = try std.fmt.allocPrint(allocator, "{}", .{module});
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $add (param $lhs i32) (param $rhs i32) (result i32)
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
        },
        .exports = &.{
            .{ .name = "add", .desc = .{ .func = "add" } },
        },
    };
    const actual = try std.fmt.allocPrint(allocator, "{}", .{module});
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $add (param $lhs i32) (param $rhs i32) (result i32)
        \\        (local.get $lhs)
        \\        (local.get $rhs)
        \\        i32.add)
        \\
        \\    (export "add" (func $add)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}
//
// test "exported function with new name" {
//     const allocator = std.testing.allocator;
//     const module = Module{
//         .funcs = &.{
//             .{
//                 .name = "add",
//                 .params = &.{ .{ .name = "lhs", .type = .i32 }, .{ .name = "rhs", .type = .i32 } },
//                 .result = .i32,
//                 .ops = &.{
//                     .{ .local_get = "lhs" },
//                     .{ .local_get = "rhs" },
//                     .i32_add,
//                 },
//             },
//         },
// 		.exports = &.{
// 			.{ .name="myAdd", .desc=.{.func = "add" } },
// 		}
//     };
// 	const actual = try std.fmt.allocPrint(allocator, "{}", .{module});
//     defer allocator.free(actual);
//     const expected =
//         \\(module
//         \\
//         \\    (func $add (param $lhs $i32) (param $rhs $i32) (result i32)
//         \\        (local.get $lhs)
//         \\        (local.get $rhs)
//         \\        i32.add)
//         \\
//         \\    (export "myAdd" (func $add)))
//     ;
//     try std.testing.expectEqualStrings(expected, actual);
// }
//
// test "function call" {
//     const allocator = std.testing.allocator;
//     const module = Module{
//         .funcs = &.{
//             .{
//                 .name = "getAnswer",
//                 .result = .i32,
//                 .ops = &.{
//                     .{ .i32_const = 42 },
//                 },
//             },
//             .{
//                 .name = "getAnswerPlus1",
//                 .result = .i32,
//                 .ops = &.{
//                     .{ .call = "getAnswer" },
//                     .{ .i32_const = 1 },
//                     .i32_add,
//                 },
//             },
//         },
// 		.exports = &.{
// 			.{ .name="getAnswerPlus1", .desc=.{.func = "getAnswerPlus1" } },
// 		}
//     };
// 	const actual = try std.fmt.allocPrint(allocator, "{}", .{module});
//     defer allocator.free(actual);
//     const expected =
//         \\(module
//         \\
//         \\    (func $getAnswer (result i32)
//         \\        (i32.const 42))
//         \\
//         \\    (func $getAnswerPlus1 (result i32)
//         \\        (call $getAnswer)
//         \\        (i32.const 1)
//         \\        i32.add)
//         \\
//         \\    (export "getAnswerPlus1" (func $getAnswerPlus1)))
//     ;
//     try std.testing.expectEqualStrings(expected, actual);
// }
//
// test "import function" {
//     const allocator = std.testing.allocator;
//     const module = Module{
//         .imports = &.{
//             .{ .func = .{ .path = .{ "console", "log" }, .name = "log", .params = &.{.i32} } },
//         },
//         .funcs = &.{
//             .{
//                 .name = "logIt",
//                 .ops = &.{
//                     .{ .i32_const = 13 },
//                     .{ .call = "log" },
//                 },
//             },
//         },
// 		.exports = &.{
// 			.{ .name="logIt", .desc=.{.func = "logIt" } },
// 		}
//     };
// 	const actual = try std.fmt.allocPrint(allocator, "{}", .{module});
//     defer allocator.free(actual);
//     const expected =
//         \\(module
//         \\
//         \\    (import "console" "log" (func $log (param i32)))
//         \\
//         \\    (func $logIt
//         \\        (i32.const 13)
//         \\        (call $log))
//         \\
//         \\    (export "logIt" (func $logIt)))
//     ;
//     try std.testing.expectEqualStrings(expected, actual);
// }
//
// test "global variables" {
//     const allocator = std.testing.allocator;
//     const module = Module{
//         .globals = &.{
//             .{ .name = "g", .path = .{ "js", "global" }, .type = .i32 },
//         },
//         .funcs = &.{
//             .{
//                 .name = "getGlobal",
//                 .result = .i32,
//                 .ops = &.{
//                     .{ .global_get = "g" },
//                 },
//             },
//             .{
//                 .name = "incGlobal",
//                 .ops = &.{
//                     .{ .global_get = "g" },
//                     .{ .i32_const = 1 },
//                     .i32_add,
//                     .{ .global_set = "g" },
//                 },
//             },
//         },
// 		.exports = &.{
// 			.{ .name="getGlobal", .desc=.{.func = "getGlobal" } },
// 			.{ .name="incGlobal", .desc=.{.func = "incGlobal" } },
// 		}
//     };
// 	const actual = try std.fmt.allocPrint(allocator, "{}", .{module});
//     defer allocator.free(actual);
//     const expected =
//         \\(module
//         \\
//         \\    (global $g (import "js" "global") (mut i32))
//         \\
//         \\    (func $getGlobal (result i32)
//         \\        (global.get $g))
//         \\
//         \\    (func $incGlobal
//         \\        (global.get $g)
//         \\        (i32.const 1)
//         \\        i32.add
//         \\        (global.set $g))
//         \\
//         \\    (export "getGlobal" (func $getGlobal))
//         \\
//         \\    (export "incGlobal" (func $incGlobal)))
//     ;
//     try std.testing.expectEqualStrings(expected, actual);
// }
//
// test "memory" {
//     const allocator = std.testing.allocator;
//     const module = Module{
//         .imports = &.{
//             .{ .func = .{ .path = .{ "console", "log" }, .name = "log", .params = &.{ .i32, .i32 } } },
//             .{ .memory = .{ .path = .{ "js", "mem" }, .size = 1 } },
//         },
//         .data = &.{
//             .{ .offset = 0, .bytes = "Hi" },
//         },
//         .funcs = &.{
//             .{
//                 .name = "writeHi",
//                 .ops = &.{
//                     .{ .i32_const = 0 },
//                     .{ .i32_const = 2 },
//                     .{ .call = "log" },
//                 },
//             },
//         },
// 		.exports = &.{
// 			.{ .name="writeHi", .desc=.{.func = "writeHi" } },
// 		}
//     };
// 	const actual = try std.fmt.allocPrint(allocator, "{}", .{module});
//     defer allocator.free(actual);
//     const expected =
//         \\(module
//         \\
//         \\    (import "console" "log" (func $log (param i32 i32)))
//         \\
//         \\    (import "js" "mem" (memory 1))
//         \\
//         \\    (data (i32.const 0) "Hi")
//         \\
//         \\    (func $writeHi
//         \\        (i32.const 0)
//         \\        (i32.const 2)
//         \\        (call $log))
//         \\
//         \\    (export "writeHi" (func $writeHi)))
//     ;
//     try std.testing.expectEqualStrings(expected, actual);
// }
