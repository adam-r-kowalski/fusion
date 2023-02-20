const std = @import("std");
pub const tokenizer = @import("test_tokenizer.zig");
pub const web_assembly = @import("test_web_assembly.zig");

test "run all tests" {
    std.testing.refAllDecls(@This());
}
