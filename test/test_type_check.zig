const std = @import("std");
const expectEqualStrings = std.testing.expectEqualStrings;
const Allocator = std.mem.Allocator;

const fusion = @import("fusion");
const type_check = fusion.type_check;
const makeContext = type_check.makeContext;
const makeSubstitution = type_check.makeSubstitution;
const MonoType = type_check.MonoType;
const applyToMonoType = type_check.applyToMonoType;
const combine = type_check.combine;

const Indent = usize;

fn indent(writer: anytype, i: Indent) !void {
    try writer.writeAll("\n");
    var j: usize = 0;
    while (j < i) : (j += 1) {
        try writer.writeAll("    ");
    }
}

fn writeMonoType(writer: anytype, m: MonoType, i: Indent) !void {
    try indent(writer, i);
    try writer.writeAll(".{");
    try indent(writer, i + 1);
    switch (m) {
        .type_variable => |v| try std.fmt.format(writer, ".type_variable = \"{s}\"", .{v}),
        .type_function_application => |f| {
            try writer.writeAll(".type_function_application = .{");
            try indent(writer, i + 2);
            try std.fmt.format(writer, ".func = \"{s}\",", .{f.func});
            try indent(writer, i + 2);
            try writer.writeAll(".args = &.{");
            if (f.args.len > 0) {
                for (f.args) |arg| {
                    try writeMonoType(writer, arg, i + 3);
                }
                try indent(writer, i + 2);
            }
            try writer.writeAll("},");
            try indent(writer, i + 1);
            try writer.writeAll("},");
        },
    }
    try indent(writer, i);
    try writer.writeAll("},");
}

fn writeMonoTypeAlloc(m: MonoType, a: Allocator) ![]const u8 {
    var list = std.ArrayList(u8).init(a);
    const writer = list.writer();
    try writer.writeAll("\n");
    try writeMonoType(writer, m, 0);
    return list.toOwnedSlice();
}

fn expectEqualMonoTypes(expected: MonoType, actual: MonoType) !void {
    const allocator = std.testing.allocator;
    const actualString = try writeMonoTypeAlloc(actual, allocator);
    defer allocator.free(actualString);
    const expectedString = try writeMonoTypeAlloc(expected, allocator);
    defer allocator.free(expectedString);
    try std.testing.expectEqualStrings(expectedString, actualString);
}

test "make context" {
    const allocator = std.testing.allocator;
    var context = try makeContext(allocator, &.{
        .{ "foo", .{ .mono_type = .{ .type_variable = "var" } } },
    });
    defer context.deinit();
    const foo = context.get("foo").?;
    try expectEqualStrings(foo.mono_type.type_variable, "var");
}

test "apply substitution to type variable" {
    const a = std.testing.allocator;
    var s = try makeSubstitution(a, &.{
        .{ "x", .{ .type_variable = "y" } },
    });
    defer s.deinit();
    const m = try applyToMonoType(a, s, .{ .type_variable = "x" });
    try expectEqualStrings(m.type_variable, "y");
}

test "apply substitution to non matching type variable" {
    const a = std.testing.allocator;
    var s = try makeSubstitution(a, &.{
        .{ "a", .{ .type_variable = "y" } },
    });
    defer s.deinit();
    const m = try applyToMonoType(a, s, .{ .type_variable = "x" });
    try expectEqualStrings(m.type_variable, "x");
}

test "apply substitution to type function application" {
    const a = std.testing.allocator;
    var s = try makeSubstitution(a, &.{
        .{ "x", .{ .type_variable = "y" } },
    });
    defer s.deinit();
    const actual = try applyToMonoType(a, s, .{
        .type_function_application = .{
            .func = "->",
            .args = &.{
                .{ .type_function_application = .{ .func = "Bool", .args = &.{} } },
                .{ .type_variable = "x" },
            },
        },
    });
    defer a.free(actual.type_function_application.args);
    const expected: MonoType = .{
        .type_function_application = .{
            .func = "->",
            .args = &.{
                .{ .type_function_application = .{ .func = "Bool", .args = &.{} } },
                .{ .type_variable = "y" },
            },
        },
    };
    try expectEqualMonoTypes(expected, actual);
}

test "apply substitution to mono type creating a type function application" {
    const a = std.testing.allocator;
    var s = try makeSubstitution(a, &.{
        .{ "x", .{ .type_function_application = .{ .func = "Bool", .args = &.{} } } },
    });
    defer s.deinit();
    const actual = try applyToMonoType(a, s, .{ .type_variable = "x" });
    const expected = .{ .type_function_application = .{ .func = "Bool", .args = &.{} } };
    try expectEqualMonoTypes(expected, actual);
}

test "combine substitutions" {
    const a = std.testing.allocator;
    var s1 = try makeSubstitution(a, &.{.{ "y", .{ .type_variable = "z" } }});
    defer s1.deinit();
    var s2 = try makeSubstitution(a, &.{.{ "x", .{ .type_variable = "y" } }});
    defer s2.deinit();
    var s = try combine(a, s1, s2);
    defer s.deinit();
    const actual = try applyToMonoType(a, s, .{ .type_variable = "x" });
    const expected = .{ .type_variable = "z" };
    try expectEqualMonoTypes(expected, actual);
}

test "combine function application substitutions" {
    const a = std.testing.allocator;
    var s1 = try makeSubstitution(a, &.{.{ "x", .{ .type_variable = "y" } }});
    defer s1.deinit();
    var s2 = try makeSubstitution(a, &.{
        .{
            "z", .{
                .type_function_application = .{
                    .func = "->",
                    .args = &.{
                        .{ .type_function_application = .{ .func = "Bool", .args = &.{} } },
                        .{ .type_variable = "x" },
                    },
                },
            },
        },
    });
    defer s2.deinit();
    var s = try combine(a, s1, s2);
    defer s.deinit();
    const actual = try applyToMonoType(a, s, .{ .type_variable = "z" });
    defer a.free(actual.type_function_application.args);
    const expected = .{
        .type_function_application = .{
            .func = "->",
            .args = &.{
                .{ .type_function_application = .{ .func = "Bool", .args = &.{} } },
                .{ .type_variable = "y" },
            },
        },
    };
    try expectEqualMonoTypes(expected, actual);
}
