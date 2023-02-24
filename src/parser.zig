const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;

const tokenizer = @import("./tokenizer.zig");
const Tokens = tokenizer.Tokens;
const Token = tokenizer.Token;
const Position = tokenizer.Position;

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
};

pub const Expression = struct {
    start: [2]usize,
    end: [2]usize,
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
    return .{ .start = start, .end = end, .kind = .{ .symbol = value } };
}

pub fn int(start: [2]usize, end: [2]usize, value: []const u8) Expression {
    return .{ .start = start, .end = end, .kind = .{ .int = value } };
}

pub fn binaryOp(
    start: [2]usize,
    end: [2]usize,
    op: BinaryOp,
    args: []const Expression,
) Expression {
    return .{
        .start = start,
        .end = end,
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
        else => unreachable,
    }
}

const InfixParser = union(enum) {
    binaryOp: BinaryOp,
};

fn infixParser(tokens: *Tokens) ?InfixParser {
    if (tokens.peek()) |token| {
        switch (token.kind) {
            .plus => return .{ .binaryOp = BinaryOp.add },
            .times => return .{ .binaryOp = BinaryOp.mul },
            else => unreachable,
        }
    } else {
        return null;
    }
}

fn runParser(
    parser: InfixParser,
    allocator: Allocator,
    tokens: *Tokens,
    left: Expression,
    precedence: u8,
) !Expression {
    const infix = tokens.next().?;
    switch (parser) {
        .binaryOp => |value| {
            const right = try parseExpression(allocator, tokens, precedence);
            const args = try allocator.alloc(Expression, 2);
            args[0] = left;
            args[1] = right;
            return binaryOp(infix.start, infix.end, value, args);
        },
    }
}

fn parserPrecedence(parser: InfixParser) u8 {
    switch (parser) {
        .binaryOp => |op| {
            switch (op) {
                .add => return 1,
                .mul => return 2,
            }
        },
    }
}
