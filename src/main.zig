const std = @import("std");
const fusion = @import("fusion");

pub fn main() void {}

test "run all tests" {
	std.testing.refAllDecls(fusion);
}
