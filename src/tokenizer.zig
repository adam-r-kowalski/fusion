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
};

pub const Token = struct {
    start: [2]usize,
    end: [2]usize,
    kind: Kind,
};

pub fn symbol(value: []const u8, start: [2]usize, end: [2]usize) Token {
    return .{
        .start = start,
        .end = end,
        .kind = .{ .symbol = value },
    };
}

fn trim(tokens: *Tokens) void {
    var i: usize = 0;
    while (i < tokens.source.len) : (i += 1) {
        switch (tokens.source[i]) {
            ' ' => tokens.pos[1] += 1,
            '\n' => tokens.pos[0] += 1,
            else => break,
        }
    }
    tokens.source = tokens.source[i..];
}

fn tokenizeNumber(tokens: *Tokens) Token {
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
    tokens.source = tokens.source[i..];
    if (value.len == 1) {
        switch (value[0]) {
            '-' => return .minus,
            '.' => return .dot,
            else => {},
        }
    }
    const token: Token = if (decimals > 0) .{ .float = value } else .{ .int = value };
    return token;
}

fn advance(tokens: *Tokens, columns: usize) void {
    tokens.source = tokens.source[columns..];
    tokens.pos[1] += columns;
}

fn tokenizeSymbol(tokens: *Tokens) Token {
    const begin = tokens.pos;
    var i: usize = 0;
    while (i < tokens.source.len and tokens.source[i] != ' ') : (i += 1) {}
    const value = tokens.source[0..i];
    advance(tokens, i);
    // if (std.mem.eql(u8, value, "not")) return .not;
    // if (std.mem.eql(u8, value, "and")) return .and_;
    // if (std.mem.eql(u8, value, "or")) return .or_;
    return symbol(value, begin, tokens.pos);
}

fn tokenizeOne(tokens: *Tokens, kind: Kind) Token {
    tokens.source = tokens.source[1..];
    return .{ .kind = kind, .start = .{ 0, 0 }, .end = .{ 0, 0 } };
}

pub const Tokens = struct {
    source: []const u8,
    pos: [2]usize,

    const Self = @This();

    pub fn next(self: *Self) ?Token {
        trim(self);
        if (self.source.len == 0) return null;
        switch (self.source[0]) {
            // '0'...'9', '-', '.' => return tokenizeNumber(self),
            // '[' => return tokenizeOne(self, .left_bracket),
            // ']' => return tokenizeOne(self, .right_bracket),
            // '{' => return tokenizeOne(self, .left_brace),
            // '}' => return tokenizeOne(self, .right_brace),
            // '(' => return tokenizeOne(self, .left_paren),
            // ')' => return tokenizeOne(self, .right_paren),
            // '=' => return tokenizeOne(self, .equal),
            // '<' => return tokenizeOne(self, .less),
            // '>' => return tokenizeOne(self, .greater),
            // '+' => return tokenizeOne(self, .plus),
            // '*' => return tokenizeOne(self, .times),
            // '/' => return tokenizeOne(self, .div),
            // '&' => return tokenizeOne(self, .ampersand),
            // '^' => return tokenizeOne(self, .caret),
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
