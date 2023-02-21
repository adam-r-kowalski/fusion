const std = @import("std");
const fusion = @import("fusion");
const tokenize = fusion.tokenizer.tokenize;
const tokenizeAlloc = fusion.tokenizer.tokenizeAlloc;
const Token = fusion.tokenizer.Token;
const symbol = fusion.tokenizer.symbol;

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
        symbol("text", .{ 0, 0 }, .{ 0, 4 }),
        symbol("camelCase", .{ 0, 5 }, .{ 0, 14 }),
        symbol("snake_case", .{ 0, 15 }, .{ 0, 25 }),
        symbol("PascalCase", .{ 0, 26 }, .{ 0, 36 }),
        symbol("😀", .{ 0, 37 }, .{ 0, 41 }),
    };
    try expectEqualTokens(expected, actual);
}

test "numbers" {
    const allocator = std.testing.allocator;
    const source = "1 42 -9 0 -0 3.14 .25 -.25 1_000 1_000.";
    var actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{ .int = "1" },
        .{ .int = "42" },
        .{ .int = "-9" },
        .{ .int = "0" },
        .{ .int = "-0" },
        .{ .float = "3.14" },
        .{ .float = ".25" },
        .{ .float = "-.25" },
        .{ .int = "1_000" },
        .{ .float = "1_000." },
    };
    try expectEqualTokens(expected, actual);
}

test "braces brackets and parens" {
    const allocator = std.testing.allocator;
    const source = "[{()}]";
    var actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .left_bracket,
        .left_brace,
        .left_paren,
        .right_paren,
        .right_brace,
        .right_bracket,
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
