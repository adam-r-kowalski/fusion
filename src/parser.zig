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
};

pub const Kind = union(enum) {
    symbol: []const u8,
    int: []const u8,
    binaryOp: struct {
        op: BinaryOp,
        args: []const Expression,
    },
    call: struct {
        func: *const Expression,
        args: []const Expression,
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
    var left = prefixParser(token);
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

fn prefixParser(token: Token) Expression {
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
    binaryOp: BinaryOp,
    call,
};

fn infixParser(tokens: *Tokens) ?InfixParser {
    if (tokens.peek()) |token| {
        switch (token.kind) {
            .plus => return .{ .binaryOp = .add },
            .times => return .{ .binaryOp = .mul },
            .left_paren => return .call,
            else => return null,
        }
    } else {
        return null;
    }
}

fn parseBinaryOp(allocator: Allocator, tokens: *Tokens, left: Expression, value: BinaryOp, precedence: u8) !Expression {
    const infix = tokens.next().?;
    const right = try parseExpression(allocator, tokens, precedence);
    const args = try allocator.dupe(Expression, &.{ left, right });
    return .{
        .span = infix.span,
        .kind = .{ .binaryOp = .{ .op = value, .args = args } },
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
        .binaryOp => |value| return parseBinaryOp(allocator, tokens, left, value, precedence),
        .call => return parseCall(allocator, tokens, left),
    }
}

const ADD = 1;
const MUL = ADD + 1;
const CALL = MUL + 1;

fn parserPrecedence(parser: InfixParser) u8 {
    switch (parser) {
        .binaryOp => |op| {
            switch (op) {
                .add => return ADD,
                .mul => return MUL,
            }
        },
        .call => return CALL,
    }
}
