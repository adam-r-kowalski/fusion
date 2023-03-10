const std = @import("std");
const eql = std.mem.eql;

const token = @import("types/token.zig");
const Tokens = token.Tokens;
const Token = token.Token;
const Span = token.Span;
const Kind = token.Kind;

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

fn string(tokens: *Tokens) Token {
    const begin = tokens.pos;
    var i: usize = 1;
    while (i < tokens.source.len) : (i += 1) {
        switch (tokens.source[i]) {
            '"' => {
                i += 1;
                break;
            },
            else => continue,
        }
    }
    const value = tokens.source[0..i];
    advance(tokens, i);
    const span: Span = .{ begin, tokens.pos };
    return .{ .span = span, .kind = .{ .string = value } };
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
    if (eql(u8, value, "if")) return .{ .span = span, .kind = .if_ };
    if (eql(u8, value, "then")) return .{ .span = span, .kind = .then };
    if (eql(u8, value, "else")) return .{ .span = span, .kind = .else_ };
    if (eql(u8, value, "when")) return .{ .span = span, .kind = .when };
    if (eql(u8, value, "is")) return .{ .span = span, .kind = .is };
    if (eql(u8, value, "for")) return .{ .span = span, .kind = .for_ };
    if (eql(u8, value, "interface")) return .{ .span = span, .kind = .interface };
    if (eql(u8, value, "instance")) return .{ .span = span, .kind = .instance };
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

fn newLine(tokens: *Tokens) ?Token {
    tokens.pos[1] = 0;
    var i: usize = 0;
    while (tokens.source.len > i and tokens.source[i] == '\n') : (i += 1) {
        tokens.pos[0] += 1;
    }
    const begin = tokens.pos;
    tokens.source = tokens.source[i..];
    if (tokens.source.len == 0) return null;
    i = 0;
    if (tokens.source[0] == ' ') {
        while (tokens.source.len > i and tokens.source[i] == ' ') : (i += 1)
            tokens.pos[1] += 1;
        tokens.source = tokens.source[i..];
        if (tokens.source.len == 0) return null;
        return .{ .kind = .{ .indent = .{ .space = tokens.pos[1] } }, .span = .{ begin, tokens.pos } };
    }
    if (tokens.source[0] == '\t') {
        while (tokens.source.len > i and tokens.source[i] == '\t') : (i += 1)
            tokens.pos[1] += 1;
        tokens.source = tokens.source[i..];
        if (tokens.source.len == 0) return null;
        return .{ .kind = .{ .indent = .{ .tab = tokens.pos[1] } }, .span = .{ begin, tokens.pos } };
    }
    return .{ .kind = .{ .indent = .{ .space = 0 } }, .span = .{ begin, tokens.pos } };
}

pub fn nextToken(tokens: *Tokens) ?Token {
    const t = peekToken(tokens);
    tokens.peeked = null;
    return t;
}

pub fn peekToken(tokens: *Tokens) ?Token {
    if (tokens.peeked) |t| return t;
    tokens.peeked = getToken(tokens);
    return tokens.peeked;
}

fn getToken(tokens: *Tokens) ?Token {
    trim(tokens);
    if (tokens.source.len == 0) return null;
    switch (tokens.source[0]) {
        '0'...'9', '-', '.' => return number(tokens),
        '[' => return exact(tokens, .left_bracket),
        ']' => return exact(tokens, .right_bracket),
        '{' => return exact(tokens, .left_brace),
        '}' => return exact(tokens, .right_brace),
        '(' => return exact(tokens, .left_paren),
        ')' => return exact(tokens, .right_paren),
        '=' => return choice(tokens, .equal, &.{ .{ '=', .equal_equal }, .{ '>', .fat_arrow } }),
        '<' => return choice(tokens, .less, &.{ .{ '=', .less_equal }, .{ '-', .left_arrow } }),
        '>' => return choice(tokens, .greater, &.{.{ '=', .greater_equal }}),
        '!' => return choice(tokens, .bang, &.{.{ '=', .bang_equal }}),
        '|' => return choice(tokens, .bang, &.{.{ '>', .pipe }}),
        '+' => return exact(tokens, .plus),
        '*' => return exact(tokens, .star),
        '/' => return exact(tokens, .slash),
        '\\' => return exact(tokens, .backslash),
        '^' => return exact(tokens, .caret),
        ',' => return exact(tokens, .comma),
        ':' => return exact(tokens, .colon),
        '%' => return exact(tokens, .percent),
        '\n' => return newLine(tokens),
        '"' => return string(tokens),
        else => return symbol(tokens),
    }
}

pub fn tokenize(source: []const u8) Tokens {
    return .{ .source = source };
}

pub fn tokenizeAlloc(source: []const u8, allocator: std.mem.Allocator) ![]Token {
    var tokens = tokenize(source);
    var list = std.ArrayList(Token).init(allocator);
    while (nextToken(&tokens)) |t| {
        try list.append(t);
    }
    return list.toOwnedSlice();
}
