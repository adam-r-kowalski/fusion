const std = @import("std");
const fusion = @import("fusion");
const tokenize = fusion.tokenizer.tokenize;
const tokenizeAlloc = fusion.tokenizer.tokenizeAlloc;
const Token = fusion.tokenizer.Token;

fn expectEqualToken(expected: Token, actual: Token) !void {
    switch (expected.kind) {
        .symbol => |s| try std.testing.expectEqualStrings(s, actual.kind.symbol),
        .int => |i| try std.testing.expectEqualStrings(i, actual.kind.int),
        .float => |f| try std.testing.expectEqualStrings(f, actual.kind.float),
        else => try std.testing.expectEqual(expected, actual),
    }
    try std.testing.expectEqual(expected.span, actual.span);
}

fn expectEqualTokens(expected: []const Token, actual: []const Token) !void {
    var i: usize = 0;
    const max = std.math.min(expected.len, actual.len);
    while (i < max) : (i += 1) {
        try expectEqualToken(expected[i], actual[i]);
    }
    try std.testing.expectEqual(expected.len, actual.len);
}

test "symbols" {
    const allocator = std.testing.allocator;
    const source = "text camelCase snake_case PascalCase 😀";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{ .span = .{ .{ 0, 0 }, .{ 0, 4 } }, .kind = .{ .symbol = "text" } },
        .{ .span = .{ .{ 0, 5 }, .{ 0, 14 } }, .kind = .{ .symbol = "camelCase" } },
        .{ .span = .{ .{ 0, 15 }, .{ 0, 25 } }, .kind = .{ .symbol = "snake_case" } },
        .{ .span = .{ .{ 0, 26 }, .{ 0, 36 } }, .kind = .{ .symbol = "PascalCase" } },
        .{ .span = .{ .{ 0, 37 }, .{ 0, 41 } }, .kind = .{ .symbol = "😀" } },
    };
    try expectEqualTokens(expected, actual);
}

test "ints" {
    const allocator = std.testing.allocator;
    const source = "1 42 -9 0 -0 1_000";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .{ .int = "1" } },
        .{ .span = .{ .{ 0, 2 }, .{ 0, 4 } }, .kind = .{ .int = "42" } },
        .{ .span = .{ .{ 0, 5 }, .{ 0, 7 } }, .kind = .{ .int = "-9" } },
        .{ .span = .{ .{ 0, 8 }, .{ 0, 9 } }, .kind = .{ .int = "0" } },
        .{ .span = .{ .{ 0, 10 }, .{ 0, 12 } }, .kind = .{ .int = "-0" } },
        .{ .span = .{ .{ 0, 13 }, .{ 0, 18 } }, .kind = .{ .int = "1_000" } },
    };
    try expectEqualTokens(expected, actual);
}

test "floats" {
    const allocator = std.testing.allocator;
    const source = "3.14 .25 -.25 1_000.3";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{ .span = .{ .{ 0, 0 }, .{ 0, 4 } }, .kind = .{ .float = "3.14" } },
        .{ .span = .{ .{ 0, 5 }, .{ 0, 8 } }, .kind = .{ .float = ".25" } },
        .{ .span = .{ .{ 0, 9 }, .{ 0, 13 } }, .kind = .{ .float = "-.25" } },
        .{ .span = .{ .{ 0, 14 }, .{ 0, 21 } }, .kind = .{ .float = "1_000.3" } },
    };
    try expectEqualTokens(expected, actual);
}

test "braces brackets and parens" {
    const allocator = std.testing.allocator;
    const source = "[{()}]";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .left_bracket },
        .{ .span = .{ .{ 0, 1 }, .{ 0, 2 } }, .kind = .left_brace },
        .{ .span = .{ .{ 0, 2 }, .{ 0, 3 } }, .kind = .left_paren },
        .{ .span = .{ .{ 0, 3 }, .{ 0, 4 } }, .kind = .right_paren },
        .{ .span = .{ .{ 0, 4 }, .{ 0, 5 } }, .kind = .right_brace },
        .{ .span = .{ .{ 0, 5 }, .{ 0, 6 } }, .kind = .right_bracket },
    };
    try expectEqualTokens(expected, actual);
}

test "comparison operators" {
    const allocator = std.testing.allocator;
    const source = "< > == != <= >=";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .less },
        .{ .span = .{ .{ 0, 2 }, .{ 0, 3 } }, .kind = .greater },
        .{ .span = .{ .{ 0, 4 }, .{ 0, 6 } }, .kind = .equal_equal },
        .{ .span = .{ .{ 0, 7 }, .{ 0, 9 } }, .kind = .bang_equal },
        .{ .span = .{ .{ 0, 10 }, .{ 0, 12 } }, .kind = .less_equal },
        .{ .span = .{ .{ 0, 13 }, .{ 0, 15 } }, .kind = .greater_equal },
    };
    try expectEqualTokens(expected, actual);
}

test "math operators" {
    const allocator = std.testing.allocator;
    const source = "+ - * / ^";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .plus },
        .{ .span = .{ .{ 0, 2 }, .{ 0, 3 } }, .kind = .dash },
        .{ .span = .{ .{ 0, 4 }, .{ 0, 5 } }, .kind = .star },
        .{ .span = .{ .{ 0, 6 }, .{ 0, 7 } }, .kind = .slash },
        .{ .span = .{ .{ 0, 8 }, .{ 0, 9 } }, .kind = .caret },
    };
    try expectEqualTokens(expected, actual);
}

test "boolean operators" {
    const allocator = std.testing.allocator;
    const source = "not and or";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{ .span = .{ .{ 0, 0 }, .{ 0, 3 } }, .kind = .not },
        .{ .span = .{ .{ 0, 4 }, .{ 0, 7 } }, .kind = .and_ },
        .{ .span = .{ .{ 0, 8 }, .{ 0, 10 } }, .kind = .or_ },
    };
    try expectEqualTokens(expected, actual);
}

test "misc operators" {
    const allocator = std.testing.allocator;
    const source = "= . -> <-";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .equal },
        .{ .span = .{ .{ 0, 2 }, .{ 0, 3 } }, .kind = .dot },
        .{ .span = .{ .{ 0, 4 }, .{ 0, 6 } }, .kind = .right_arrow },
        .{ .span = .{ .{ 0, 7 }, .{ 0, 9 } }, .kind = .left_arrow },
    };
    try expectEqualTokens(expected, actual);
}

test "single line function" {
    const allocator = std.testing.allocator;
    const source =
        \\double = \x -> x + x
    ;
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{ .span = .{ .{ 0, 0 }, .{ 0, 6 } }, .kind = .{ .symbol = "double" } },
        .{ .span = .{ .{ 0, 7 }, .{ 0, 8 } }, .kind = .equal },
        .{ .span = .{ .{ 0, 9 }, .{ 0, 10 } }, .kind = .backslash },
        .{ .span = .{ .{ 0, 10 }, .{ 0, 11 } }, .kind = .{ .symbol = "x" } },
        .{ .span = .{ .{ 0, 12 }, .{ 0, 14 } }, .kind = .right_arrow },
        .{ .span = .{ .{ 0, 15 }, .{ 0, 16 } }, .kind = .{ .symbol = "x" } },
        .{ .span = .{ .{ 0, 17 }, .{ 0, 18 } }, .kind = .plus },
        .{ .span = .{ .{ 0, 19 }, .{ 0, 20 } }, .kind = .{ .symbol = "x" } },
    };
    try expectEqualTokens(expected, actual);
}

test "multi line function" {
    const allocator = std.testing.allocator;
    const source =
        \\double = \x ->
        \\    x + x
    ;
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{ .span = .{ .{ 0, 0 }, .{ 0, 6 } }, .kind = .{ .symbol = "double" } },
        .{ .span = .{ .{ 0, 7 }, .{ 0, 8 } }, .kind = .equal },
        .{ .span = .{ .{ 0, 9 }, .{ 0, 10 } }, .kind = .backslash },
        .{ .span = .{ .{ 0, 10 }, .{ 0, 11 } }, .kind = .{ .symbol = "x" } },
        .{ .span = .{ .{ 0, 12 }, .{ 0, 14 } }, .kind = .right_arrow },
        .{ .span = .{ .{ 1, 0 }, .{ 1, 4 } }, .kind = .indent },
        .{ .span = .{ .{ 1, 4 }, .{ 1, 5 } }, .kind = .{ .symbol = "x" } },
        .{ .span = .{ .{ 1, 7 }, .{ 1, 8 } }, .kind = .plus },
        .{ .span = .{ .{ 1, 9 }, .{ 1, 10 } }, .kind = .{ .symbol = "x" } },
    };
    try expectEqualTokens(expected, actual);
}

test "function call" {
    const allocator = std.testing.allocator;
    const source = "min 10 20";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{ .span = .{ .{ 0, 0 }, .{ 0, 3 } }, .kind = .{ .symbol = "min" } },
        .{ .span = .{ .{ 0, 4 }, .{ 0, 6 } }, .kind = .{ .int = "10" } },
        .{ .span = .{ .{ 0, 7 }, .{ 0, 9 } }, .kind = .{ .int = "20" } },
    };
    try expectEqualTokens(expected, actual);
}

test "next and peek" {
    const source = "x + y";
    var tokens = tokenize(source);
    const x = .{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .{ .symbol = "x" } };
    const p = .{ .span = .{ .{ 0, 2 }, .{ 0, 3 } }, .kind = .plus };
    const y = .{ .span = .{ .{ 0, 4 }, .{ 0, 5 } }, .kind = .{ .symbol = "y" } };
    try expectEqualToken(tokens.peek().?, x);
    try expectEqualToken(tokens.peek().?, x);
    try expectEqualToken(tokens.next().?, x);
    try expectEqualToken(tokens.peek().?, p);
    try expectEqualToken(tokens.peek().?, p);
    try expectEqualToken(tokens.next().?, p);
    try expectEqualToken(tokens.peek().?, y);
    try expectEqualToken(tokens.peek().?, y);
    try expectEqualToken(tokens.next().?, y);
    try std.testing.expectEqual(tokens.peek(), null);
    try std.testing.expectEqual(tokens.peek(), null);
    try std.testing.expectEqual(tokens.next(), null);
}
