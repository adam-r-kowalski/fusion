const std = @import("std");

const types = @import("../types.zig");
const Span = types.ast.Span;
const BinaryOpKind = types.ast.BinaryOpKind;
const BinaryOp = types.ast.BinaryOp;
const Call = types.ast.Call;
const Define = types.ast.Define;
const Lambda = types.ast.Lambda;
const Expression = types.ast.Expression;
const Annotate = types.ast.Annotate;
const Group = types.ast.Group;
const For = types.ast.For;
const If = types.ast.If;
const Ast = types.ast.Ast;

const Indent = usize;

fn indent(writer: anytype, i: Indent) !void {
    try writer.writeAll("\n");
    var j: usize = 0;
    while (j < i) : (j += 1) {
        try writer.writeAll("    ");
    }
}

fn span(writer: anytype, s: Span) !void {
    const fmt = ".span = .{{ .{{ {}, {} }}, .{{ {}, {} }} }},";
    try std.fmt.format(writer, fmt, .{ s[0][0], s[0][1], s[1][0], s[1][1] });
}

fn opName(kind: BinaryOpKind) []const u8 {
    return switch (kind) {
        .add => ".add",
        .mul => ".mul",
        .pow => ".pow",
        .arrow => ".arrow",
        .dot => ".dot",
        .greater => ".greater",
    };
}

fn binaryOp(writer: anytype, op: BinaryOp, i: Indent) !void {
    try indent(writer, i + 2);
    try writer.writeAll(".binary_op = .{");
    try indent(writer, i + 3);
    try std.fmt.format(writer, ".kind = {s},", .{opName(op.kind)});
    try indent(writer, i + 3);
    try writer.writeAll(".left = &");
    try expression(writer, op.left.*, i + 3, false);
    try indent(writer, i + 3);
    try writer.writeAll(".right = &");
    try expression(writer, op.right.*, i + 3, false);
    try indent(writer, i + 2);
    try writer.writeAll("},");
    try indent(writer, i + 1);
    try writer.writeAll("},");
}

fn call(writer: anytype, c: Call, i: Indent) !void {
    try indent(writer, i + 2);
    try writer.writeAll(".call = .{");
    try indent(writer, i + 3);
    try writer.writeAll(".func = &");
    try expression(writer, c.func.*, i + 3, false);
    try indent(writer, i + 3);
    try writer.writeAll(".args = &.{");
    for (c.args) |arg| {
        try expression(writer, arg, i + 4, true);
    }
    try indent(writer, i + 3);
    try writer.writeAll("},");
    try indent(writer, i + 2);
    try writer.writeAll("},");
    try indent(writer, i + 1);
    try writer.writeAll("},");
}

fn define(writer: anytype, d: Define, i: Indent) !void {
    try indent(writer, i + 2);
    try writer.writeAll(".define = .{");
    try indent(writer, i + 3);
    try writer.writeAll(".name = &.{");
    try expression(writer, d.name.*, i + 3, false);
    try indent(writer, i + 3);
    try writer.writeAll(".body = &.{");
    for (d.body) |expr| {
        try expression(writer, expr, i + 4, true);
    }
    try indent(writer, i + 3);
    try writer.writeAll("},");
    try indent(writer, i + 2);
    try writer.writeAll("},");
    try indent(writer, i + 1);
    try writer.writeAll("},");
}

fn lambda(writer: anytype, l: Lambda, i: Indent) !void {
    try indent(writer, i + 2);
    try writer.writeAll(".lambda = .{");
    try indent(writer, i + 3);
    try writer.writeAll(".params = &.{");
    for (l.params) |arg| {
        try expression(writer, arg, i + 4, true);
    }
    try indent(writer, i + 3);
    try writer.writeAll("},");
    try indent(writer, i + 3);
    try writer.writeAll(".body = &.{");
    for (l.body) |expr| {
        try expression(writer, expr, i + 4, true);
    }
    try indent(writer, i + 3);
    try writer.writeAll("},");
    try indent(writer, i + 2);
    try writer.writeAll("},");
    try indent(writer, i + 1);
    try writer.writeAll("},");
}

fn annotate(writer: anytype, a: Annotate, i: Indent) !void {
    try indent(writer, i + 2);
    try writer.writeAll(".annotate = .{");
    try indent(writer, i + 3);
    try writer.writeAll(".name = &.{");
    try expression(writer, a.name.*, i + 3, false);
    try indent(writer, i + 3);
    try writer.writeAll(".type = &.{");
    try expression(writer, a.type.*, i + 3, false);
    try indent(writer, i + 2);
    try writer.writeAll("},");
    try indent(writer, i + 1);
    try writer.writeAll("},");
}

fn group(writer: anytype, g: Group, i: Indent) !void {
    try indent(writer, i + 2);
    try writer.writeAll(".group = .{");
    try indent(writer, i + 3);
    try writer.writeAll(".expr = &.{");
    try expression(writer, g.expr.*, i + 3, false);
    try indent(writer, i + 2);
    try writer.writeAll("},");
    try indent(writer, i + 1);
    try writer.writeAll("},");
}

fn for_(writer: anytype, f: For, i: Indent) !void {
    try indent(writer, i + 2);
    try writer.writeAll(".for_ = .{");
    try indent(writer, i + 3);
    try writer.writeAll(".indices = &.{");
    for (f.indices) |arg| {
        try expression(writer, arg, i + 4, true);
    }
    try indent(writer, i + 3);
    try writer.writeAll("},");
    try indent(writer, i + 3);
    try writer.writeAll(".body = &.{");
    for (f.body) |expr| {
        try expression(writer, expr, i + 4, true);
    }
    try indent(writer, i + 3);
    try writer.writeAll("},");
    try indent(writer, i + 2);
    try writer.writeAll("},");
    try indent(writer, i + 1);
    try writer.writeAll("},");
}

fn if_(writer: anytype, c: If, i: Indent) !void {
    try indent(writer, i + 2);
    try writer.writeAll(".if_ = .{");
    try indent(writer, i + 3);
    try writer.writeAll(".condition = &.{");
    try expression(writer, c.condition.*, i + 3, false);
    try indent(writer, i + 3);
    try writer.writeAll(".then = &.{");
    for (c.then) |e| {
        try expression(writer, e, i + 4, true);
    }
    try indent(writer, i + 3);
    try writer.writeAll("},");
    try indent(writer, i + 3);
    try writer.writeAll(".else_ = &.{");
    for (c.else_) |e| {
        try expression(writer, e, i + 4, true);
    }
    try indent(writer, i + 3);
    try writer.writeAll("},");
    try indent(writer, i + 2);
    try writer.writeAll("},");
    try indent(writer, i + 1);
    try writer.writeAll("},");
}

fn expression(writer: anytype, e: Expression, i: Indent, newline: bool) error{OutOfMemory}!void {
    if (newline) try indent(writer, i);
    try writer.writeAll(".{");
    try indent(writer, i + 1);
    try span(writer, e.span);
    try indent(writer, i + 1);
    try writer.writeAll(".kind = .{ ");
    switch (e.kind) {
        .symbol => |s| try std.fmt.format(writer, ".symbol = \"{s}\" }},", .{s}),
        .int => |s| try std.fmt.format(writer, ".int = \"{s}\" }},", .{s}),
        .string => |s| try std.fmt.format(writer, ".string = \"{s}\" }},", .{s}),
        .binary_op => |op| try binaryOp(writer, op, i),
        .call => |c| try call(writer, c, i),
        .define => |d| try define(writer, d, i),
        .lambda => |l| try lambda(writer, l, i),
        .annotate => |a| try annotate(writer, a, i),
        .group => |g| try group(writer, g, i),
        .for_ => |f| try for_(writer, f, i),
        .if_ => |c| try if_(writer, c, i),
    }
    try indent(writer, i);
    try writer.writeAll("},");
}

pub fn expressions(writer: anytype, es: []const Expression) !void {
    for (es) |e| {
        try expression(writer, e, 0, true);
    }
}

pub fn expressionsAlloc(es: []const Expression, allocator: std.mem.Allocator) ![]const u8 {
    var list = std.ArrayList(u8).init(allocator);
    try expressions(list.writer(), es);
    return list.toOwnedSlice();
}

pub fn ast(writer: anytype, a: Ast) !void {
    try expressions(writer, a.expressions);
}

pub fn astAlloc(a: Ast, allocator: std.mem.Allocator) ![]const u8 {
    var list = std.ArrayList(u8).init(allocator);
    try ast(list.writer(), a);
    return list.toOwnedSlice();
}
