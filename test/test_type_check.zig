const std = @import("std");

const fusion = @import("fusion");
const type_check = fusion.type_check;

test "woah" {
    const p = type_check.PolyType{ .mono_type = .{ .type_variable = "foo" } };
    try std.testing.expectEqualStrings(p.mono_type.type_variable, "foo");
}
