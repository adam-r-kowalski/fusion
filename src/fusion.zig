const std = @import("std");
pub const web_assembly = @import("web_assembly.zig");

test "run all tests" {
    std.testing.refAllDecls(@This());
}
