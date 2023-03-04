const std = @import("std");

const web_assembly = @import("../types.zig").web_assembly;
const Type = web_assembly.Type;
const Import = web_assembly.Import;
const Memory = web_assembly.Memory;
const Global = web_assembly.Global;
const Data = web_assembly.Data;
const Table = web_assembly.Table;
const Elem = web_assembly.Elem;
const FuncType = web_assembly.FuncType;
const Param = web_assembly.Param;
const Op = web_assembly.Op;
const Func = web_assembly.Func;
const Export = web_assembly.Export;
const TopLevel = web_assembly.TopLevel;

fn watType(t: Type, writer: anytype) !void {
    switch (t) {
        .i32 => try writer.writeAll("i32"),
        .i64 => try writer.writeAll("i64"),
        .f32 => try writer.writeAll("f32"),
        .f64 => try writer.writeAll("f64"),
        .v128 => try writer.writeAll("v128"),
    }
}

fn import(writer: anytype, i: Import) !void {
    const fmt = "\n\n    (import \"{s}\" \"{s}\" ";
    try std.fmt.format(writer, fmt, .{ i[0][0], i[0][1] });
    switch (i[1]) {
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
            try std.fmt.format(writer, "(global ${s}", .{g[0]});
            if (g[1] == .mut) {
                try writer.writeAll(" (mut ");
                try watType(g[2], writer);
                try writer.writeAll(")");
            } else {
                try writer.writeAll(" ");
                try watType(g[2], writer);
            }
            try writer.writeAll(")");
        },
        .memory => |m| {
            try std.fmt.format(writer, "(memory ${s} {})", .{ m[0], m[1] });
        },
    }
    try writer.writeAll(")");
}

fn memory(writer: anytype, m: Memory) !void {
    try std.fmt.format(writer, "\n\n    (memory ${s} {})", .{ m[0], m[1] });
}

fn globalType(writer: anytype, g: Global) !void {
    if (g[1] == .mut) try writer.writeAll("(mut ");
    switch (g[2]) {
        .i32 => try writer.writeAll("i32"),
    }
    if (g[1] == .mut) try writer.writeAll(")");
}

fn global(writer: anytype, g: Global) !void {
    try std.fmt.format(writer, "\n\n    (global ${s} ", .{g[0]});
    try globalType(writer, g);
    switch (g[2]) {
        .i32 => |value| try std.fmt.format(writer, " (i32.const {})", .{value}),
    }
    try writer.writeAll(")");
}

fn data(writer: anytype, d: Data) !void {
    const fmt = "\n\n    (data (i32.const {}) \"{s}\")";
    try std.fmt.format(writer, fmt, .{ d[0], d[1] });
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

fn funcParams(writer: anytype, params: []const Param) !void {
    for (params) |p| {
        try std.fmt.format(writer, " (param ${s} ", .{p[0]});
        try watType(p[1], writer);
        try writer.writeAll(")");
    }
}

fn funcResults(writer: anytype, results: []const Type) !void {
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

fn ops(writer: anytype, os: []const Op, indent: u8) !void {
    for (os) |op| {
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
                try std.fmt.format(writer, "(block ${s}", .{b[0]});
                try ops(writer, b[1], indent + 1);
                try writer.writeAll(")");
            },
            .loop => |l| {
                try std.fmt.format(writer, "(loop ${s}", .{l[0]});
                try ops(writer, l[1], indent + 1);
                try writer.writeAll(")");
            },
            .if_ => |i| {
                try writer.writeAll("(if");
                try watIndent(indent + 1, writer);
                try writer.writeAll("(then");
                try ops(writer, i.then, indent + 2);
                try writer.writeAll(")");
                if (i.else_.len > 0) {
                    try watIndent(indent + 1, writer);
                    try writer.writeAll("(else");
                    try ops(writer, i.else_, indent + 2);
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

fn func(writer: anytype, f: Func) !void {
    try std.fmt.format(writer, "\n\n    (func ${s}", .{f.name});
    try funcParams(writer, f.params);
    try funcResults(writer, f.results);
    try ops(writer, f.ops, 2);
    try writer.writeAll(")");
}

fn export_(writer: anytype, e: Export) !void {
    try std.fmt.format(writer, "\n\n    (export \"{s}\" ", .{e[0]});
    switch (e[1]) {
        .func => |name| try std.fmt.format(writer, "(func ${s})", .{name}),
        .global => |name| try std.fmt.format(writer, "(global ${s})", .{name}),
        .memory => |name| try std.fmt.format(writer, "(memory ${s})", .{name}),
        .table => |name| try std.fmt.format(writer, "(table ${s})", .{name}),
    }
    try writer.writeAll(")");
}

fn start(writer: anytype, name: []const u8) !void {
    try std.fmt.format(writer, "\n\n    (start ${s})", .{name});
}

pub fn wat(writer: anytype, module: []const TopLevel) !void {
    try writer.writeAll("(module");
    for (module) |top_level| {
        switch (top_level) {
            .import => |i| try import(writer, i),
            .memory => |m| try memory(writer, m),
            .global => |g| try global(writer, g),
            .data => |d| try data(writer, d),
            .table => |t| try watTable(t, writer),
            .elem => |e| try watElem(e, writer),
            .functype => |f| try watFuncType(f, writer),
            .func => |f| try func(writer, f),
            .export_ => |e| try export_(writer, e),
            .start => |name| try start(writer, name),
        }
    }
    try writer.writeAll(")");
}

pub fn watAlloc(module: []const TopLevel, allocator: std.mem.Allocator) ![]const u8 {
    var list = std.ArrayList(u8).init(allocator);
    try wat(list.writer(), module);
    return list.toOwnedSlice();
}
