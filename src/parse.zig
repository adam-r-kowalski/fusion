const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;

const types = @import("types.zig");
const Tokens = types.token.Tokens;
const Token = types.token.Token;
const Position = types.token.Position;
const TokenKind = types.token.Kind;
pub const Span = types.token.Span;
const Indent = types.token.Indent;
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
        .indent = .{ .space = 0 },
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
    indent: Indent,
};

fn withPrecedence(context: Context, p: u8) Context {
    return .{
        .allocator = context.allocator,
        .tokens = context.tokens,
        .precedence = p,
        .indent = context.indent,
    };
}

fn withIndent(context: Context, i: Indent) Context {
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
        .string => |value| return .{ .span = token.span, .kind = .{ .string = value } },
        .backslash => return lambda(context, token),
        .left_paren => return group(withPrecedence(context, LOWEST), token),
        .for_ => return for_(context, token),
        .if_ => return if_(context, token),
        .interface => return interface(context, token),
        .instance => return instance(context, token),
        else => |kind| {
            std.debug.print("\nno prefix parser for {}!", .{kind});
            unreachable;
        },
    }
}

fn expect(context: Context, kind: TokenKind) Token {
    const token = nextToken(context.tokens).?;
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
            const indented = withIndent(context, indent);
            while (true) {
                const expr = try expression(indented);
                try body.append(expr);
                if (peekToken(indented.tokens)) |t| {
                    if (t.kind != .indent) break;
                    if (!std.meta.eql(t.kind.indent, indent)) break;
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
        if (token.kind == .dot) break;
        const param = try expression(highest);
        try params.append(param);
    }
    _ = expect(context, .dot);
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
    _ = expect(context, .right_paren);
    return .{
        .span = .{ left_paren.span[0], expr.span[1] },
        .kind = .{ .group = .{ .expr = expr } },
    };
}

fn for_(context: Context, lhs: Token) !Expression {
    var indices = std.ArrayList(Expression).init(context.allocator);
    const highest = withPrecedence(context, HIGHEST);
    while (peekToken(highest.tokens)) |token| {
        if (token.kind == .dot) break;
        const param = try expression(highest);
        try indices.append(param);
    }
    _ = expect(context, .dot);
    const body = try block(context);
    return .{
        .span = .{ lhs.span[0], last(body).span[1] },
        .kind = .{
            .for_ = .{
                .indices = indices.toOwnedSlice(),
                .body = body,
            },
        },
    };
}

fn if_(context: Context, lhs: Token) !Expression {
    const condition = try context.allocator.create(Expression);
    condition.* = try expression(context);
    if (peekToken(context.tokens)) |token| {
        if (token.kind == .indent)
            _ = nextToken(context.tokens);
    }
    _ = expect(context, .then);
    const then = try block(context);
    if (peekToken(context.tokens)) |token| {
        if (token.kind == .indent)
            _ = nextToken(context.tokens);
    }
    _ = expect(context, .else_);
    const else_ = try block(context);
    return .{
        .span = .{ lhs.span[0], last(else_).span[1] },
        .kind = .{
            .if_ = .{
                .condition = condition,
                .then = then,
                .else_ = else_,
            },
        },
    };
}

fn interface(context: Context, lhs: Token) !Expression {
    const name = try context.allocator.create(Expression);
    name.* = try expression(withPrecedence(context, HIGHEST));
    var params = std.ArrayList(Expression).init(context.allocator);
    while (peekToken(context.tokens)) |token| {
        if (token.kind == .indent) break;
        const param = try expression(context);
        try params.append(param);
    }
    const body = try block(context);
    return .{
        .span = .{ lhs.span[0], last(body).span[1] },
        .kind = .{
            .interface = .{
                .name = name,
                .params = params.toOwnedSlice(),
                .body = body,
            },
        },
    };
}

fn instance(context: Context, lhs: Token) !Expression {
    const name = try context.allocator.create(Expression);
    name.* = try expression(withPrecedence(context, HIGHEST));
    var args = std.ArrayList(Expression).init(context.allocator);
    while (peekToken(context.tokens)) |token| {
        if (token.kind == .indent) break;
        const arg = try expression(context);
        try args.append(arg);
    }
    const body = try block(context);
    return .{
        .span = .{ lhs.span[0], last(body).span[1] },
        .kind = .{
            .instance = .{
                .name = name,
                .args = args.toOwnedSlice(),
                .body = body,
            },
        },
    };
}

const DELTA = 10;

const LOWEST = 0;
const DEFINE = LOWEST;
const ANNOTATE = DEFINE;
const ARROW = ANNOTATE + DELTA;
const FAT_ARROW = ARROW + DELTA;
const PIPE = FAT_ARROW + DELTA;
const COMPARE = PIPE + DELTA;
const ADD = COMPARE + DELTA;
const MUL = ADD + DELTA;
const POW = MUL + DELTA;
const DOT = POW + DELTA;
const CALL = DOT + DELTA;
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
                .fat_arrow => return FAT_ARROW,
                .dot => return DOT,
                .greater => return COMPARE,
                .less => return COMPARE,
                .equal => return COMPARE,
                .rem => return MUL,
                .pipe => return PIPE,
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
                .pow, .arrow, .fat_arrow => return .right,
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
            .fat_arrow => return .{ .binary_op = .fat_arrow },
            .dot => return .{ .binary_op = .dot },
            .greater => return .{ .binary_op = .greater },
            .less => return .{ .binary_op = .less },
            .equal_equal => return .{ .binary_op = .equal },
            .percent => return .{ .binary_op = .rem },
            .pipe => return .{ .binary_op = .pipe },
            .equal => return .define,
            .colon => return .annotate,
            .indent, .right_paren, .then, .else_ => return null,
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
        switch (token.kind) {
            .indent, .right_paren, .pipe => break,
            else => {
                const arg = try expression(context);
                try args.append(arg);
            },
        }
    }
    return args.toOwnedSlice();
}

fn call(context: Context, lhs: Expression) !Expression {
    const func = try context.allocator.create(Expression);
    func.* = lhs;
    const args = try arguments(withPrecedence(context, HIGHEST));
    return .{
        .span = .{ lhs.span[0], last(args).span[1] },
        .kind = .{ .call = .{ .func = func, .args = args } },
    };
}

fn define(context: Context, lhs: Expression) !Expression {
    const equal = expect(context, .equal);
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
    const colon = expect(context, .colon);
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
