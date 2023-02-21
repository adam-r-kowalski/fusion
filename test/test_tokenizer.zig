const std = @import("std");
const fusion = @import("fusion");
const tokenize = fusion.tokenizer.tokenize;
const tokenizeAlloc = fusion.tokenizer.tokenizeAlloc;
const Token = fusion.tokenizer.Token;
const symbol = fusion.tokenizer.symbol;
const int = fusion.tokenizer.int;
const float = fusion.tokenizer.float;
const left_bracket = fusion.tokenizer.left_bracket;
const left_brace = fusion.tokenizer.left_brace;
const left_paren = fusion.tokenizer.left_paren;
const right_paren = fusion.tokenizer.right_paren;
const right_brace = fusion.tokenizer.right_brace;
const right_bracket = fusion.tokenizer.right_bracket;

fn expectEqualToken(expected: Token, actual: Token) !void {
    try std.testing.expectEqual(expected.start, actual.start);
    try std.testing.expectEqual(expected.end, actual.end);
    switch (expected.kind) {
        .symbol => |s| try std.testing.expectEqualStrings(s, actual.kind.symbol),
        .int => |i| try std.testing.expectEqualStrings(i, actual.kind.int),
        .float => |f| try std.testing.expectEqualStrings(f, actual.kind.float),
        else => try std.testing.expectEqual(expected, actual),
    }
}

fn expectEqualTokens(expected: []const Token, actual: []const Token) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected) |e, i| {
        try expectEqualToken(e, actual[i]);
    }
}

test "symbols" {
    const allocator = std.testing.allocator;
    const source = "text camelCase snake_case PascalCase 😀";
    var actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        symbol(.{ 0, 0 }, .{ 0, 4 }, "text"),
        symbol(.{ 0, 5 }, .{ 0, 14 }, "camelCase"),
        symbol(.{ 0, 15 }, .{ 0, 25 }, "snake_case"),
        symbol(.{ 0, 26 }, .{ 0, 36 }, "PascalCase"),
        symbol(.{ 0, 37 }, .{ 0, 41 }, "😀"),
    };
    try expectEqualTokens(expected, actual);
}

test "numbers" {
    const allocator = std.testing.allocator;
    const source = "1 42 -9 0 -0 3.14 .25 -.25 1_000 1_000.";
    var actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        int(.{ 0, 0 }, .{ 0, 1 }, "1"),
        int(.{ 0, 2 }, .{ 0, 4 }, "42"),
        int(.{ 0, 5 }, .{ 0, 7 }, "-9"),
        int(.{ 0, 8 }, .{ 0, 9 }, "0"),
        int(.{ 0, 10 }, .{ 0, 12 }, "-0"),
        float(.{ 0, 13 }, .{ 0, 17 }, "3.14"),
        float(.{ 0, 18 }, .{ 0, 21 }, ".25"),
        float(.{ 0, 22 }, .{ 0, 26 }, "-.25"),
        int(.{ 0, 27 }, .{ 0, 32 }, "1_000"),
        float(.{ 0, 33 }, .{ 0, 39 }, "1_000."),
    };
    try expectEqualTokens(expected, actual);
}

test "braces brackets and parens" {
    const allocator = std.testing.allocator;
    const source = "[{()}]";
    var actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        left_bracket(.{ 0, 0 }, .{ 0, 1 }),
        left_brace(.{ 0, 1 }, .{ 0, 2 }),
        left_paren(.{ 0, 2 }, .{ 0, 3 }),
        right_paren(.{ 0, 3 }, .{ 0, 4 }),
        right_brace(.{ 0, 4 }, .{ 0, 5 }),
        right_bracket(.{ 0, 5 }, .{ 0, 6 }),
    };
    try expectEqualTokens(expected, actual);
}

test "operators" {
    const allocator = std.testing.allocator;
    // const source = "== != <= >=";
    const source = "= < > + - * / . & ^ not and or";
    var actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .equal,
        .less,
        .greater,
        .plus,
        .minus,
        .times,
        .div,
        .dot,
        .ampersand,
        .caret,
        .not,
        .and_,
        .or_,
    };
    try expectEqualTokens(expected, actual);
}

test "function" {
    const allocator = std.testing.allocator;
    const source =
        \\main = () {
        \\    42
        \\}
    ;
    var actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{ .symbol = "main" },
        .equal,
        .left_paren,
        .right_paren,
        .left_brace,
        .{ .int = "42" },
        .right_brace,
    };
    try expectEqualTokens(expected, actual);
}
