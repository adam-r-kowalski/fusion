const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;

const tokenizer = @import("./tokenizer.zig");
const Tokens = tokenizer.Tokens;
const Token = tokenizer.Token;
const Position = tokenizer.Position;
const TokenKind = tokenizer.Kind;
pub const Span = tokenizer.Span;
const ast = @import("./types/ast.zig");
const Ast = ast.Ast;
const Expression = ast.Expression;
const BinaryOpKind = ast.BinaryOpKind;

pub fn parse(tokens: *Tokens, allocator: Allocator) !Ast {
    var arena = Arena.init(allocator);
    var expressions = std.ArrayList(Expression).init(arena.allocator());
    const expr = try expression(arena.allocator(), tokens, 0);
    try expressions.append(expr);
    return .{ .arena = arena, .expressions = expressions.toOwnedSlice() };
}

const Precedence = u8;

fn expression(allocator: Allocator, tokens: *Tokens, p: Precedence) error{OutOfMemory}!Expression {
    const token = tokens.next().?;
    var left = try prefix(allocator, tokens, token);
    while (true) {
        if (infix(tokens, left)) |parser| {
            const next = precedence(parser);
            if (p <= next) {
                left = try run(parser, allocator, tokens, left, next);
            } else {
                return left;
            }
        } else {
            return left;
        }
    }
}

fn prefix(allocator: Allocator, tokens: *Tokens, token: Token) !Expression {
    switch (token.kind) {
        .symbol => |value| return .{ .span = token.span, .kind = .{ .symbol = value } },
        .int => |value| return .{ .span = token.span, .kind = .{ .int = value } },
        .backslash => return lambda(allocator, tokens, token),
        else => |kind| {
            std.debug.print("\nno prefix parser for {}!", .{kind});
            unreachable;
        },
    }
}

fn expect(tokens: *Tokens, kind: TokenKind) Token {
    const token = tokens.next().?;
    std.debug.assert(std.meta.activeTag(token.kind) == std.meta.activeTag(kind));
    return token;
}

fn last(exprs: std.ArrayList(Expression)) Expression {
    return exprs.items[exprs.items.len - 1];
}

fn lambda(allocator: Allocator, tokens: *Tokens, backslash: Token) !Expression {
    var params = std.ArrayList(Expression).init(allocator);
    while (tokens.peek()) |token| {
        if (token.kind == .right_arrow) break;
        const param = try expression(allocator, tokens, HIGHEST);
        try params.append(param);
    }
    _ = expect(tokens, .right_arrow);
    var body = std.ArrayList(Expression).init(allocator);
    const expr = try expression(allocator, tokens, LOWEST);
    try body.append(expr);
    return .{
        .span = .{ backslash.span[0], last(body).span[1] },
        .kind = .{
            .lambda = .{
                .params = params.toOwnedSlice(),
                .body = body.toOwnedSlice(),
            },
        },
    };
}

const LOWEST = 0;
const DEFINE = LOWEST;
const ADD = DEFINE + 1;
const MUL = ADD + 1;
const CALL = MUL + 1;
const HIGHEST = CALL + 1;

const Infix = union(enum) {
    binary_op: BinaryOpKind,
    call,
    define,
};

fn precedence(parser: Infix) Precedence {
    switch (parser) {
        .binary_op => |op| {
            switch (op) {
                .add => return ADD,
                .mul => return MUL,
            }
        },
        .define => return DEFINE,
        .call => return CALL,
    }
}

fn infix(tokens: *Tokens, left: Expression) ?Infix {
    if (tokens.peek()) |token| {
        switch (token.kind) {
            .plus => return .{ .binary_op = .add },
            .star => return .{ .binary_op = .mul },
            .equal => return .define,
            else => {
                if (left.kind == .symbol) return .call;
                return null;
            },
        }
    } else {
        return null;
    }
}

fn binaryOp(allocator: Allocator, tokens: *Tokens, lhs: Expression, kind: BinaryOpKind, p: Precedence) !Expression {
    const op = tokens.next().?;
    const left = try allocator.create(Expression);
    left.* = lhs;
    const right = try allocator.create(Expression);
    right.* = try expression(allocator, tokens, p);
    return .{
        .span = op.span,
        .kind = .{ .binary_op = .{ .kind = kind, .left = left, .right = right } },
    };
}

fn call(allocator: Allocator, tokens: *Tokens, lhs: Expression) !Expression {
    const func = try allocator.create(Expression);
    func.* = lhs;
    var args = std.ArrayList(Expression).init(allocator);
    while (tokens.peek()) |token| {
        if (token.kind == .new_line) break;
        const arg = try expression(allocator, tokens, LOWEST);
        try args.append(arg);
    }
    return .{
        .span = .{ lhs.span[0], last(args).span[1] },
        .kind = .{ .call = .{ .func = func, .args = args.toOwnedSlice() } },
    };
}

fn define(allocator: Allocator, tokens: *Tokens, lhs: Expression) !Expression {
    const equal = expect(tokens, .equal);
    const name = try allocator.create(Expression);
    name.* = lhs;
    var body = std.ArrayList(Expression).init(allocator);
    const expr = try expression(allocator, tokens, LOWEST);
    try body.append(expr);
    return .{
        .span = equal.span,
        .kind = .{
            .define = .{
                .name = name,
                .body = body.toOwnedSlice(),
            },
        },
    };
}

fn run(
    parser: Infix,
    allocator: Allocator,
    tokens: *Tokens,
    left: Expression,
    p: Precedence,
) !Expression {
    switch (parser) {
        .binary_op => |value| return binaryOp(allocator, tokens, left, value, p),
        .call => return call(allocator, tokens, left),
        .define => return define(allocator, tokens, left),
    }
}
