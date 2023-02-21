const std = @import("std");

pub const Kind = union(enum) {
    symbol: []const u8,
    int: []const u8,
    float: []const u8,
    left_bracket,
    right_bracket,
    left_brace,
    right_brace,
    left_paren,
    right_paren,
    equal,
    less,
    greater,
    plus,
    minus,
    times,
    div,
    dot,
    ampersand,
    caret,
    not,
    and_,
    or_,
    equal_equal,
    not_equal,
    less_equal,
    greater_equal,
};

pub const Token = struct {
    start: [2]usize,
    end: [2]usize,
    kind: Kind,
};

pub fn symbol(start: [2]usize, end: [2]usize, value: []const u8) Token {
    return .{
        .start = start,
        .end = end,
        .kind = .{ .symbol = value },
    };
}

pub fn int(start: [2]usize, end: [2]usize, value: []const u8) Token {
    return .{
        .start = start,
        .end = end,
        .kind = .{ .int = value },
    };
}

pub fn float(start: [2]usize, end: [2]usize, value: []const u8) Token {
    return .{
        .start = start,
        .end = end,
        .kind = .{ .float = value },
    };
}

pub fn left_bracket(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .left_bracket };
}

pub fn left_brace(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .left_brace };
}

pub fn left_paren(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .left_paren };
}

pub fn right_bracket(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .right_bracket };
}

pub fn right_brace(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .right_brace };
}

pub fn right_paren(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .right_paren };
}

pub fn equal(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .equal };
}

pub fn less(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .less };
}

pub fn greater(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .greater };
}

pub fn plus(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .plus };
}

pub fn minus(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .minus };
}

pub fn times(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .times };
}

pub fn div(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .div };
}

pub fn dot(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .dot };
}

pub fn ampersand(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .ampersand };
}

pub fn caret(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .caret };
}

pub fn not(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .not };
}

pub fn and_(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .and_ };
}

pub fn or_(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .or_ };
}

pub fn equalEqual(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .equal_equal };
}

pub fn notEqual(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .not_equal };
}

pub fn lessEqual(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .less_equal };
}

pub fn greaterEqual(start: [2]usize, end: [2]usize) Token {
    return .{ .start = start, .end = end, .kind = .greater_equal };
}

fn trim(tokens: *Tokens) void {
    var i: usize = 0;
    while (i < tokens.source.len) : (i += 1) {
        switch (tokens.source[i]) {
            ' ' => tokens.pos[1] += 1,
            '\n' => {
                tokens.pos[0] += 1;
                tokens.pos[1] = 0;
            },
            else => break,
        }
    }
    tokens.source = tokens.source[i..];
}

fn advance(tokens: *Tokens, columns: usize) void {
    tokens.source = tokens.source[columns..];
    tokens.pos[1] += columns;
}

fn tokenizeNumber(tokens: *Tokens) Token {
    const start = tokens.pos;
    var i: usize = 1;
    var decimals: usize = if (tokens.source[0] == '.') 1 else 0;
    while (i < tokens.source.len) : (i += 1) {
        switch (tokens.source[i]) {
            '0'...'9', '_' => {},
            '.' => decimals += 1,
            else => break,
        }
    }
    const value = tokens.source[0..i];
    advance(tokens, i);
    if (value.len == 1) {
        switch (value[0]) {
            '-' => return minus(start, tokens.pos),
            '.' => return dot(start, tokens.pos),
            else => {},
        }
    }
    return if (decimals > 0)
        float(start, tokens.pos, value)
    else
        int(start, tokens.pos, value);
}

fn reserved(char: u8) bool {
    return switch (char) {
        ' ', '\n' => true,
        else => false,
    };
}

fn tokenizeSymbol(tokens: *Tokens) Token {
    const start = tokens.pos;
    var i: usize = 0;
    while (i < tokens.source.len and !reserved(tokens.source[i])) : (i += 1) {}
    const value = tokens.source[0..i];
    advance(tokens, i);
    if (std.mem.eql(u8, value, "not")) return not(start, tokens.pos);
    if (std.mem.eql(u8, value, "and")) return and_(start, tokens.pos);
    if (std.mem.eql(u8, value, "or")) return or_(start, tokens.pos);
    if (std.mem.eql(u8, value, "!=")) return notEqual(start, tokens.pos);
    return symbol(start, tokens.pos, value);
}

fn tokenizeOne(tokens: *Tokens, kind: Kind) Token {
    const start = tokens.pos;
    advance(tokens, 1);
    return .{ .kind = kind, .start = start, .end = tokens.pos };
}

fn tokenizeOneOrTwo(tokens: *Tokens, kind: Kind, second: u8, kind2: Kind) Token {
    const start = tokens.pos;
    if (tokens.source.len > 1 and tokens.source[1] == second) {
        advance(tokens, 2);
        return .{ .kind = kind2, .start = start, .end = tokens.pos };
    }
    advance(tokens, 1);
    return .{ .kind = kind, .start = start, .end = tokens.pos };
}

pub const Tokens = struct {
    source: []const u8,
    pos: [2]usize,

    const Self = @This();

    pub fn next(self: *Self) ?Token {
        trim(self);
        if (self.source.len == 0) return null;
        switch (self.source[0]) {
            '0'...'9', '-', '.' => return tokenizeNumber(self),
            '[' => return tokenizeOne(self, .left_bracket),
            ']' => return tokenizeOne(self, .right_bracket),
            '{' => return tokenizeOne(self, .left_brace),
            '}' => return tokenizeOne(self, .right_brace),
            '(' => return tokenizeOne(self, .left_paren),
            ')' => return tokenizeOne(self, .right_paren),
            '=' => return tokenizeOneOrTwo(self, .equal, '=', .equal_equal),
            '<' => return tokenizeOneOrTwo(self, .less, '=', .less_equal),
            '>' => return tokenizeOneOrTwo(self, .greater, '=', .greater_equal),
            '+' => return tokenizeOne(self, .plus),
            '*' => return tokenizeOne(self, .times),
            '/' => return tokenizeOne(self, .div),
            '&' => return tokenizeOne(self, .ampersand),
            '^' => return tokenizeOne(self, .caret),
            else => return tokenizeSymbol(self),
        }
    }
};

pub fn tokenize(source: []const u8) Tokens {
    return .{ .source = source, .pos = .{ 0, 0 } };
}

pub fn tokenizeAlloc(source: []const u8, allocator: std.mem.Allocator) ![]Token {
    var tokens = tokenize(source);
    var list = std.ArrayList(Token).init(allocator);
    while (tokens.next()) |token| {
        try list.append(token);
    }
    return list.toOwnedSlice();
}
