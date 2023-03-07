const std = @import("std");

const types = @import("../types.zig");
const Span = types.token.Span;
const Token = types.token.Token;

fn span(writer: anytype, s: Span) !void {
    const fmt = ".span = .{{ .{{ {}, {} }}, .{{ {}, {} }} }},";
    try std.fmt.format(writer, fmt, .{ s[0][0], s[0][1], s[1][0], s[1][1] });
}

pub fn token(writer: anytype, t: Token) !void {
    try writer.writeAll("\n.{");
    try span(writer, t.span);
    try writer.writeAll(" .kind = ");
    switch (t.kind) {
        .symbol => |symbol| try std.fmt.format(writer, ".{{ .symbol = \"{s}\" }}", .{symbol}),
        .int => |int| try std.fmt.format(writer, ".{{ .int = \"{s}\" }}", .{int}),
        .float => |float| try std.fmt.format(writer, ".{{ .float = \"{s}\" }}", .{float}),
        .string => |string| try std.fmt.format(writer, ".{{ .string = \"{s}\" }}", .{string}),
        .left_bracket => try writer.writeAll(".left_bracket"),
        .right_bracket => try writer.writeAll(".right_bracket"),
        .left_brace => try writer.writeAll(".left_brace"),
        .right_brace => try writer.writeAll(".right_brace"),
        .left_paren => try writer.writeAll(".left_paren"),
        .right_paren => try writer.writeAll(".right_paren"),
        .equal => try writer.writeAll(".equal"),
        .less => try writer.writeAll(".less"),
        .greater => try writer.writeAll(".greater"),
        .plus => try writer.writeAll(".plus"),
        .dash => try writer.writeAll(".dash"),
        .star => try writer.writeAll(".star"),
        .slash => try writer.writeAll(".slash"),
        .backslash => try writer.writeAll(".backslash"),
        .dot => try writer.writeAll(".dot"),
        .caret => try writer.writeAll(".caret"),
        .not => try writer.writeAll(".not"),
        .and_ => try writer.writeAll(".and_"),
        .or_ => try writer.writeAll(".or_"),
        .equal_equal => try writer.writeAll(".equal_equal"),
        .less_equal => try writer.writeAll(".less_equal"),
        .greater_equal => try writer.writeAll(".greater_equal"),
        .comma => try writer.writeAll(".comma"),
        .bang => try writer.writeAll(".bang"),
        .bang_equal => try writer.writeAll(".bang_equal"),
        .colon => try writer.writeAll(".colon"),
        .left_arrow => try writer.writeAll(".left_arrow"),
        .right_arrow => try writer.writeAll(".right_arrow"),
        .fat_arrow => try writer.writeAll(".fat_arrow"),
        .indent => |indent| try std.fmt.format(writer, ".{{ .indent = {} }}", .{indent}),
        .if_ => try writer.writeAll(".if_"),
        .then => try writer.writeAll(".then"),
        .else_ => try writer.writeAll(".else_"),
        .when => try writer.writeAll(".when"),
        .is => try writer.writeAll(".is"),
        .for_ => try writer.writeAll(".for_"),
    }
    try writer.writeAll(" },");
}

pub fn tokenAlloc(t: Token, allocator: std.mem.Allocator) ![]const u8 {
    var list = std.ArrayList(u8).init(allocator);
    try token(list.writer(), t);
    return list.toOwnedSlice();
}

pub fn tokens(writer: anytype, ts: []const Token) !void {
    for (ts) |t| try token(writer, t);
}

pub fn tokensAlloc(ts: []const Token, allocator: std.mem.Allocator) ![]const u8 {
    var list = std.ArrayList(u8).init(allocator);
    try tokens(list.writer(), ts);
    return list.toOwnedSlice();
}
