const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;

const tokenizer = @import("./tokenizer.zig");
const Tokens = tokenizer.Tokens;
const Token = tokenizer.Token;
const Position = tokenizer.Position;
pub const Span = tokenizer.Span;

pub const BinaryOpKind = enum {
    add,
    mul,
    assign,
};

pub const BinaryOp = struct {
    kind: BinaryOpKind,
    left: *const Expression,
    right: *const Expression,
};

pub const Call = struct {
    func: *const Expression,
    args: []const Expression,
};

pub const Kind = union(enum) {
    symbol: []const u8,
    int: []const u8,
    binary_op: BinaryOp,
    call: Call,
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
    var left = try prefixParser(token);
    while (true) {
        if (infixParser(tokens, left)) |parser| {
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

fn prefixParser(token: Token) !Expression {
    switch (token.kind) {
        .symbol => |value| return .{ .span = token.span, .kind = .{ .symbol = value } },
        .int => |value| return .{ .span = token.span, .kind = .{ .int = value } },
        else => |kind| {
            std.debug.print("\nno prefix parser for {}!", .{kind});
            unreachable;
        },
    }
}

const InfixParser = union(enum) {
    binary_op: BinaryOpKind,
    call,
};

fn infixParser(tokens: *Tokens, left: Expression) ?InfixParser {
    if (tokens.peek()) |token| {
        switch (token.kind) {
            .plus => return .{ .binary_op = .add },
            .star => return .{ .binary_op = .mul },
            .equal => return .{ .binary_op = .assign },
            else => {
                if (left.kind == .symbol) return .call;
                return null;
            },
        }
    } else {
        return null;
    }
}

fn parseBinaryOp(allocator: Allocator, tokens: *Tokens, lhs: Expression, kind: BinaryOpKind, precedence: u8) !Expression {
    const infix = tokens.next().?;
    const left = try allocator.create(Expression);
    left.* = lhs;
    const right = try allocator.create(Expression);
    right.* = try parseExpression(allocator, tokens, precedence);
    return .{
        .span = infix.span,
        .kind = .{ .binary_op = .{ .kind = kind, .left = left, .right = right } },
    };
}

fn parseCall(allocator: Allocator, tokens: *Tokens, lhs: Expression) !Expression {
    const func = try allocator.create(Expression);
    func.* = lhs;
    var args = std.ArrayList(Expression).init(allocator);
    while (tokens.peek()) |token| {
        if (token.kind == .new_line) break;
        const arg = try parseExpression(allocator, tokens, LOWEST);
        try args.append(arg);
    }
    return .{
        .span = .{ lhs.span[0], args.items[args.items.len - 1].span[1] },
        .kind = .{ .call = .{ .func = func, .args = args.toOwnedSlice() } },
    };
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

const LOWEST = 0;
const ASSIGN = LOWEST;
const ADD = ASSIGN + 1;
const MUL = ADD + 1;
const CALL = MUL + 1;
const HIGHEST = CALL + 1;

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
