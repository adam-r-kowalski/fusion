const std = @import("std");
pub const tokenizer = @import("test_tokenizer.zig");
pub const parser = @import("test_parser.zig");
pub const web_assembly = @import("test_wat.zig");

test "run all tests" {
    std.testing.refAllDecls(@This());
}
