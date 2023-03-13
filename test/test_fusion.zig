const std = @import("std");
pub const tokenizer = @import("test_tokenizer.zig");
pub const parser = @import("test_parser.zig");
pub const type_check = @import("test_type_check.zig");
pub const web_assembly = @import("test_wat.zig");

test "run all tests" {
    std.testing.refAllDecls(@This());
}
