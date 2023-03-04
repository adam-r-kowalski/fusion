const std = @import("std");
const fusion = @import("fusion");
const tokenize = fusion.tokenizer.tokenize;
const parse = fusion.parser.parse;
const Expression = fusion.parser.Expression;
const Ast = fusion.parser.Ast;
const BinaryOp = fusion.parser.BinaryOp;
const BinaryOpKind = fusion.parser.BinaryOpKind;
const Func = fusion.parser.Func;
const Call = fusion.parser.Call;
const Define = fusion.parser.Define;
const Span = fusion.parser.Span;
const Lambda = fusion.parser.Lambda;

fn expectEqualExpressions(expected: []const Expression, actual: []const Expression) !void {
    var actualString = std.ArrayList(u8).init(std.testing.allocator);
    defer actualString.deinit();
    try writeExpressions(actualString.writer(), actual);
    var expectedString = std.ArrayList(u8).init(std.testing.allocator);
    defer expectedString.deinit();
    try writeExpressions(expectedString.writer(), expected);
    try std.testing.expectEqualStrings(expectedString.items, actualString.items);
}

fn writeIndent(writer: anytype, indent: usize) !void {
    try writer.writeAll("\n");
    var i: usize = 0;
    while (i < indent) : (i += 1) {
        try writer.writeAll("    ");
    }
}

fn writeSpan(writer: anytype, span: Span) !void {
    const fmt = ".span = .{{ .{{ {}, {} }}, .{{ {}, {} }} }},";
    try std.fmt.format(writer, fmt, .{
        span[0][0],
        span[0][1],
        span[1][0],
        span[1][1],
    });
}

fn opName(kind: BinaryOpKind) []const u8 {
    return switch (kind) {
        .add => ".add",
        .mul => ".mul",
        .define => ".define",
    };
}

fn writeBinaryOp(writer: anytype, op: BinaryOp, indent: usize) !void {
    try writeIndent(writer, indent + 2);
    try writer.writeAll(".binary_op = .{");
    try writeIndent(writer, indent + 3);
    try std.fmt.format(writer, ".kind = {s},", .{opName(op.kind)});
    try writeIndent(writer, indent + 3);
    try writer.writeAll(".left = &");
    try writeExpression(writer, op.left.*, indent + 3, false);
    try writeIndent(writer, indent + 3);
    try writer.writeAll(".right = &");
    try writeExpression(writer, op.right.*, indent + 3, false);
    try writeIndent(writer, indent + 2);
    try writer.writeAll("},");
    try writeIndent(writer, indent + 1);
    try writer.writeAll("},");
}

fn writeCall(writer: anytype, call: Call, indent: usize) !void {
    try writeIndent(writer, indent + 2);
    try writer.writeAll(".call = .{");
    try writeIndent(writer, indent + 3);
    try writer.writeAll(".func = &");
    try writeExpression(writer, call.func.*, indent + 3, false);
    try writeIndent(writer, indent + 3);
    try writer.writeAll(".args = &.{");
    for (call.args) |arg| {
        try writeExpression(writer, arg, indent + 4, true);
    }
    try writeIndent(writer, indent + 3);
    try writer.writeAll("},");
    try writeIndent(writer, indent + 2);
    try writer.writeAll("},");
    try writeIndent(writer, indent + 1);
    try writer.writeAll("},");
}

fn writeLambda(writer: anytype, lambda: Lambda, indent: usize) !void {
    try writeIndent(writer, indent + 2);
    try writer.writeAll(".lambda = .{");
    try writeIndent(writer, indent + 3);
    try writer.writeAll(".params = &.{");
    for (lambda.params) |arg| {
        try writeExpression(writer, arg, indent + 4, true);
    }
    try writeIndent(writer, indent + 3);
    try writer.writeAll("},");
    try writer.writeAll(".body = &.{");
    for (lambda.body) |expr| {
        try writeExpression(writer, expr, indent + 4, true);
    }
    try writeIndent(writer, indent + 3);
    try writer.writeAll("},");
    try writeIndent(writer, indent + 2);
    try writer.writeAll("},");
    try writeIndent(writer, indent + 1);
    try writer.writeAll("},");
}

fn writeExpression(writer: anytype, expression: Expression, indent: usize, newline: bool) error{OutOfMemory}!void {
    if (newline) try writeIndent(writer, indent);
    try writer.writeAll(".{");
    try writeIndent(writer, indent + 1);
    try writeSpan(writer, expression.span);
    try writeIndent(writer, indent + 1);
    try writer.writeAll(".kind = .{ ");
    switch (expression.kind) {
        .symbol => |s| try std.fmt.format(writer, ".symbol = \"{s}\" }},", .{s}),
        .int => |s| try std.fmt.format(writer, ".int = \"{s}\" }},", .{s}),
        .binary_op => |op| try writeBinaryOp(writer, op, indent),
        .call => |call| try writeCall(writer, call, indent),
        .lambda => |lambda| try writeLambda(writer, lambda, indent),
    }
    try writeIndent(writer, indent);
    try writer.writeAll("},");
}

fn writeExpressions(writer: anytype, expressions: []const Expression) !void {
    for (expressions) |expr| {
        try writeExpression(writer, expr, 0, true);
    }
}

fn printAst(ast: Ast) !void {
    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();
    const writer = list.writer();
    try writeExpressions(writer, ast.expressions);
    std.debug.print("{s}", .{list.items});
}

test "symbol" {
    const allocator = std.testing.allocator;
    const source = "x";
    var tokens = tokenize(source);
    const ast = try parse(&tokens, allocator);
    defer ast.deinit();
    const expected: []const Expression = &.{
        .{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .{ .symbol = "x" } },
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
        .{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .{ .int = "5" } },
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
    try expectEqualExpressions(expected, ast.expressions);
}

test "operator precedence lower first" {
    const allocator = std.testing.allocator;
    const source = "x + y * 5";
    var tokens = tokenize(source);
    const ast = try parse(&tokens, allocator);
    defer ast.deinit();
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
    try expectEqualExpressions(expected, ast.expressions);
}

test "operator precedence higher first" {
    const allocator = std.testing.allocator;
    const source = "x * y + 5";
    var tokens = tokenize(source);
    const ast = try parse(&tokens, allocator);
    defer ast.deinit();
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
    try expectEqualExpressions(expected, ast.expressions);
}

test "function call" {
    const allocator = std.testing.allocator;
    const source = "min 10 20";
    var tokens = tokenize(source);
    const ast = try parse(&tokens, allocator);
    defer ast.deinit();
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
    try expectEqualExpressions(expected, ast.expressions);
}

test "define" {
    const allocator = std.testing.allocator;
    const source = "x = 5";
    var tokens = tokenize(source);
    const ast = try parse(&tokens, allocator);
    defer ast.deinit();
    const expected: []const Expression = &.{
        .{
            .span = .{ .{ 0, 2 }, .{ 0, 3 } },
            .kind = .{
                .binary_op = .{
                    .kind = .define,
                    .left = &.{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .{ .symbol = "x" } },
                    .right = &.{ .span = .{ .{ 0, 4 }, .{ 0, 5 } }, .kind = .{ .int = "5" } },
                },
            },
        },
    };
    try expectEqualExpressions(expected, ast.expressions);
}

test "single line function definition" {
    const allocator = std.testing.allocator;
    const source =
        \\double = \x -> x * 2
    ;
    var tokens = tokenize(source);
    const ast = try parse(&tokens, allocator);
    defer ast.deinit();
    const expected: []const Expression = &.{
        .{
            .span = .{ .{ 0, 7 }, .{ 0, 8 } },
            .kind = .{
                .binary_op = .{
                    .kind = .define,
                    .left = &.{ .span = .{ .{ 0, 0 }, .{ 0, 6 } }, .kind = .{ .symbol = "double" } },
                    .right = &.{
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
    };
    try expectEqualExpressions(expected, ast.expressions);
}

// test "multi line function definition" {
//     const allocator = std.testing.allocator;
//     const source =
//         \\main = () {
//         \\    x = 5
//         \\    y = 10
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
//                                 .body = &.{
//                                     .{
//                                         .span = .{ .begin = .{ .line = 1, .col = 6 }, .end = .{ .line = 1, .col = 7 } },
//                                         .kind = .{
//                                             .binary_op = .{
//                                                 .kind = .assign,
//                                                 .left = &.{
//                                                     .span = .{ .begin = .{ .line = 1, .col = 4 }, .end = .{ .line = 1, .col = 5 } },
//                                                     .kind = .{ .symbol = "x" },
//                                                 },
//                                                 .right = &.{
//                                                     .span = .{ .begin = .{ .line = 1, .col = 8 }, .end = .{ .line = 1, .col = 9 } },
//                                                     .kind = .{ .int = "5" },
//                                                 },
//                                             },
//                                         },
//                                     },
//                                     .{
//                                         .span = .{ .begin = .{ .line = 2, .col = 6 }, .end = .{ .line = 2, .col = 7 } },
//                                         .kind = .{
//                                             .binary_op = .{
//                                                 .kind = .assign,
//                                                 .left = &.{
//                                                     .span = .{ .begin = .{ .line = 2, .col = 4 }, .end = .{ .line = 2, .col = 5 } },
//                                                     .kind = .{ .symbol = "y" },
//                                                 },
//                                                 .right = &.{
//                                                     .span = .{ .begin = .{ .line = 2, .col = 8 }, .end = .{ .line = 2, .col = 10 } },
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
//
// test "function definition with parameters" {
//     const allocator = std.testing.allocator;
//     const source =
//         \\add = (x, y) {
//         \\    x + y
//         \\}
//     ;
//     var tokens = tokenize(source);
//     const ast = try parse(&tokens, allocator);
//     defer ast.deinit();
//     const expected: []const Expression = &.{
//         .{
//             .span = .{ .begin = .{ .line = 0, .col = 4 }, .end = .{ .line = 0, .col = 5 } },
//             .kind = .{
//                 .binary_op = .{
//                     .kind = .assign,
//                     .left = &.{
//                         .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 3 } },
//                         .kind = .{ .symbol = "add" },
//                     },
//                     .right = &.{
//                         .span = .{ .begin = .{ .line = 0, .col = 6 }, .end = .{ .line = 2, .col = 1 } },
//                         .kind = .{
//                             .func = .{
//                                 .params = &.{ .{ .name = "x" }, .{ .name = "y" } },
//                                 .body = &.{
//                                     .{
//                                         .span = .{ .begin = .{ .line = 1, .col = 6 }, .end = .{ .line = 1, .col = 7 } },
//                                         .kind = .{
//                                             .binary_op = .{
//                                                 .kind = .add,
//                                                 .left = &.{
//                                                     .span = .{ .begin = .{ .line = 1, .col = 4 }, .end = .{ .line = 1, .col = 5 } },
//                                                     .kind = .{ .symbol = "x" },
//                                                 },
//                                                 .right = &.{
//                                                     .span = .{ .begin = .{ .line = 1, .col = 8 }, .end = .{ .line = 1, .col = 9 } },
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
//
// test "typed function definition" {
//     const allocator = std.testing.allocator;
//     const source =
//         \\add = (x: i32, y: i32) -> i32 {
//         \\    x + y
//         \\}
//     ;
//     var tokens = tokenize(source);
//     const ast = try parse(&tokens, allocator);
//     defer ast.deinit();
//     const expected: []const Expression = &.{
//         .{
//             .span = .{ .begin = .{ .line = 0, .col = 4 }, .end = .{ .line = 0, .col = 5 } },
//             .kind = .{
//                 .binary_op = .{
//                     .kind = .assign,
//                     .left = &.{
//                         .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 3 } },
//                         .kind = .{ .symbol = "add" },
//                     },
//                     .right = &.{
//                         .span = .{ .begin = .{ .line = 0, .col = 6 }, .end = .{ .line = 2, .col = 1 } },
//                         .kind = .{
//                             .func = .{
//                                 .params = &.{
//                                     .{
//                                         .name = "x",
//                                         .type = .{
//                                             .span = .{ .begin = .{ .line = 0, .col = 10 }, .end = .{ .line = 0, .col = 13 } },
//                                             .kind = .{ .symbol = "i32" },
//                                         },
//                                     },
//                                     .{
//                                         .name = "y",
//                                         .type = .{
//                                             .span = .{ .begin = .{ .line = 0, .col = 18 }, .end = .{ .line = 0, .col = 21 } },
//                                             .kind = .{ .symbol = "i32" },
//                                         },
//                                     },
//                                 },
//                                 .return_type = &.{
//                                     .span = .{ .begin = .{ .line = 0, .col = 26 }, .end = .{ .line = 0, .col = 29 } },
//                                     .kind = .{ .symbol = "i32" },
//                                 },
//                                 .body = &.{
//                                     .{
//                                         .span = .{ .begin = .{ .line = 1, .col = 6 }, .end = .{ .line = 1, .col = 7 } },
//                                         .kind = .{
//                                             .binary_op = .{
//                                                 .kind = .add,
//                                                 .left = &.{
//                                                     .span = .{ .begin = .{ .line = 1, .col = 4 }, .end = .{ .line = 1, .col = 5 } },
//                                                     .kind = .{ .symbol = "x" },
//                                                 },
//                                                 .right = &.{
//                                                     .span = .{ .begin = .{ .line = 1, .col = 8 }, .end = .{ .line = 1, .col = 9 } },
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
//
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
