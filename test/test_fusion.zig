const std = @import("std");
pub const web_assembly = @import("test_web_assembly.zig");

test "run all tests" {
    std.testing.refAllDecls(@This());
}
