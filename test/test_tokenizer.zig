const std = @import("std");
const fusion = @import("fusion");
const tokenize = fusion.tokenize.tokenize;
const tokenizeAlloc = fusion.tokenize.tokenizeAlloc;
const peekToken = fusion.tokenize.peekToken;
const nextToken = fusion.tokenize.nextToken;
const Token = fusion.types.token.Token;
const Span = fusion.types.token.Span;

fn expectEqualToken(expected: Token, actual: Token) !void {
    const allocator = std.testing.allocator;
    const actualString = try fusion.write.tokens.tokenAlloc(actual, allocator);
    defer allocator.free(actualString);
    const expectedString = try fusion.write.tokens.tokenAlloc(expected, allocator);
    defer allocator.free(expectedString);
    try std.testing.expectEqualStrings(expectedString, actualString);
}

fn expectEqual(expected: []const Token, actual: []const Token) !void {
    const allocator = std.testing.allocator;
    const actualString = try fusion.write.tokens.tokensAlloc(actual, allocator);
    defer allocator.free(actualString);
    const expectedString = try fusion.write.tokens.tokensAlloc(expected, allocator);
    defer allocator.free(expectedString);
    try std.testing.expectEqualStrings(expectedString, actualString);
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
    try expectEqual(expected, actual);
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
    try expectEqual(expected, actual);
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
    try expectEqual(expected, actual);
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
    try expectEqual(expected, actual);
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
    try expectEqual(expected, actual);
}

test "math operators" {
    const allocator = std.testing.allocator;
    const source = "+ - * / ^ %";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .plus },
        .{ .span = .{ .{ 0, 2 }, .{ 0, 3 } }, .kind = .dash },
        .{ .span = .{ .{ 0, 4 }, .{ 0, 5 } }, .kind = .star },
        .{ .span = .{ .{ 0, 6 }, .{ 0, 7 } }, .kind = .slash },
        .{ .span = .{ .{ 0, 8 }, .{ 0, 9 } }, .kind = .caret },
        .{ .span = .{ .{ 0, 10 }, .{ 0, 11 } }, .kind = .percent },
    };
    try expectEqual(expected, actual);
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
    try expectEqual(expected, actual);
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
    try expectEqual(expected, actual);
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
    try expectEqual(expected, actual);
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
        .{ .span = .{ .{ 1, 0 }, .{ 1, 4 } }, .kind = .{ .indent = .{ .space = 4 } } },
        .{ .span = .{ .{ 1, 4 }, .{ 1, 5 } }, .kind = .{ .symbol = "x" } },
        .{ .span = .{ .{ 1, 6 }, .{ 1, 7 } }, .kind = .plus },
        .{ .span = .{ .{ 1, 8 }, .{ 1, 9 } }, .kind = .{ .symbol = "x" } },
    };
    try expectEqual(expected, actual);
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
    try expectEqual(expected, actual);
}

test "function declaration" {
    const allocator = std.testing.allocator;
    const source =
        \\transpose : m=>n=>v -> n=>m=>v
    ;
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{ .span = .{ .{ 0, 0 }, .{ 0, 9 } }, .kind = .{ .symbol = "transpose" } },
        .{ .span = .{ .{ 0, 10 }, .{ 0, 11 } }, .kind = .colon },
        .{ .span = .{ .{ 0, 12 }, .{ 0, 13 } }, .kind = .{ .symbol = "m" } },
        .{ .span = .{ .{ 0, 13 }, .{ 0, 15 } }, .kind = .fat_arrow },
        .{ .span = .{ .{ 0, 15 }, .{ 0, 16 } }, .kind = .{ .symbol = "n" } },
        .{ .span = .{ .{ 0, 16 }, .{ 0, 18 } }, .kind = .fat_arrow },
        .{ .span = .{ .{ 0, 18 }, .{ 0, 19 } }, .kind = .{ .symbol = "v" } },
        .{ .span = .{ .{ 0, 20 }, .{ 0, 22 } }, .kind = .right_arrow },
        .{ .span = .{ .{ 0, 23 }, .{ 0, 24 } }, .kind = .{ .symbol = "n" } },
        .{ .span = .{ .{ 0, 24 }, .{ 0, 26 } }, .kind = .fat_arrow },
        .{ .span = .{ .{ 0, 26 }, .{ 0, 27 } }, .kind = .{ .symbol = "m" } },
        .{ .span = .{ .{ 0, 27 }, .{ 0, 29 } }, .kind = .fat_arrow },
        .{ .span = .{ .{ 0, 29 }, .{ 0, 30 } }, .kind = .{ .symbol = "v" } },
    };
    try expectEqual(expected, actual);
}

test "function declaration and definition" {
    const allocator = std.testing.allocator;
    const source =
        \\double : F32 -> F32
        \\double = \x -> x * x
    ;
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{ .span = .{ .{ 0, 0 }, .{ 0, 6 } }, .kind = .{ .symbol = "double" } },
        .{ .span = .{ .{ 0, 7 }, .{ 0, 8 } }, .kind = .colon },
        .{ .span = .{ .{ 0, 9 }, .{ 0, 12 } }, .kind = .{ .symbol = "F32" } },
        .{ .span = .{ .{ 0, 13 }, .{ 0, 15 } }, .kind = .right_arrow },
        .{ .span = .{ .{ 0, 16 }, .{ 0, 19 } }, .kind = .{ .symbol = "F32" } },
        .{ .span = .{ .{ 1, 0 }, .{ 1, 0 } }, .kind = .{ .indent = .{ .space = 0 } } },
        .{ .span = .{ .{ 1, 0 }, .{ 1, 6 } }, .kind = .{ .symbol = "double" } },
        .{ .span = .{ .{ 1, 7 }, .{ 1, 8 } }, .kind = .equal },
        .{ .span = .{ .{ 1, 9 }, .{ 1, 10 } }, .kind = .backslash },
        .{ .span = .{ .{ 1, 10 }, .{ 1, 11 } }, .kind = .{ .symbol = "x" } },
        .{ .span = .{ .{ 1, 12 }, .{ 1, 14 } }, .kind = .right_arrow },
        .{ .span = .{ .{ 1, 15 }, .{ 1, 16 } }, .kind = .{ .symbol = "x" } },
        .{ .span = .{ .{ 1, 17 }, .{ 1, 18 } }, .kind = .star },
        .{ .span = .{ .{ 1, 19 }, .{ 1, 20 } }, .kind = .{ .symbol = "x" } },
    };
    try expectEqual(expected, actual);
}

test "multiple indentations in one function" {
    const allocator = std.testing.allocator;
    const source =
        \\sumSquares = \x y ->
        \\    x2 = x ^ 2
        \\    y2 = y ^ 2
        \\    x2 + y2
    ;
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{ .span = .{ .{ 0, 0 }, .{ 0, 10 } }, .kind = .{ .symbol = "sumSquares" } },
        .{ .span = .{ .{ 0, 11 }, .{ 0, 12 } }, .kind = .equal },
        .{ .span = .{ .{ 0, 13 }, .{ 0, 14 } }, .kind = .backslash },
        .{ .span = .{ .{ 0, 14 }, .{ 0, 15 } }, .kind = .{ .symbol = "x" } },
        .{ .span = .{ .{ 0, 16 }, .{ 0, 17 } }, .kind = .{ .symbol = "y" } },
        .{ .span = .{ .{ 0, 18 }, .{ 0, 20 } }, .kind = .right_arrow },
        .{ .span = .{ .{ 1, 0 }, .{ 1, 4 } }, .kind = .{ .indent = .{ .space = 4 } } },
        .{ .span = .{ .{ 1, 4 }, .{ 1, 6 } }, .kind = .{ .symbol = "x2" } },
        .{ .span = .{ .{ 1, 7 }, .{ 1, 8 } }, .kind = .equal },
        .{ .span = .{ .{ 1, 9 }, .{ 1, 10 } }, .kind = .{ .symbol = "x" } },
        .{ .span = .{ .{ 1, 11 }, .{ 1, 12 } }, .kind = .caret },
        .{ .span = .{ .{ 1, 13 }, .{ 1, 14 } }, .kind = .{ .int = "2" } },
        .{ .span = .{ .{ 2, 0 }, .{ 2, 4 } }, .kind = .{ .indent = .{ .space = 4 } } },
        .{ .span = .{ .{ 2, 4 }, .{ 2, 6 } }, .kind = .{ .symbol = "y2" } },
        .{ .span = .{ .{ 2, 7 }, .{ 2, 8 } }, .kind = .equal },
        .{ .span = .{ .{ 2, 9 }, .{ 2, 10 } }, .kind = .{ .symbol = "y" } },
        .{ .span = .{ .{ 2, 11 }, .{ 2, 12 } }, .kind = .caret },
        .{ .span = .{ .{ 2, 13 }, .{ 2, 14 } }, .kind = .{ .int = "2" } },
        .{ .span = .{ .{ 3, 0 }, .{ 3, 4 } }, .kind = .{ .indent = .{ .space = 4 } } },
        .{ .span = .{ .{ 3, 4 }, .{ 3, 6 } }, .kind = .{ .symbol = "x2" } },
        .{ .span = .{ .{ 3, 7 }, .{ 3, 8 } }, .kind = .plus },
        .{ .span = .{ .{ 3, 9 }, .{ 3, 11 } }, .kind = .{ .symbol = "y2" } },
    };
    try expectEqual(expected, actual);
}

test "control flow tokens" {
    const allocator = std.testing.allocator;
    const source =
        \\if then else when is for
    ;
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{ .span = .{ .{ 0, 0 }, .{ 0, 2 } }, .kind = .if_ },
        .{ .span = .{ .{ 0, 3 }, .{ 0, 7 } }, .kind = .then },
        .{ .span = .{ .{ 0, 8 }, .{ 0, 12 } }, .kind = .else_ },
        .{ .span = .{ .{ 0, 13 }, .{ 0, 17 } }, .kind = .when },
        .{ .span = .{ .{ 0, 18 }, .{ 0, 20 } }, .kind = .is },
        .{ .span = .{ .{ 0, 21 }, .{ 0, 24 } }, .kind = .for_ },
    };
    try expectEqual(expected, actual);
}

test "string" {
    const allocator = std.testing.allocator;
    const source =
        \\"text" "camelCase" "snake_case" "PascalCase" "😀"
    ;
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{ .span = .{ .{ 0, 0 }, .{ 0, 6 } }, .kind = .{ .string = "\"text\"" } },
        .{ .span = .{ .{ 0, 7 }, .{ 0, 18 } }, .kind = .{ .string = "\"camelCase\"" } },
        .{ .span = .{ .{ 0, 19 }, .{ 0, 31 } }, .kind = .{ .string = "\"snake_case\"" } },
        .{ .span = .{ .{ 0, 32 }, .{ 0, 44 } }, .kind = .{ .string = "\"PascalCase\"" } },
        .{ .span = .{ .{ 0, 45 }, .{ 0, 51 } }, .kind = .{ .string = "\"😀\"" } },
    };
    try expectEqual(expected, actual);
}

test "indent using tab" {
    const allocator = std.testing.allocator;
    const source =
        \\double = \x ->
        \\	x + x
    ;
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{ .span = .{ .{ 0, 0 }, .{ 0, 6 } }, .kind = .{ .symbol = "double" } },
        .{ .span = .{ .{ 0, 7 }, .{ 0, 8 } }, .kind = .equal },
        .{ .span = .{ .{ 0, 9 }, .{ 0, 10 } }, .kind = .backslash },
        .{ .span = .{ .{ 0, 10 }, .{ 0, 11 } }, .kind = .{ .symbol = "x" } },
        .{ .span = .{ .{ 0, 12 }, .{ 0, 14 } }, .kind = .right_arrow },
        .{ .span = .{ .{ 1, 0 }, .{ 1, 1 } }, .kind = .{ .indent = .{ .tab = 1 } } },
        .{ .span = .{ .{ 1, 1 }, .{ 1, 2 } }, .kind = .{ .symbol = "x" } },
        .{ .span = .{ .{ 1, 3 }, .{ 1, 4 } }, .kind = .plus },
        .{ .span = .{ .{ 1, 5 }, .{ 1, 6 } }, .kind = .{ .symbol = "x" } },
    };
    try expectEqual(expected, actual);
}

test "pipeline" {
    const allocator = std.testing.allocator;
    const source = "a |> f b c |> g d";
    const actual = try tokenizeAlloc(source, allocator);
    defer allocator.free(actual);
    const expected: []const Token = &.{
        .{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .{ .symbol = "a" } },
        .{ .span = .{ .{ 0, 2 }, .{ 0, 4 } }, .kind = .pipe },
        .{ .span = .{ .{ 0, 5 }, .{ 0, 6 } }, .kind = .{ .symbol = "f" } },
        .{ .span = .{ .{ 0, 7 }, .{ 0, 8 } }, .kind = .{ .symbol = "b" } },
        .{ .span = .{ .{ 0, 9 }, .{ 0, 10 } }, .kind = .{ .symbol = "c" } },
        .{ .span = .{ .{ 0, 11 }, .{ 0, 13 } }, .kind = .pipe },
        .{ .span = .{ .{ 0, 14 }, .{ 0, 15 } }, .kind = .{ .symbol = "g" } },
        .{ .span = .{ .{ 0, 16 }, .{ 0, 17 } }, .kind = .{ .symbol = "d" } },
    };
    try expectEqual(expected, actual);
}

test "next and peek" {
    const source = "x + y";
    var tokens = tokenize(source);
    const x = .{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .{ .symbol = "x" } };
    const p = .{ .span = .{ .{ 0, 2 }, .{ 0, 3 } }, .kind = .plus };
    const y = .{ .span = .{ .{ 0, 4 }, .{ 0, 5 } }, .kind = .{ .symbol = "y" } };
    try expectEqualToken(peekToken(&tokens).?, x);
    try expectEqualToken(peekToken(&tokens).?, x);
    try expectEqualToken(nextToken(&tokens).?, x);
    try expectEqualToken(peekToken(&tokens).?, p);
    try expectEqualToken(peekToken(&tokens).?, p);
    try expectEqualToken(nextToken(&tokens).?, p);
    try expectEqualToken(peekToken(&tokens).?, y);
    try expectEqualToken(peekToken(&tokens).?, y);
    try expectEqualToken(nextToken(&tokens).?, y);
    try std.testing.expectEqual(peekToken(&tokens), null);
    try std.testing.expectEqual(peekToken(&tokens), null);
    try std.testing.expectEqual(nextToken(&tokens), null);
}
