const std = @import("std");
const fusion = @import("fusion");
const tokenize = fusion.tokenizer.tokenize;
const parse = fusion.parser.parse;
const Expression = fusion.parser.Expression;
const symbol = fusion.parser.symbol;
const int = fusion.parser.int;
const binaryOp = fusion.parser.binaryOp;

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
