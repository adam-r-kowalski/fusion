// Web Assembly types and operations for generating wat (web assembly text format).
// A writer is used throughout and represents any type which has a `writeAll` function
// which takes a string ([] const u8). Examples of writers are files, arrays, etc.
// This allows for no allocation writing to a file.

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

pub const Types = []const Type;

pub const Memory = struct {
    name: str,
    initial: u32,
    max: ?u32 = null,
};

pub const Memories = []const Memory;

pub const Import = struct {
    module: str,
    name: str,
    kind: union(enum) {
        function: struct {
            name: str,
            parameters: Types = &.{},
            results: Types = &.{},
        },
        global: struct {
            name: str,
            type: Type,
            mutable: bool = false,
        },
        memory: Memory,
    },
};

pub const Imports = []const Import;

pub const Global = struct {
    name: str,
    value: union(enum) {
        i32: i32,
    },
    mutable: bool = false,
};

pub const Globals = []const Global;

pub const Data = struct {
    offset: u32,
    bytes: str,
};

pub const Datas = []const Data;

pub const Parameter = struct {
    name: str,
    type: Type,
};

pub const Parameters = []const Parameter;

pub const Instruction = union(enum) {
    call: str,
    local_get: str,
    local_set: str,
    local_tee: str,
    global_get: str,
    global_set: str,
    i32_add,
    i32_lt_s,
    i32_eq,
    i32_const: i32,
    block: struct {
        name: str,
        body: Instructions,
    },
    loop: struct {
        name: str,
        body: Instructions,
    },
    if_: struct {
        then: Instructions,
        else_: Instructions = &.{},
    },
    br: str,
    br_if: str,
    unreachable_,
    select,
    nop,
    return_,
};

pub const Instructions = []const Instruction;

pub const Local = struct {
    name: str,
    type: Type,
};

pub const Locals = []const Local;

pub const Function = struct {
    name: str,
    parameters: Parameters = &.{},
    results: Types = &.{},
    locals: Locals = &.{},
    body: Instructions,
};

pub const Functions = []const Function;

pub const Export = struct {
    name: str,
    kind: union(enum) {
        function: str,
        global: str,
        memory: str,
    },
};

pub const Exports = []const Export;

pub const Module = struct {
    imports: Imports = &.{},
    memories: Memories = &.{},
    globals: Globals = &.{},
    datas: Datas = &.{},
    functions: Functions = &.{},
    exports: Exports = &.{},
    start: ?str = null,
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
            .function => |func| {
                try std.fmt.format(writer, "(func ${s}", .{func.name});
                if (func.parameters.len > 0) {
                    try writer.writeAll(" (param");
                    for (func.parameters) |param| {
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
            .memory => |memory| {
                try std.fmt.format(writer, "(memory ${s} {})", .{ memory.name, memory.initial });
            },
        }
        try writer.writeAll(")");
    }
}

fn watMemories(memories: Memories, writer: anytype) !void {
    for (memories) |memory| {
        try std.fmt.format(writer, "\n\n    (memory ${s} {})", .{ memory.name, memory.initial });
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

fn watFunctionParameters(parameters: Parameters, writer: anytype) !void {
    for (parameters) |param| {
        try std.fmt.format(writer, " (param ${s} ", .{param.name});
        try watType(param.type, writer);
        try writer.writeAll(")");
    }
}

fn watFunctionResults(results: Types, writer: anytype) !void {
    for (results) |result| {
        try writer.writeAll(" (result ");
        try watType(result, writer);
        try writer.writeAll(")");
    }
}

fn watFunctionLocals(locals: Locals, writer: anytype) !void {
    for (locals) |local| {
        try std.fmt.format(writer, "\n        (local ${s} ", .{local.name});
        try watType(local.type, writer);
        try writer.writeAll(")");
    }
    if (locals.len > 0) try writer.writeAll("\n");
}

fn watIndent(indent: u8, writer: anytype) !void {
    try writer.writeAll("\n");
    var i: u8 = 0;
    while (i < indent) : (i += 1) {
        try writer.writeAll("    ");
    }
}

fn watInstructions(instructions: Instructions, indent: u8, writer: anytype) !void {
    for (instructions) |op| {
        try watIndent(indent, writer);
        switch (op) {
            .call => |value| try std.fmt.format(writer, "(call ${s})", .{value}),
            .local_get => |value| try std.fmt.format(writer, "(local.get ${s})", .{value}),
            .local_set => |value| try std.fmt.format(writer, "(local.set ${s})", .{value}),
            .local_tee => |value| try std.fmt.format(writer, "(local.tee ${s})", .{value}),
            .global_get => |value| try std.fmt.format(writer, "(global.get ${s})", .{value}),
            .global_set => |value| try std.fmt.format(writer, "(global.set ${s})", .{value}),
            .i32_add => try writer.writeAll("i32.add"),
            .i32_lt_s => try writer.writeAll("i32.lt_s"),
            .i32_eq => try writer.writeAll("i32.eq"),
            .i32_const => |value| try std.fmt.format(writer, "(i32.const {})", .{value}),
            .block => |block| {
                try std.fmt.format(writer, "(block ${s}", .{block.name});
                try watInstructions(block.body, indent + 1, writer);
                try writer.writeAll(")");
            },
            .loop => |loop| {
                try std.fmt.format(writer, "(loop ${s}", .{loop.name});
                try watInstructions(loop.body, indent + 1, writer);
                try writer.writeAll(")");
            },
            .if_ => |if_| {
                try writer.writeAll("(if");
                try watIndent(indent + 1, writer);
                try writer.writeAll("(then");
                try watInstructions(if_.then, indent + 2, writer);
                try writer.writeAll(")");
                if (if_.else_.len > 0) {
                    try watIndent(indent + 1, writer);
                    try writer.writeAll("(else");
                    try watInstructions(if_.else_, indent + 2, writer);
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
        }
    }
}

fn watFunctions(functions: Functions, writer: anytype) !void {
    for (functions) |func| {
        try std.fmt.format(writer, "\n\n    (func ${s}", .{func.name});
        try watFunctionParameters(func.parameters, writer);
        try watFunctionResults(func.results, writer);
        try watFunctionLocals(func.locals, writer);
        try watInstructions(func.body, 2, writer);
        try writer.writeAll(")");
    }
}

fn watExports(exports: Exports, writer: anytype) !void {
    for (exports) |e| {
        try std.fmt.format(writer, "\n\n    (export \"{s}\" ", .{e.name});
        switch (e.kind) {
            .function => |name| try std.fmt.format(writer, "(func ${s})", .{name}),
            .global => |name| try std.fmt.format(writer, "(global ${s})", .{name}),
            .memory => |name| try std.fmt.format(writer, "(memory ${s})", .{name}),
        }
        try writer.writeAll(")");
    }
}

fn watStart(start: ?str, writer: anytype) !void {
    if (start) |name| {
        try std.fmt.format(writer, "\n\n    (start ${s})", .{name});
    }
}

pub fn wat(module: Module, writer: anytype) !void {
    try writer.writeAll("(module");
    try watImports(module.imports, writer);
    try watMemories(module.memories, writer);
    try watGlobals(module.globals, writer);
    try watDatas(module.datas, writer);
    try watFunctions(module.functions, writer);
    try watExports(module.exports, writer);
    try watStart(module.start, writer);
    try writer.writeAll(")");
}

pub fn allocWat(module: Module, allocator: Allocator) !str {
    var list = std.ArrayList(u8).init(allocator);
    try wat(module, list.writer());
    return list.toOwnedSlice();
}
