const std = @import("std");
const Arena = std.heap.ArenaAllocator;

const tokenizer = @import("../tokenizer.zig");
pub const Span = tokenizer.Span;

pub const BinaryOpKind = enum {
    add,
    mul,
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

pub const Define = struct {
    name: *const Expression,
    body: []const Expression,
};

pub const Lambda = struct {
    params: []const Expression,
    body: []const Expression,
};

pub const Kind = union(enum) {
    symbol: []const u8,
    int: []const u8,
    binary_op: BinaryOp,
    call: Call,
    define: Define,
    lambda: Lambda,
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
