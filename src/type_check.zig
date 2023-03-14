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

const Mappings = std.StringHashMap(TypeVariable);

pub const Fresh = struct {
    current: u64,
};

fn newTypeVar(a: Allocator, fresh: *Fresh) ![]const u8 {
    const name = try std.fmt.allocPrint(a, "{}", .{fresh.current});
    fresh.current += 1;
    return name;
}

pub fn instantiateImpl(a: Allocator, t: PolyType, m: *Mappings, f: *Fresh) !MonoType {
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
                        args[i] = try instantiateImpl(a, .{ .mono_type = arg }, m, f);
                    }
                    return .{ .type_function_application = .{ .func = app.func, .args = args } };
                },
            }
        },
        .type_quantifier => |q| {
            const b = try newTypeVar(a, f);
            try m.put(q.name, b);
            return try instantiateImpl(a, q.sigma.*, m, f);
        },
    }
}

pub fn instantiate(a: Allocator, t: PolyType, f: *Fresh) !MonoType {
    var m = Mappings.init(a);
    defer m.deinit();
    return instantiateImpl(a, t, &m, f);
}

pub fn diff(a: Allocator, x: []const []const u8, y: []const []const u8) ![][]const u8 {
    var m = std.StringHashMap(void).init(a);
    defer m.deinit();
    for (y) |e| try m.put(e, {});
    var result = std.ArrayList([]const u8).init(a);
    for (x) |e| {
        if (m.contains(e)) continue;
        try result.append(e);
    }
    return result.toOwnedSlice();
}

fn freeVarsMonoTypeImpl(a: std.ArrayList([]const u8), m: MonoType) !void {
    switch (m) {
        .type_variable => |v| try a.append(v),
        .type_function_application => |f| {
            for (f.args) |arg| try freeVarsMonoTypeImpl(a, arg);
        },
    }
}

fn freeVarsContextImpl(a: std.ArrayList([]const u8), c: Context) !void {
    var iterator = c.valueIterator();
    while (iterator.next()) |p| try freeVarsPolyType(a, p);
}

fn freeVarsPolyTypeImpl(a: std.ArrayList([]const u8), p: PolyType) !void {
    switch (p) {
        .mono_type => |m| try freeVarsMonoTypeImpl(a, m),
        .type_quantifier => |q| {
            const result = std.ArrayList([]const u8).init(a.allocator);
            defer result.deinit();
            freeVarsPolyTypeImpl(result, q.sigma);
            for (result) |v| if (v != q.name) try a.append(v);
        },
    }
}

fn freeVarsMonoType(a: Allocator, m: MonoType) ![][]const u8 {
    var result = std.ArrayList([]const u8).init(a);
    try freeVarsMonoTypeImpl(result, m);
    return result.toOwnedSlice();
}

fn freeVarsPolyType(a: Allocator, p: PolyType) ![][]const u8 {
    var result = std.ArrayList([]const u8).init(a);
    try freeVarsPolyTypeImpl(result, p);
    return result.toOwnedSlice();
}

fn freeVarsContext(a: Allocator, c: Context) ![][]const u8 {
    var result = std.ArrayList([]const u8).init(a);
    try freeVarsContextImpl(result, c);
    return result.toOwnedSlice();
}

pub fn generalise(a: Allocator, c: Context, m: MonoType) PolyType {
    const quantifiers = diff(freeVarsMonoType(m), freeVarsContext(c));
    var p: PolyType = .{ .mono_type = m };
    for (quantifiers) |q| {
        const sigma = try a.create(PolyType);
        sigma.* = p;
        p = .{ .type_quantifier = .{ .name = q, .sigma = sigma } };
    }
    return p;
}
