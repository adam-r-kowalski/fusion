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
    dash,
    star,
    slash,
    backslash,
    dot,
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
    left_arrow,
    right_arrow,
    indent,
};

/// row, col
pub const Position = [2]usize;

/// begin, end
pub const Span = [2]Position;

pub const Token = struct {
    span: Span,
    kind: Kind,
};

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
    if (value.len == 1) {
        switch (value[0]) {
            '-' => return tokenizeOneOrTwo(tokens, .dash, '>', .right_arrow),
            '.' => {
                advance(tokens, i);
                return .{ .span = .{ begin, tokens.pos }, .kind = .dot };
            },
            else => {},
        }
    }
    advance(tokens, i);
    const span: Span = .{ begin, tokens.pos };
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
    const span: Span = .{ begin, tokens.pos };
    if (eql(u8, value, "not")) return .{ .span = span, .kind = .not };
    if (eql(u8, value, "and")) return .{ .span = span, .kind = .and_ };
    if (eql(u8, value, "or")) return .{ .span = span, .kind = .or_ };
    return .{ .span = span, .kind = .{ .symbol = value } };
}

fn tokenizeOne(tokens: *Tokens, kind: Kind) Token {
    const begin = tokens.pos;
    advance(tokens, 1);
    return .{ .kind = kind, .span = .{ begin, tokens.pos } };
}

fn tokenizeOneOrTwo(tokens: *Tokens, kind: Kind, second: u8, kind2: Kind) Token {
    const begin = tokens.pos;
    if (tokens.source.len > 1 and tokens.source[1] == second) {
        advance(tokens, 2);
        return .{ .kind = kind2, .span = .{ begin, tokens.pos } };
    }
    advance(tokens, 1);
    return .{ .kind = kind, .span = .{ begin, tokens.pos } };
}

fn tokenizeOneOrTwoChoice(tokens: *Tokens, kind: Kind, second: u8, kind2: Kind, third: u8, kind3: Kind) Token {
    const begin = tokens.pos;
    if (tokens.source.len > 1) {
        if (tokens.source[1] == second) {
            advance(tokens, 2);
            return .{ .kind = kind2, .span = .{ begin, tokens.pos } };
        }
        if (tokens.source[1] == third) {
            advance(tokens, 2);
            return .{ .kind = kind3, .span = .{ begin, tokens.pos } };
        }
    }
    advance(tokens, 1);
    return .{ .kind = kind, .span = .{ begin, tokens.pos } };
}

pub const Tokens = struct {
    source: []const u8,
    pos: Position = .{ 0, 0 },
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
            '<' => return tokenizeOneOrTwoChoice(self, .less, '=', .less_equal, '-', .left_arrow),
            '>' => return tokenizeOneOrTwo(self, .greater, '=', .greater_equal),
            '!' => return tokenizeOneOrTwo(self, .bang, '=', .bang_equal),
            '+' => return tokenizeOne(self, .plus),
            '*' => return tokenizeOne(self, .star),
            '/' => return tokenizeOne(self, .slash),
            '\\' => return tokenizeOne(self, .backslash),
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
