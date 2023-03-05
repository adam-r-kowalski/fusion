const std = @import("std");
const Arena = std.heap.ArenaAllocator;

pub const Span = @import("token.zig").Span;

pub const BinaryOpKind = enum {
    add,
    mul,
    pow,
    arrow,
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

pub const Annotate = struct {
    name: *const Expression,
    type: *const Expression,
};

pub const Kind = union(enum) {
    symbol: []const u8,
    int: []const u8,
    binary_op: BinaryOp,
    call: Call,
    define: Define,
    lambda: Lambda,
    annotate: Annotate,
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
