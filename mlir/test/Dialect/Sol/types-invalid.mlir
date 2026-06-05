// RUN: mlir-opt %s -split-input-file -verify-diagnostics

// Two different bodies for the same identified struct.
// expected-error @below {{conflicting body for identified struct 'C'}}
func.func private @conflict(!sol.struct<"C", Storage, (i256)>, !sol.struct<"C", Storage, (i8)>)

// -----

// A body nested inside the struct's own body definition (the printer only
// emits name-only back-references there).
// expected-error @below {{identifier 'S' already used for an enclosing struct}}
func.func private @nested_redefinition(!sol.struct<"S", Storage, (!sol.struct<"S", Storage, (i256)>)>)

// -----

// A direct self-member cannot be laid out: the recursion has no
// cycle-breaking member.
// expected-error @below {{member of identified struct 'D' directly embeds opaque struct 'D' (a recursive reference must go through a cycle-breaking member such as a dynamic array or mapping)}}
func.func private @direct_self_member(!sol.struct<"D", Storage, (i256, !sol.struct<"D", Storage>)>)

// -----

// A fixed-size array does not break the cycle either: its footprint depends
// on the element layout.
// expected-error @below {{member of identified struct 'F' directly embeds opaque struct 'F'}}
func.func private @fixed_array_self_member(!sol.struct<"F", Storage, (!sol.array<2 x !sol.struct<"F", Storage>, Storage>)>)

// -----

// The same applies to opaque structs embedded in literal struct members.
// expected-error @below {{literal struct member directly embeds opaque struct 'Q'}}
func.func private @literal_opaque_member(!sol.struct<(!sol.struct<"Q", Storage>), Storage>)

// -----

// Sizes above 2^64-1 are only representable for storage/transient arrays.
// expected-error @below {{array size exceeds uint64 for non-storage array}}
func.func private @huge_memory_array(!sol.array<18446744073709551616 x i256, Memory>)
