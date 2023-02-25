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
        .{
            .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 4 } },
            .kind = .{ .symbol = "text" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 5 }, .end = .{ .line = 0, .col = 14 } },
            .kind = .{ .symbol = "camelCase" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 15 }, .end = .{ .line = 0, .col = 25 } },
            .kind = .{ .symbol = "snake_case" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 26 }, .end = .{ .line = 0, .col = 36 } },
            .kind = .{ .symbol = "PascalCase" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 37 }, .end = .{ .line = 0, .col = 41 } },
            .kind = .{ .symbol = "😀" },
        },
    };
    try expectEqualTokens(expected, actual);
}

test "ints" {
    const allocator = std.testing.allocator;
    const source = "1 42 -9 0 -0 1_000";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{
            .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 1 } },
            .kind = .{ .int = "1" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 2 }, .end = .{ .line = 0, .col = 4 } },
            .kind = .{ .int = "42" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 5 }, .end = .{ .line = 0, .col = 7 } },
            .kind = .{ .int = "-9" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 8 }, .end = .{ .line = 0, .col = 9 } },
            .kind = .{ .int = "0" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 10 }, .end = .{ .line = 0, .col = 12 } },
            .kind = .{ .int = "-0" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 13 }, .end = .{ .line = 0, .col = 18 } },
            .kind = .{ .int = "1_000" },
        },
    };
    try expectEqualTokens(expected, actual);
}

test "floats" {
    const allocator = std.testing.allocator;
    const source = "3.14 .25 -.25 1_000.3";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{
            .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 4 } },
            .kind = .{ .float = "3.14" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 5 }, .end = .{ .line = 0, .col = 8 } },
            .kind = .{ .float = ".25" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 9 }, .end = .{ .line = 0, .col = 13 } },
            .kind = .{ .float = "-.25" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 14 }, .end = .{ .line = 0, .col = 21 } },
            .kind = .{ .float = "1_000.3" },
        },
    };
    try expectEqualTokens(expected, actual);
}

test "braces brackets and parens" {
    const allocator = std.testing.allocator;
    const source = "[{()}]";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{
            .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 1 } },
            .kind = .left_bracket,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 1 }, .end = .{ .line = 0, .col = 2 } },
            .kind = .left_brace,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 2 }, .end = .{ .line = 0, .col = 3 } },
            .kind = .left_paren,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 3 }, .end = .{ .line = 0, .col = 4 } },
            .kind = .right_paren,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 4 }, .end = .{ .line = 0, .col = 5 } },
            .kind = .right_brace,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 5 }, .end = .{ .line = 0, .col = 6 } },
            .kind = .right_bracket,
        },
    };
    try expectEqualTokens(expected, actual);
}

test "comparison operators" {
    const allocator = std.testing.allocator;
    const source = "< > == != <= >=";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{
            .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 1 } },
            .kind = .less,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 2 }, .end = .{ .line = 0, .col = 3 } },
            .kind = .greater,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 4 }, .end = .{ .line = 0, .col = 6 } },
            .kind = .equal_equal,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 7 }, .end = .{ .line = 0, .col = 9 } },
            .kind = .bang_equal,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 10 }, .end = .{ .line = 0, .col = 12 } },
            .kind = .less_equal,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 13 }, .end = .{ .line = 0, .col = 15 } },
            .kind = .greater_equal,
        },
    };
    try expectEqualTokens(expected, actual);
}

test "math operators" {
    const allocator = std.testing.allocator;
    const source = "+ - * / ^";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{
            .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 1 } },
            .kind = .plus,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 2 }, .end = .{ .line = 0, .col = 3 } },
            .kind = .minus,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 4 }, .end = .{ .line = 0, .col = 5 } },
            .kind = .times,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 6 }, .end = .{ .line = 0, .col = 7 } },
            .kind = .div,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 8 }, .end = .{ .line = 0, .col = 9 } },
            .kind = .caret,
        },
    };
    try expectEqualTokens(expected, actual);
}

test "boolean operators" {
    const allocator = std.testing.allocator;
    const source = "not and or";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{
            .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 3 } },
            .kind = .not,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 4 }, .end = .{ .line = 0, .col = 7 } },
            .kind = .and_,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 8 }, .end = .{ .line = 0, .col = 10 } },
            .kind = .or_,
        },
    };
    try expectEqualTokens(expected, actual);
}

test "access operators" {
    const allocator = std.testing.allocator;
    const source = "= . &";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{
            .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 1 } },
            .kind = .equal,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 2 }, .end = .{ .line = 0, .col = 3 } },
            .kind = .dot,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 4 }, .end = .{ .line = 0, .col = 5 } },
            .kind = .ampersand,
        },
    };
    try expectEqualTokens(expected, actual);
}

test "single line function" {
    const allocator = std.testing.allocator;
    const source =
        \\main = () {
        \\    42
        \\}
    ;
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{
            .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 4 } },
            .kind = .{ .symbol = "main" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 5 }, .end = .{ .line = 0, .col = 6 } },
            .kind = .equal,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 7 }, .end = .{ .line = 0, .col = 8 } },
            .kind = .left_paren,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 8 }, .end = .{ .line = 0, .col = 9 } },
            .kind = .right_paren,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 10 }, .end = .{ .line = 0, .col = 11 } },
            .kind = .left_brace,
        },
        .{
            .span = .{ .begin = .{ .line = 1, .col = 4 }, .end = .{ .line = 1, .col = 6 } },
            .kind = .{ .int = "42" },
        },
        .{
            .span = .{ .begin = .{ .line = 2, .col = 0 }, .end = .{ .line = 2, .col = 1 } },
            .kind = .right_brace,
        },
    };
    try expectEqualTokens(expected, actual);
}

test "multi line function" {
    const allocator = std.testing.allocator;
    const source =
        \\main = () {
        \\    x = 10
        \\    y = 25
        \\    x + y
        \\}
    ;
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{
            .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 4 } },
            .kind = .{ .symbol = "main" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 5 }, .end = .{ .line = 0, .col = 6 } },
            .kind = .equal,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 7 }, .end = .{ .line = 0, .col = 8 } },
            .kind = .left_paren,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 8 }, .end = .{ .line = 0, .col = 9 } },
            .kind = .right_paren,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 10 }, .end = .{ .line = 0, .col = 11 } },
            .kind = .left_brace,
        },
        .{
            .span = .{ .begin = .{ .line = 1, .col = 4 }, .end = .{ .line = 1, .col = 5 } },
            .kind = .{ .symbol = "x" },
        },
        .{
            .span = .{ .begin = .{ .line = 1, .col = 6 }, .end = .{ .line = 1, .col = 7 } },
            .kind = .equal,
        },
        .{
            .span = .{ .begin = .{ .line = 1, .col = 8 }, .end = .{ .line = 1, .col = 10 } },
            .kind = .{ .int = "10" },
        },
        .{
            .span = .{ .begin = .{ .line = 2, .col = 4 }, .end = .{ .line = 2, .col = 5 } },
            .kind = .{ .symbol = "y" },
        },
        .{
            .span = .{ .begin = .{ .line = 2, .col = 6 }, .end = .{ .line = 2, .col = 7 } },
            .kind = .equal,
        },
        .{
            .span = .{ .begin = .{ .line = 2, .col = 8 }, .end = .{ .line = 2, .col = 10 } },
            .kind = .{ .int = "25" },
        },
        .{
            .span = .{ .begin = .{ .line = 3, .col = 4 }, .end = .{ .line = 3, .col = 5 } },
            .kind = .{ .symbol = "x" },
        },
        .{
            .span = .{ .begin = .{ .line = 3, .col = 6 }, .end = .{ .line = 3, .col = 7 } },
            .kind = .plus,
        },
        .{
            .span = .{ .begin = .{ .line = 3, .col = 8 }, .end = .{ .line = 3, .col = 9 } },
            .kind = .{ .symbol = "y" },
        },
        .{
            .span = .{ .begin = .{ .line = 4, .col = 0 }, .end = .{ .line = 4, .col = 1 } },
            .kind = .right_brace,
        },
    };
    try expectEqualTokens(expected, actual);
}

test "function call" {
    const allocator = std.testing.allocator;
    const source = "min(10, 20)";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{
            .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 3 } },
            .kind = .{ .symbol = "min" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 3 }, .end = .{ .line = 0, .col = 4 } },
            .kind = .left_paren,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 4 }, .end = .{ .line = 0, .col = 6 } },
            .kind = .{ .int = "10" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 6 }, .end = .{ .line = 0, .col = 7 } },
            .kind = .comma,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 8 }, .end = .{ .line = 0, .col = 10 } },
            .kind = .{ .int = "20" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 10 }, .end = .{ .line = 0, .col = 11 } },
            .kind = .right_paren,
        },
    };
    try expectEqualTokens(expected, actual);
}

test "ufcs function call" {
    const allocator = std.testing.allocator;
    const source = "10.min(20)";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{
            .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 2 } },
            .kind = .{ .int = "10" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 2 }, .end = .{ .line = 0, .col = 3 } },
            .kind = .dot,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 3 }, .end = .{ .line = 0, .col = 6 } },
            .kind = .{ .symbol = "min" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 6 }, .end = .{ .line = 0, .col = 7 } },
            .kind = .left_paren,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 7 }, .end = .{ .line = 0, .col = 9 } },
            .kind = .{ .int = "20" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 9 }, .end = .{ .line = 0, .col = 10 } },
            .kind = .right_paren,
        },
    };
    try expectEqualTokens(expected, actual);
}

test "variable with explicit type" {
    const allocator = std.testing.allocator;
    const source = "x: i32 = 10";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{
            .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 1 } },
            .kind = .{ .symbol = "x" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 1 }, .end = .{ .line = 0, .col = 2 } },
            .kind = .colon,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 3 }, .end = .{ .line = 0, .col = 6 } },
            .kind = .{ .symbol = "i32" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 7 }, .end = .{ .line = 0, .col = 8 } },
            .kind = .equal,
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 9 }, .end = .{ .line = 0, .col = 11 } },
            .kind = .{ .int = "10" },
        },
    };
    try expectEqualTokens(expected, actual);
}

test "next and peek" {
    const source = "x + y";
    var tokens = tokenize(source);
    const x = .{
        .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 1 } },
        .kind = .{ .symbol = "x" },
    };
    const p = .{
        .span = .{ .begin = .{ .line = 0, .col = 2 }, .end = .{ .line = 0, .col = 3 } },
        .kind = .plus,
    };
    const y = .{
        .span = .{ .begin = .{ .line = 0, .col = 4 }, .end = .{ .line = 0, .col = 5 } },
        .kind = .{ .symbol = "y" },
    };
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
