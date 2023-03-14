const std = @import("std");
const Allocator = std.mem.Allocator;
const Tuple = std.meta.Tuple;

pub const TypeFunctionApplication = struct {
    func: []const u8,
    args: []const MonoType,
};

const TypeVariable = []const u8;

pub const MonoType = union(enum) {
    type_variable: TypeVariable,
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

pub const Context = std.StringHashMap(PolyType);

pub const Substitution = std.StringHashMap(MonoType);

pub fn makeContext(a: Allocator, entries: []const Tuple(&.{ []const u8, PolyType })) !Context {
    var context = Context.init(a);
    for (entries) |entry| {
        try context.put(entry[0], entry[1]);
    }
    return context;
}

pub fn makeSubstitution(a: Allocator, entries: []const Tuple(&.{ []const u8, MonoType })) !Substitution {
    var substitution = Substitution.init(a);
    for (entries) |entry| {
        try substitution.put(entry[0], entry[1]);
    }
    return substitution;
}

fn applyToContext(a: Allocator, s: Substitution, c: Context) !Context {
    var new_context = Context.init(a);
    var iterator = c.iterator();
    while (iterator.next()) |entry| {
        try new_context.put(entry.key, applyToPolyType(a, s, entry.value));
    }
    return new_context;
}

pub fn applyToMonoType(a: Allocator, s: Substitution, m: MonoType) !MonoType {
    switch (m) {
        .type_variable => |v| {
            if (s.get(v)) |t| return t;
            return m;
        },
        .type_function_application => |f| {
            const args = try a.alloc(MonoType, f.args.len);
            for (f.args) |arg, i| {
                args[i] = try applyToMonoType(a, s, arg);
            }
            return .{ .type_function_application = .{ .func = f.func, .args = args } };
        },
    }
}

fn applyToPolyType(a: Allocator, s: Substitution, t: PolyType) PolyType {
    return switch (t) {
        .mono_type => |m| .{ .mono_type = applyToMonoType(a, s, m) },
        .type_quantifier => |q| .{
            .type_quantifier = .{ .name = q.name, .sigma = applyToPolyType(a, s, q.sigma) },
        },
    };
}

pub fn combine(a: Allocator, s1: Substitution, s2: Substitution) !Substitution {
    var s = try s1.cloneWithAllocator(a);
    var iterator = s2.iterator();
    while (iterator.next()) |entry| {
        const value = try applyToMonoType(a, s1, entry.value_ptr.*);
        try s.put(entry.key_ptr.*, value);
    }
    return s;
}

pub const Mappings = std.StringHashMap(TypeVariable);

pub const Fresh = struct {
    a: Allocator,
    current: u64,
};

fn newTypeVar(fresh: *Fresh) ![]const u8 {
    const name = try std.fmt.allocPrint(fresh.a, "{}", .{fresh.current});
    fresh.current += 1;
    return name;
}

pub fn instantiate(a: Allocator, t: PolyType, m: *Mappings, f: *Fresh) !MonoType {
    switch (t) {
        .mono_type => |mono| {
            switch (mono) {
                .type_variable => |v| {
                    if (m.get(v)) |value| return .{ .type_variable = value };
                    return mono;
                },
                .type_function_application => |app| {
                    const args = try a.alloc(MonoType, app.args.len);
                    for (app.args) |arg, i| {
                        args[i] = try instantiate(a, .{ .mono_type = arg }, m, f);
                    }
                    return .{ .type_function_application = .{ .func = app.func, .args = args } };
                },
            }
        },
        .type_quantifier => |q| {
            const b = try newTypeVar(f);
            try m.put(q.name, b);
            return try instantiate(a, q.sigma.*, m, f);
        },
    }
}
