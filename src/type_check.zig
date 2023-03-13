const std = @import("std");

pub const TypeFunctionApplication = struct {
    func: []const u8,
    args: []const MonoType,
};

pub const MonoType = union(enum) {
    type_variable: []const u8,
    type_function_application: TypeFunctionApplication,
};

pub const TypeQuantifier = struct {
    name: []const u8,
    sigma: *const PolyType,
};

pub const PolyType = union(enum) {
    mono_type: MonoType,
    type_quantifier: TypeQuantifier,
};

pub const Context = u8;

pub const Substitution = struct {
    raw: std.StringHashMap(MonoType),
};
