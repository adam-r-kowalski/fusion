const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;

const tokenizer = @import("./tokenizer.zig");
const Tokens = tokenizer.Tokens;
const Token = tokenizer.Token;
const Position = tokenizer.Position;

const BinaryOp = enum {
    add,
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
    const expression = parseExpression(tokens);
    try expressions.append(expression);
    return .{ .arena = arena, .expressions = expressions.toOwnedSlice() };
}

fn parseExpression(tokens: *Tokens) Expression {
    const token = tokens.next().?;
    const left = prefixParser(token);
    return left;
}

fn prefixParser(token: Token) Expression {
    switch (token.kind) {
        .symbol => |value| return symbol(token.start, token.end, value),
        .int => |value| return int(token.start, token.end, value),
        else => unreachable,
    }
}
