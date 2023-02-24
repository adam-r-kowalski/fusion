const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;

const tokenizer = @import("./tokenizer.zig");
const Tokens = tokenizer.Tokens;
const Token = tokenizer.Token;

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

const Position = struct {
    line: usize,
    col: usize,
};

const Span = struct {
    begin: Position,
    end: Position,
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

pub fn symbol(start: [2]usize, end: [2]usize, value: []const u8) Expression {
    return .{
        .span = .{
            .begin = .{ .line = start[0], .col = start[1] },
            .end = .{ .line = end[0], .col = end[1] },
        },
        .kind = .{ .symbol = value },
    };
}

pub fn int(start: [2]usize, end: [2]usize, value: []const u8) Expression {
    return .{
        .span = .{
            .begin = .{ .line = start[0], .col = start[1] },
            .end = .{ .line = end[0], .col = end[1] },
        },
        .kind = .{ .int = value },
    };
}

pub fn binaryOp(
    start: [2]usize,
    end: [2]usize,
    op: BinaryOp,
    args: []const Expression,
) Expression {
    return .{
        .span = .{
            .begin = .{ .line = start[0], .col = start[1] },
            .end = .{ .line = end[0], .col = end[1] },
        },
        .kind = .{
            .binaryOp = .{ .op = op, .args = args },
        },
    };
}

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
        .symbol => |value| return symbol(token.start, token.end, value),
        .int => |value| return int(token.start, token.end, value),
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
    const args = try allocator.alloc(Expression, 2);
    args[0] = left;
    args[1] = right;
    return binaryOp(infix.start, infix.end, value, args);
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
                    .span = .{
                        .begin = .{ .line = left_paren.start[0], .col = left_paren.start[1] },
                        .end = .{ .line = token.end[0], .col = token.end[1] },
                    },
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
