const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;

const tokenizer = @import("./tokenizer.zig");
const Tokens = tokenizer.Tokens;
const Token = tokenizer.Token;
const Position = tokenizer.Position;
const Span = tokenizer.Span;

pub const BinaryOp = enum {
    add,
    mul,
    assign,
};

pub const Kind = union(enum) {
    symbol: []const u8,
    int: []const u8,
    binary_op: struct {
        op: BinaryOp,
        lhs: *const Expression,
        rhs: *const Expression,
    },
    call: struct {
        func: *const Expression,
        args: []const Expression,
    },
    func: struct {
        params: []const Expression,
        body: []const Expression,
    },
};

pub const Expression = struct {
    span: Span,
    kind: Kind,
};

pub const Ast = struct {
    arena: Arena,
    expressions: []Expression,

    pub fn deinit(self: @This()) void {
        self.arena.deinit();
    }
};

pub fn parse(tokens: *Tokens, allocator: Allocator) !Ast {
    var arena = Arena.init(allocator);
    var expressions = std.ArrayList(Expression).init(arena.allocator());
    const expression = try parseExpression(arena.allocator(), tokens, 0);
    try expressions.append(expression);
    return .{ .arena = arena, .expressions = expressions.toOwnedSlice() };
}

fn parseExpression(allocator: Allocator, tokens: *Tokens, precedence: u8) error{OutOfMemory}!Expression {
    const token = tokens.next().?;
    var left = try prefixParser(allocator, tokens, token);
    while (true) {
        if (infixParser(tokens)) |parser| {
            const nextPrecedence = parserPrecedence(parser);
            if (precedence <= nextPrecedence) {
                left = try runParser(parser, allocator, tokens, left, nextPrecedence);
            } else {
                return left;
            }
        } else {
            return left;
        }
    }
}

fn prefixParser(allocator: Allocator, tokens: *Tokens, token: Token) !Expression {
    switch (token.kind) {
        .symbol => |value| return .{ .span = token.span, .kind = .{ .symbol = value } },
        .int => |value| return .{ .span = token.span, .kind = .{ .int = value } },
        .left_paren => return try parseFunction(allocator, tokens, token),
        else => |kind| {
            std.debug.print("\nno prefix parser for {}!", .{kind});
            unreachable;
        },
    }
}

fn parseFunction(allocator: Allocator, tokens: *Tokens, left_paren: Token) !Expression {
    std.debug.assert(tokens.next().?.kind == .right_paren);
    std.debug.assert(tokens.next().?.kind == .left_brace);
    var body = std.ArrayList(Expression).init(allocator);
    const expression = try parseExpression(allocator, tokens, 0);
    try body.append(expression);
    const right_brace = tokens.next().?;
    std.debug.assert(right_brace.kind == .right_brace);
    return .{
        .span = .{ .begin = left_paren.span.begin, .end = right_brace.span.end },
        .kind = .{
            .func = .{
                .params = &.{},
                .body = body.toOwnedSlice(),
            },
        },
    };
}

const InfixParser = union(enum) {
    binary_op: BinaryOp,
    call,
};

fn infixParser(tokens: *Tokens) ?InfixParser {
    if (tokens.peek()) |token| {
        switch (token.kind) {
            .plus => return .{ .binary_op = .add },
            .times => return .{ .binary_op = .mul },
            .equal => return .{ .binary_op = .assign },
            .left_paren => return .call,
            else => return null,
        }
    } else {
        return null;
    }
}

fn parseBinaryOp(allocator: Allocator, tokens: *Tokens, left: Expression, value: BinaryOp, precedence: u8) !Expression {
    const infix = tokens.next().?;
    const lhs = try allocator.create(Expression);
    lhs.* = left;
    const rhs = try allocator.create(Expression);
    rhs.* = try parseExpression(allocator, tokens, precedence);
    return .{
        .span = infix.span,
        .kind = .{ .binary_op = .{ .op = value, .lhs = lhs, .rhs = rhs } },
    };
}

fn parseCall(allocator: Allocator, tokens: *Tokens, left: Expression) !Expression {
    const left_paren = tokens.next().?;
    var arguments = std.ArrayList(Expression).init(allocator);
    while (tokens.peek()) |token| {
        switch (token.kind) {
            .right_paren => {
                _ = tokens.next();
                const func = try allocator.create(Expression);
                func.* = left;
                return .{
                    .span = .{ .begin = left_paren.span.begin, .end = token.span.end },
                    .kind = .{
                        .call = .{
                            .func = func,
                            .args = arguments.toOwnedSlice(),
                        },
                    },
                };
            },
            .comma => _ = tokens.next(),
            else => {
                const argument = try parseExpression(allocator, tokens, 0);
                try arguments.append(argument);
            },
        }
    }
    unreachable;
}

fn runParser(
    parser: InfixParser,
    allocator: Allocator,
    tokens: *Tokens,
    left: Expression,
    precedence: u8,
) !Expression {
    switch (parser) {
        .binary_op => |value| return parseBinaryOp(allocator, tokens, left, value, precedence),
        .call => return parseCall(allocator, tokens, left),
    }
}

const ASSIGN = 0;
const ADD = ASSIGN + 1;
const MUL = ADD + 1;
const CALL = MUL + 1;

fn parserPrecedence(parser: InfixParser) u8 {
    switch (parser) {
        .binary_op => |op| {
            switch (op) {
                .add => return ADD,
                .mul => return MUL,
                .assign => return ASSIGN,
            }
        },
        .call => return CALL,
    }
}
