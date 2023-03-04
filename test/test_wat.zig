const std = @import("std");
const fusion = @import("fusion");
const watAlloc = fusion.write.wat.watAlloc;

test "non exported function" {
    const allocator = std.testing.allocator;
    const module = &.{
        .{
            .func = .{
                .name = "add",
                .params = &.{ .{ "lhs", .i32 }, .{ "rhs", .i32 } },
                .results = &.{.i32},
                .ops = &.{
                    .{ .local_get = "lhs" },
                    .{ .local_get = "rhs" },
                    .i32_add,
                },
            },
        },
    };
    var actual = try watAlloc(module, allocator);
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
        .{
            .func = .{
                .name = "add",
                .params = &.{ .{ "lhs", .i32 }, .{ "rhs", .i32 } },
                .results = &.{.i32},
                .ops = &.{
                    .{ .local_get = "lhs" },
                    .{ .local_get = "rhs" },
                    .i32_add,
                },
            },
        },
        .{ .export_ = .{ "add", .{ .func = "add" } } },
    };
    var actual = try watAlloc(module, allocator);
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
        .{
            .func = .{
                .name = "add",
                .params = &.{ .{ "lhs", .i32 }, .{ "rhs", .i32 } },
                .results = &.{.i32},
                .ops = &.{
                    .{ .local_get = "lhs" },
                    .{ .local_get = "rhs" },
                    .i32_add,
                },
            },
        },
        .{ .export_ = .{ "myAdd", .{ .func = "add" } } },
    };
    var actual = try watAlloc(module, allocator);
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
        .{
            .func = .{
                .name = "getAnswer",
                .params = &.{},
                .results = &.{.i32},
                .ops = &.{.{ .i32_const = 42 }},
            },
        },
        .{
            .func = .{
                .name = "getAnswerPlus1",
                .params = &.{},
                .results = &.{.i32},
                .ops = &.{
                    .{ .call = "getAnswer" },
                    .{ .i32_const = 1 },
                    .i32_add,
                },
            },
        },
        .{ .export_ = .{ "getAnswerPlus1", .{ .func = "getAnswerPlus1" } } },
    };
    var actual = try watAlloc(module, allocator);
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
        .{ .import = .{ .{ "console", "log" }, .{ .func = .{ .name = "log", .params = &.{.i32} } } } },
        .{
            .func = .{
                .name = "logIt",
                .params = &.{},
                .results = &.{},
                .ops = &.{
                    .{ .i32_const = 13 },
                    .{ .call = "log" },
                },
            },
        },
        .{ .export_ = .{ "logIt", .{ .func = "logIt" } } },
    };
    var actual = try watAlloc(module, allocator);
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
        .{ .import = .{ .{ "js", "global" }, .{ .global = .{ "g", .mut, .i32 } } } },
        .{
            .func = .{
                .name = "getGlobal",
                .results = &.{.i32},
                .ops = &.{.{ .global_get = "g" }},
            },
        },
        .{
            .func = .{
                .name = "incGlobal",
                .ops = &.{
                    .{ .global_get = "g" },
                    .{ .i32_const = 1 },
                    .i32_add,
                    .{ .global_set = "g" },
                },
            },
        },
        .{ .export_ = .{ "getGlobal", .{ .func = "getGlobal" } } },
        .{ .export_ = .{ "incGlobal", .{ .func = "incGlobal" } } },
    };
    var actual = try watAlloc(module, allocator);
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
        .{ .global = .{ "g", .mut, .{ .i32 = 42 } } },
        .{
            .func = .{
                .name = "getGlobal",
                .results = &.{.i32},
                .ops = &.{.{ .global_get = "g" }},
            },
        },
        .{
            .func = .{
                .name = "incGlobal",
                .ops = &.{
                    .{ .global_get = "g" },
                    .{ .i32_const = 1 },
                    .i32_add,
                    .{ .global_set = "g" },
                },
            },
        },
        .{ .export_ = .{ "getGlobal", .{ .func = "getGlobal" } } },
        .{ .export_ = .{ "incGlobal", .{ .func = "incGlobal" } } },
    };
    var actual = try watAlloc(module, allocator);
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
        .{ .global = .{ "g", .immutable, .{ .i32 = 42 } } },
        .{
            .func = .{
                .name = "getGlobal",
                .results = &.{.i32},
                .ops = &.{.{ .global_get = "g" }},
            },
        },
        .{ .export_ = .{ "getGlobal", .{ .func = "getGlobal" } } },
    };
    var actual = try watAlloc(module, allocator);
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
        .{ .global = .{ "g", .mut, .{ .i32 = 42 } } },
        .{
            .func = .{
                .name = "getGlobal",
                .results = &.{.i32},
                .ops = &.{.{ .global_get = "g" }},
            },
        },
        .{
            .func = .{
                .name = "incGlobal",
                .ops = &.{
                    .{ .global_get = "g" },
                    .{ .i32_const = 1 },
                    .i32_add,
                    .{ .global_set = "g" },
                },
            },
        },
        .{ .export_ = .{ "getGlobal", .{ .func = "getGlobal" } } },
        .{ .export_ = .{ "incGlobal", .{ .func = "incGlobal" } } },
        .{ .export_ = .{ "g", .{ .global = "g" } } },
    };
    var actual = try watAlloc(module, allocator);
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
        .{ .import = .{ .{ "js", "log" }, .{ .func = .{ .name = "log", .params = &.{ .i32, .i32 } } } } },
        .{ .import = .{ .{ "js", "mem" }, .{ .memory = .{ "mem", 1 } } } },
        .{ .data = .{ 0, "Hi" } },
        .{
            .func = .{
                .name = "writeHi",
                .ops = &.{
                    .{ .i32_const = 0 },
                    .{ .i32_const = 2 },
                    .{ .call = "log" },
                },
            },
        },
        .{ .export_ = .{ "writeHi", .{ .func = "writeHi" } } },
    };
    var actual = try watAlloc(module, allocator);
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
        .{ .import = .{ .{ "js", "log" }, .{ .func = .{ .name = "log", .params = &.{ .i32, .i32 } } } } },
        .{ .memory = .{ "mem", 1 } },
        .{ .data = .{ 0, "Hi" } },
        .{
            .func = .{
                .name = "writeHi",
                .ops = &.{
                    .{ .i32_const = 0 },
                    .{ .i32_const = 2 },
                    .{ .call = "log" },
                },
            },
        },
        .{ .export_ = .{ "writeHi", .{ .func = "writeHi" } } },
    };
    var actual = try watAlloc(module, allocator);
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
        .{ .import = .{ .{ "js", "log" }, .{ .func = .{ .name = "log", .params = &.{ .i32, .i32 } } } } },
        .{ .memory = .{ "mem", 1 } },
        .{ .data = .{ 0, "Hi" } },
        .{
            .func = .{
                .name = "writeHi",
                .ops = &.{
                    .{ .i32_const = 0 },
                    .{ .i32_const = 2 },
                    .{ .call = "log" },
                },
            },
        },
        .{ .export_ = .{ "writeHi", .{ .func = "writeHi" } } },
        .{ .export_ = .{ "mem", .{ .memory = "mem" } } },
    };
    var actual = try watAlloc(module, allocator);
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
        .{ .import = .{ .{ "console", "log" }, .{ .func = .{ .name = "log", .params = &.{.i32} } } } },
        .{
            .func = .{
                .name = "logIt",
                .ops = &.{
                    .{ .i32_const = 13 },
                    .{ .call = "log" },
                },
            },
        },
        .{ .start = "logIt" },
    };
    var actual = try watAlloc(module, allocator);
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
        .{ .import = .{ .{ "console", "log" }, .{ .func = .{ .name = "log", .params = &.{.i32} } } } },
        .{
            .func = .{
                .name = "main",
                .ops = &.{
                    .{ .local = .{ .name = "var", .type = .i32 } },
                    .{ .i32_const = 10 },
                    .{ .local_set = "var" },
                    .{ .local_get = "var" },
                    .{ .call = "log" },
                },
            },
        },
        .{ .start = "main" },
    };
    var actual = try watAlloc(module, allocator);
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
        .{ .import = .{ .{ "console", "log" }, .{ .func = .{ .name = "log", .params = &.{.i32} } } } },
        .{
            .func = .{
                .name = "main",
                .ops = &.{
                    .{ .local = .{ .name = "var", .type = .i32 } },
                    .{ .i32_const = 10 },
                    .{ .local_tee = "var" },
                    .{ .call = "log" },
                },
            },
        },
        .{ .start = "main" },
    };
    var actual = try watAlloc(module, allocator);
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
        .{ .import = .{ .{ "console", "log" }, .{ .func = .{ .name = "log", .params = &.{.i32} } } } },
        .{
            .func = .{
                .name = "main",
                .ops = &.{
                    .{ .local = .{ .name = "i", .type = .i32 } },
                    .{
                        .loop = .{
                            "my_loop", &.{
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
                            },
                        },
                    },
                },
            },
        },
        .{ .start = "main" },
    };
    var actual = try watAlloc(module, allocator);
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
        .{ .import = .{ .{ "console", "log" }, .{ .func = .{ .name = "log", .params = &.{.i32} } } } },
        .{
            .func = .{
                .name = "main",
                .ops = &.{
                    .{ .i32_const = 0 },
                    .{
                        .if_ = .{
                            .then = &.{
                                .{ .i32_const = 1 },
                                .{ .call = "log" },
                            },
                            .else_ = &.{
                                .{ .i32_const = 0 },
                                .{ .call = "log" },
                            },
                        },
                    },
                },
            },
        },
        .{ .start = "main" },
    };
    var actual = try watAlloc(module, allocator);
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
        .{ .import = .{ .{ "console", "log" }, .{ .func = .{ .name = "log", .params = &.{.i32} } } } },
        .{
            .func = .{
                .name = "log_if_not_100",
                .params = &.{.{ "num", .i32 }},
                .ops = &.{
                    .{
                        .block = .{ "my_block", &.{
                            .{ .local_get = "num" },
                            .{ .i32_const = 100 },
                            .i32_eq,
                            .{ .if_ = .{ .then = &.{.{ .br = "my_block" }} } },
                            .{ .local_get = "num" },
                            .{ .call = "log" },
                        } },
                    },
                },
            },
        },
        .{ .export_ = .{ "log_if_not_100", .{ .func = "log_if_not_100" } } },
    };
    var actual = try watAlloc(module, allocator);
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

// test "unreachable" {
//     const allocator = std.testing.allocator;
//     const module = &.{
//         .{
//             .func = .{
//                 .name = "throw",
//                 .params = &.{},
//                 .results = &.{},
//                 .ops = &.{
//                     .unreachable_,
//                 },
//             },
//         },
//         .{ .export_ = .{ .name = "throw", .kind = .{ .func = "throw" } } },
//     };
//     var actual = try watAlloc(module, allocator);
//     defer allocator.free(actual);
//     const expected =
//         \\(module
//         \\
//         \\    (func $throw
//         \\        unreachable)
//         \\
//         \\    (export "throw" (func $throw)))
//     ;
//     try std.testing.expectEqualStrings(expected, actual);
// }
//
// test "select" {
//     const allocator = std.testing.allocator;
//     const module = &.{
//         .{
//             .import = .{
//                 .path = .{ "console", "log" },
//                 .kind = .{ .func = .{ .name = "log", .params = &.{.i32}, .results = &.{} } },
//             },
//         },
//         .{
//             .func = .{
//                 .name = "select_simple",
//                 .params = &.{},
//                 .results = &.{},
//                 .ops = &.{
//                     .{ .i32_const = 10 },
//                     .{ .i32_const = 20 },
//                     .{ .i32_const = 0 },
//                     .select,
//                     .{ .call = "log" },
//                 },
//             },
//         },
//         .{ .start = "select_simple" },
//     };
//     var actual = try watAlloc(module, allocator);
//     defer allocator.free(actual);
//     const expected =
//         \\(module
//         \\
//         \\    (import "console" "log" (func $log (param i32)))
//         \\
//         \\    (func $select_simple
//         \\        (i32.const 10)
//         \\        (i32.const 20)
//         \\        (i32.const 0)
//         \\        select
//         \\        (call $log))
//         \\
//         \\    (start $select_simple))
//     ;
//     try std.testing.expectEqualStrings(expected, actual);
// }
//
// test "nop" {
//     const allocator = std.testing.allocator;
//     const module = &.{
//         .{
//             .func = .{
//                 .name = "do_nothing",
//                 .params = &.{},
//                 .results = &.{},
//                 .ops = &.{
//                     .nop,
//                 },
//             },
//         },
//     };
//     var actual = try watAlloc(module, allocator);
//     defer allocator.free(actual);
//     const expected =
//         \\(module
//         \\
//         \\    (func $do_nothing
//         \\        nop))
//     ;
//     try std.testing.expectEqualStrings(expected, actual);
// }
//
// test "return" {
//     const allocator = std.testing.allocator;
//     const module = &.{
//         .{
//             .func = .{
//                 .name = "get_90",
//                 .params = &.{},
//                 .results = &.{.i32},
//                 .ops = &.{
//                     .{ .i32_const = 10 },
//                     .{ .i32_const = 90 },
//                     // return the second value (90); the first is discarded
//                     .return_,
//                 },
//             },
//         },
//     };
//     var actual = try watAlloc(module, allocator);
//     defer allocator.free(actual);
//     const expected =
//         \\(module
//         \\
//         \\    (func $get_90 (result i32)
//         \\        (i32.const 10)
//         \\        (i32.const 90)
//         \\        return))
//     ;
//     try std.testing.expectEqualStrings(expected, actual);
// }
//
// test "drop" {
//     const allocator = std.testing.allocator;
//     const module = &.{
//         .{
//             .import = .{
//                 .path = .{ "console", "log" },
//                 .kind = .{ .func = .{ .name = "log", .params = &.{.i32}, .results = &.{} } },
//             },
//         },
//         .{
//             .func = .{
//                 .name = "main",
//                 .params = &.{},
//                 .results = &.{},
//                 .ops = &.{
//                     .{ .i32_const = 10 },
//                     .{ .i32_const = 20 },
//                     .drop,
//                     .{ .call = "log" },
//                 },
//             },
//         },
//         .{ .start = "main" },
//     };
//     var actual = try watAlloc(module, allocator);
//     defer allocator.free(actual);
//     const expected =
//         \\(module
//         \\
//         \\    (import "console" "log" (func $log (param i32)))
//         \\
//         \\    (func $main
//         \\        (i32.const 10)
//         \\        (i32.const 20)
//         \\        drop
//         \\        (call $log))
//         \\
//         \\    (start $main))
//     ;
//     try std.testing.expectEqualStrings(expected, actual);
// }
//
// test "tables" {
//     const allocator = std.testing.allocator;
//     const module = &.{
//         .{ .table = .{ .name = "table", .initial = 2 } },
//         .{
//             .func = .{
//                 .name = "f",
//                 .params = &.{},
//                 .results = &.{.i32},
//                 .ops = &.{.{ .i32_const = 42 }},
//             },
//         },
//         .{
//             .func = .{
//                 .name = "g",
//                 .params = &.{},
//                 .results = &.{.i32},
//                 .ops = &.{.{ .i32_const = 13 }},
//             },
//         },
//         .{ .elem = .{ .offset = 0, .name = "f" } },
//         .{ .elem = .{ .offset = 1, .name = "g" } },
//         .{ .functype = .{ .name = "return_i32", .params = &.{}, .results = &.{.i32} } },
//         .{
//             .func = .{
//                 .name = "callByIndex",
//                 .params = &.{.{ .name = "i", .type = .i32 }},
//                 .results = &.{.i32},
//                 .ops = &.{
//                     .{ .local_get = "i" },
//                     .{ .call_indirect = "return_i32" },
//                 },
//             },
//         },
//     };
//     var actual = try watAlloc(module, allocator);
//     defer allocator.free(actual);
//     const expected =
//         \\(module
//         \\
//         \\    (table $table 2 funcref)
//         \\
//         \\    (func $f (result i32)
//         \\        (i32.const 42))
//         \\
//         \\    (func $g (result i32)
//         \\        (i32.const 13))
//         \\
//         \\    (elem (i32.const 0) $f)
//         \\
//         \\    (elem (i32.const 1) $g)
//         \\
//         \\    (type $return_i32 (func (result i32)))
//         \\
//         \\    (func $callByIndex (param $i i32) (result i32)
//         \\        (local.get $i)
//         \\        (call_indirect (type $return_i32))))
//     ;
//     try std.testing.expectEqualStrings(expected, actual);
// }
//
// test "export table" {
//     const allocator = std.testing.allocator;
//     const module = &.{
//         .{ .table = .{ .name = "table", .initial = 2 } },
//         .{
//             .func = .{
//                 .name = "f",
//                 .params = &.{},
//                 .results = &.{.i32},
//                 .ops = &.{.{ .i32_const = 42 }},
//             },
//         },
//         .{
//             .func = .{
//                 .name = "g",
//                 .params = &.{},
//                 .results = &.{.i32},
//                 .ops = &.{.{ .i32_const = 13 }},
//             },
//         },
//         .{ .elem = .{ .offset = 0, .name = "f" } },
//         .{ .elem = .{ .offset = 1, .name = "g" } },
//         .{ .functype = .{ .name = "return_i32", .params = &.{}, .results = &.{.i32} } },
//         .{
//             .func = .{
//                 .name = "callByIndex",
//                 .params = &.{.{ .name = "i", .type = .i32 }},
//                 .results = &.{.i32},
//                 .ops = &.{
//                     .{ .local_get = "i" },
//                     .{ .call_indirect = "return_i32" },
//                 },
//             },
//         },
//         .{ .export_ = .{ .name = "table", .kind = .{ .table = "table" } } },
//     };
//     var actual = try watAlloc(module, allocator);
//     defer allocator.free(actual);
//     const expected =
//         \\(module
//         \\
//         \\    (table $table 2 funcref)
//         \\
//         \\    (func $f (result i32)
//         \\        (i32.const 42))
//         \\
//         \\    (func $g (result i32)
//         \\        (i32.const 13))
//         \\
//         \\    (elem (i32.const 0) $f)
//         \\
//         \\    (elem (i32.const 1) $g)
//         \\
//         \\    (type $return_i32 (func (result i32)))
//         \\
//         \\    (func $callByIndex (param $i i32) (result i32)
//         \\        (local.get $i)
//         \\        (call_indirect (type $return_i32)))
//         \\
//         \\    (export "table" (table $table)))
//     ;
//     try std.testing.expectEqualStrings(expected, actual);
// }
