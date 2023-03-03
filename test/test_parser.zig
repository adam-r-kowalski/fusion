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
        .assign => ".assign",
    };
}

fn writeBinaryOp(writer: anytype, op: BinaryOp, indent: usize) !void {
    try writeIndent(writer, indent + 2);
    try writer.writeAll(".binary_op = .{");
    try writeIndent(writer, indent + 3);
    try std.fmt.format(writer, ".kind = {s},", .{opName(op.kind)});
    try writeIndent(writer, indent + 3);
    try writer.writeAll(".lhs = &");
    try writeExpression(writer, op.lhs.*, indent + 3, false);
    try writeIndent(writer, indent + 3);
    try writer.writeAll(".rhs = &");
    try writeExpression(writer, op.rhs.*, indent + 3, false);
    try writeIndent(writer, indent + 2);
    try writer.writeAll("},");
    try writeIndent(writer, indent + 1);
    try writer.writeAll("},");
}

fn writeFunc(writer: anytype, func: Func, indent: usize) !void {
    try writeIndent(writer, indent + 2);
    try writer.writeAll(".func = .{");
    try writeIndent(writer, indent + 3);
    try writer.writeAll(".params = &.{");
    for (func.params) |param| {
        try writeIndent(writer, indent + 4);
        try writer.writeAll(".param = .{");
        try writeIndent(writer, indent + 5);
        try std.fmt.format(writer, ".name = \"{s}\",", .{param.name});
        if (param.type) |type_| {
            try writeIndent(writer, indent + 5);
            try writer.writeAll(".type = &");
            try writeExpression(writer, type_, indent + 5, false);
            try writeIndent(writer, indent + 4);
            try writer.writeAll("},");
        }
    }
    if (func.params.len > 0) try writeIndent(writer, indent + 3);
    try writer.writeAll("},");
    if (func.return_type) |return_type| {
        try writeIndent(writer, indent + 3);
        try writer.writeAll(".return_type = &");
        try writeExpression(writer, return_type.*, indent + 3, false);
    }
    try writeIndent(writer, indent + 3);
    try writer.writeAll(".body = &.{");
    for (func.body) |expr| {
        try writeExpression(writer, expr, indent + 4, true);
    }
    if (func.body.len > 0) try writeIndent(writer, indent + 3);
    try writer.writeAll("},");
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
    try writer.writeAll(".args = &{");
    for (call.args) |expr| {
        try writeExpression(writer, expr, indent + 4, true);
    }
    if (call.args.len > 0) try writeIndent(writer, indent + 3);
    try writer.writeAll("},");
    try writeIndent(writer, indent + 2);
    try writer.writeAll("},");
    try writeIndent(writer, indent + 1);
    try writer.writeAll("},");
}

fn writeDefine(writer: anytype, define: Define, indent: usize) !void {
    try writeIndent(writer, indent + 2);
    try writer.writeAll(".define = .{");
    try writeIndent(writer, indent + 3);
    try writer.writeAll(".name = &");
    try writeExpression(writer, define.name.*, indent + 3, false);
    if (define.type) |type_| {
        try writeIndent(writer, indent + 3);
        try writer.writeAll(".type = &");
        try writeExpression(writer, type_.*, indent + 3, false);
    }
    try writeIndent(writer, indent + 3);
    try writer.writeAll(".value = &");
    try writeExpression(writer, define.value.*, indent + 3, false);
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
        .func => |f| try writeFunc(writer, f, indent),
        .call => |c| try writeCall(writer, c, indent),
        .define => |d| try writeDefine(writer, d, indent),
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
    const writer = std.io.getStdOut().writer();
    try writeExpressions(writer, ast.expressions);
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
                    .lhs = &.{ .span = .{ .{ 0, 0 }, .{ 0, 1 } }, .kind = .{ .symbol = "x" } },
                    .rhs = &.{ .span = .{ .{ 0, 4 }, .{ 0, 5 } }, .kind = .{ .symbol = "y" } },
                },
            },
        },
    };
    try expectEqualExpressions(expected, ast.expressions);
}

// test "operator precedence lower first" {
//     const allocator = std.testing.allocator;
//     const source = "x + y * 5";
//     var tokens = tokenize(source);
//     const ast = try parse(&tokens, allocator);
//     defer ast.deinit();
//     const expected: []const Expression = &.{
//         .{
//             .span = .{ .begin = .{ .line = 0, .col = 2 }, .end = .{ .line = 0, .col = 3 } },
//             .kind = .{
//                 .binary_op = .{
//                     .kind = .add,
//                     .lhs = &.{
//                         .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 1 } },
//                         .kind = .{ .symbol = "x" },
//                     },
//                     .rhs = &.{
//                         .span = .{ .begin = .{ .line = 0, .col = 6 }, .end = .{ .line = 0, .col = 7 } },
//                         .kind = .{
//                             .binary_op = .{
//                                 .kind = .mul,
//                                 .lhs = &.{
//                                     .span = .{ .begin = .{ .line = 0, .col = 4 }, .end = .{ .line = 0, .col = 5 } },
//                                     .kind = .{ .symbol = "y" },
//                                 },
//                                 .rhs = &.{
//                                     .span = .{ .begin = .{ .line = 0, .col = 8 }, .end = .{ .line = 0, .col = 9 } },
//                                     .kind = .{ .int = "5" },
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
// test "operator precedence higher first" {
//     const allocator = std.testing.allocator;
//     const source = "x * y + 5";
//     var tokens = tokenize(source);
//     const ast = try parse(&tokens, allocator);
//     defer ast.deinit();
//     const expected: []const Expression = &.{
//         .{
//             .span = .{ .begin = .{ .line = 0, .col = 6 }, .end = .{ .line = 0, .col = 7 } },
//             .kind = .{
//                 .binary_op = .{
//                     .kind = .add,
//                     .lhs = &.{
//                         .span = .{ .begin = .{ .line = 0, .col = 2 }, .end = .{ .line = 0, .col = 3 } },
//                         .kind = .{
//                             .binary_op = .{
//                                 .kind = .mul,
//                                 .lhs = &.{
//                                     .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 1 } },
//                                     .kind = .{ .symbol = "x" },
//                                 },
//                                 .rhs = &.{
//                                     .span = .{ .begin = .{ .line = 0, .col = 4 }, .end = .{ .line = 0, .col = 5 } },
//                                     .kind = .{ .symbol = "y" },
//                                 },
//                             },
//                         },
//                     },
//                     .rhs = &.{
//                         .span = .{ .begin = .{ .line = 0, .col = 8 }, .end = .{ .line = 0, .col = 9 } },
//                         .kind = .{ .int = "5" },
//                     },
//                 },
//             },
//         },
//     };
//     try expectEqualExpressions(expected, ast.expressions);
// }
//
// test "function call" {
//     const allocator = std.testing.allocator;
//     const source = "min(10, 20)";
//     var tokens = tokenize(source);
//     const ast = try parse(&tokens, allocator);
//     defer ast.deinit();
//     const expected: []const Expression = &.{
//         .{
//             .span = .{ .begin = .{ .line = 0, .col = 3 }, .end = .{ .line = 0, .col = 11 } },
//             .kind = .{
//                 .call = .{
//                     .func = &.{
//                         .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 3 } },
//                         .kind = .{ .symbol = "min" },
//                     },
//                     .args = &.{
//                         .{
//                             .span = .{ .begin = .{ .line = 0, .col = 4 }, .end = .{ .line = 0, .col = 6 } },
//                             .kind = .{ .int = "10" },
//                         },
//                         .{
//                             .span = .{ .begin = .{ .line = 0, .col = 8 }, .end = .{ .line = 0, .col = 10 } },
//                             .kind = .{ .int = "20" },
//                         },
//                     },
//                 },
//             },
//         },
//     };
//     try expectEqualExpressions(expected, ast.expressions);
// }
//
// test "variable declaration" {
//     const allocator = std.testing.allocator;
//     const source = "x = 5";
//     var tokens = tokenize(source);
//     const ast = try parse(&tokens, allocator);
//     defer ast.deinit();
//     const expected: []const Expression = &.{
//         .{
//             .span = .{ .begin = .{ .line = 0, .col = 2 }, .end = .{ .line = 0, .col = 3 } },
//             .kind = .{
//                 .binary_op = .{
//                     .kind = .assign,
//                     .lhs = &.{
//                         .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 1 } },
//                         .kind = .{ .symbol = "x" },
//                     },
//                     .rhs = &.{
//                         .span = .{ .begin = .{ .line = 0, .col = 4 }, .end = .{ .line = 0, .col = 5 } },
//                         .kind = .{ .int = "5" },
//                     },
//                 },
//             },
//         },
//     };
//     try expectEqualExpressions(expected, ast.expressions);
// }
//
// test "single line function definition" {
//     const allocator = std.testing.allocator;
//     const source = "main = () { 42 }";
//     var tokens = tokenize(source);
//     const ast = try parse(&tokens, allocator);
//     defer ast.deinit();
//     const expected: []const Expression = &.{
//         .{
//             .span = .{ .begin = .{ .line = 0, .col = 5 }, .end = .{ .line = 0, .col = 6 } },
//             .kind = .{
//                 .binary_op = .{
//                     .kind = .assign,
//                     .lhs = &.{
//                         .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 4 } },
//                         .kind = .{ .symbol = "main" },
//                     },
//                     .rhs = &.{
//                         .span = .{ .begin = .{ .line = 0, .col = 7 }, .end = .{ .line = 0, .col = 16 } },
//                         .kind = .{
//                             .func = .{
//                                 .params = &.{},
//                                 .body = &.{
//                                     .{
//                                         .span = .{ .begin = .{ .line = 0, .col = 12 }, .end = .{ .line = 0, .col = 14 } },
//                                         .kind = .{ .int = "42" },
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
//                     .lhs = &.{
//                         .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 4 } },
//                         .kind = .{ .symbol = "main" },
//                     },
//                     .rhs = &.{
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
//                                                 .lhs = &.{
//                                                     .span = .{ .begin = .{ .line = 1, .col = 4 }, .end = .{ .line = 1, .col = 5 } },
//                                                     .kind = .{ .symbol = "x" },
//                                                 },
//                                                 .rhs = &.{
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
//                                                 .lhs = &.{
//                                                     .span = .{ .begin = .{ .line = 2, .col = 4 }, .end = .{ .line = 2, .col = 5 } },
//                                                     .kind = .{ .symbol = "y" },
//                                                 },
//                                                 .rhs = &.{
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
//                                                 .lhs = &.{
//                                                     .span = .{ .begin = .{ .line = 3, .col = 4 }, .end = .{ .line = 3, .col = 5 } },
//                                                     .kind = .{ .symbol = "x" },
//                                                 },
//                                                 .rhs = &.{
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
//                     .lhs = &.{
//                         .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 3 } },
//                         .kind = .{ .symbol = "add" },
//                     },
//                     .rhs = &.{
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
//                                                 .lhs = &.{
//                                                     .span = .{ .begin = .{ .line = 1, .col = 4 }, .end = .{ .line = 1, .col = 5 } },
//                                                     .kind = .{ .symbol = "x" },
//                                                 },
//                                                 .rhs = &.{
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
//                     .lhs = &.{
//                         .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 3 } },
//                         .kind = .{ .symbol = "add" },
//                     },
//                     .rhs = &.{
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
//                                                 .lhs = &.{
//                                                     .span = .{ .begin = .{ .line = 1, .col = 4 }, .end = .{ .line = 1, .col = 5 } },
//                                                     .kind = .{ .symbol = "x" },
//                                                 },
//                                                 .rhs = &.{
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
//                     .lhs = &.{
//                         .span = .{ .begin = .{ .line = 0, .col = 0 }, .end = .{ .line = 0, .col = 4 } },
//                         .kind = .{ .symbol = "main" },
//                     },
//                     .rhs = &.{
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
//                                                 .lhs = &.{
//                                                     .span = .{ .begin = .{ .line = 3, .col = 4 }, .end = .{ .line = 3, .col = 5 } },
//                                                     .kind = .{ .symbol = "x" },
//                                                 },
//                                                 .rhs = &.{
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
