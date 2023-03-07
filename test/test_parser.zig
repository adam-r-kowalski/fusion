const std = @import("std");
const fusion = @import("fusion");
const tokenize = fusion.tokenize.tokenize;
const parse = fusion.parse;
const Expression = fusion.types.ast.Expression;
const Ast = fusion.types.ast.Ast;

fn expectEqual(expected: []const Expression, actual: Ast) !void {
    const allocator = std.testing.allocator;
    const actualString = try fusion.write.ast.astAlloc(actual, allocator);
    defer allocator.free(actualString);
    const expectedString = try fusion.write.ast.expressionsAlloc(expected, allocator);
    defer allocator.free(expectedString);
    try std.testing.expectEqualStrings(expectedString, actualString);
}

test "symbol" {
    const allocator = std.testing.allocator;
    const source = "x";
    var tokens = tokenize(source);
    const actual = try parse(&tokens, allocator);
    defer actual.deinit();
    const expected: []const Expression = &.{
        .{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .{ .symbol = "x" } },
    };
    try expectEqual(expected, actual);
}

test "int" {
    const allocator = std.testing.allocator;
    const source = "5";
    var tokens = tokenize(source);
    const actual = try parse(&tokens, allocator);
    defer actual.deinit();
    const expected: []const Expression = &.{
        .{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .{ .int = "5" } },
    };
    try expectEqual(expected, actual);
}

test "add two symbols" {
    const allocator = std.testing.allocator;
    const source = "x + y";
    var tokens = tokenize(source);
    const actual = try parse(&tokens, allocator);
    defer actual.deinit();
    const expected: []const Expression = &.{
        .{
            .span = .{ .{ 0, 2 }, .{ 0, 3 } },
            .kind = .{
                .binary_op = .{
                    .kind = .add,
                    .left = &.{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .{ .symbol = "x" } },
                    .right = &.{ .span = .{ .{ 0, 4 }, .{ 0, 5 } }, .kind = .{ .symbol = "y" } },
                },
            },
        },
    };
    try expectEqual(expected, actual);
}

test "operator precedence lower first" {
    const allocator = std.testing.allocator;
    const source = "x + y * 5";
    var tokens = tokenize(source);
    const actual = try parse(&tokens, allocator);
    defer actual.deinit();
    const expected: []const Expression = &.{
        .{
            .span = .{ .{ 0, 2 }, .{ 0, 3 } },
            .kind = .{
                .binary_op = .{
                    .kind = .add,
                    .left = &.{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .{ .symbol = "x" } },
                    .right = &.{
                        .span = .{ .{ 0, 6 }, .{ 0, 7 } },
                        .kind = .{
                            .binary_op = .{
                                .kind = .mul,
                                .left = &.{ .span = .{ .{ 0, 4 }, .{ 0, 5 } }, .kind = .{ .symbol = "y" } },
                                .right = &.{ .span = .{ .{ 0, 8 }, .{ 0, 9 } }, .kind = .{ .int = "5" } },
                            },
                        },
                    },
                },
            },
        },
    };
    try expectEqual(expected, actual);
}

test "operator precedence higher first" {
    const allocator = std.testing.allocator;
    const source = "x * y + 5";
    var tokens = tokenize(source);
    const actual = try parse(&tokens, allocator);
    defer actual.deinit();
    const expected: []const Expression = &.{
        .{
            .span = .{ .{ 0, 6 }, .{ 0, 7 } },
            .kind = .{
                .binary_op = .{
                    .kind = .add,
                    .left = &.{
                        .span = .{ .{ 0, 2 }, .{ 0, 3 } },
                        .kind = .{
                            .binary_op = .{
                                .kind = .mul,
                                .left = &.{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .{ .symbol = "x" } },
                                .right = &.{ .span = .{ .{ 0, 4 }, .{ 0, 5 } }, .kind = .{ .symbol = "y" } },
                            },
                        },
                    },
                    .right = &.{ .span = .{ .{ 0, 8 }, .{ 0, 9 } }, .kind = .{ .int = "5" } },
                },
            },
        },
    };
    try expectEqual(expected, actual);
}

test "left associative operator" {
    const allocator = std.testing.allocator;
    const source = "x + y + 5";
    var tokens = tokenize(source);
    const actual = try parse(&tokens, allocator);
    defer actual.deinit();
    const expected: []const Expression = &.{
        .{
            .span = .{ .{ 0, 6 }, .{ 0, 7 } },
            .kind = .{
                .binary_op = .{
                    .kind = .add,
                    .left = &.{
                        .span = .{ .{ 0, 2 }, .{ 0, 3 } },
                        .kind = .{
                            .binary_op = .{
                                .kind = .add,
                                .left = &.{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .{ .symbol = "x" } },
                                .right = &.{ .span = .{ .{ 0, 4 }, .{ 0, 5 } }, .kind = .{ .symbol = "y" } },
                            },
                        },
                    },
                    .right = &.{ .span = .{ .{ 0, 8 }, .{ 0, 9 } }, .kind = .{ .int = "5" } },
                },
            },
        },
    };
    try expectEqual(expected, actual);
}

test "left associative operator with group" {
    const allocator = std.testing.allocator;
    const source = "(x + y) + 5";
    var tokens = tokenize(source);
    const actual = try parse(&tokens, allocator);
    defer actual.deinit();
    const expected: []const Expression = &.{
        .{
            .span = .{ .{ 0, 8 }, .{ 0, 9 } },
            .kind = .{
                .binary_op = .{
                    .kind = .add,
                    .left = &.{
                        .span = .{ .{ 0, 0 }, .{ 0, 4 } },
                        .kind = .{
                            .group = .{
                                .expr = &.{
                                    .span = .{ .{ 0, 3 }, .{ 0, 4 } },
                                    .kind = .{
                                        .binary_op = .{
                                            .kind = .add,
                                            .left = &.{ .span = .{ .{ 0, 1 }, .{ 0, 2 } }, .kind = .{ .symbol = "x" } },
                                            .right = &.{ .span = .{ .{ 0, 5 }, .{ 0, 6 } }, .kind = .{ .symbol = "y" } },
                                        },
                                    },
                                },
                            },
                        },
                    },
                    .right = &.{ .span = .{ .{ 0, 10 }, .{ 0, 11 } }, .kind = .{ .int = "5" } },
                },
            },
        },
    };
    try expectEqual(expected, actual);
}

test "right associative operator" {
    const allocator = std.testing.allocator;
    const source = "x ^ y ^ 5";
    var tokens = tokenize(source);
    const actual = try parse(&tokens, allocator);
    defer actual.deinit();
    const expected: []const Expression = &.{
        .{
            .span = .{ .{ 0, 2 }, .{ 0, 3 } },
            .kind = .{
                .binary_op = .{
                    .kind = .pow,
                    .left = &.{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .{ .symbol = "x" } },
                    .right = &.{
                        .span = .{ .{ 0, 6 }, .{ 0, 7 } },
                        .kind = .{
                            .binary_op = .{
                                .kind = .pow,
                                .left = &.{ .span = .{ .{ 0, 4 }, .{ 0, 5 } }, .kind = .{ .symbol = "y" } },
                                .right = &.{ .span = .{ .{ 0, 8 }, .{ 0, 9 } }, .kind = .{ .int = "5" } },
                            },
                        },
                    },
                },
            },
        },
    };
    try expectEqual(expected, actual);
}

test "parenthesis for grouping" {
    const allocator = std.testing.allocator;
    const source = "x ^ (y ^ 5)";
    var tokens = tokenize(source);
    const actual = try parse(&tokens, allocator);
    defer actual.deinit();
    const expected: []const Expression = &.{
        .{
            .span = .{ .{ 0, 2 }, .{ 0, 3 } },
            .kind = .{
                .binary_op = .{
                    .kind = .pow,
                    .left = &.{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .{ .symbol = "x" } },
                    .right = &.{
                        .span = .{ .{ 0, 4 }, .{ 0, 8 } },
                        .kind = .{
                            .group = .{
                                .expr = &.{
                                    .span = .{ .{ 0, 7 }, .{ 0, 8 } },
                                    .kind = .{
                                        .binary_op = .{
                                            .kind = .pow,
                                            .left = &.{ .span = .{ .{ 0, 5 }, .{ 0, 6 } }, .kind = .{ .symbol = "y" } },
                                            .right = &.{ .span = .{ .{ 0, 9 }, .{ 0, 10 } }, .kind = .{ .int = "5" } },
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    };
    try expectEqual(expected, actual);
}

test "function call" {
    const allocator = std.testing.allocator;
    const source = "min 10 20";
    var tokens = tokenize(source);
    const actual = try parse(&tokens, allocator);
    defer actual.deinit();
    const expected: []const Expression = &.{
        .{
            .span = .{ .{ 0, 0 }, .{ 0, 9 } },
            .kind = .{
                .call = .{
                    .func = &.{ .span = .{ .{ 0, 0 }, .{ 0, 3 } }, .kind = .{ .symbol = "min" } },
                    .args = &.{
                        .{ .span = .{ .{ 0, 4 }, .{ 0, 6 } }, .kind = .{ .int = "10" } },
                        .{ .span = .{ .{ 0, 7 }, .{ 0, 9 } }, .kind = .{ .int = "20" } },
                    },
                },
            },
        },
    };
    try expectEqual(expected, actual);
}

test "single line define" {
    const allocator = std.testing.allocator;
    const source = "x = 5";
    var tokens = tokenize(source);
    const actual = try parse(&tokens, allocator);
    defer actual.deinit();
    const expected: []const Expression = &.{
        .{
            .span = .{ .{ 0, 2 }, .{ 0, 3 } },
            .kind = .{
                .define = .{
                    .name = &.{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .{ .symbol = "x" } },
                    .body = &.{.{ .span = .{ .{ 0, 4 }, .{ 0, 5 } }, .kind = .{ .int = "5" } }},
                },
            },
        },
    };
    try expectEqual(expected, actual);
}

test "multi line define" {
    const allocator = std.testing.allocator;
    const source =
        \\x =
        \\    a = 10
        \\    b = 20
        \\    a + b
    ;
    var tokens = tokenize(source);
    const ast = try parse(&tokens, allocator);
    defer ast.deinit();
    const expected: []const Expression = &.{
        .{
            .span = .{ .{ 0, 2 }, .{ 0, 3 } },
            .kind = .{
                .define = .{
                    .name = &.{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .{ .symbol = "x" } },
                    .body = &.{
                        .{
                            .span = .{ .{ 1, 6 }, .{ 1, 7 } },
                            .kind = .{
                                .define = .{
                                    .name = &.{ .span = .{ .{ 1, 4 }, .{ 1, 5 } }, .kind = .{ .symbol = "a" } },
                                    .body = &.{.{ .span = .{ .{ 1, 8 }, .{ 1, 10 } }, .kind = .{ .int = "10" } }},
                                },
                            },
                        },
                        .{
                            .span = .{ .{ 2, 6 }, .{ 2, 7 } },
                            .kind = .{
                                .define = .{
                                    .name = &.{ .span = .{ .{ 2, 4 }, .{ 2, 5 } }, .kind = .{ .symbol = "b" } },
                                    .body = &.{.{ .span = .{ .{ 2, 8 }, .{ 2, 10 } }, .kind = .{ .int = "20" } }},
                                },
                            },
                        },
                        .{
                            .span = .{ .{ 3, 6 }, .{ 3, 7 } },
                            .kind = .{
                                .binary_op = .{
                                    .kind = .add,
                                    .left = &.{ .span = .{ .{ 3, 4 }, .{ 3, 5 } }, .kind = .{ .symbol = "a" } },
                                    .right = &.{ .span = .{ .{ 3, 8 }, .{ 3, 9 } }, .kind = .{ .symbol = "b" } },
                                },
                            },
                        },
                    },
                },
            },
        },
    };
    try expectEqual(expected, ast);
}

test "single line lambda" {
    const allocator = std.testing.allocator;
    const source =
        \\double = \x -> x * 2
    ;
    var tokens = tokenize(source);
    const actual = try parse(&tokens, allocator);
    defer actual.deinit();
    const expected: []const Expression = &.{
        .{
            .span = .{ .{ 0, 7 }, .{ 0, 8 } },
            .kind = .{
                .define = .{
                    .name = &.{ .span = .{ .{ 0, 0 }, .{ 0, 6 } }, .kind = .{ .symbol = "double" } },
                    .body = &.{
                        .{
                            .span = .{ .{ 0, 9 }, .{ 0, 18 } },
                            .kind = .{
                                .lambda = .{
                                    .params = &.{.{ .span = .{ .{ 0, 10 }, .{ 0, 11 } }, .kind = .{ .symbol = "x" } }},
                                    .body = &.{
                                        .{
                                            .span = .{ .{ 0, 17 }, .{ 0, 18 } },
                                            .kind = .{
                                                .binary_op = .{
                                                    .kind = .mul,
                                                    .left = &.{ .span = .{ .{ 0, 15 }, .{ 0, 16 } }, .kind = .{ .symbol = "x" } },
                                                    .right = &.{ .span = .{ .{ 0, 19 }, .{ 0, 20 } }, .kind = .{ .int = "2" } },
                                                },
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    };
    try expectEqual(expected, actual);
}

test "multi line lambda" {
    const allocator = std.testing.allocator;
    const source =
        \\sumOfSquares = \x y ->
        \\    x2 = x ^ 2
        \\    y2 = y ^ 2
        \\    x2 + y2
    ;
    var tokens = tokenize(source);
    const ast = try parse(&tokens, allocator);
    defer ast.deinit();
    const expected: []const Expression = &.{
        .{
            .span = .{ .{ 0, 13 }, .{ 0, 14 } },
            .kind = .{
                .define = .{
                    .name = &.{ .span = .{ .{ 0, 0 }, .{ 0, 12 } }, .kind = .{ .symbol = "sumOfSquares" } },
                    .body = &.{
                        .{
                            .span = .{ .{ 0, 15 }, .{ 3, 8 } },
                            .kind = .{
                                .lambda = .{
                                    .params = &.{
                                        .{ .span = .{ .{ 0, 16 }, .{ 0, 17 } }, .kind = .{ .symbol = "x" } },
                                        .{ .span = .{ .{ 0, 18 }, .{ 0, 19 } }, .kind = .{ .symbol = "y" } },
                                    },
                                    .body = &.{
                                        .{
                                            .span = .{ .{ 1, 7 }, .{ 1, 8 } },
                                            .kind = .{
                                                .define = .{
                                                    .name = &.{ .span = .{ .{ 1, 4 }, .{ 1, 6 } }, .kind = .{ .symbol = "x2" } },
                                                    .body = &.{
                                                        .{
                                                            .span = .{ .{ 1, 11 }, .{ 1, 12 } },
                                                            .kind = .{
                                                                .binary_op = .{
                                                                    .kind = .pow,
                                                                    .left = &.{ .span = .{ .{ 1, 9 }, .{ 1, 10 } }, .kind = .{ .symbol = "x" } },
                                                                    .right = &.{ .span = .{ .{ 1, 13 }, .{ 1, 14 } }, .kind = .{ .int = "2" } },
                                                                },
                                                            },
                                                        },
                                                    },
                                                },
                                            },
                                        },
                                        .{
                                            .span = .{ .{ 2, 7 }, .{ 2, 8 } },
                                            .kind = .{
                                                .define = .{
                                                    .name = &.{ .span = .{ .{ 2, 4 }, .{ 2, 6 } }, .kind = .{ .symbol = "y2" } },
                                                    .body = &.{
                                                        .{
                                                            .span = .{ .{ 2, 11 }, .{ 2, 12 } },
                                                            .kind = .{
                                                                .binary_op = .{
                                                                    .kind = .pow,
                                                                    .left = &.{ .span = .{ .{ 2, 9 }, .{ 2, 10 } }, .kind = .{ .symbol = "y" } },
                                                                    .right = &.{ .span = .{ .{ 2, 13 }, .{ 2, 14 } }, .kind = .{ .int = "2" } },
                                                                },
                                                            },
                                                        },
                                                    },
                                                },
                                            },
                                        },
                                        .{
                                            .span = .{ .{ 3, 7 }, .{ 3, 8 } },
                                            .kind = .{
                                                .binary_op = .{
                                                    .kind = .add,
                                                    .left = &.{ .span = .{ .{ 3, 4 }, .{ 3, 6 } }, .kind = .{ .symbol = "x2" } },
                                                    .right = &.{ .span = .{ .{ 3, 9 }, .{ 3, 11 } }, .kind = .{ .symbol = "y2" } },
                                                },
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    };
    try expectEqual(expected, ast);
}

test "function annotation" {
    const allocator = std.testing.allocator;
    const source =
        \\add : I32 -> I32 -> I32
        \\add = \x y -> x + y
    ;
    var tokens = tokenize(source);
    const ast = try parse(&tokens, allocator);
    defer ast.deinit();
    const expected: []const Expression = &.{
        .{
            .span = .{ .{ 0, 4 }, .{ 0, 5 } },
            .kind = .{
                .annotate = .{
                    .name = &.{ .span = .{ .{ 0, 0 }, .{ 0, 3 } }, .kind = .{ .symbol = "add" } },
                    .type = &.{
                        .span = .{ .{ 0, 10 }, .{ 0, 12 } },
                        .kind = .{
                            .binary_op = .{
                                .kind = .arrow,
                                .left = &.{ .span = .{ .{ 0, 6 }, .{ 0, 9 } }, .kind = .{ .symbol = "I32" } },
                                .right = &.{
                                    .span = .{ .{ 0, 17 }, .{ 0, 19 } },
                                    .kind = .{
                                        .binary_op = .{
                                            .kind = .arrow,
                                            .left = &.{ .span = .{ .{ 0, 13 }, .{ 0, 16 } }, .kind = .{ .symbol = "I32" } },
                                            .right = &.{ .span = .{ .{ 0, 20 }, .{ 0, 23 } }, .kind = .{ .symbol = "I32" } },
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
        .{
            .span = .{ .{ 1, 4 }, .{ 1, 5 } },
            .kind = .{
                .define = .{
                    .name = &.{ .span = .{ .{ 1, 0 }, .{ 1, 3 } }, .kind = .{ .symbol = "add" } },
                    .body = &.{
                        .{
                            .span = .{ .{ 1, 6 }, .{ 1, 17 } },
                            .kind = .{
                                .lambda = .{
                                    .params = &.{
                                        .{ .span = .{ .{ 1, 7 }, .{ 1, 8 } }, .kind = .{ .symbol = "x" } },
                                        .{ .span = .{ .{ 1, 9 }, .{ 1, 10 } }, .kind = .{ .symbol = "y" } },
                                    },
                                    .body = &.{
                                        .{
                                            .span = .{ .{ 1, 16 }, .{ 1, 17 } },
                                            .kind = .{
                                                .binary_op = .{
                                                    .kind = .add,
                                                    .left = &.{ .span = .{ .{ 1, 14 }, .{ 1, 15 } }, .kind = .{ .symbol = "x" } },
                                                    .right = &.{ .span = .{ .{ 1, 18 }, .{ 1, 19 } }, .kind = .{ .symbol = "y" } },
                                                },
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    };
    try expectEqual(expected, ast);
}

test "for expression" {
    const allocator = std.testing.allocator;
    const source =
        \\transpose = \x ->
        \\    for i j ->
        \\        x.j.i
    ;
    var tokens = tokenize(source);
    const ast = try parse(&tokens, allocator);
    defer ast.deinit();
    const expected: []const Expression = &.{
        .{
            .span = .{ .{ 0, 10 }, .{ 0, 11 } },
            .kind = .{
                .define = .{
                    .name = &.{ .span = .{ .{ 0, 0 }, .{ 0, 9 } }, .kind = .{ .symbol = "transpose" } },
                    .body = &.{
                        .{
                            .span = .{ .{ 0, 12 }, .{ 2, 12 } },
                            .kind = .{
                                .lambda = .{
                                    .params = &.{.{ .span = .{ .{ 0, 13 }, .{ 0, 14 } }, .kind = .{ .symbol = "x" } }},
                                    .body = &.{
                                        .{
                                            .span = .{ .{ 1, 4 }, .{ 2, 12 } },
                                            .kind = .{
                                                .for_ = .{
                                                    .indices = &.{
                                                        .{ .span = .{ .{ 1, 8 }, .{ 1, 9 } }, .kind = .{ .symbol = "i" } },
                                                        .{ .span = .{ .{ 1, 10 }, .{ 1, 11 } }, .kind = .{ .symbol = "j" } },
                                                    },
                                                    .body = &.{
                                                        .{
                                                            .span = .{ .{ 2, 11 }, .{ 2, 12 } },
                                                            .kind = .{
                                                                .binary_op = .{
                                                                    .kind = .dot,
                                                                    .left = &.{
                                                                        .span = .{ .{ 2, 9 }, .{ 2, 10 } },
                                                                        .kind = .{
                                                                            .binary_op = .{
                                                                                .kind = .dot,
                                                                                .left = &.{
                                                                                    .span = .{ .{ 2, 8 }, .{ 2, 9 } },
                                                                                    .kind = .{ .symbol = "x" },
                                                                                },
                                                                                .right = &.{
                                                                                    .span = .{ .{ 2, 10 }, .{ 2, 11 } },
                                                                                    .kind = .{ .symbol = "j" },
                                                                                },
                                                                            },
                                                                        },
                                                                    },
                                                                    .right = &.{
                                                                        .span = .{ .{ 2, 12 }, .{ 2, 13 } },
                                                                        .kind = .{ .symbol = "i" },
                                                                    },
                                                                },
                                                            },
                                                        },
                                                    },
                                                },
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    };
    try expectEqual(expected, ast);
}

test "if expression" {
    const allocator = std.testing.allocator;
    const source =
        \\if x > y then "bigger" else "smaller"
    ;
    var tokens = tokenize(source);
    const actual = try parse(&tokens, allocator);
    defer actual.deinit();
    const expected: []const Expression = &.{
        .{
            .span = .{ .{ 0, 0 }, .{ 0, 37 } },
            .kind = .{
                .if_ = .{
                    .condition = &.{
                        .span = .{ .{ 0, 5 }, .{ 0, 6 } },
                        .kind = .{
                            .binary_op = .{
                                .kind = .greater,
                                .left = &.{ .span = .{ .{ 0, 3 }, .{ 0, 4 } }, .kind = .{ .symbol = "x" } },
                                .right = &.{ .span = .{ .{ 0, 7 }, .{ 0, 8 } }, .kind = .{ .symbol = "y" } },
                            },
                        },
                    },
                    .then = &.{
                        .{ .span = .{ .{ 0, 14 }, .{ 0, 22 } }, .kind = .{ .string = "\"bigger\"" } },
                    },
                    .else_ = &.{
                        .{ .span = .{ .{ 0, 28 }, .{ 0, 37 } }, .kind = .{ .string = "\"smaller\"" } },
                    },
                },
            },
        },
    };
    try expectEqual(expected, actual);
}
