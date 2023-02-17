const std = @import("std");
pub const wasm = @import("wasm.zig");

test "run all tests" {
	std.testing.refAllDecls(@This());
}
