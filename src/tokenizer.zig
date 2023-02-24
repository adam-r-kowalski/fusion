const std = @import("std");
const eql = std.mem.eql;

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
    less_equal,
    greater_equal,
    comma,
    bang,
    bang_equal,
    colon,
};

pub const Position = struct {
    line: usize,
    col: usize,
};

pub const Span = struct {
    begin: Position,
    end: Position,
};

pub const Token = struct {
    span: Span,
    kind: Kind,
};

pub fn symbol(start: [2]usize, end: [2]usize, value: []const u8) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .{ .symbol = value },
    };
}

pub fn int(start: [2]usize, end: [2]usize, value: []const u8) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .{ .int = value },
    };
}

pub fn float(start: [2]usize, end: [2]usize, value: []const u8) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .{ .float = value },
    };
}

pub fn left_bracket(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .left_bracket,
    };
}

pub fn left_brace(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .left_brace,
    };
}

pub fn left_paren(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .left_paren,
    };
}

pub fn right_bracket(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .left_bracket,
    };
}

pub fn right_brace(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .right_brace,
    };
}

pub fn right_paren(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .right_paren,
    };
}

pub fn equal(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .equal,
    };
}

pub fn less(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .less,
    };
}

pub fn greater(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .greater,
    };
}

pub fn plus(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .plus,
    };
}

pub fn minus(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .minus,
    };
}

pub fn times(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .times,
    };
}

pub fn div(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .div,
    };
}

pub fn dot(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .dot,
    };
}

pub fn ampersand(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .ampersand,
    };
}

pub fn caret(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .caret,
    };
}

pub fn not(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .not,
    };
}

pub fn and_(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .and_,
    };
}

pub fn or_(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .or_,
    };
}

pub fn equalEqual(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .equal_equal,
    };
}

pub fn lessEqual(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .less_equal,
    };
}

pub fn greaterEqual(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .greater_equal,
    };
}

pub fn comma(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .comma,
    };
}

pub fn bang(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .bang,
    };
}

pub fn bangEqual(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .bang_equal,
    };
}

pub fn colon(start: [2]usize, end: [2]usize) Token {
    return .{
        .span = .{ .begin = .{ .line = start[0], .col = start[1] }, .end = .{ .line = end[0], .col = end[1] } },
        .kind = .colon,
    };
}

fn trim(tokens: *Tokens) void {
    var i: usize = 0;
    while (i < tokens.source.len) : (i += 1) {
        switch (tokens.source[i]) {
            ' ' => tokens.pos.col += 1,
            '\n' => {
                tokens.pos.line += 1;
                tokens.pos.col = 0;
            },
            else => break,
        }
    }
    tokens.source = tokens.source[i..];
}

fn advance(tokens: *Tokens, columns: usize) void {
    tokens.source = tokens.source[columns..];
    tokens.pos.col += columns;
}

fn tokenizeNumber(tokens: *Tokens) Token {
    const begin = tokens.pos;
    var i: usize = 1;
    var decimals: usize = if (tokens.source[0] == '.') 1 else 0;
    while (i < tokens.source.len) : (i += 1) {
        switch (tokens.source[i]) {
            '0'...'9', '_' => {},
            '.' => decimals += 1,
            else => break,
        }
    }
    if (i > 2 and tokens.source[i - 1] == '.') {
        i -= 1;
        decimals -= 1;
    }
    const value = tokens.source[0..i];
    advance(tokens, i);
    const span = .{ .begin = begin, .end = tokens.pos };
    if (value.len == 1) {
        switch (value[0]) {
            '-' => return .{ .span = span, .kind = .minus },
            '.' => return .{ .span = span, .kind = .dot },
            else => {},
        }
    }
    if (decimals > 0)
        return .{ .span = span, .kind = .{ .float = value } };
    return .{ .span = span, .kind = .{ .int = value } };
}

fn reserved(char: u8) bool {
    return switch (char) {
        ' ',
        '\n',
        '(',
        ')',
        '[',
        ']',
        '{',
        '}',
        ',',
        '+',
        '-',
        '/',
        '*',
        '<',
        '>',
        '.',
        '!',
        '=',
        '&',
        '^',
        ':',
        => true,
        else => false,
    };
}

fn tokenizeSymbol(tokens: *Tokens) Token {
    const begin = tokens.pos;
    var i: usize = 1;
    while (i < tokens.source.len and !reserved(tokens.source[i])) : (i += 1) {}
    const value = tokens.source[0..i];
    advance(tokens, i);
    const span = .{ .begin = begin, .end = tokens.pos };
    if (eql(u8, value, "not")) return .{ .span = span, .kind = .not };
    if (eql(u8, value, "and")) return .{ .span = span, .kind = .and_ };
    if (eql(u8, value, "or")) return .{ .span = span, .kind = .or_ };
    return .{ .span = span, .kind = .{ .symbol = value } };
}

fn tokenizeOne(tokens: *Tokens, kind: Kind) Token {
    const begin = tokens.pos;
    advance(tokens, 1);
    return .{ .kind = kind, .span = .{ .begin = begin, .end = tokens.pos } };
}

fn tokenizeOneOrTwo(tokens: *Tokens, kind: Kind, second: u8, kind2: Kind) Token {
    const begin = tokens.pos;
    if (tokens.source.len > 1 and tokens.source[1] == second) {
        advance(tokens, 2);
        return .{ .kind = kind2, .span = .{ .begin = begin, .end = tokens.pos } };
    }
    advance(tokens, 1);
    return .{ .kind = kind, .span = .{ .begin = begin, .end = tokens.pos } };
}

pub const Tokens = struct {
    source: []const u8,
    pos: Position = .{ .line = 0, .col = 0 },
    peeked: ?Token = null,

    const Self = @This();

    pub fn next(self: *Self) ?Token {
        const token = self.peek();
        self.peeked = null;
        return token;
    }

    pub fn peek(self: *Self) ?Token {
        if (self.peeked) |token| return token;
        self.peeked = self.getToken();
        return self.peeked;
    }

    fn getToken(self: *Self) ?Token {
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
            '!' => return tokenizeOneOrTwo(self, .bang, '=', .bang_equal),
            '+' => return tokenizeOne(self, .plus),
            '*' => return tokenizeOne(self, .times),
            '/' => return tokenizeOne(self, .div),
            '&' => return tokenizeOne(self, .ampersand),
            '^' => return tokenizeOne(self, .caret),
            ',' => return tokenizeOne(self, .comma),
            ':' => return tokenizeOne(self, .colon),
            else => return tokenizeSymbol(self),
        }
    }
};

pub fn tokenize(source: []const u8) Tokens {
    return .{ .source = source };
}

pub fn tokenizeAlloc(source: []const u8, allocator: std.mem.Allocator) ![]Token {
    var tokens = tokenize(source);
    var list = std.ArrayList(Token).init(allocator);
    while (tokens.next()) |token| {
        try list.append(token);
    }
    return list.toOwnedSlice();
}
