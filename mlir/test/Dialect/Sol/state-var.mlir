// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// CHECK: sol.state_var @a slot 0 offset 0 : !sol.string<Storage>
sol.state_var @a slot 0 offset 0 : !sol.string<Storage>
// CHECK: sol.state_var @b transient slot 1 offset 2 : ui8
sol.state_var @b transient slot 1 offset 2 : ui8
// CHECK: sol.state_var @c slot 340282366920938463463374607431768211457 offset 31 {foo} : ui8
sol.state_var @c slot 340282366920938463463374607431768211457 offset 31 {foo} : ui8
