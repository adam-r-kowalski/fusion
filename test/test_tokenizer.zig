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
const equal = fusion.tokenizer.equal;
const less = fusion.tokenizer.less;
const greater = fusion.tokenizer.greater;
const plus = fusion.tokenizer.plus;
const minus = fusion.tokenizer.minus;
const times = fusion.tokenizer.times;
const div = fusion.tokenizer.div;
const dot = fusion.tokenizer.dot;
const ampersand = fusion.tokenizer.ampersand;
const caret = fusion.tokenizer.caret;
const not = fusion.tokenizer.not;
const and_ = fusion.tokenizer.and_;
const or_ = fusion.tokenizer.or_;
const equalEqual = fusion.tokenizer.equalEqual;
const lessEqual = fusion.tokenizer.lessEqual;
const greaterEqual = fusion.tokenizer.greaterEqual;
const comma = fusion.tokenizer.comma;
const bang = fusion.tokenizer.bang;
const bangEqual = fusion.tokenizer.bangEqual;
const colon = fusion.tokenizer.colon;

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

test "numbers" {
    const allocator = std.testing.allocator;
    const source = "1 42 -9 0 -0 3.14 .25 -.25 1_000";
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
            .span = .{ .begin = .{ .line = 0, .col = 13 }, .end = .{ .line = 0, .col = 17 } },
            .kind = .{ .float = "3.14" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 18 }, .end = .{ .line = 0, .col = 21 } },
            .kind = .{ .float = ".25" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 22 }, .end = .{ .line = 0, .col = 26 } },
            .kind = .{ .float = "-.25" },
        },
        .{
            .span = .{ .begin = .{ .line = 0, .col = 27 }, .end = .{ .line = 0, .col = 32 } },
            .kind = .{ .int = "1_000" },
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
    const source = "= < > + - * / . & ^ not and or == != <= >=";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        equal(.{ 0, 0 }, .{ 0, 1 }),
        less(.{ 0, 2 }, .{ 0, 3 }),
        greater(.{ 0, 4 }, .{ 0, 5 }),
        plus(.{ 0, 6 }, .{ 0, 7 }),
        minus(.{ 0, 8 }, .{ 0, 9 }),
        times(.{ 0, 10 }, .{ 0, 11 }),
        div(.{ 0, 12 }, .{ 0, 13 }),
        dot(.{ 0, 14 }, .{ 0, 15 }),
        ampersand(.{ 0, 16 }, .{ 0, 17 }),
        caret(.{ 0, 18 }, .{ 0, 19 }),
        not(.{ 0, 20 }, .{ 0, 23 }),
        and_(.{ 0, 24 }, .{ 0, 27 }),
        or_(.{ 0, 28 }, .{ 0, 30 }),
        equalEqual(.{ 0, 31 }, .{ 0, 33 }),
        bangEqual(.{ 0, 34 }, .{ 0, 36 }),
        lessEqual(.{ 0, 37 }, .{ 0, 39 }),
        greaterEqual(.{ 0, 40 }, .{ 0, 42 }),
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
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        symbol(.{ 0, 0 }, .{ 0, 4 }, "main"),
        equal(.{ 0, 5 }, .{ 0, 6 }),
        left_paren(.{ 0, 7 }, .{ 0, 8 }),
        right_paren(.{ 0, 8 }, .{ 0, 9 }),
        left_brace(.{ 0, 10 }, .{ 0, 11 }),
        int(.{ 1, 4 }, .{ 1, 6 }, "42"),
        right_brace(.{ 2, 0 }, .{ 2, 1 }),
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
        symbol(.{ 0, 0 }, .{ 0, 4 }, "main"),
        equal(.{ 0, 5 }, .{ 0, 6 }),
        left_paren(.{ 0, 7 }, .{ 0, 8 }),
        right_paren(.{ 0, 8 }, .{ 0, 9 }),
        left_brace(.{ 0, 10 }, .{ 0, 11 }),
        symbol(.{ 1, 4 }, .{ 1, 5 }, "x"),
        equal(.{ 1, 6 }, .{ 1, 7 }),
        int(.{ 1, 8 }, .{ 1, 10 }, "10"),
        symbol(.{ 2, 4 }, .{ 2, 5 }, "y"),
        equal(.{ 2, 6 }, .{ 2, 7 }),
        int(.{ 2, 8 }, .{ 2, 10 }, "25"),
        symbol(.{ 3, 4 }, .{ 3, 5 }, "x"),
        plus(.{ 3, 6 }, .{ 3, 7 }),
        symbol(.{ 3, 8 }, .{ 3, 9 }, "y"),
        right_brace(.{ 4, 0 }, .{ 4, 1 }),
    };
    try expectEqualTokens(expected, actual);
}

test "function call" {
    const allocator = std.testing.allocator;
    const source = "min(10, 20)";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        symbol(.{ 0, 0 }, .{ 0, 3 }, "min"),
        left_paren(.{ 0, 3 }, .{ 0, 4 }),
        int(.{ 0, 4 }, .{ 0, 6 }, "10"),
        comma(.{ 0, 6 }, .{ 0, 7 }),
        int(.{ 0, 8 }, .{ 0, 10 }, "20"),
        right_paren(.{ 0, 10 }, .{ 0, 11 }),
    };
    try expectEqualTokens(expected, actual);
}

test "ufcs function call" {
    const allocator = std.testing.allocator;
    const source = "10.min(20)";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        int(.{ 0, 0 }, .{ 0, 2 }, "10"),
        dot(.{ 0, 2 }, .{ 0, 3 }),
        symbol(.{ 0, 3 }, .{ 0, 6 }, "min"),
        left_paren(.{ 0, 6 }, .{ 0, 7 }),
        int(.{ 0, 7 }, .{ 0, 9 }, "20"),
        right_paren(.{ 0, 9 }, .{ 0, 10 }),
    };
    try expectEqualTokens(expected, actual);
}

test "variable with explicit type" {
    const allocator = std.testing.allocator;
    const source = "x: i32 = 10";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        symbol(.{ 0, 0 }, .{ 0, 1 }, "x"),
        colon(.{ 0, 1 }, .{ 0, 2 }),
        symbol(.{ 0, 3 }, .{ 0, 6 }, "i32"),
        equal(.{ 0, 7 }, .{ 0, 8 }),
        int(.{ 0, 9 }, .{ 0, 11 }, "10"),
    };
    try expectEqualTokens(expected, actual);
}

test "next and peek" {
    const source = "x + y";
    var tokens = tokenize(source);
    const x = symbol(.{ 0, 0 }, .{ 0, 1 }, "x");
    const p = plus(.{ 0, 2 }, .{ 0, 3 });
    const y = symbol(.{ 0, 4 }, .{ 0, 5 }, "y");
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
