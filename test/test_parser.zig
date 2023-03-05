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

test "define" {
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

test "single line function definition" {
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

test "multi line function definition" {
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

test "typed function definition" {
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

// test "typed variable declaration" {
//     const allocator = std.testing.allocator;
//     const source =
//         \\main = () -> i32 {
//         \\    x: i32 = 5
//         \\    y: i32 = 10
//         \\    x + y
//         \\}
//     ;
//     var tokens = tokenize(source);
//     const ast = try parse(&tokens, allocator);
//     defer ast.deinit();
//     const expected: []const Expression = &.{
//         .{
//             .span = .{ .begin = .{ .line = 0, .col = 5 }, .end = .{ .line = 0, .col = 6 } },
//             .kind = .{
//                 .binary_op = .{
//                     .kind = .assign,
//                     .left = &.{
//                         .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 4 } },
//                         .kind = .{ .symbol = "main" },
//                     },
//                     .right = &.{
//                         .span = .{ .begin = .{ .line = 0, .col = 7 }, .end = .{ .line = 4, .col = 1 } },
//                         .kind = .{
//                             .func = .{
//                                 .params = &.{},
//                                 .return_type = &.{
//                                     .span = .{ .begin = .{ .line = 0, .col = 13 }, .end = .{ .line = 0, .col = 16 } },
//                                     .kind = .{ .symbol = "i32" },
//                                 },
//                                 .body = &.{
//                                     .{
//                                         .span = .{ .begin = .{ .line = 1, .col = 4 }, .end = .{ .line = 1, .col = 14 } },
//                                         .kind = .{
//                                             .define = .{
//                                                 .name = &.{
//                                                     .span = .{ .begin = .{ .line = 1, .col = 4 }, .end = .{ .line = 1, .col = 5 } },
//                                                     .kind = .{ .symbol = "x" },
//                                                 },
//                                                 .type = &.{
//                                                     .span = .{ .begin = .{ .line = 1, .col = 7 }, .end = .{ .line = 1, .col = 10 } },
//                                                     .kind = .{ .symbol = "i32" },
//                                                 },
//                                                 .value = &.{
//                                                     .span = .{ .begin = .{ .line = 1, .col = 13 }, .end = .{ .line = 1, .col = 14 } },
//                                                     .kind = .{ .int = "5" },
//                                                 },
//                                             },
//                                         },
//                                     },
//                                     .{
//                                         .span = .{ .begin = .{ .line = 2, .col = 4 }, .end = .{ .line = 2, .col = 15 } },
//                                         .kind = .{
//                                             .define = .{
//                                                 .name = &.{
//                                                     .span = .{ .begin = .{ .line = 2, .col = 4 }, .end = .{ .line = 2, .col = 5 } },
//                                                     .kind = .{ .symbol = "y" },
//                                                 },
//                                                 .type = &.{
//                                                     .span = .{ .begin = .{ .line = 2, .col = 7 }, .end = .{ .line = 2, .col = 10 } },
//                                                     .kind = .{ .symbol = "i32" },
//                                                 },
//                                                 .value = &.{
//                                                     .span = .{ .begin = .{ .line = 2, .col = 13 }, .end = .{ .line = 2, .col = 15 } },
//                                                     .kind = .{ .int = "10" },
//                                                 },
//                                             },
//                                         },
//                                     },
//                                     .{
//                                         .span = .{ .begin = .{ .line = 3, .col = 6 }, .end = .{ .line = 3, .col = 7 } },
//                                         .kind = .{
//                                             .binary_op = .{
//                                                 .kind = .add,
//                                                 .left = &.{
//                                                     .span = .{ .begin = .{ .line = 3, .col = 4 }, .end = .{ .line = 3, .col = 5 } },
//                                                     .kind = .{ .symbol = "x" },
//                                                 },
//                                                 .right = &.{
//                                                     .span = .{ .begin = .{ .line = 3, .col = 8 }, .end = .{ .line = 3, .col = 9 } },
//                                                     .kind = .{ .symbol = "y" },
//                                                 },
//                                             },
//                                         },
//                                     },
//                                 },
//                             },
//                         },
//                     },
//                 },
//             },
//         },
//     };
//     try expectEqualExpressions(expected, ast.expressions);
// }
