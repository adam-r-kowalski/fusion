const std = @import("std");
const Allocator = std.mem.Allocator;
const str = []const u8;
const Opts = std.fmt.FormatOptions;

pub const Type = enum {
    i32,
    i64,
    f32,
    f64,
    v128,

    pub fn format(self: @This(), comptime _: str, _: Opts, writer: anytype) !void {
        switch (self) {
            .i32 => try writer.writeAll("i32"),
            .i64 => try writer.writeAll("i64"),
            .f32 => try writer.writeAll("f32"),
            .f64 => try writer.writeAll("f64"),
            .v128 => try writer.writeAll("v128"),
        }
    }
};

pub const Limit = struct {
    min: u32,
    max: ?u32 = null,
};

pub const Param = struct {
    name: str,
    type: Type,

    pub fn format(self: @This(), comptime _: str, _: Opts, writer: anytype) !void {
        try std.fmt.format(writer, "(param ${s} {})", .{ self.name, self.type });
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
    results: []const Type = &.{},
    body: []const Op,

    pub fn format(self: @This(), comptime _: str, _: Opts, writer: anytype) !void {
        try std.fmt.format(writer, "(func ${s}", .{self.name});
        for (self.params) |param| {
            try std.fmt.format(writer, " {}", .{param});
        }
        for (self.results) |result| {
            try std.fmt.format(writer, " (result {})", .{result});
        }
        for (self.body) |op| {
            try std.fmt.format(writer, "\n        {}", .{op});
        }
        try writer.writeAll(")");
    }
};

pub const Import = struct {
    module: str,
    name: str,
    desc: union(enum) {
        func: struct {
            name: str,
            params: []const Type = &.{},
            results: []const Type = &.{},
        },
        global: struct {
            name: str,
            type: Type,
            mutable: bool = false,
        },
        memory: Limit,

        pub fn format(self: @This(), comptime _: str, _: Opts, writer: anytype) !void {
            switch (self) {
                .func => |func| {
                    try std.fmt.format(writer, "(func ${s}", .{func.name});
                    if (func.params.len > 0) {
                        try writer.writeAll(" (param");
                        for (func.params) |param| {
                            try std.fmt.format(writer, " {}", .{param});
                        }
                        try writer.writeAll(")");
                    }
                    if (func.results.len > 0) {
                        try writer.writeAll(" (result");
                        for (func.results) |result| {
                            try std.fmt.format(writer, " {}", .{result});
                        }
                        try writer.writeAll(")");
                    }
                    try writer.writeAll(")");
                },
                .global => |global| {
                    try std.fmt.format(writer, "(global ${s}", .{global.name});
                    if (global.mutable) {
                        try std.fmt.format(writer, " (mut {})", .{global.type});
                    } else {
                        try std.fmt.format(writer, " {}", .{global.type});
                    }
                    try writer.writeAll(")");
                },
                .memory => |limit| {
                    try std.fmt.format(writer, "(memory {})", .{limit.min});
                },
            }
        }
    },

    pub fn format(self: @This(), comptime _: str, _: Opts, writer: anytype) !void {
        const fmt = "(import \"{s}\" \"{s}\" {})";
        try std.fmt.format(writer, fmt, .{ self.module, self.name, self.desc });
    }
};

pub const Global = struct {
    name: str,
    value: union(enum) {
        i32: i32,
    },
    mutable: bool = false,

    fn writeType(self: @This(), writer: anytype) !void {
        if (self.mutable) try writer.writeAll("(mut ");
        switch (self.value) {
            .i32 => try writer.writeAll("i32"),
        }
        if (self.mutable) try writer.writeAll(")");
    }

    pub fn format(self: @This(), comptime _: str, _: Opts, writer: anytype) !void {
        try std.fmt.format(writer, "(global ${s} ", .{self.name});
        try self.writeType(writer);
        switch (self.value) {
            .i32 => |value| try std.fmt.format(writer, " (i32.const {})", .{value}),
        }
        try writer.writeAll(")");
    }
};

pub const Data = struct {
    offset: u32,
    bytes: str,

    pub fn format(self: @This(), comptime _: str, _: Opts, writer: anytype) !void {
        const fmt = "(data (i32.const {}) \"{s}\")";
        try std.fmt.format(writer, fmt, .{ self.offset, self.bytes });
    }
};

pub const Export = struct {
    name: str,
    desc: union(enum) {
        func: str,
        global: str,

        pub fn format(self: @This(), comptime _: str, _: Opts, writer: anytype) !void {
            switch (self) {
                .func => |name| try std.fmt.format(writer, "(func ${s})", .{name}),
                .global => |name| try std.fmt.format(writer, "(global ${s})", .{name}),
            }
        }
    },

    pub fn format(self: @This(), comptime _: str, _: Opts, writer: anytype) !void {
        try std.fmt.format(writer, "(export \"{s}\" {})", .{ self.name, self.desc });
    }
};

pub const Module = struct {
    imports: []const Import = &.{},
    globals: []const Global = &.{},
    datas: []const Data = &.{},
    funcs: []const Func = &.{},
    exports: []const Export = &.{},

    pub fn format(self: @This(), comptime _: str, _: Opts, writer: anytype) !void {
        try writer.writeAll("(module");
        for (self.imports) |import| {
            try std.fmt.format(writer, "\n\n    {}", .{import});
        }
        for (self.globals) |global| {
            try std.fmt.format(writer, "\n\n    {}", .{global});
        }
        for (self.datas) |data| {
            try std.fmt.format(writer, "\n\n    {}", .{data});
        }
        for (self.funcs) |func| {
            try std.fmt.format(writer, "\n\n    {}", .{func});
        }
        for (self.exports) |e| {
            try std.fmt.format(writer, "\n\n    {}", .{e});
        }
        try writer.writeAll(")");
    }
};

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
            .{ .name = "myAdd", .desc = .{ .func = "add" } },
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
        .{ .name = "getAnswerPlus1", .desc = .{ .func = "getAnswerPlus1" } },
    } };
    const actual = try std.fmt.allocPrint(allocator, "{}", .{module});
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
                .desc = .{
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
            .{ .name = "logIt", .desc = .{ .func = "logIt" } },
        },
    };
    const actual = try std.fmt.allocPrint(allocator, "{}", .{module});
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
                .desc = .{
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
            .{ .name = "getGlobal", .desc = .{ .func = "getGlobal" } },
            .{ .name = "incGlobal", .desc = .{ .func = "incGlobal" } },
        },
    };
    const actual = try std.fmt.allocPrint(allocator, "{}", .{module});
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
            .{ .name = "getGlobal", .desc = .{ .func = "getGlobal" } },
            .{ .name = "incGlobal", .desc = .{ .func = "incGlobal" } },
        },
    };
    const actual = try std.fmt.allocPrint(allocator, "{}", .{module});
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
            .{ .name = "getGlobal", .desc = .{ .func = "getGlobal" } },
        },
    };
    const actual = try std.fmt.allocPrint(allocator, "{}", .{module});
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
            .{ .name = "getGlobal", .desc = .{ .func = "getGlobal" } },
            .{ .name = "incGlobal", .desc = .{ .func = "incGlobal" } },
            .{ .name = "g", .desc = .{ .global = "g" } },
        },
    };
    const actual = try std.fmt.allocPrint(allocator, "{}", .{module});
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
                .desc = .{
                    .func = .{ .name = "log", .params = &.{ .i32, .i32 } },
                },
            },
            .{ .module = "js", .name = "mem", .desc = .{ .memory = .{ .min = 1 } } },
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
            .{ .name = "writeHi", .desc = .{ .func = "writeHi" } },
        },
    };
    const actual = try std.fmt.allocPrint(allocator, "{}", .{module});
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
