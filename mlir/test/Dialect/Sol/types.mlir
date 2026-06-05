// RUN: mlir-opt %s | mlir-opt | FileCheck %s

// Round-trip of sol.struct syntax: the second mlir-opt proves the printed
// form is itself parseable.

// Literal structs keep the original syntax.
// CHECK-LABEL: @literal
// CHECK-SAME: !sol.struct<(i256, i8), Memory>
func.func private @literal(!sol.struct<(i256, i8), Memory>)

// Self-referential identified struct: the inner occurrence prints as a
// name-only back-reference.
// CHECK-LABEL: @self_ref
// CHECK-SAME: !sol.struct<"S", Storage, (i256, !sol.array<? x !sol.struct<"S", Storage>, Storage>)>
func.func private @self_ref(!sol.struct<"S", Storage, (i256, !sol.array<? x !sol.struct<"S", Storage>, Storage>)>)

// A name-only reference to a struct whose body is known prints the full body.
// CHECK-LABEL: @body_from_ref
// CHECK-SAME: !sol.struct<"S", Storage, (i256, !sol.array<? x !sol.struct<"S", Storage>, Storage>)>
func.func private @body_from_ref(!sol.struct<"S", Storage>)

// Re-stating the same body is idempotent.
// CHECK-LABEL: @redefine_same
// CHECK-SAME: !sol.struct<"S", Storage, (i256, !sol.array<? x !sol.struct<"S", Storage>, Storage>)>
func.func private @redefine_same(!sol.struct<"S", Storage, (i256, !sol.array<? x !sol.struct<"S", Storage>, Storage>)>)

// The same name in a different data location is a distinct identified type.
// CHECK-LABEL: @memory_variant
// CHECK-SAME: !sol.struct<"S", Memory, (i256, !sol.array<? x !sol.struct<"S", Memory>, Memory>)>
func.func private @memory_variant(!sol.struct<"S", Memory, (i256, !sol.array<? x !sol.struct<"S", Memory>, Memory>)>)

// An opaque struct (no body anywhere in the module) stays name-only.
// CHECK-LABEL: @opaque
// CHECK-SAME: !sol.struct<"O", Memory>)
func.func private @opaque(!sol.struct<"O", Memory>)

// Mutually recursive structs: "B" prints its full body nested in "A"; the
// reference back to "A" is name-only.
// CHECK-LABEL: @mutual
// CHECK-SAME: !sol.struct<"A", Storage, (i256, !sol.array<? x !sol.struct<"B", Storage, (i256, !sol.array<? x !sol.struct<"A", Storage>, Storage>)>, Storage>)>
func.func private @mutual(!sol.struct<"A", Storage, (i256, !sol.array<? x !sol.struct<"B", Storage, (i256, !sol.array<? x !sol.struct<"A", Storage>, Storage>)>, Storage>)>)

// Recursion through a mapping value type.
// CHECK-LABEL: @map_rec
// CHECK-SAME: !sol.struct<"M", Storage, (i32, !sol.mapping<i8, !sol.struct<"M", Storage>>)>
func.func private @map_rec(!sol.struct<"M", Storage, (i32, !sol.mapping<i8, !sol.struct<"M", Storage>>)>)

// Static storage array sizes are 256-bit: 2^64 and 2^256-1 round-trip.
// CHECK-LABEL: @huge_static_array
// CHECK-SAME: !sol.array<18446744073709551616 x i256, Storage>
func.func private @huge_static_array(!sol.array<18446744073709551616 x i256, Storage>)

// CHECK-LABEL: @max_static_array
// CHECK-SAME: !sol.array<115792089237316195423570985008687907853269984665640564039457584007913129639935 x i256, Storage>
func.func private @max_static_array(!sol.array<115792089237316195423570985008687907853269984665640564039457584007913129639935 x i256, Storage>)

// Transient storage allows huge sizes as well.
// CHECK-LABEL: @huge_transient_array
// CHECK-SAME: !sol.array<18446744073709551616 x i256, Transient>
func.func private @huge_transient_array(!sol.array<18446744073709551616 x i256, Transient>)

// A huge static array of multi-slot elements: a member laid out after it in a
// struct sits beyond 2^64 slots.
// CHECK-LABEL: @huge_member_offset
// CHECK-SAME: !sol.struct<(i256, !sol.array<18446744073709551616 x !sol.array<2 x i256, Storage>, Storage>, i256), Storage>
func.func private @huge_member_offset(!sol.struct<(i256, !sol.array<18446744073709551616 x !sol.array<2 x i256, Storage>, Storage>, i256), Storage>)
