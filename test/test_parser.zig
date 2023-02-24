const std = @import("std");
const fusion = @import("fusion");
const tokenize = fusion.tokenizer.tokenize;
const parse = fusion.parser.parse;
const Expression = fusion.parser.Expression;
const Ast = fusion.parser.Ast;
const symbol = fusion.parser.symbol;
const int = fusion.parser.int;
const binaryOp = fusion.parser.binaryOp;
const BinaryOp = fusion.parser.BinaryOp;

fn expectEqualExpression(expected: Expression, actual: Expression) error{TestExpectedEqual}!void {
    switch (expected.kind) {
        .symbol => |e| try std.testing.expectEqualStrings(e, actual.kind.symbol),
        .int => |e| try std.testing.expectEqualStrings(e, actual.kind.int),
        .binaryOp => |e| {
            const a = actual.kind.binaryOp;
            try std.testing.expectEqual(e.op, a.op);
            try expectEqualExpressions(e.args, a.args);
        },
    }
    try std.testing.expectEqual(expected.start, actual.start);
    try std.testing.expectEqual(expected.end, actual.end);
}

fn expectEqualExpressions(expected: []const Expression, actual: []const Expression) !void {
    var i: usize = 0;
    const max = std.math.min(expected.len, actual.len);
    while (i < max) : (i += 1) {
        try expectEqualExpression(expected[i], actual[i]);
    }
    try std.testing.expectEqual(expected.len, actual.len);
}

fn writeIndent(writer: anytype, indent: usize) !void {
    try writer.writeAll("\n");
    var i: usize = 0;
    while (i < indent) : (i += 1) {
        try writer.writeAll("    ");
    }
}

fn writePosition(writer: anytype, expression: Expression) !void {
    try std.fmt.format(writer, ".{{ {}, {} }}, .{{ {}, {} }}", .{
        expression.start[0],
        expression.start[1],
        expression.end[0],
        expression.end[1],
    });
}

fn opName(op: BinaryOp) []const u8 {
    return switch (op) {
        .add => ".add",
        .mul => ".mul",
    };
}

fn writeExpression(writer: anytype, expression: Expression, indent: usize) !void {
    try writeIndent(writer, indent);
    switch (expression.kind) {
        .symbol => |s| {
            try writer.writeAll("symbol(");
            try writePosition(writer, expression);
            try std.fmt.format(writer, ", \"{s}\"),", .{s});
        },
        .int => |i| {
            try writer.writeAll("int(");
            try writePosition(writer, expression);
            try std.fmt.format(writer, ", \"{s}\"),", .{i});
        },
        .binaryOp => |b| {
            try writer.writeAll("binaryOp(");
            try writePosition(writer, expression);
            try std.fmt.format(writer, " {s}, &.{{", .{opName(b.op)});
            for (b.args) |arg| {
                try writeExpression(writer, arg, indent + 1);
            }
            try writeIndent(writer, indent);
            try writer.writeAll("}),");
        },
    }
}

fn writeAst(writer: anytype, ast: Ast) !void {
    try writer.writeAll("\n\n");
    for (ast.expressions) |expr| {
        try writeExpression(writer, expr, 0);
    }
    try writer.writeAll("\n\n");
}

fn printAst(ast: Ast) !void {
    const writer = std.io.getStdOut().writer();
    try writeAst(writer, ast);
}

test "symbol" {
    const allocator = std.testing.allocator;
    const source = "x";
    var tokens = tokenize(source);
    const ast = try parse(&tokens, allocator);
    defer ast.deinit();
    const expected: []const Expression = &.{
        symbol(.{ 0, 0 }, .{ 0, 1 }, "x"),
    };
    try expectEqualExpressions(expected, ast.expressions);
}

test "int" {
    const allocator = std.testing.allocator;
    const source = "5";
    var tokens = tokenize(source);
    const ast = try parse(&tokens, allocator);
    defer ast.deinit();
    const expected: []const Expression = &.{
        int(.{ 0, 0 }, .{ 0, 1 }, "5"),
    };
    try expectEqualExpressions(expected, ast.expressions);
}

test "add two symbols" {
    const allocator = std.testing.allocator;
    const source = "x + y";
    var tokens = tokenize(source);
    const ast = try parse(&tokens, allocator);
    defer ast.deinit();
    const expected: []const Expression = &.{
        binaryOp(.{ 0, 2 }, .{ 0, 3 }, .add, &.{
            symbol(.{ 0, 0 }, .{ 0, 1 }, "x"),
            symbol(.{ 0, 4 }, .{ 0, 5 }, "y"),
        }),
    };
    try expectEqualExpressions(expected, ast.expressions);
}

test "operator precedence lower first" {
    const allocator = std.testing.allocator;
    const source = "x + y * 5";
    var tokens = tokenize(source);
    const ast = try parse(&tokens, allocator);
    defer ast.deinit();
    const expected: []const Expression = &.{
        binaryOp(.{ 0, 2 }, .{ 0, 3 }, .add, &.{
            symbol(.{ 0, 0 }, .{ 0, 1 }, "x"),
            binaryOp(.{ 0, 6 }, .{ 0, 7 }, .mul, &.{
                symbol(.{ 0, 4 }, .{ 0, 5 }, "y"),
                int(.{ 0, 8 }, .{ 0, 9 }, "5"),
            }),
        }),
    };
    try expectEqualExpressions(expected, ast.expressions);
}

test "operator precedence higher first" {
    const allocator = std.testing.allocator;
    const source = "x * y + 5";
    var tokens = tokenize(source);
    const ast = try parse(&tokens, allocator);
    defer ast.deinit();
    const expected: []const Expression = &.{
        binaryOp(.{ 0, 6 }, .{ 0, 7 }, .add, &.{
            binaryOp(.{ 0, 2 }, .{ 0, 3 }, .mul, &.{
                symbol(.{ 0, 0 }, .{ 0, 1 }, "x"),
                symbol(.{ 0, 4 }, .{ 0, 5 }, "y"),
            }),
            int(.{ 0, 8 }, .{ 0, 9 }, "5"),
        }),
    };
    try expectEqualExpressions(expected, ast.expressions);
}
