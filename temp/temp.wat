(module

    (func $add (param $lhs i32) (param $rhs i32) (result i32)
        (local.get $lhs)
        (local.get $rhs)
        i32.add)

    (func $start (result i32)
        (i32.const 5)
        (i32.const 10)
        (call $add))

    (export "_start" (func $start)))