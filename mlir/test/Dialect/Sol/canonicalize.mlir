// RUN: mlir-opt %s -canonicalize | FileCheck %s

// A checked division by a constant that is neither zero nor, for a signed
// type, minus one is the unchecked division.

// CHECK-LABEL: func @by_constant
// CHECK:         sol.div
// CHECK-NOT:     sol.cdiv
func.func @by_constant(%a: ui256) -> ui256 {
  %c = sol.constant 2 : ui256
  %0 = sol.cdiv %a, %c : ui256
  return %0 : ui256
}

// CHECK-LABEL: func @signed_by_constant
// CHECK:         sol.div
// CHECK-NOT:     sol.cdiv
func.func @signed_by_constant(%a: si8) -> si8 {
  %c = sol.constant -2 : si8
  %0 = sol.cdiv %a, %c : si8
  return %0 : si8
}

// CHECK-LABEL: func @unsigned_by_all_ones
// CHECK:         sol.div
// CHECK-NOT:     sol.cdiv
func.func @unsigned_by_all_ones(%a: ui8) -> ui8 {
  %c = sol.constant 255 : ui8
  %0 = sol.cdiv %a, %c : ui8
  return %0 : ui8
}

// CHECK-LABEL: func @by_zero
// CHECK:         sol.cdiv
func.func @by_zero(%a: ui256) -> ui256 {
  %c = sol.constant 0 : ui256
  %0 = sol.cdiv %a, %c : ui256
  return %0 : ui256
}

// CHECK-LABEL: func @signed_by_minus_one
// CHECK:         sol.cdiv
func.func @signed_by_minus_one(%a: si256) -> si256 {
  %c = sol.constant -1 : si256
  %0 = sol.cdiv %a, %c : si256
  return %0 : si256
}

// CHECK-LABEL: func @by_variable
// CHECK:         sol.cdiv
func.func @by_variable(%a: ui256, %b: ui256) -> ui256 {
  %0 = sol.cdiv %a, %b : ui256
  return %0 : ui256
}

// An identity folds, checked or not.

// CHECK-LABEL: func @identities
// CHECK-SAME:  (%[[A:.*]]: ui256)
// CHECK-NEXT:    %[[Z:.*]] = sol.constant 0 : ui256
// CHECK-NEXT:    return %[[A]], %[[A]], %[[Z]], %[[Z]], %[[A]], %[[A]], %[[A]], %[[A]], %[[Z]], %[[Z]], %[[A]], %[[A]]
func.func @identities(%a: ui256) -> (ui256, ui256, ui256, ui256, ui256, ui256, ui256, ui256, ui256, ui256, ui256, ui256) {
  %c0 = sol.constant 0 : ui256
  %c1 = sol.constant 1 : ui256
  %0 = sol.cadd %a, %c0 : ui256
  %1 = sol.csub %a, %c0 : ui256
  %2 = sol.csub %a, %a : ui256
  %3 = sol.cmul %a, %c0 : ui256
  %4 = sol.cmul %a, %c1 : ui256
  %5 = sol.cdiv %a, %c1 : ui256
  %6 = sol.add %a, %c0 : ui256
  %7 = sol.sub %a, %c0 : ui256
  %8 = sol.sub %a, %a : ui256
  %9 = sol.mul %a, %c0 : ui256
  %10 = sol.mul %a, %c1 : ui256
  %11 = sol.div %a, %c1 : ui256
  return %0, %1, %2, %3, %4, %5, %6, %7, %8, %9, %10, %11 : ui256, ui256, ui256, ui256, ui256, ui256, ui256, ui256, ui256, ui256, ui256, ui256
}

// A constant on the left of a commutative op moves right first.
// CHECK-LABEL: func @left_identity
// CHECK-SAME:  (%[[A:.*]]: ui256)
// CHECK-NEXT:    return %[[A]]
func.func @left_identity(%a: ui256) -> ui256 {
  %c0 = sol.constant 0 : ui256
  %0 = sol.cadd %c0, %a : ui256
  return %0 : ui256
}

// Two constants fold when the result fits the type.

// CHECK-LABEL: func @checked_in_range
// CHECK-NEXT:    %[[C255:.*]] = sol.constant 255 : ui8
// CHECK-NEXT:    %[[C240:.*]] = sol.constant 240 : ui8
// CHECK-NEXT:    %[[C50:.*]] = sol.constant 50 : ui8
// CHECK-NEXT:    %[[C25:.*]] = sol.constant 25 : ui8
// CHECK-NEXT:    %[[CM128:.*]] = sol.constant -128 : si8
// CHECK-NEXT:    return %[[C255]], %[[C240]], %[[C50]], %[[C25]], %[[CM128]]
func.func @checked_in_range() -> (ui8, ui8, ui8, ui8, si8) {
  %c250 = sol.constant 250 : ui8
  %c5 = sol.constant 5 : ui8
  %c10 = sol.constant 10 : ui8
  %c2 = sol.constant 2 : ui8
  %c64 = sol.constant 64 : si8
  %cm2 = sol.constant -2 : si8
  %0 = sol.cadd %c250, %c5 : ui8
  %1 = sol.csub %c250, %c10 : ui8
  %2 = sol.cmul %c5, %c10 : ui8
  %3 = sol.cdiv %c250, %c10 : ui8
  %4 = sol.cmul %c64, %cm2 : si8
  return %0, %1, %2, %3, %4 : ui8, ui8, ui8, ui8, si8
}

// A result out of range keeps the checked op, which panics.

// CHECK-LABEL: func @checked_out_of_range
// CHECK:         sol.cadd
// CHECK:         sol.csub
// CHECK:         sol.cmul
// CHECK:         sol.cmul
// CHECK:         sol.cdiv
// CHECK:         sol.cdiv
func.func @checked_out_of_range() -> (ui8, ui8, ui8, si8, si8, ui8) {
  %c250 = sol.constant 250 : ui8
  %c10 = sol.constant 10 : ui8
  %c0 = sol.constant 0 : ui8
  %cmin = sol.constant -128 : si8
  %cm1 = sol.constant -1 : si8
  %0 = sol.cadd %c250, %c10 : ui8
  %1 = sol.csub %c10, %c250 : ui8
  %2 = sol.cmul %c250, %c10 : ui8
  %3 = sol.cmul %cmin, %cm1 : si8
  %4 = sol.cdiv %cmin, %cm1 : si8
  %5 = sol.cdiv %c250, %c0 : ui8
  return %0, %1, %2, %3, %4, %5 : ui8, ui8, ui8, si8, si8, ui8
}

// The unchecked ops wrap; a division by zero stays, it panics.

// CHECK-LABEL: func @unchecked
// CHECK-NEXT:    %[[C0:.*]] = sol.constant 0 : ui8
// CHECK-NEXT:    %[[C4:.*]] = sol.constant 4 : ui8
// CHECK-NEXT:    %[[C16:.*]] = sol.constant 16 : ui8
// CHECK-NEXT:    %[[C196:.*]] = sol.constant 196 : ui8
// CHECK-NEXT:    %[[CM128:.*]] = sol.constant -128 : si8
// CHECK-NEXT:    %[[DIV:.*]] = sol.div %[[C4]], %[[C0]]
// CHECK-NEXT:    return %[[C4]], %[[C16]], %[[C196]], %[[CM128]], %[[DIV]]
func.func @unchecked() -> (ui8, ui8, ui8, si8, ui8) {
  %c250 = sol.constant 250 : ui8
  %c10 = sol.constant 10 : ui8
  %c0 = sol.constant 0 : ui8
  %cmin = sol.constant -128 : si8
  %cm1 = sol.constant -1 : si8
  %0 = sol.add %c250, %c10 : ui8
  %1 = sol.sub %c10, %c250 : ui8
  %2 = sol.mul %c250, %c10 : ui8
  %3 = sol.div %cmin, %cm1 : si8
  %4 = sol.div %0, %c0 : ui8
  return %0, %1, %2, %3, %4 : ui8, ui8, ui8, si8, ui8
}
