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
    while (peekToken(tokens)) |token| {
        if (token.kind == .indent) {
            _ = nextToken(tokens);
        }
        const expr = try expression(context);
        try expressions.append(expr);
    }
    return .{ .arena = arena, .expressions = expressions.toOwnedSlice() };
}

const Context = struct {
    allocator: Allocator,
    tokens: *Tokens,
    precedence: u8,
    indent: usize,
};

fn withPrecedence(context: Context, p: u8) Context {
    return .{
        .allocator = context.allocator,
        .tokens = context.tokens,
        .precedence = p,
        .indent = context.indent,
    };
}

fn withIndent(context: Context, i: usize) Context {
    return .{
        .allocator = context.allocator,
        .tokens = context.tokens,
        .precedence = context.precedence,
        .indent = i,
    };
}

fn expression(context: Context) error{OutOfMemory}!Expression {
    const token = nextToken(context.tokens).?;
    var left = try prefix(context, token);
    while (true) {
        if (infix(context, left)) |parser| {
            var next = precedence(parser);
            if (context.precedence <= next) {
                if (associativity(parser) == .left) {
                    next += 1;
                }
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
        .left_paren => return group(context, token),
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

fn last(exprs: []const Expression) Expression {
    return exprs[exprs.len - 1];
}

fn block(context: Context) ![]Expression {
    var body = std.ArrayList(Expression).init(context.allocator);
    if (peekToken(context.tokens)) |token| {
        if (token.kind != .indent) {
            const expr = try expression(context);
            try body.append(expr);
        } else {
            _ = nextToken(context.tokens);
            const indent = token.kind.indent;
            std.debug.assert(indent > context.indent);
            const indented = withIndent(context, indent);
            while (true) {
                const expr = try expression(indented);
                try body.append(expr);
                if (peekToken(indented.tokens)) |t| {
                    if (t.kind != .indent) break;
                    if (t.kind.indent != indent) break;
                    _ = nextToken(indented.tokens);
                } else break;
            }
        }
    }
    return body.toOwnedSlice();
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
    const body = try block(context);
    return .{
        .span = .{ backslash.span[0], last(body).span[1] },
        .kind = .{
            .lambda = .{
                .params = params.toOwnedSlice(),
                .body = body,
            },
        },
    };
}

fn group(context: Context, left_paren: Token) !Expression {
    const expr = try context.allocator.create(Expression);
    expr.* = try expression(withPrecedence(context, LOWEST));
    _ = expect(context.tokens, .right_paren);
    return .{
        .span = .{ left_paren.span[0], expr.span[1] },
        .kind = .{ .group = .{ .expr = expr } },
    };
}

const DELTA = 10;

const LOWEST = 0;
const DEFINE = LOWEST;
const ANNOTATE = DEFINE;
const ARROW = ANNOTATE + DELTA;
const ADD = ARROW + DELTA;
const MUL = ADD + DELTA;
const POW = MUL + DELTA;
const CALL = MUL + DELTA;
const HIGHEST = CALL + DELTA;

const Infix = union(enum) {
    binary_op: BinaryOpKind,
    call,
    define,
    annotate,
};

fn precedence(parser: Infix) u8 {
    switch (parser) {
        .binary_op => |op| {
            switch (op) {
                .add => return ADD,
                .mul => return MUL,
                .pow => return POW,
                .arrow => return ARROW,
            }
        },
        .define => return DEFINE,
        .call => return CALL,
        .annotate => return ANNOTATE,
    }
}

const Associativity = enum { left, right };

fn associativity(parser: Infix) Associativity {
    switch (parser) {
        .binary_op => |op| {
            switch (op) {
                .pow, .arrow => return .right,
                else => return .left,
            }
        },
        .define => return .right,
        else => return .left,
    }
}

fn infix(context: Context, left: Expression) ?Infix {
    if (peekToken(context.tokens)) |token| {
        switch (token.kind) {
            .plus => return .{ .binary_op = .add },
            .star => return .{ .binary_op = .mul },
            .caret => return .{ .binary_op = .pow },
            .right_arrow => return .{ .binary_op = .arrow },
            .equal => return .define,
            .colon => return .annotate,
            .indent => return null,
            .right_paren => return null,
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

fn arguments(context: Context) ![]Expression {
    var args = std.ArrayList(Expression).init(context.allocator);
    while (peekToken(context.tokens)) |token| {
        if (token.kind == .indent) break;
        const arg = try expression(context);
        try args.append(arg);
    }
    return args.toOwnedSlice();
}

fn call(context: Context, lhs: Expression) !Expression {
    const func = try context.allocator.create(Expression);
    func.* = lhs;
    const args = try arguments(withPrecedence(context, LOWEST));
    return .{
        .span = .{ lhs.span[0], last(args).span[1] },
        .kind = .{ .call = .{ .func = func, .args = args } },
    };
}

fn define(context: Context, lhs: Expression) !Expression {
    const equal = expect(context.tokens, .equal);
    const name = try context.allocator.create(Expression);
    name.* = lhs;
    const body = try block(context);
    return .{
        .span = equal.span,
        .kind = .{
            .define = .{
                .name = name,
                .body = body,
            },
        },
    };
}

fn annotate(context: Context, lhs: Expression) !Expression {
    const colon = expect(context.tokens, .colon);
    const name = try context.allocator.create(Expression);
    name.* = lhs;
    var type_ = try context.allocator.create(Expression);
    type_.* = try expression(withPrecedence(context, LOWEST));
    return .{
        .span = colon.span,
        .kind = .{
            .annotate = .{
                .name = name,
                .type = type_,
            },
        },
    };
}

fn run(parser: Infix, context: Context, left: Expression) !Expression {
    switch (parser) {
        .binary_op => |value| return binaryOp(context, left, value),
        .call => return call(context, left),
        .define => return define(context, left),
        .annotate => return annotate(context, left),
    }
}
