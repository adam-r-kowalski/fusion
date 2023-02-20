const std = @import("std");
const isWhitespace = std.ascii.isWhitespace;

pub const Token = union(enum) {
    symbol: []const u8,
    int: []const u8,
    float: []const u8,
};

fn trim(source: []const u8) []const u8 {
    var i: usize = 0;
    while (i < source.len and isWhitespace(source[i])) : (i += 1) {}
    return source[i..];
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
    const token: Token = if (decimals > 0) .{ .float = value } else .{ .int = value };
    tokens.source = tokens.source[i..];
    return token;
}

fn tokenizeSymbol(tokens: *Tokens) Token {
    var i: usize = 0;
    while (i < tokens.source.len and !isWhitespace(tokens.source[i])) : (i += 1) {}
    const token = Token{ .symbol = tokens.source[0..i] };
    tokens.source = tokens.source[i..];
    return token;
}

pub const Tokens = struct {
    source: []const u8,

    const Self = @This();

    pub fn next(self: *Self) ?Token {
        self.source = trim(self.source);
        if (self.source.len == 0) {
            return null;
        }
        switch (self.source[0]) {
            '0'...'9', '-', '.' => return tokenizeNumber(self),
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
