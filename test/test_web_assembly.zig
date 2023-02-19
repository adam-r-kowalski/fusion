const std = @import("std");
const fusion = @import("fusion");
const Module = fusion.web_assembly.Module;
const allocWat = fusion.web_assembly.allocWat;

test "non exported function" {
    const allocator = std.testing.allocator;
    const module = Module{
        .functions = &.{
            .{
                .name = "add",
                .parameters = &.{
                    .{ .name = "lhs", .type = .i32 },
                    .{ .name = "rhs", .type = .i32 },
                },
                .results = &.{.i32},
                .body = &.{
                    .{ .local_get = "lhs" },
                    .{ .local_get = "rhs" },
                    .i32_add,
                },
            },
        },
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
    const module = Module{
        .functions = &.{
            .{
                .name = "add",
                .parameters = &.{
                    .{ .name = "lhs", .type = .i32 },
                    .{ .name = "rhs", .type = .i32 },
                },
                .results = &.{.i32},
                .body = &.{
                    .{ .local_get = "lhs" },
                    .{ .local_get = "rhs" },
                    .i32_add,
                },
            },
        },
        .exports = &.{
            .{ .name = "add", .kind = .{ .function = "add" } },
        },
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
    const module = Module{
        .functions = &.{
            .{
                .name = "add",
                .parameters = &.{
                    .{ .name = "lhs", .type = .i32 },
                    .{ .name = "rhs", .type = .i32 },
                },
                .results = &.{.i32},
                .body = &.{
                    .{ .local_get = "lhs" },
                    .{ .local_get = "rhs" },
                    .i32_add,
                },
            },
        },
        .exports = &.{
            .{ .name = "myAdd", .kind = .{ .function = "add" } },
        },
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
    const module = Module{ .functions = &.{
        .{
            .name = "getAnswer",
            .results = &.{.i32},
            .body = &.{
                .{ .i32_const = 42 },
            },
        },
        .{
            .name = "getAnswerPlus1",
            .results = &.{.i32},
            .body = &.{
                .{ .call = "getAnswer" },
                .{ .i32_const = 1 },
                .i32_add,
            },
        },
    }, .exports = &.{
        .{ .name = "getAnswerPlus1", .kind = .{ .function = "getAnswerPlus1" } },
    } };
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
    const module = Module{
        .imports = &.{
            .{
                .module = "console",
                .name = "log",
                .kind = .{
                    .function = .{ .name = "log", .parameters = &.{.i32} },
                },
            },
        },
        .functions = &.{
            .{
                .name = "logIt",
                .body = &.{
                    .{ .i32_const = 13 },
                    .{ .call = "log" },
                },
            },
        },
        .exports = &.{
            .{ .name = "logIt", .kind = .{ .function = "logIt" } },
        },
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
    const module = Module{
        .imports = &.{
            .{
                .module = "js",
                .name = "global",
                .kind = .{
                    .global = .{ .name = "g", .type = .i32, .mutable = true },
                },
            },
        },
        .functions = &.{
            .{
                .name = "getGlobal",
                .results = &.{.i32},
                .body = &.{
                    .{ .global_get = "g" },
                },
            },
            .{
                .name = "incGlobal",
                .body = &.{
                    .{ .global_get = "g" },
                    .{ .i32_const = 1 },
                    .i32_add,
                    .{ .global_set = "g" },
                },
            },
        },
        .exports = &.{
            .{ .name = "getGlobal", .kind = .{ .function = "getGlobal" } },
            .{ .name = "incGlobal", .kind = .{ .function = "incGlobal" } },
        },
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
    const module = Module{
        .globals = &.{
            .{ .name = "g", .value = .{ .i32 = 42 }, .mutable = true },
        },
        .functions = &.{
            .{
                .name = "getGlobal",
                .results = &.{.i32},
                .body = &.{
                    .{ .global_get = "g" },
                },
            },
            .{
                .name = "incGlobal",
                .body = &.{
                    .{ .global_get = "g" },
                    .{ .i32_const = 1 },
                    .i32_add,
                    .{ .global_set = "g" },
                },
            },
        },
        .exports = &.{
            .{ .name = "getGlobal", .kind = .{ .function = "getGlobal" } },
            .{ .name = "incGlobal", .kind = .{ .function = "incGlobal" } },
        },
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
    const module = Module{
        .globals = &.{
            .{ .name = "g", .value = .{ .i32 = 42 } },
        },
        .functions = &.{
            .{
                .name = "getGlobal",
                .results = &.{.i32},
                .body = &.{
                    .{ .global_get = "g" },
                },
            },
        },
        .exports = &.{
            .{ .name = "getGlobal", .kind = .{ .function = "getGlobal" } },
        },
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
    const module = Module{
        .globals = &.{
            .{ .name = "g", .value = .{ .i32 = 42 }, .mutable = true },
        },
        .functions = &.{
            .{
                .name = "getGlobal",
                .results = &.{.i32},
                .body = &.{
                    .{ .global_get = "g" },
                },
            },
            .{
                .name = "incGlobal",
                .body = &.{
                    .{ .global_get = "g" },
                    .{ .i32_const = 1 },
                    .i32_add,
                    .{ .global_set = "g" },
                },
            },
        },
        .exports = &.{
            .{ .name = "getGlobal", .kind = .{ .function = "getGlobal" } },
            .{ .name = "incGlobal", .kind = .{ .function = "incGlobal" } },
            .{ .name = "g", .kind = .{ .global = "g" } },
        },
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
    const module = Module{
        .imports = &.{
            .{
                .module = "js",
                .name = "log",
                .kind = .{
                    .function = .{ .name = "log", .parameters = &.{ .i32, .i32 } },
                },
            },
            .{ .module = "js", .name = "mem", .kind = .{ .memory = .{ .name = "mem", .initial = 1 } } },
        },
        .datas = &.{
            .{ .offset = 0, .bytes = "Hi" },
        },
        .functions = &.{
            .{
                .name = "writeHi",
                .body = &.{
                    .{ .i32_const = 0 },
                    .{ .i32_const = 2 },
                    .{ .call = "log" },
                },
            },
        },
        .exports = &.{
            .{ .name = "writeHi", .kind = .{ .function = "writeHi" } },
        },
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
    const module = Module{
        .imports = &.{
            .{
                .module = "js",
                .name = "log",
                .kind = .{
                    .function = .{ .name = "log", .parameters = &.{ .i32, .i32 } },
                },
            },
        },
        .memories = &.{
            .{ .name = "mem", .initial = 1 },
        },
        .datas = &.{
            .{ .offset = 0, .bytes = "Hi" },
        },
        .functions = &.{
            .{
                .name = "writeHi",
                .body = &.{
                    .{ .i32_const = 0 },
                    .{ .i32_const = 2 },
                    .{ .call = "log" },
                },
            },
        },
        .exports = &.{
            .{ .name = "writeHi", .kind = .{ .function = "writeHi" } },
        },
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
    const module = Module{
        .imports = &.{
            .{
                .module = "js",
                .name = "log",
                .kind = .{
                    .function = .{ .name = "log", .parameters = &.{ .i32, .i32 } },
                },
            },
        },
        .memories = &.{
            .{ .name = "mem", .initial = 1 },
        },
        .datas = &.{
            .{ .offset = 0, .bytes = "Hi" },
        },
        .functions = &.{
            .{
                .name = "writeHi",
                .body = &.{
                    .{ .i32_const = 0 },
                    .{ .i32_const = 2 },
                    .{ .call = "log" },
                },
            },
        },
        .exports = &.{
            .{ .name = "writeHi", .kind = .{ .function = "writeHi" } },
            .{ .name = "mem", .kind = .{ .memory = "mem" } },
        },
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
    const module = Module{
        .imports = &.{
            .{
                .module = "console",
                .name = "log",
                .kind = .{
                    .function = .{ .name = "log", .parameters = &.{.i32} },
                },
            },
        },
        .functions = &.{
            .{
                .name = "logIt",
                .body = &.{
                    .{ .i32_const = 13 },
                    .{ .call = "log" },
                },
            },
        },
        .start = "logIt",
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
    const module = Module{
        .imports = &.{
            .{
                .module = "console",
                .name = "log",
                .kind = .{
                    .function = .{ .name = "log", .parameters = &.{.i32} },
                },
            },
        },
        .functions = &.{
            .{
                .name = "main",
                .locals = &.{.{ .name = "var", .type = .i32 }},
                .body = &.{
                    .{ .i32_const = 10 },
                    .{ .local_set = "var" },
                    .{ .local_get = "var" },
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
        \\        (local $var i32)
        \\
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
    const module = Module{
        .imports = &.{
            .{
                .module = "console",
                .name = "log",
                .kind = .{
                    .function = .{ .name = "log", .parameters = &.{.i32} },
                },
            },
        },
        .functions = &.{
            .{
                .name = "main",
                .locals = &.{.{ .name = "var", .type = .i32 }},
                .body = &.{
                    .{ .i32_const = 10 },
                    .{ .local_tee = "var" },
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
        \\        (local $var i32)
        \\
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
    const module = Module{
        .imports = &.{
            .{
                .module = "console",
                .name = "log",
                .kind = .{
                    .function = .{ .name = "log", .parameters = &.{.i32} },
                },
            },
        },
        .functions = &.{
            .{
                .name = "main",
                .locals = &.{.{ .name = "i", .type = .i32 }},
                .body = &.{
                    .{
                        .loop = .{
                            .name = "my_loop",
                            .body = &.{
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
        \\        (local $i i32)
        \\
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
    const module = Module{
        .imports = &.{
            .{
                .module = "console",
                .name = "log",
                .kind = .{
                    .function = .{ .name = "log", .parameters = &.{.i32} },
                },
            },
        },
        .functions = &.{
            .{
                .name = "main",
                .body = &.{
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
    const module = Module{
        .imports = &.{
            .{
                .module = "console",
                .name = "log",
                .kind = .{
                    .function = .{ .name = "log", .parameters = &.{.i32} },
                },
            },
        },
        .functions = &.{
            .{
                .name = "log_if_not_100",
                .parameters = &.{.{ .name = "num", .type = .i32 }},
                .body = &.{
                    .{
                        .block = .{
                            .name = "my_block",
                            .body = &.{
                                .{ .local_get = "num" },
                                .{ .i32_const = 100 },
                                .i32_eq,
                                .{
                                    .if_ = .{
                                        .then = &.{
                                            .{ .br = "my_block" },
                                        },
                                    },
                                },
                                .{ .local_get = "num" },
                                .{ .call = "log" },
                            },
                        },
                    },
                },
            },
        },
        .exports = &.{
            .{ .name = "log_if_not_100", .kind = .{ .function = "log_if_not_100" } },
        },
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
