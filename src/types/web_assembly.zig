pub const Type = enum {
    i32,
    i64,
    f32,
    f64,
    v128,
};

pub const Memory = struct {
    name: []const u8,
    initial: u32,
    max: ?u32 = null,
};

pub const Mutable = enum {
    mutable,
    immutable,
};

pub const Import = struct {
    path: [2][]const u8,
    kind: union(enum) {
        func: struct {
            name: []const u8,
            params: []const Type = &.{},
            results: []const Type = &.{},
        },
        global: struct {
            name: []const u8,
            type: Type,
            mut: Mutable = .immutable,
        },
        memory: Memory,
    },
};

const Value = union(enum) {
    i32: i32,
};

pub const Global = struct {
    name: []const u8,
    value: Value,
    mut: Mutable = .immutable,
};

pub const Data = struct {
    offset: u32,
    bytes: []const u8,
};

pub const Table = struct {
    name: []const u8,
    initial: u32,
    max: ?u32 = null,
};

pub const Elem = struct {
    offset: u32,
    name: []const u8,
};

pub const FuncType = struct {
    name: []const u8,
    params: []const Type = &.{},
    results: []const Type = &.{},
};

pub const Param = struct {
    name: []const u8,
    type: Type,
};

pub const Op = union(enum) {
    call: []const u8,
    call_indirect: []const u8,
    local: struct { name: []const u8, type: Type },
    local_get: []const u8,
    local_set: []const u8,
    local_tee: []const u8,
    global_get: []const u8,
    global_set: []const u8,
    i32_add,
    i32_lt_s,
    i32_eq,
    i32_const: i32,
    block: struct {
        name: []const u8,
        ops: []const Op,
    },
    loop: struct {
        name: []const u8,
        ops: []const Op,
    },
    if_: struct {
        then: []const Op,
        else_: []const Op = &.{},
    },
    br: []const u8,
    br_if: []const u8,
    unreachable_,
    select,
    nop,
    return_,
    drop,
};

pub const Local = struct {
    name: []const u8,
    type: Type,
};

pub const Func = struct {
    name: []const u8,
    params: []const Param = &.{},
    results: []const Type = &.{},
    ops: []const Op = &.{},
};

pub const Export = struct {
    name: []const u8,
    kind: union(enum) {
        func: []const u8,
        global: []const u8,
        memory: []const u8,
        table: []const u8,
    },
};

pub const TopLevel = union(enum) {
    import: Import,
    memory: Memory,
    global: Global,
    data: Data,
    table: Table,
    elem: Elem,
    functype: FuncType,
    func: Func,
    export_: Export,
    start: []const u8,
};
