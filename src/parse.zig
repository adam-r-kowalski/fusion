const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;

const types = @import("types.zig");
const Tokens = types.token.Tokens;
const Token = types.token.Token;
const Position = types.token.Position;
const TokenKind = types.token.Kind;
pub const Span = types.token.Span;
const Ast = types.ast.Ast;
const Expression = types.ast.Expression;
const BinaryOpKind = types.ast.BinaryOpKind;
const tokenize = @import("tokenize.zig");
const nextToken = tokenize.nextToken;
const peekToken = tokenize.peekToken;

pub fn parse(tokens: *Tokens, allocator: Allocator) !Ast {
    var arena = Arena.init(allocator);
    var expressions = std.ArrayList(Expression).init(arena.allocator());
    const context = .{
        .allocator = arena.allocator(),
        .tokens = tokens,
        .precedence = LOWEST,
        .indent = 0,
    };
    const expr = try expression(context);
    try expressions.append(expr);
    return .{ .arena = arena, .expressions = expressions.toOwnedSlice() };
}

const Context = struct {
    allocator: Allocator,
    tokens: *Tokens,
    precedence: u8,
    indent: u8,
};

fn withPrecedence(context: Context, p: u8) Context {
    return .{
        .allocator = context.allocator,
        .tokens = context.tokens,
        .precedence = p,
        .indent = context.indent,
    };
}

fn expression(context: Context) error{OutOfMemory}!Expression {
    const token = nextToken(context.tokens).?;
    var left = try prefix(context, token);
    while (true) {
        if (infix(context, left)) |parser| {
            const next = precedence(parser);
            if (context.precedence <= next) {
                left = try run(parser, withPrecedence(context, next), left);
            } else {
                return left;
            }
        } else {
            return left;
        }
    }
}

fn prefix(context: Context, token: Token) !Expression {
    switch (token.kind) {
        .symbol => |value| return .{ .span = token.span, .kind = .{ .symbol = value } },
        .int => |value| return .{ .span = token.span, .kind = .{ .int = value } },
        .backslash => return lambda(context, token),
        else => |kind| {
            std.debug.print("\nno prefix parser for {}!", .{kind});
            unreachable;
        },
    }
}

fn expect(tokens: *Tokens, kind: TokenKind) Token {
    const token = nextToken(tokens).?;
    std.debug.assert(std.meta.activeTag(token.kind) == std.meta.activeTag(kind));
    return token;
}

fn last(exprs: std.ArrayList(Expression)) Expression {
    return exprs.items[exprs.items.len - 1];
}

fn lambda(context: Context, backslash: Token) !Expression {
    var params = std.ArrayList(Expression).init(context.allocator);
    const highest = withPrecedence(context, HIGHEST);
    while (peekToken(highest.tokens)) |token| {
        if (token.kind == .right_arrow) break;
        const param = try expression(highest);
        try params.append(param);
    }
    _ = expect(context.tokens, .right_arrow);
    var body = std.ArrayList(Expression).init(context.allocator);
    const expr = try expression(withPrecedence(context, LOWEST));
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

fn precedence(parser: Infix) u8 {
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

fn infix(context: Context, left: Expression) ?Infix {
    if (peekToken(context.tokens)) |token| {
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

fn binaryOp(context: Context, lhs: Expression, kind: BinaryOpKind) !Expression {
    const op = nextToken(context.tokens).?;
    const left = try context.allocator.create(Expression);
    left.* = lhs;
    const right = try context.allocator.create(Expression);
    right.* = try expression(context);
    return .{
        .span = op.span,
        .kind = .{ .binary_op = .{ .kind = kind, .left = left, .right = right } },
    };
}

fn call(context: Context, lhs: Expression) !Expression {
    const func = try context.allocator.create(Expression);
    func.* = lhs;
    var args = std.ArrayList(Expression).init(context.allocator);
    const lowest = withPrecedence(context, LOWEST);
    while (peekToken(lowest.tokens)) |token| {
        if (token.kind == .new_line) break;
        const arg = try expression(lowest);
        try args.append(arg);
    }
    return .{
        .span = .{ lhs.span[0], last(args).span[1] },
        .kind = .{ .call = .{ .func = func, .args = args.toOwnedSlice() } },
    };
}

fn define(context: Context, lhs: Expression) !Expression {
    const equal = expect(context.tokens, .equal);
    const name = try context.allocator.create(Expression);
    name.* = lhs;
    var body = std.ArrayList(Expression).init(context.allocator);
    const expr = try expression(withPrecedence(context, LOWEST));
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

fn run(parser: Infix, context: Context, left: Expression) !Expression {
    switch (parser) {
        .binary_op => |value| return binaryOp(context, left, value),
        .call => return call(context, left),
        .define => return define(context, left),
    }
}
