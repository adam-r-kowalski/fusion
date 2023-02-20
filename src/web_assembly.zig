// Web Assembly types and operations for generating wat (web assembly text format).
// A writer is used throughout and represents any type which has a `writeAll` function
// which takes a string ([] const u8). Examples of writers are files, arrays, etc.
// This allows for no allocation writing to a file.

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Type = enum {
    i32,
    i64,
    f32,
    f64,
    v128,
};

pub const Memory = struct {
    name: []const u8,
    initial: u32,
    max: ?u32 = null,
};

pub const Mutable = enum {
    mutable,
    immutable,
};

pub const Import = struct {
    path: [2][]const u8,
    kind: union(enum) {
        func: struct {
            name: []const u8,
            params: []const Type = &.{},
            results: []const Type = &.{},
        },
        global: struct {
            name: []const u8,
            type: Type,
            mut: Mutable = .immutable,
        },
        memory: Memory,
    },
};

const Value = union(enum) {
    i32: i32,
};

pub const Global = struct {
    name: []const u8,
    value: Value,
    mut: Mutable = .immutable,
};

pub const Data = struct {
    offset: u32,
    bytes: []const u8,
};

pub const Table = struct {
    name: []const u8,
    initial: u32,
    max: ?u32 = null,
};

pub const Elem = struct {
    offset: u32,
    name: []const u8,
};

pub const FuncType = struct {
    name: []const u8,
    params: []const Type = &.{},
    results: []const Type = &.{},
};

pub const Param = struct {
    name: []const u8,
    type: Type,
};

pub const Op = union(enum) {
    call: []const u8,
    call_indirect: []const u8,
    local: struct { name: []const u8, type: Type },
    local_get: []const u8,
    local_set: []const u8,
    local_tee: []const u8,
    global_get: []const u8,
    global_set: []const u8,
    i32_add,
    i32_lt_s,
    i32_eq,
    i32_const: i32,
    block: struct {
        name: []const u8,
        ops: []const Op,
    },
    loop: struct {
        name: []const u8,
        ops: []const Op,
    },
    if_: struct {
        then: []const Op,
        else_: []const Op = &.{},
    },
    br: []const u8,
    br_if: []const u8,
    unreachable_,
    select,
    nop,
    return_,
    drop,
};

pub const Local = struct {
    name: []const u8,
    type: Type,
};

pub const Func = struct {
    name: []const u8,
    params: []const Param = &.{},
    results: []const Type = &.{},
    ops: []const Op = &.{},
};

pub const Export = struct {
    name: []const u8,
    kind: union(enum) {
        func: []const u8,
        global: []const u8,
        memory: []const u8,
    },
};

pub const TopLevel = union(enum) {
    import: Import,
    memory: Memory,
    global: Global,
    data: Data,
    table: Table,
    elem: Elem,
    functype: FuncType,
    func: Func,
    export_: Export,
    start: []const u8,
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

fn watImport(import: Import, writer: anytype) !void {
    const fmt = "\n\n    (import \"{s}\" \"{s}\" ";
    try std.fmt.format(writer, fmt, .{ import.path[0], import.path[1] });
    switch (import.kind) {
        .func => |f| {
            try std.fmt.format(writer, "(func ${s}", .{f.name});
            if (f.params.len > 0) {
                try writer.writeAll(" (param");
                for (f.params) |p| {
                    try writer.writeAll(" ");
                    try watType(p, writer);
                }
                try writer.writeAll(")");
            }
            if (f.results.len > 0) {
                try writer.writeAll(" (result");
                for (f.results) |result| {
                    try writer.writeAll(" ");
                    try watType(result, writer);
                }
                try writer.writeAll(")");
            }
            try writer.writeAll(")");
        },
        .global => |g| {
            try std.fmt.format(writer, "(global ${s}", .{g.name});
            if (g.mut == .mutable) {
                try writer.writeAll(" (mut ");
                try watType(g.type, writer);
                try writer.writeAll(")");
            } else {
                try writer.writeAll(" ");
                try watType(g.type, writer);
            }
            try writer.writeAll(")");
        },
        .memory => |m| {
            try std.fmt.format(writer, "(memory ${s} {})", .{ m.name, m.initial });
        },
    }
    try writer.writeAll(")");
}

fn watMemory(m: Memory, writer: anytype) !void {
    try std.fmt.format(writer, "\n\n    (memory ${s} {})", .{ m.name, m.initial });
}

fn watGlobalType(g: Global, writer: anytype) !void {
    if (g.mut == .mutable) try writer.writeAll("(mut ");
    switch (g.value) {
        .i32 => try writer.writeAll("i32"),
    }
    if (g.mut == .mutable) try writer.writeAll(")");
}

fn watGlobal(g: Global, writer: anytype) !void {
    try std.fmt.format(writer, "\n\n    (global ${s} ", .{g.name});
    try watGlobalType(g, writer);
    switch (g.value) {
        .i32 => |value| try std.fmt.format(writer, " (i32.const {})", .{value}),
    }
    try writer.writeAll(")");
}

fn watData(d: Data, writer: anytype) !void {
    const fmt = "\n\n    (data (i32.const {}) \"{s}\")";
    try std.fmt.format(writer, fmt, .{ d.offset, d.bytes });
}

fn watTable(t: Table, writer: anytype) !void {
    const fmt = "\n\n    (table ${s} {} funcref)";
    try std.fmt.format(writer, fmt, .{ t.name, t.initial });
}

fn watElem(e: Elem, writer: anytype) !void {
    const fmt = "\n\n    (elem (i32.const {}) ${s})";
    try std.fmt.format(writer, fmt, .{ e.offset, e.name });
}

fn watFuncType(f: FuncType, writer: anytype) !void {
    const fmt = "\n\n    (type ${s} (func";
    try std.fmt.format(writer, fmt, .{f.name});
    if (f.params.len > 0) {
        try writer.writeAll(" (param");
        for (f.params) |p| {
            try writer.writeAll(" ");
            try watType(p, writer);
        }
        try writer.writeAll(")");
    }
    if (f.results.len > 0) {
        try writer.writeAll(" (result");
        for (f.results) |result| {
            try writer.writeAll(" ");
            try watType(result, writer);
        }
        try writer.writeAll(")");
    }
    try writer.writeAll("))");
}

fn watFuncParams(params: []const Param, writer: anytype) !void {
    for (params) |p| {
        try std.fmt.format(writer, " (param ${s} ", .{p.name});
        try watType(p.type, writer);
        try writer.writeAll(")");
    }
}

fn watFuncResults(results: []const Type, writer: anytype) !void {
    for (results) |result| {
        try writer.writeAll(" (result ");
        try watType(result, writer);
        try writer.writeAll(")");
    }
}

fn watIndent(indent: u8, writer: anytype) !void {
    try writer.writeAll("\n");
    var i: u8 = 0;
    while (i < indent) : (i += 1) {
        try writer.writeAll("    ");
    }
}

fn watOps(ops: []const Op, indent: u8, writer: anytype) !void {
    for (ops) |op| {
        try watIndent(indent, writer);
        switch (op) {
            .call => |value| try std.fmt.format(writer, "(call ${s})", .{value}),
            .call_indirect => |value| try std.fmt.format(writer, "(call_indirect (type ${s}))", .{value}),
            .local => |l| {
                try std.fmt.format(writer, "(local ${s} ", .{l.name});
                try watType(l.type, writer);
                try writer.writeAll(")");
            },
            .local_get => |value| try std.fmt.format(writer, "(local.get ${s})", .{value}),
            .local_set => |value| try std.fmt.format(writer, "(local.set ${s})", .{value}),
            .local_tee => |value| try std.fmt.format(writer, "(local.tee ${s})", .{value}),
            .global_get => |value| try std.fmt.format(writer, "(global.get ${s})", .{value}),
            .global_set => |value| try std.fmt.format(writer, "(global.set ${s})", .{value}),
            .i32_add => try writer.writeAll("i32.add"),
            .i32_lt_s => try writer.writeAll("i32.lt_s"),
            .i32_eq => try writer.writeAll("i32.eq"),
            .i32_const => |value| try std.fmt.format(writer, "(i32.const {})", .{value}),
            .block => |b| {
                try std.fmt.format(writer, "(block ${s}", .{b.name});
                try watOps(b.ops, indent + 1, writer);
                try writer.writeAll(")");
            },
            .loop => |l| {
                try std.fmt.format(writer, "(loop ${s}", .{l.name});
                try watOps(l.ops, indent + 1, writer);
                try writer.writeAll(")");
            },
            .if_ => |i| {
                try writer.writeAll("(if");
                try watIndent(indent + 1, writer);
                try writer.writeAll("(then");
                try watOps(i.then, indent + 2, writer);
                try writer.writeAll(")");
                if (i.else_.len > 0) {
                    try watIndent(indent + 1, writer);
                    try writer.writeAll("(else");
                    try watOps(i.else_, indent + 2, writer);
                    try writer.writeAll(")");
                }
                try writer.writeAll(")");
            },
            .br => |value| try std.fmt.format(writer, "(br ${s})", .{value}),
            .br_if => |value| try std.fmt.format(writer, "(br_if ${s})", .{value}),
            .unreachable_ => try writer.writeAll("unreachable"),
            .select => try writer.writeAll("select"),
            .nop => try writer.writeAll("nop"),
            .return_ => try writer.writeAll("return"),
            .drop => try writer.writeAll("drop"),
        }
    }
}

fn watFunc(f: Func, writer: anytype) !void {
    try std.fmt.format(writer, "\n\n    (func ${s}", .{f.name});
    try watFuncParams(f.params, writer);
    try watFuncResults(f.results, writer);
    try watOps(f.ops, 2, writer);
    try writer.writeAll(")");
}

fn watExport(e: Export, writer: anytype) !void {
    try std.fmt.format(writer, "\n\n    (export \"{s}\" ", .{e.name});
    switch (e.kind) {
        .func => |name| try std.fmt.format(writer, "(func ${s})", .{name}),
        .global => |name| try std.fmt.format(writer, "(global ${s})", .{name}),
        .memory => |name| try std.fmt.format(writer, "(memory ${s})", .{name}),
    }
    try writer.writeAll(")");
}

fn watStart(name: []const u8, writer: anytype) !void {
    try std.fmt.format(writer, "\n\n    (start ${s})", .{name});
}

pub fn wat(module: []const TopLevel, writer: anytype) !void {
    try writer.writeAll("(module");
    for (module) |top_level| {
        switch (top_level) {
            .import => |i| try watImport(i, writer),
            .memory => |m| try watMemory(m, writer),
            .global => |g| try watGlobal(g, writer),
            .data => |d| try watData(d, writer),
            .table => |t| try watTable(t, writer),
            .elem => |e| try watElem(e, writer),
            .functype => |f| try watFuncType(f, writer),
            .func => |f| try watFunc(f, writer),
            .export_ => |e| try watExport(e, writer),
            .start => |name| try watStart(name, writer),
        }
    }
    try writer.writeAll(")");
}

pub fn watAlloc(module: []const TopLevel, allocator: Allocator) ![]const u8 {
    var list = std.ArrayList(u8).init(allocator);
    try wat(module, list.writer());
    return list.toOwnedSlice();
}

pub fn param(name: []const u8, type_: Type) Param {
    return .{
        .name = name,
        .type = type_,
    };
}

pub fn global(name: []const u8, value: Value, mut: Mutable) TopLevel {
    return .{ .global = .{ .name = name, .value = value, .mut = mut } };
}

pub fn func(
    name: []const u8,
    params: []const Param,
    results: []const Type,
    ops: []const Op,
) TopLevel {
    return .{
        .func = .{
            .name = name,
            .params = params,
            .results = results,
            .ops = ops,
        },
    };
}

pub fn importGlobal(
    path: [2][]const u8,
    name: []const u8,
    type_: Type,
    mut: Mutable,
) TopLevel {
    return .{
        .import = .{
            .path = path,
            .kind = .{
                .global = .{
                    .name = name,
                    .type = type_,
                    .mut = mut,
                },
            },
        },
    };
}

pub fn importFunc(
    path: [2][]const u8,
    name: []const u8,
    params: []const Type,
    results: []const Type,
) TopLevel {
    return .{
        .import = .{
            .path = path,
            .kind = .{
                .func = .{
                    .name = name,
                    .params = params,
                    .results = results,
                },
            },
        },
    };
}

pub fn importMemory(
    path: [2][]const u8,
    name: []const u8,
    initial: u8,
) TopLevel {
    return .{
        .import = .{
            .path = path,
            .kind = .{
                .memory = .{
                    .name = name,
                    .initial = initial,
                },
            },
        },
    };
}

pub fn data(offset: u32, bytes: []const u8) TopLevel {
    return .{ .data = .{ .offset = offset, .bytes = bytes } };
}

pub fn table(name: []const u8, initial: u32) TopLevel {
    return .{ .table = .{ .name = name, .initial = initial } };
}

pub fn elem(offset: u32, name: []const u8) TopLevel {
    return .{ .elem = .{ .offset = offset, .name = name } };
}

pub fn functype(name: []const u8, params: []const Type, results: []const Type) TopLevel {
    return .{ .functype = .{ .name = name, .params = params, .results = results } };
}

pub fn memory(name: []const u8, initial: u32) TopLevel {
    return .{ .memory = .{ .name = name, .initial = initial } };
}

pub fn start(name: []const u8) TopLevel {
    return .{ .start = name };
}

pub fn local(name: []const u8, type_: Type) Op {
    return .{ .local = .{ .name = name, .type = type_ } };
}

pub fn loop(name: []const u8, ops: []const Op) Op {
    return .{ .loop = .{ .name = name, .ops = ops } };
}

pub fn if_(then: []const Op, else_: []const Op) Op {
    return .{ .if_ = .{ .then = then, .else_ = else_ } };
}

pub fn block(name: []const u8, ops: []const Op) Op {
    return .{ .block = .{ .name = name, .ops = ops } };
}

pub fn when(ops: []const Op) Op {
    return .{ .if_ = .{ .then = ops } };
}

pub fn exportFunc(name: []const u8, config: struct { as: []const u8 = "" }) TopLevel {
    const as = if (config.as.len > 0) config.as else name;
    return .{ .export_ = .{ .name = as, .kind = .{ .func = name } } };
}

pub fn exportGlobal(name: []const u8, config: struct { as: []const u8 = "" }) TopLevel {
    const as = if (config.as.len > 0) config.as else name;
    return .{ .export_ = .{ .name = as, .kind = .{ .global = name } } };
}

pub fn exportMemory(name: []const u8, config: struct { as: []const u8 = "" }) TopLevel {
    const as = if (config.as.len > 0) config.as else name;
    return .{ .export_ = .{ .name = as, .kind = .{ .memory = name } } };
}
