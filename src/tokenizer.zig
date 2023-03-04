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
    fat_arrow,
    indent,
    new_line,
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
            else => break,
        }
    }
    tokens.source = tokens.source[i..];
}

fn advance(tokens: *Tokens, columns: usize) void {
    tokens.source = tokens.source[columns..];
    tokens.pos[1] += columns;
}

fn number(tokens: *Tokens) Token {
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
            '-' => return choice(tokens, .dash, &.{.{ '>', .right_arrow }}),
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

fn symbol(tokens: *Tokens) Token {
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

fn exact(tokens: *Tokens, kind: Kind) Token {
    const begin = tokens.pos;
    advance(tokens, 1);
    return .{ .kind = kind, .span = .{ begin, tokens.pos } };
}

const Choice = std.meta.Tuple(&.{ u8, Kind });

fn choice(tokens: *Tokens, kind: Kind, choices: []const Choice) Token {
    const begin = tokens.pos;
    if (tokens.source.len > 1) {
        const t = tokens.source[1];
        for (choices) |c| {
            if (t == c[0]) {
                advance(tokens, 2);
                return .{ .kind = c[1], .span = .{ begin, tokens.pos } };
            }
        }
    }
    advance(tokens, 1);
    return .{ .kind = kind, .span = .{ begin, tokens.pos } };
}

fn newLine(tokens: *Tokens) Token {
    const begin = tokens.pos;
    tokens.pos[0] += 1;
    tokens.pos[1] = 0;
    tokens.source = tokens.source[1..];
    tokens.expecting_indent = true;
    return .{ .kind = .new_line, .span = .{ begin, tokens.pos } };
}

fn indent(tokens: *Tokens) Token {
    const begin = tokens.pos;
    var i: usize = 0;
    while (i < tokens.source.len and tokens.source[i] == ' ') : (i += 1) {}
    advance(tokens, i);
    return .{ .kind = .indent, .span = .{ begin, tokens.pos } };
}

pub const Tokens = struct {
    source: []const u8,
    pos: Position = .{ 0, 0 },
    peeked: ?Token = null,
    expecting_indent: bool = true,

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
        if (!self.expecting_indent) trim(self);
        self.expecting_indent = false;
        if (self.source.len == 0) return null;
        switch (self.source[0]) {
            '0'...'9', '-', '.' => return number(self),
            '[' => return exact(self, .left_bracket),
            ']' => return exact(self, .right_bracket),
            '{' => return exact(self, .left_brace),
            '}' => return exact(self, .right_brace),
            '(' => return exact(self, .left_paren),
            ')' => return exact(self, .right_paren),
            '=' => return choice(self, .equal, &.{ .{ '=', .equal_equal }, .{ '>', .fat_arrow } }),
            '<' => return choice(self, .less, &.{ .{ '=', .less_equal }, .{ '-', .left_arrow } }),
            '>' => return choice(self, .greater, &.{.{ '=', .greater_equal }}),
            '!' => return choice(self, .bang, &.{.{ '=', .bang_equal }}),
            '+' => return exact(self, .plus),
            '*' => return exact(self, .star),
            '/' => return exact(self, .slash),
            '\\' => return exact(self, .backslash),
            '^' => return exact(self, .caret),
            ',' => return exact(self, .comma),
            ':' => return exact(self, .colon),
            ' ' => return indent(self),
            '\n' => return newLine(self),
            else => return symbol(self),
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
