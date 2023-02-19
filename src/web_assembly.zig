const std = @import("std");
const Allocator = std.mem.Allocator;
const str = []const u8;

pub const Type = enum {
    i32,
    i64,
    f32,
    f64,
    v128,
};

const Types = []const Type;

pub const Limit = struct {
    min: u32,
    max: ?u32 = null,
};

pub const Import = struct {
    module: str,
    name: str,
    kind: union(enum) {
        func: struct {
            name: str,
            params: Types = &.{},
            results: Types = &.{},
        },
        global: struct {
            name: str,
            type: Type,
            mutable: bool = false,
        },
        memory: Limit,
    },
};

const Imports = []const Import;

pub const Global = struct {
    name: str,
    value: union(enum) {
        i32: i32,
    },
    mutable: bool = false,
};

const Globals = []const Global;

pub const Data = struct {
    offset: u32,
    bytes: str,
};

const Datas = []const Data;

pub const Param = struct {
    name: str,
    type: Type,
};

const Params = []const Param;

pub const Op = union(enum) {
    call: str,
    local_get: str,
    global_get: str,
    global_set: str,
    i32_add,
    i32_const: i32,
};

const Body = []const Op;

pub const Func = struct {
    name: str,
    params: Params = &.{},
    results: Types = &.{},
    body: Body,
};

const Funcs = []const Func;

pub const Export = struct {
    name: str,
    kind: union(enum) {
        func: str,
        global: str,
    },
};

const Exports = []const Export;

pub const Module = struct {
    imports: Imports = &.{},
    globals: Globals = &.{},
    datas: Datas = &.{},
    funcs: Funcs = &.{},
    exports: Exports = &.{},
};

fn watType(t: Type, writer: anytype) !void {
    switch (t) {
        .i32 => try writer.writeAll("i32"),
        .i64 => try writer.writeAll("i64"),
        .f32 => try writer.writeAll("f32"),
        .f64 => try writer.writeAll("f64"),
        .v128 => try writer.writeAll("v128"),
    }
}

fn watImports(imports: Imports, writer: anytype) !void {
    for (imports) |import| {
        const fmt = "\n\n    (import \"{s}\" \"{s}\" ";
        try std.fmt.format(writer, fmt, .{ import.module, import.name });
        switch (import.kind) {
            .func => |func| {
                try std.fmt.format(writer, "(func ${s}", .{func.name});
                if (func.params.len > 0) {
                    try writer.writeAll(" (param");
                    for (func.params) |param| {
                        try writer.writeAll(" ");
                        try watType(param, writer);
                    }
                    try writer.writeAll(")");
                }
                if (func.results.len > 0) {
                    try writer.writeAll(" (result");
                    for (func.results) |result| {
                        try writer.writeAll(" ");
                        try watType(result, writer);
                    }
                    try writer.writeAll(")");
                }
                try writer.writeAll(")");
            },
            .global => |global| {
                try std.fmt.format(writer, "(global ${s}", .{global.name});
                if (global.mutable) {
                    try writer.writeAll(" (mut ");
                    try watType(global.type, writer);
                    try writer.writeAll(")");
                } else {
                    try writer.writeAll(" ");
                    try watType(global.type, writer);
                }
                try writer.writeAll(")");
            },
            .memory => |limit| {
                try std.fmt.format(writer, "(memory {})", .{limit.min});
            },
        }
        try writer.writeAll(")");
    }
}

fn watGlobalType(global: Global, writer: anytype) !void {
    if (global.mutable) try writer.writeAll("(mut ");
    switch (global.value) {
        .i32 => try writer.writeAll("i32"),
    }
    if (global.mutable) try writer.writeAll(")");
}

fn watGlobals(globals: Globals, writer: anytype) !void {
    for (globals) |global| {
        try std.fmt.format(writer, "\n\n    (global ${s} ", .{global.name});
        try watGlobalType(global, writer);
        switch (global.value) {
            .i32 => |value| try std.fmt.format(writer, " (i32.const {})", .{value}),
        }
        try writer.writeAll(")");
    }
}

fn watDatas(datas: Datas, writer: anytype) !void {
    for (datas) |data| {
        const fmt = "\n\n    (data (i32.const {}) \"{s}\")";
        try std.fmt.format(writer, fmt, .{ data.offset, data.bytes });
    }
}

fn watFuncParams(params: Params, writer: anytype) !void {
    for (params) |param| {
        try std.fmt.format(writer, " (param ${s} ", .{param.name});
        try watType(param.type, writer);
        try writer.writeAll(")");
    }
}

fn watFuncResults(results: Types, writer: anytype) !void {
    for (results) |result| {
        try writer.writeAll(" (result ");
        try watType(result, writer);
        try writer.writeAll(")");
    }
}

fn watFuncBody(body: Body, writer: anytype) !void {
    for (body) |op| {
        try writer.writeAll("\n        ");
        switch (op) {
            .call => |value| try std.fmt.format(writer, "(call ${s})", .{value}),
            .local_get => |value| try std.fmt.format(writer, "(local.get ${s})", .{value}),
            .global_get => |value| try std.fmt.format(writer, "(global.get ${s})", .{value}),
            .global_set => |value| try std.fmt.format(writer, "(global.set ${s})", .{value}),
            .i32_add => try writer.writeAll("i32.add"),
            .i32_const => |value| try std.fmt.format(writer, "(i32.const {})", .{value}),
        }
    }
}

fn watFuncs(funcs: Funcs, writer: anytype) !void {
    for (funcs) |func| {
        try std.fmt.format(writer, "\n\n    (func ${s}", .{func.name});
        try watFuncParams(func.params, writer);
        try watFuncResults(func.results, writer);
        try watFuncBody(func.body, writer);
        try writer.writeAll(")");
    }
}

fn watExports(exports: Exports, writer: anytype) !void {
    for (exports) |e| {
        try std.fmt.format(writer, "\n\n    (export \"{s}\" ", .{e.name});
        switch (e.kind) {
            .func => |name| try std.fmt.format(writer, "(func ${s})", .{name}),
            .global => |name| try std.fmt.format(writer, "(global ${s})", .{name}),
        }
        try writer.writeAll(")");
    }
}

pub fn wat(module: Module, writer: anytype) !void {
    try writer.writeAll("(module");
    try watImports(module.imports, writer);
    try watGlobals(module.globals, writer);
    try watDatas(module.datas, writer);
    try watFuncs(module.funcs, writer);
    try watExports(module.exports, writer);
    try writer.writeAll(")");
}

pub fn allocWat(module: Module, allocator: Allocator) !str {
    var list = std.ArrayList(u8).init(allocator);
    try wat(module, list.writer());
    return list.toOwnedSlice();
}

test "non exported function" {
    const allocator = std.testing.allocator;
    const module = Module{
        .funcs = &.{
            .{
                .name = "add",
                .params = &.{
                    .{ .name = "lhs", .type = .i32 },
                    .{ .name = "rhs", .type = .i32 },
                },
                .results = &.{.i32},
                .body = &.{
                    .{ .local_get = "lhs" },
                    .{ .local_get = "rhs" },
                    .i32_add,
                },
            },
        },
    };
    var actual = try allocWat(module, allocator);
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
                    .{ .name = "lhs", .type = .i32 },
                    .{ .name = "rhs", .type = .i32 },
                },
                .results = &.{.i32},
                .body = &.{
                    .{ .local_get = "lhs" },
                    .{ .local_get = "rhs" },
                    .i32_add,
                },
            },
        },
        .exports = &.{
            .{ .name = "add", .kind = .{ .func = "add" } },
        },
    };
    var actual = try allocWat(module, allocator);
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

test "exported function with new name" {
    const allocator = std.testing.allocator;
    const module = Module{
        .funcs = &.{
            .{
                .name = "add",
                .params = &.{
                    .{ .name = "lhs", .type = .i32 },
                    .{ .name = "rhs", .type = .i32 },
                },
                .results = &.{.i32},
                .body = &.{
                    .{ .local_get = "lhs" },
                    .{ .local_get = "rhs" },
                    .i32_add,
                },
            },
        },
        .exports = &.{
            .{ .name = "myAdd", .kind = .{ .func = "add" } },
        },
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $add (param $lhs i32) (param $rhs i32) (result i32)
        \\        (local.get $lhs)
        \\        (local.get $rhs)
        \\        i32.add)
        \\
        \\    (export "myAdd" (func $add)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "function call" {
    const allocator = std.testing.allocator;
    const module = Module{ .funcs = &.{
        .{
            .name = "getAnswer",
            .results = &.{.i32},
            .body = &.{
                .{ .i32_const = 42 },
            },
        },
        .{
            .name = "getAnswerPlus1",
            .results = &.{.i32},
            .body = &.{
                .{ .call = "getAnswer" },
                .{ .i32_const = 1 },
                .i32_add,
            },
        },
    }, .exports = &.{
        .{ .name = "getAnswerPlus1", .kind = .{ .func = "getAnswerPlus1" } },
    } };
    var actual = try allocWat(module, allocator);
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
            .{
                .module = "console",
                .name = "log",
                .kind = .{
                    .func = .{ .name = "log", .params = &.{.i32} },
                },
            },
        },
        .funcs = &.{
            .{
                .name = "logIt",
                .body = &.{
                    .{ .i32_const = 13 },
                    .{ .call = "log" },
                },
            },
        },
        .exports = &.{
            .{ .name = "logIt", .kind = .{ .func = "logIt" } },
        },
    };
    var actual = try allocWat(module, allocator);
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

test "import global variable" {
    const allocator = std.testing.allocator;
    const module = Module{
        .imports = &.{
            .{
                .module = "js",
                .name = "global",
                .kind = .{
                    .global = .{ .name = "g", .type = .i32, .mutable = true },
                },
            },
        },
        .funcs = &.{
            .{
                .name = "getGlobal",
                .results = &.{.i32},
                .body = &.{
                    .{ .global_get = "g" },
                },
            },
            .{
                .name = "incGlobal",
                .body = &.{
                    .{ .global_get = "g" },
                    .{ .i32_const = 1 },
                    .i32_add,
                    .{ .global_set = "g" },
                },
            },
        },
        .exports = &.{
            .{ .name = "getGlobal", .kind = .{ .func = "getGlobal" } },
            .{ .name = "incGlobal", .kind = .{ .func = "incGlobal" } },
        },
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (import "js" "global" (global $g (mut i32)))
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

test "module only global variable" {
    const allocator = std.testing.allocator;
    const module = Module{
        .globals = &.{
            .{ .name = "g", .value = .{ .i32 = 42 }, .mutable = true },
        },
        .funcs = &.{
            .{
                .name = "getGlobal",
                .results = &.{.i32},
                .body = &.{
                    .{ .global_get = "g" },
                },
            },
            .{
                .name = "incGlobal",
                .body = &.{
                    .{ .global_get = "g" },
                    .{ .i32_const = 1 },
                    .i32_add,
                    .{ .global_set = "g" },
                },
            },
        },
        .exports = &.{
            .{ .name = "getGlobal", .kind = .{ .func = "getGlobal" } },
            .{ .name = "incGlobal", .kind = .{ .func = "incGlobal" } },
        },
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (global $g (mut i32) (i32.const 42))
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

test "immutable global variable" {
    const allocator = std.testing.allocator;
    const module = Module{
        .globals = &.{
            .{ .name = "g", .value = .{ .i32 = 42 } },
        },
        .funcs = &.{
            .{
                .name = "getGlobal",
                .results = &.{.i32},
                .body = &.{
                    .{ .global_get = "g" },
                },
            },
        },
        .exports = &.{
            .{ .name = "getGlobal", .kind = .{ .func = "getGlobal" } },
        },
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (global $g i32 (i32.const 42))
        \\
        \\    (func $getGlobal (result i32)
        \\        (global.get $g))
        \\
        \\    (export "getGlobal" (func $getGlobal)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "export global variable" {
    const allocator = std.testing.allocator;
    const module = Module{
        .globals = &.{
            .{ .name = "g", .value = .{ .i32 = 42 }, .mutable = true },
        },
        .funcs = &.{
            .{
                .name = "getGlobal",
                .results = &.{.i32},
                .body = &.{
                    .{ .global_get = "g" },
                },
            },
            .{
                .name = "incGlobal",
                .body = &.{
                    .{ .global_get = "g" },
                    .{ .i32_const = 1 },
                    .i32_add,
                    .{ .global_set = "g" },
                },
            },
        },
        .exports = &.{
            .{ .name = "getGlobal", .kind = .{ .func = "getGlobal" } },
            .{ .name = "incGlobal", .kind = .{ .func = "incGlobal" } },
            .{ .name = "g", .kind = .{ .global = "g" } },
        },
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (global $g (mut i32) (i32.const 42))
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
        \\    (export "incGlobal" (func $incGlobal))
        \\
        \\    (export "g" (global $g)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "import memory" {
    const allocator = std.testing.allocator;
    const module = Module{
        .imports = &.{
            .{
                .module = "js",
                .name = "log",
                .kind = .{
                    .func = .{ .name = "log", .params = &.{ .i32, .i32 } },
                },
            },
            .{ .module = "js", .name = "mem", .kind = .{ .memory = .{ .min = 1 } } },
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
            .{ .name = "writeHi", .kind = .{ .func = "writeHi" } },
        },
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (import "js" "log" (func $log (param i32 i32)))
        \\
        \\    (import "js" "mem" (memory 1))
        \\
        \\    (data (i32.const 0) "Hi")
        \\
        \\    (func $writeHi
        \\        (i32.const 0)
        \\        (i32.const 2)
        \\        (call $log))
        \\
        \\    (export "writeHi" (func $writeHi)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}
