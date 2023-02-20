const std = @import("std");
const fusion = @import("fusion");
const allocWat = fusion.web_assembly.allocWat;
const p = fusion.web_assembly.param;
const global = fusion.web_assembly.global;
const func = fusion.web_assembly.func;
const data = fusion.web_assembly.data;
const memory = fusion.web_assembly.memory;
const start = fusion.web_assembly.start;
const local = fusion.web_assembly.local;
const loop = fusion.web_assembly.loop;
const block = fusion.web_assembly.block;
const when = fusion.web_assembly.when;
const if_ = fusion.web_assembly.if_;
const Module = fusion.web_assembly.Module;
const importGlobal = fusion.web_assembly.importGlobal;
const importFunc = fusion.web_assembly.importFunc;
const importMemory = fusion.web_assembly.importMemory;
const exportGlobal = fusion.web_assembly.exportGlobal;
const exportFunc = fusion.web_assembly.exportFunc;
const exportMemory = fusion.web_assembly.exportMemory;

test "non exported function" {
    const allocator = std.testing.allocator;
    const module = &.{
        func("add", &.{ p("lhs", .i32), p("rhs", .i32) }, &.{.i32}, &.{
            .{ .local_get = "lhs" },
            .{ .local_get = "rhs" },
            .i32_add,
        }),
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $add (param $lhs i32) (param $rhs i32) (result i32)
        \\        (local.get $lhs)
        \\        (local.get $rhs)
        \\        i32.add))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "exported function" {
    const allocator = std.testing.allocator;
    const module = &.{
        func("add", &.{ p("lhs", .i32), p("rhs", .i32) }, &.{.i32}, &.{
            .{ .local_get = "lhs" },
            .{ .local_get = "rhs" },
            .i32_add,
        }),
        exportFunc("add", .{}),
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $add (param $lhs i32) (param $rhs i32) (result i32)
        \\        (local.get $lhs)
        \\        (local.get $rhs)
        \\        i32.add)
        \\
        \\    (export "add" (func $add)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "exported function with new name" {
    const allocator = std.testing.allocator;
    const module = &.{
        func("add", &.{ p("lhs", .i32), p("rhs", .i32) }, &.{.i32}, &.{
            .{ .local_get = "lhs" },
            .{ .local_get = "rhs" },
            .i32_add,
        }),
        exportFunc("add", .{ .as = "myAdd" }),
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $add (param $lhs i32) (param $rhs i32) (result i32)
        \\        (local.get $lhs)
        \\        (local.get $rhs)
        \\        i32.add)
        \\
        \\    (export "myAdd" (func $add)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "function call" {
    const allocator = std.testing.allocator;
    const module = &.{
        func("getAnswer", &.{}, &.{.i32}, &.{
            .{ .i32_const = 42 },
        }),
        func("getAnswerPlus1", &.{}, &.{.i32}, &.{
            .{ .call = "getAnswer" },
            .{ .i32_const = 1 },
            .i32_add,
        }),
        exportFunc("getAnswerPlus1", .{}),
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $getAnswer (result i32)
        \\        (i32.const 42))
        \\
        \\    (func $getAnswerPlus1 (result i32)
        \\        (call $getAnswer)
        \\        (i32.const 1)
        \\        i32.add)
        \\
        \\    (export "getAnswerPlus1" (func $getAnswerPlus1)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "import function" {
    const allocator = std.testing.allocator;
    const module = &.{
        importFunc(.{ "console", "log" }, "log", &.{.i32}, &.{}),
        func("logIt", &.{}, &.{}, &.{
            .{ .i32_const = 13 },
            .{ .call = "log" },
        }),
        exportFunc("logIt", .{}),
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (import "console" "log" (func $log (param i32)))
        \\
        \\    (func $logIt
        \\        (i32.const 13)
        \\        (call $log))
        \\
        \\    (export "logIt" (func $logIt)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "import global variable" {
    const allocator = std.testing.allocator;
    const module = &.{
        importGlobal(.{ "js", "global" }, "g", .i32, .mutable),
        func("getGlobal", &.{}, &.{.i32}, &.{
            .{ .global_get = "g" },
        }),
        func("incGlobal", &.{}, &.{}, &.{
            .{ .global_get = "g" },
            .{ .i32_const = 1 },
            .i32_add,
            .{ .global_set = "g" },
        }),
        exportFunc("getGlobal", .{}),
        exportFunc("incGlobal", .{}),
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (import "js" "global" (global $g (mut i32)))
        \\
        \\    (func $getGlobal (result i32)
        \\        (global.get $g))
        \\
        \\    (func $incGlobal
        \\        (global.get $g)
        \\        (i32.const 1)
        \\        i32.add
        \\        (global.set $g))
        \\
        \\    (export "getGlobal" (func $getGlobal))
        \\
        \\    (export "incGlobal" (func $incGlobal)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "module only global variable" {
    const allocator = std.testing.allocator;
    const module = &.{
        global("g", .{ .i32 = 42 }, .mutable),
        func("getGlobal", &.{}, &.{.i32}, &.{
            .{ .global_get = "g" },
        }),
        func("incGlobal", &.{}, &.{}, &.{
            .{ .global_get = "g" },
            .{ .i32_const = 1 },
            .i32_add,
            .{ .global_set = "g" },
        }),
        exportFunc("getGlobal", .{}),
        exportFunc("incGlobal", .{}),
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (global $g (mut i32) (i32.const 42))
        \\
        \\    (func $getGlobal (result i32)
        \\        (global.get $g))
        \\
        \\    (func $incGlobal
        \\        (global.get $g)
        \\        (i32.const 1)
        \\        i32.add
        \\        (global.set $g))
        \\
        \\    (export "getGlobal" (func $getGlobal))
        \\
        \\    (export "incGlobal" (func $incGlobal)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "immutable global variable" {
    const allocator = std.testing.allocator;
    const module = &.{
        global("g", .{ .i32 = 42 }, .immutable),
        func("getGlobal", &.{}, &.{.i32}, &.{
            .{ .global_get = "g" },
        }),
        exportFunc("getGlobal", .{}),
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (global $g i32 (i32.const 42))
        \\
        \\    (func $getGlobal (result i32)
        \\        (global.get $g))
        \\
        \\    (export "getGlobal" (func $getGlobal)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "export global variable" {
    const allocator = std.testing.allocator;
    const module = &.{
        global("g", .{ .i32 = 42 }, .mutable),
        func("getGlobal", &.{}, &.{.i32}, &.{
            .{ .global_get = "g" },
        }),
        func("incGlobal", &.{}, &.{}, &.{
            .{ .global_get = "g" },
            .{ .i32_const = 1 },
            .i32_add,
            .{ .global_set = "g" },
        }),
        exportFunc("getGlobal", .{}),
        exportFunc("incGlobal", .{}),
        exportGlobal("g", .{}),
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (global $g (mut i32) (i32.const 42))
        \\
        \\    (func $getGlobal (result i32)
        \\        (global.get $g))
        \\
        \\    (func $incGlobal
        \\        (global.get $g)
        \\        (i32.const 1)
        \\        i32.add
        \\        (global.set $g))
        \\
        \\    (export "getGlobal" (func $getGlobal))
        \\
        \\    (export "incGlobal" (func $incGlobal))
        \\
        \\    (export "g" (global $g)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "import memory" {
    const allocator = std.testing.allocator;
    const module = &.{
        importFunc(.{ "js", "log" }, "log", &.{ .i32, .i32 }, &.{}),
        importMemory(.{ "js", "mem" }, "mem", 1),
        data(0, "Hi"),
        func("writeHi", &.{}, &.{}, &.{
            .{ .i32_const = 0 },
            .{ .i32_const = 2 },
            .{ .call = "log" },
        }),
        exportFunc("writeHi", .{}),
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (import "js" "log" (func $log (param i32 i32)))
        \\
        \\    (import "js" "mem" (memory $mem 1))
        \\
        \\    (data (i32.const 0) "Hi")
        \\
        \\    (func $writeHi
        \\        (i32.const 0)
        \\        (i32.const 2)
        \\        (call $log))
        \\
        \\    (export "writeHi" (func $writeHi)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "module only memory" {
    const allocator = std.testing.allocator;
    const module = &.{
        importFunc(.{ "js", "log" }, "log", &.{ .i32, .i32 }, &.{}),
        memory("mem", 1),
        data(0, "Hi"),
        func("writeHi", &.{}, &.{}, &.{
            .{ .i32_const = 0 },
            .{ .i32_const = 2 },
            .{ .call = "log" },
        }),
        exportFunc("writeHi", .{}),
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (import "js" "log" (func $log (param i32 i32)))
        \\
        \\    (memory $mem 1)
        \\
        \\    (data (i32.const 0) "Hi")
        \\
        \\    (func $writeHi
        \\        (i32.const 0)
        \\        (i32.const 2)
        \\        (call $log))
        \\
        \\    (export "writeHi" (func $writeHi)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "export memory" {
    const allocator = std.testing.allocator;
    const module = &.{
        importFunc(.{ "js", "log" }, "log", &.{ .i32, .i32 }, &.{}),
        memory("mem", 1),
        data(0, "Hi"),
        func("writeHi", &.{}, &.{}, &.{
            .{ .i32_const = 0 },
            .{ .i32_const = 2 },
            .{ .call = "log" },
        }),
        exportFunc("writeHi", .{}),
        exportMemory("mem", .{}),
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (import "js" "log" (func $log (param i32 i32)))
        \\
        \\    (memory $mem 1)
        \\
        \\    (data (i32.const 0) "Hi")
        \\
        \\    (func $writeHi
        \\        (i32.const 0)
        \\        (i32.const 2)
        \\        (call $log))
        \\
        \\    (export "writeHi" (func $writeHi))
        \\
        \\    (export "mem" (memory $mem)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "start function" {
    const allocator = std.testing.allocator;
    const module = &.{
        importFunc(.{ "console", "log" }, "log", &.{.i32}, &.{}),
        func("logIt", &.{}, &.{}, &.{
            .{ .i32_const = 13 },
            .{ .call = "log" },
        }),
        start("logIt"),
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (import "console" "log" (func $log (param i32)))
        \\
        \\    (func $logIt
        \\        (i32.const 13)
        \\        (call $log))
        \\
        \\    (start $logIt))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "local variables" {
    const allocator = std.testing.allocator;
    const module = &.{
        importFunc(.{ "console", "log" }, "log", &.{.i32}, &.{}),
        func("main", &.{}, &.{}, &.{
            local("var", .i32),
            .{ .i32_const = 10 },
            .{ .local_set = "var" },
            .{ .local_get = "var" },
            .{ .call = "log" },
        }),
        start("main"),
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (import "console" "log" (func $log (param i32)))
        \\
        \\    (func $main
        \\        (local $var i32)
        \\        (i32.const 10)
        \\        (local.set $var)
        \\        (local.get $var)
        \\        (call $log))
        \\
        \\    (start $main))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "tee local variable" {
    const allocator = std.testing.allocator;
    const module = &.{
        importFunc(.{ "console", "log" }, "log", &.{.i32}, &.{}),
        func("main", &.{}, &.{}, &.{
            local("var", .i32),
            .{ .i32_const = 10 },
            .{ .local_tee = "var" },
            .{ .call = "log" },
        }),
        start("main"),
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (import "console" "log" (func $log (param i32)))
        \\
        \\    (func $main
        \\        (local $var i32)
        \\        (i32.const 10)
        \\        (local.tee $var)
        \\        (call $log))
        \\
        \\    (start $main))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "loop" {
    const allocator = std.testing.allocator;
    const module = &.{
        importFunc(.{ "console", "log" }, "log", &.{.i32}, &.{}),
        func("main", &.{}, &.{}, &.{
            local("i", .i32),
            loop("my_loop", &.{
                // increment i
                .{ .local_get = "i" },
                .{ .i32_const = 1 },
                .i32_add,
                .{ .local_set = "i" },
                // log i
                .{ .local_get = "i" },
                .{ .call = "log" },
                // if i < 10 then loop
                .{ .local_get = "i" },
                .{ .i32_const = 10 },
                .i32_lt_s,
                .{ .br_if = "my_loop" },
            }),
        }),
        start("main"),
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (import "console" "log" (func $log (param i32)))
        \\
        \\    (func $main
        \\        (local $i i32)
        \\        (loop $my_loop
        \\            (local.get $i)
        \\            (i32.const 1)
        \\            i32.add
        \\            (local.set $i)
        \\            (local.get $i)
        \\            (call $log)
        \\            (local.get $i)
        \\            (i32.const 10)
        \\            i32.lt_s
        \\            (br_if $my_loop)))
        \\
        \\    (start $main))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "if then else" {
    const allocator = std.testing.allocator;
    const module = &.{
        importFunc(.{ "console", "log" }, "log", &.{.i32}, &.{}),
        func("main", &.{}, &.{}, &.{
            .{ .i32_const = 0 },
            if_(&.{
                .{ .i32_const = 1 },
                .{ .call = "log" },
            }, &.{
                .{ .i32_const = 0 },
                .{ .call = "log" },
            }),
        }),
        start("main"),
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (import "console" "log" (func $log (param i32)))
        \\
        \\    (func $main
        \\        (i32.const 0)
        \\        (if
        \\            (then
        \\                (i32.const 1)
        \\                (call $log))
        \\            (else
        \\                (i32.const 0)
        \\                (call $log))))
        \\
        \\    (start $main))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "block" {
    const allocator = std.testing.allocator;
    const module = &.{
        importFunc(.{ "console", "log" }, "log", &.{.i32}, &.{}),
        func("log_if_not_100", &.{p("num", .i32)}, &.{}, &.{
            block("my_block", &.{
                .{ .local_get = "num" },
                .{ .i32_const = 100 },
                .i32_eq,
                when(&.{
                    .{ .br = "my_block" },
                }),
                .{ .local_get = "num" },
                .{ .call = "log" },
            }),
        }),
        exportFunc("log_if_not_100", .{}),
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (import "console" "log" (func $log (param i32)))
        \\
        \\    (func $log_if_not_100 (param $num i32)
        \\        (block $my_block
        \\            (local.get $num)
        \\            (i32.const 100)
        \\            i32.eq
        \\            (if
        \\                (then
        \\                    (br $my_block)))
        \\            (local.get $num)
        \\            (call $log)))
        \\
        \\    (export "log_if_not_100" (func $log_if_not_100)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "unreachable" {
    const allocator = std.testing.allocator;
    const module = Module{
        .funcs = &.{
            .{
                .name = "throw",
                .ops = &.{.unreachable_},
            },
        },
        .exports = &.{
            .{ .name = "throw", .kind = .{ .func = "throw" } },
        },
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $throw
        \\        unreachable)
        \\
        \\    (export "throw" (func $throw)))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "select" {
    const allocator = std.testing.allocator;
    const module = Module{
        .imports = &.{
            .{
                .module = "console",
                .name = "log",
                .kind = .{ .func = .{ .name = "log", .params = &.{.i32} } },
            },
        },
        .funcs = &.{
            .{
                .name = "select_simple",
                .ops = &.{
                    .{ .i32_const = 10 },
                    .{ .i32_const = 20 },
                    .{ .i32_const = 0 },
                    .select,
                    .{ .call = "log" },
                },
            },
        },
        .start = "select_simple",
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (import "console" "log" (func $log (param i32)))
        \\
        \\    (func $select_simple
        \\        (i32.const 10)
        \\        (i32.const 20)
        \\        (i32.const 0)
        \\        select
        \\        (call $log))
        \\
        \\    (start $select_simple))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "nop" {
    const allocator = std.testing.allocator;
    const module = Module{
        .funcs = &.{
            .{
                .name = "do_nothing",
                .ops = &.{.nop},
            },
        },
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $do_nothing
        \\        nop))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "return" {
    const allocator = std.testing.allocator;
    const module = Module{
        .funcs = &.{
            .{
                .name = "get_90",
                .results = &.{.i32},
                .ops = &.{
                    .{ .i32_const = 10 },
                    .{ .i32_const = 90 },
                    // return the second value (90); the first is discarded
                    .return_,
                },
            },
        },
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (func $get_90 (result i32)
        \\        (i32.const 10)
        \\        (i32.const 90)
        \\        return))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}

test "drop" {
    const allocator = std.testing.allocator;
    const module = Module{
        .imports = &.{
            .{
                .module = "console",
                .name = "log",
                .kind = .{ .func = .{ .name = "log", .params = &.{.i32} } },
            },
        },
        .funcs = &.{
            .{
                .name = "main",
                .ops = &.{
                    .{ .i32_const = 10 },
                    .{ .i32_const = 20 },
                    .drop,
                    .{ .call = "log" },
                },
            },
        },
        .start = "main",
    };
    var actual = try allocWat(module, allocator);
    defer allocator.free(actual);
    const expected =
        \\(module
        \\
        \\    (import "console" "log" (func $log (param i32)))
        \\
        \\    (func $main
        \\        (i32.const 10)
        \\        (i32.const 20)
        \\        drop
        \\        (call $log))
        \\
        \\    (start $main))
    ;
    try std.testing.expectEqualStrings(expected, actual);
}
