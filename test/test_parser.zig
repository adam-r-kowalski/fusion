const std = @import("std");
const fusion = @import("fusion");
const tokenize = fusion.tokenizer.tokenize;
const parse = fusion.parser.parse;
const symbol = fusion.parser.symbol;
const int = fusion.parser.int;
const Expression = fusion.parser.Expression;

fn expectEqualExpression(expected: Expression, actual: Expression) !void {
    switch (expected.kind) {
        .symbol => |s| try std.testing.expectEqualStrings(s, actual.kind.symbol),
        .int => |s| try std.testing.expectEqualStrings(s, actual.kind.int),
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
    const expected: []const Expression = &.{
        symbol(.{ 0, 0 }, .{ 0, 1 }, "x"),
    };
    try expectEqualExpressions(expected, ast.expressions);
    defer ast.deinit();
}

test "int" {
    const allocator = std.testing.allocator;
    const source = "5";
    var tokens = tokenize(source);
    const ast = try parse(&tokens, allocator);
    const expected: []const Expression = &.{
        int(.{ 0, 0 }, .{ 0, 1 }, "5"),
    };
    try expectEqualExpressions(expected, ast.expressions);
    defer ast.deinit();
}
