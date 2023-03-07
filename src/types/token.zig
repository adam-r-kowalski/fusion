pub const Kind = union(enum) {
    symbol: []const u8,
    int: []const u8,
    float: []const u8,
    string: []const u8,
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
    indent: usize,
    if_,
    then,
    else_,
    when,
    is,
    for_,
};

/// row, col
pub const Position = [2]usize;

/// begin, end
pub const Span = [2]Position;

pub const Token = struct {
    span: Span,
    kind: Kind,
};

pub const Tokens = struct {
    source: []const u8,
    pos: Position = .{ 0, 0 },
    peeked: ?Token = null,
};
